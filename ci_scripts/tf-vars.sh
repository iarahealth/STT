#!/bin/bash

set -ex

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)
CI_TASK_DIR=${CI_TASK_DIR:-${ROOT_DIR}}

# /tmp/artifacts for docker-worker on linux,
# and task subdir for generic-worker on osx
export CI_ARTIFACTS_DIR=${CI_ARTIFACTS_DIR:-/tmp/artifacts}

export OS=$(uname)
if [ "${OS}" = "Linux" ]; then
    export DS_ROOT_TASK=${CI_TASK_DIR}

    BAZEL_URL=https://github.com/bazelbuild/bazelisk/releases/download/v1.10.1/bazelisk-linux-amd64
    BAZEL_SHA256=4cb534c52cdd47a6223d4596d530e7c9c785438ab3b0a49ff347e991c210b2cd

    ANDROID_NDK_URL=https://dl.google.com/android/repository/android-ndk-r19c-linux-x86_64.zip
    ANDROID_NDK_SHA256=4c62514ec9c2309315fd84da6d52465651cdb68605058f231f1e480fcf2692e1

    ANDROID_SDK_URL=https://dl.google.com/android/repository/sdk-tools-linux-4333796.zip
    ANDROID_SDK_SHA256=92ffee5a1d98d856634e8b71132e8a95d96c83a63fde1099be3d86df3106def9

    WGET=/usr/bin/wget
elif [ "${OS}" = "${CI_MSYS_VERSION}" ]; then
    if [ -z "${CI_TASK_DIR}" -o -z "${CI_ARTIFACTS_DIR}" ]; then
        echo "Inconsistent Windows setup: missing some vars."
        echo "CI_TASK_DIR=${CI_TASK_DIR}"
        echo "CI_ARTIFACTS_DIR=${CI_ARTIFACTS_DIR}"
        exit 1
    fi;

    # Re-export with cygpath to make sure it is sane, otherwise it might trigger
    # unobvious failures with cp etc.
    export CI_TASK_DIR="$(cygpath ${CI_TASK_DIR})"
    export CI_ARTIFACTS_DIR="$(cygpath ${CI_ARTIFACTS_DIR})"

    export DS_ROOT_TASK=${CI_TASK_DIR}
    export BAZEL_VC="C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC"
    export MSYS2_ARG_CONV_EXCL='//'

    # Fix to MSYS make to avoid conflicts with mingw32-make in PATH
    export MAKE="/usr/bin/make"

    mkdir -p ${CI_TASK_DIR}/tmp/
    export TEMP=${CI_TASK_DIR}/tmp/
    export TMP=${CI_TASK_DIR}/tmp/

    BAZEL_URL=https://github.com/bazelbuild/bazelisk/releases/download/v1.10.1/bazelisk-windows-amd64.exe
    BAZEL_SHA256=9a89e6a8cc0a3aea37affcf8c146d8925ffbda1d2290c0c6a845ea81e05de62c

    TAR=/usr/bin/tar.exe
elif [ "${OS}" = "Darwin" ]; then
    if [ -z "${CI_TASK_DIR}" -o -z "${CI_ARTIFACTS_DIR}" ]; then
        echo "Inconsistent OSX setup: missing some vars."
        echo "CI_TASK_DIR=${CI_TASK_DIR}"
        echo "CI_ARTIFACTS_DIR=${CI_ARTIFACTS_DIR}"
        exit 1
    fi;

    export DS_ROOT_TASK=${CI_TASK_DIR}

    ARCH="$(uname -m)"
    if [ "${ARCH}" = "arm64" ]; then
        BAZEL_URL=https://github.com/bazelbuild/bazelisk/releases/download/v1.10.1/bazelisk-darwin-arm64
        BAZEL_SHA256=c22d48601466d9d3b043ccd74051f2f4230f9b9f4509f097017c97303aa88d13
    else
        BAZEL_URL=https://github.com/bazelbuild/bazelisk/releases/download/v1.10.1/bazelisk-darwin-amd64
        BAZEL_SHA256=e485bbf84532d02a60b0eb23c702610b5408df3a199087a4f2b5e0995bbf2d5a
    fi

    SHA_SUM="shasum -a 256 -c"
    TAR=gtar
fi;

MAKE=${MAKE:-"make"}
WGET=${WGET:-"wget"}
CURL=${CURL:-"curl"}
TAR=${TAR:-"tar"}
XZ=${XZ:-"xz -9 -T0"}
ZIP=${ZIP:-"zip"}
UNXZ=${UNXZ:-"xz -T0 -d"}
UNGZ=${UNGZ:-"gunzip"}
SHA_SUM=${SHA_SUM:-"sha256sum -c --strict"}

### Define variables that needs to be exported to other processes

PATH=${DS_ROOT_TASK}/bin:$PATH
if [ "${OS}" = "Darwin" ]; then
    PATH=${DS_ROOT_TASK}/homebrew/bin/:${DS_ROOT_TASK}/homebrew/opt/node@10/bin:$PATH
fi;
export PATH

if [ "${OS}" = "Linux" ]; then
    export ANDROID_SDK_HOME=${DS_ROOT_TASK}/STT/Android/SDK/
    export ANDROID_NDK_HOME=${DS_ROOT_TASK}/STT/Android/android-ndk-r19c/
fi;

export TF_ENABLE_XLA=0
export TF_DOWNLOAD_CLANG=0
export TF_SET_ANDROID_WORKSPACE=0
export TF_NEED_TENSORRT=0
export TF_NEED_ROCM=0
export TF_NEED_CUDA=0

## Below, define or export some build variables

if [ "${OS}" != "${CI_MSYS_VERSION}" ]; then
    BAZEL_EXTRA_FLAGS="--config=noaws --config=nogcp --config=nohdfs --config=nonccl"
fi

if [ "${OS}" = "${CI_MSYS_VERSION}" ]; then
    if [ "${DISABLE_AVX}" = "true" ]; then
        BAZEL_OPT_FLAGS=""
    else
        BAZEL_OPT_FLAGS="--copt=/arch:AVX"
    fi
elif [ "${OS}" = "Darwin" ]; then
    FROM="$(uname | tr '[:upper:]' '[:lower:]')-$(uname -m)"
    if [ "$SYSTEM_TARGET" = "host" ]; then
        TO="$FROM"
    else
        TO="$SYSTEM_TARGET"
    fi

    if [ "$FROM" = "darwin-x86_64" -a "$TO" = "darwin-x86_64" ]; then
        if [ "${DISABLE_AVX}" = "true" ]; then
            BAZEL_OPT_FLAGS="--copt=-mtune=generic --copt=-march=x86-64 --copt=-msse --copt=-msse2 --copt=-msse3 --copt=-msse4.1 --copt=-msse4.2"
        else
            BAZEL_OPT_FLAGS="--copt=-mtune=generic --copt=-march=x86-64 --copt=-msse --copt=-msse2 --copt=-msse3 --copt=-msse4.1 --copt=-msse4.2 --copt=-mavx"
        fi

        if [ "${CI}" = true ]; then
            BAZEL_EXTRA_FLAGS="${BAZEL_EXTRA_FLAGS} --macos_minimum_os 10.10 --macos_sdk_version 14.2"
        fi
    elif [ "$FROM" = "darwin-x86_64" -a "$TO" = "darwin-arm64" ]; then
        BAZEL_OPT_FLAGS=""
        if [ "${CI}" = true ]; then
            BAZEL_EXTRA_FLAGS="--config=macos_arm64 --xcode_version 15.2 --macos_minimum_os 11.0 --macos_sdk_version 14.2"
        fi
    elif [ "$FROM" = "darwin-arm64" -a "$TO" = "darwin-arm64" ]; then
        BAZEL_OPT_FLAGS="--xcode_version 15.2 --macos_minimum_os 11.0 --macos_sdk_version 14.2"
    elif [ "$FROM" = "darwin-arm64" -a "$TO" = "darwin-x86_64" ]; then
        echo "TensorFlow does not support building for x86_64 on arm64" 1>&2
        exit 1
    fi
else
    # Enable some SIMD support. Limit ourselves to what Tensorflow needs.
    # Also ensure to not require too recent CPU: AVX2/FMA introduced by:
    #  - Intel with Haswell (2013)
    #  - AMD with Excavator (2015)
    # For better compatibility, AVX ony might be better.
    #
    # Build for generic amd64 platforms, no device-specific optimization
    # See https://gcc.gnu.org/onlinedocs/gcc/x86-Options.html for targetting specific CPUs
    BAZEL_OPT_FLAGS="--copt=-mtune=generic --copt=-march=x86-64 --copt=-msse --copt=-msse2 --copt=-msse3 --copt=-msse4.1 --copt=-msse4.2 --copt=-mavx"
fi

if [ "$CI" != "true" ]; then
    BAZEL_CACHE=""
fi
