.. _training-flags:

Command-line flags for the training scripts
===========================================

Below you can find the definition of all command-line flags supported by the training modules. This includes the modules ``iara_stt_training.train``, ``iara_stt_training.evaluate``, ``iara_stt_training.export``, ``iara_stt_training.training_graph_inference``, and the scripts ``evaluate_tflite.py``, ``transcribe.py`` and ``lm_optimizer.py``.

Flags
-----

.. literalinclude:: ../training/iara_stt_training/util/config.py
   :language: python
   :start-after: sphinx-doc: training_ref_flags_start
   :end-before: sphinx-doc: training_ref_flags_end
