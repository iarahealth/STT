# Copyright 2018 The TensorFlow Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Image warping using per-pixel flow vectors.

Port of tf.contrib.image.dense_image_warp, which TensorFlow 2 removed.
The spectrogram Warp augmentation depends on this exact sampling.
"""

import tensorflow as tf


def _interpolate_bilinear(grid, query_points, indexing="ij"):
    if indexing not in ("ij", "xy"):
        raise ValueError("Indexing mode must be 'ij' or 'xy'")

    grid = tf.convert_to_tensor(grid)
    query_points = tf.convert_to_tensor(query_points)
    if grid.shape.rank != 4:
        raise ValueError("Grid must be 4 dimensional. Received %s" % grid.shape)

    batch_size = tf.shape(grid)[0]
    height = tf.shape(grid)[1]
    width = tf.shape(grid)[2]
    channels = tf.shape(grid)[3]
    shape = [batch_size, height, width, channels]
    query_type = query_points.dtype
    grid_type = grid.dtype
    num_queries = tf.shape(query_points)[1]

    alphas = []
    floors = []
    ceils = []
    index_order = [0, 1] if indexing == "ij" else [1, 0]
    unstacked_query_points = tf.unstack(query_points, axis=2)

    for dim in index_order:
        queries = unstacked_query_points[dim]
        size_in_indexing_dimension = shape[dim + 1]
        max_floor = tf.cast(size_in_indexing_dimension - 2, query_type)
        floor = tf.minimum(tf.maximum(tf.zeros([], query_type), tf.floor(queries)), max_floor)
        int_floor = tf.cast(floor, tf.int32)
        floors.append(int_floor)
        ceils.append(int_floor + 1)
        alpha = tf.cast(queries - floor, grid_type)
        alpha = tf.clip_by_value(alpha, tf.zeros([], grid_type), tf.ones([], grid_type))
        alphas.append(tf.expand_dims(alpha, 2))

    flattened_grid = tf.reshape(grid, [batch_size * height * width, channels])
    batch_offsets = tf.reshape(tf.range(batch_size) * height * width, [batch_size, 1])

    def gather(y_coords, x_coords):
        linear_coordinates = batch_offsets + y_coords * width + x_coords
        gathered_values = tf.gather(flattened_grid, linear_coordinates)
        return tf.reshape(gathered_values, [batch_size, num_queries, channels])

    top_left = gather(floors[0], floors[1])
    top_right = gather(floors[0], ceils[1])
    bottom_left = gather(ceils[0], floors[1])
    bottom_right = gather(ceils[0], ceils[1])

    interp_top = alphas[1] * (top_right - top_left) + top_left
    interp_bottom = alphas[1] * (bottom_right - bottom_left) + bottom_left
    return alphas[0] * (interp_bottom - interp_top) + interp_top


def dense_image_warp(image, flow):
    """Warp `image` with a dense flow field. Same contract as tf.contrib.image."""
    batch_size = tf.shape(image)[0]
    height = tf.shape(image)[1]
    width = tf.shape(image)[2]
    channels = tf.shape(image)[3]

    grid_x, grid_y = tf.meshgrid(tf.range(width), tf.range(height))
    stacked_grid = tf.cast(tf.stack([grid_y, grid_x], axis=2), flow.dtype)
    query_points_on_grid = tf.expand_dims(stacked_grid, axis=0) - flow
    query_points_flattened = tf.reshape(
        query_points_on_grid, [batch_size, height * width, 2]
    )
    interpolated = _interpolate_bilinear(image, query_points_flattened)
    return tf.reshape(interpolated, [batch_size, height, width, channels])
