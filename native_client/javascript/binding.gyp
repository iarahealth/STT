{
    "targets": [
        {
            "target_name": "stt",
            "sources": ["stt_wrap.cxx"],
            "libraries": [],
            "include_dirs": ["../"],
            "cflags_cc": [ "-std=c++17" ],
            "conditions": [
                [
                    "OS=='mac'",
                    {
                        "xcode_settings": {
                            "CLANG_CXX_LIBRARY": "libc++",
                            "CLANG_CXX_LANGUAGE_STANDARD":"c++17",
                            "OTHER_CXXFLAGS": [
                                "-mmacosx-version-min=10.10",
                            ],
                            "OTHER_LDFLAGS": [
                                "-mmacosx-version-min=10.10",
                            ],
                        }
                    },
                ],
                [
                    "OS=='win'",
                    {
                        "msvs_settings": {
                            "VCCLCompilerTool": {
                                "AdditionalOptions": ["/std:c++17"]
                            }
                        },
                        "libraries": [
                            "../../../tensorflow/bazel-bin/native_client/libstt.so.if.lib",
                            "../../../tensorflow/bazel-bin/native_client/libkenlm.so.if.lib",
                        ],
                    },
                    {
                        "libraries": [
                            "../../../tensorflow/bazel-bin/native_client/libstt.so",
                            "../../../tensorflow/bazel-bin/native_client/libkenlm.so",
                        ],
                    },
                ],
            ],
        },
        {
            "target_name": "action_after_build",
            "type": "none",
            "dependencies": ["<(module_name)"],
            "copies": [
                {
                    "files": ["<(PRODUCT_DIR)/<(module_name).node"],
                    "destination": "<(module_path)",
                }
            ],
        },
    ],
    "variables": {
        "build_v8_with_gn": 0,
        "openssl_fips": "",
        "v8_enable_pointer_compression": 0,
        "v8_enable_31bit_smis_on_64bit_arch": 0,
        "enable_lto": 1,
    },
}
