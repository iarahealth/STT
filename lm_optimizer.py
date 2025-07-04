#!/usr/bin/env python
# -*- coding: utf-8 -*-
from __future__ import absolute_import, division, print_function

if __name__ == "__main__":
    print(
        "Using the top level lm_optimizer.py script is deprecated and will be removed "
        "in a future release. Instead use: python -m iara_stt_training.util.lm_optimize"
    )
    try:
        from iara_stt_training.util import lm_optimize
    except ImportError:
        print("Training package is not installed. See training documentation.")
        raise

    lm_optimize.main()
