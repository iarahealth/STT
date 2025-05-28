#!/bin/bash

set -xe

macos_target_arch=$1
DISABLE_AVX=$2
SYSTEM_TARGET=host

if [ "${macos_target_arch}" = "arm64" ]; then
  SYSTEM_TARGET="darwin-arm64"
fi

source $(dirname "$0")/all-vars.sh
source $(dirname "$0")/all-utils.sh
source $(dirname "$0")/build-utils.sh

source $(dirname "$0")/tf-vars.sh

BAZEL_TARGETS="
//native_client:libstt.so
//native_client:libkenlm.so
//native_client:generate_scorer_package
"

BAZEL_BUILD_FLAGS="${BAZEL_OPT_FLAGS} ${BAZEL_EXTRA_FLAGS}"

if [ "${macos_target_arch}" = "arm64" ]; then
  BAZEL_BUILD_FLAGS="${BAZEL_BUILD_FLAGS} --config=darwin-arm64"
fi

do_bazel_build

do_stt_binary_build
