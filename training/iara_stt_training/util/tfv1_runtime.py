"""Turn on the TensorFlow 1 graph runtime used by the trainer."""

_ENABLED = False


def enable_tf1_runtime():
    """Disable TensorFlow 2 eager execution so placeholders and sessions work."""
    global _ENABLED
    if _ENABLED:
        return
    import tensorflow.compat.v1 as tfv1

    tfv1.disable_v2_behavior()
    _ENABLED = True
