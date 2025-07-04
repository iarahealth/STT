NC_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

TARGET    ?= host
ROOT_DIR  ?= $(abspath $(NC_DIR)/..)
TFDIR     ?= $(abspath $(NC_DIR)/../tensorflow)
PREFIX    ?= /usr/local
SO_SEARCH ?= $(TFDIR)/bazel-bin/

TOOL_AS   := as
TOOL_CC   := gcc
TOOL_CXX  := c++
TOOL_LD   := ld
TOOL_LDD  := ldd
TOOL_LIBEXE :=

OS        := $(shell uname -s)

ifeq ($(findstring _NT,$(OS)),_NT)
PLATFORM_EXE_SUFFIX := .exe
endif

STT_BIN       := stt$(PLATFORM_EXE_SUFFIX)
CFLAGS_STT    := -std=c++11 -o $(STT_BIN)
LINK_STT      := -lstt -lkenlm
LINK_PATH_STT := -L${TFDIR}/bazel-bin/native_client -L${TFDIR}/bazel-bin/tensorflow/lite

ifeq ($(TARGET),host)
TOOLCHAIN       :=
CFLAGS          :=
CXXFLAGS        :=
LDFLAGS         :=
SOX_CFLAGS      := -I$(ROOT_DIR)/sox-build/include
ifeq ($(OS),Linux)
LINK_STT := $(LINK_STT) -llzma -lbz2
SOX_LDFLAGS     := -L$(ROOT_DIR)/sox-build/lib -lsox
else ifeq ($(OS),Darwin)
CFLAGS                  := -mmacosx-version-min=10.10 -target x86_64-apple-macos10.10
LDFLAGS                 := -mmacosx-version-min=10.10 -target x86_64-apple-macos10.10

SOX_CFLAGS              := $(shell pkg-config --cflags sox)
SOX_LDFLAGS             := $(shell pkg-config --libs sox) -framework CoreAudio -lz
else
SOX_LDFLAGS     := `pkg-config --libs sox`
endif # OS others
PYTHON_PACKAGES := numpy${NUMPY_BUILD_VERSION}
ifeq ($(OS),Linux)
PYTHON_PLATFORM_NAME ?= --plat-name manylinux_2_24_x86_64
endif
endif

ifeq ($(findstring _NT,$(OS)),_NT)
TOOLCHAIN := '$(VCToolsInstallDir)\bin\Hostx64\x64\'
TOOL_CC     := cl.exe
TOOL_CXX    := cl.exe
TOOL_LD     := link.exe
TOOL_LIBEXE := lib.exe
LINK_STT      := $(shell cygpath "$(TFDIR)/bazel-bin/native_client/libstt.so.if.lib") $(shell cygpath "$(TFDIR)/bazel-bin/native_client/libkenlm.so.if.lib")
LINK_PATH_STT :=
CFLAGS_STT    := -nologo -Fe$(STT_BIN)
SOX_CFLAGS      :=
SOX_LDFLAGS     :=
PYTHON_PACKAGES := numpy${NUMPY_BUILD_VERSION}
endif

ifeq ($(TARGET),rpi3)
PYVER := $(shell python -c "import platform; maj, min, _ = platform.python_version_tuple(); print(maj+'.'+min);")
ifeq ($(PYVER), 3.7)
RASPBIAN    ?= $(abspath $(NC_DIR)/../multistrap-raspbian-buster)
NUMPY_INCLUDE        := NUMPY_INCLUDE=$(RASPBIAN)/usr/include/python$(PYVER)m/
PYTHON_SYSCONFIGDATA := _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata_m_linux_arm-linux-gnueabihf
else
RASPBIAN    ?= $(abspath $(NC_DIR)/../multistrap-raspbian-bullseye)
NUMPY_INCLUDE        := NUMPY_INCLUDE=$(RASPBIAN)/usr/include/python$(PYVER)/
PYTHON_SYSCONFIGDATA := _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata__linux_arm-linux-gnueabihf
endif

TOOLCHAIN_DIR ?= ${TFDIR}/bazel-$(shell basename "${TFDIR}")/external/armhf_linux_toolchain
TOOLCHAIN   ?= $(TOOLCHAIN_DIR)/bin/arm-linux-gnueabihf-
# -D_XOPEN_SOURCE -D_FILE_OFFSET_BITS=64 => to avoid EOVERFLOW on readdir() with 64-bits inode
CFLAGS      := -march=armv7-a -mtune=cortex-a53 -mfpu=neon-fp-armv8 -mfloat-abi=hard -D_GLIBCXX_USE_CXX11_ABI=0 -D_XOPEN_SOURCE -D_FILE_OFFSET_BITS=64 -isystem $(TOOLCHAIN_DIR)/lib/gcc/arm-linux-gnueabihf/8.3.0/include -isystem $(TOOLCHAIN_DIR)/lib/gcc/arm-linux-gnueabihf/8.3.0/include-fixed -isystem $(TOOLCHAIN_DIR)/arm-linux-gnueabihf/include/c++/8.3.0/ -isystem $(TOOLCHAIN_DIR)/arm-linux-gnueabihf/libc/usr/include/ -isystem $(RASPBIAN)/usr/include -isystem /usr/include -no-canonical-prefixes -fno-canonical-system-headers
CXXFLAGS    := $(CFLAGS)
LDFLAGS     := -Wl,-rpath-link,$(RASPBIAN)/lib/arm-linux-gnueabihf/ -Wl,-rpath-link,$(RASPBIAN)/usr/lib/arm-linux-gnueabihf/

SOX_CFLAGS  :=
SOX_LDFLAGS := $(RASPBIAN)/usr/lib/arm-linux-gnueabihf/libsox.so

PYTHON_PACKAGES      :=
PYTHON_PATH          := PYTHONPATH=$(RASPBIAN)/usr/lib/python$(PYVER)/:$(RASPBIAN)/usr/lib/python3/dist-packages/
PYTHON_PLATFORM_NAME := --plat-name linux_armv7l
NODE_PLATFORM_TARGET := --target_arch=arm --target_platform=linux
TOOLCHAIN_LDD_OPTS   := --root $(RASPBIAN)/
endif # ($(TARGET),rpi3)

ifeq ($(TARGET),rpi3-armv8)
PYVER := $(shell python -c "import platform; maj, min, _ = platform.python_version_tuple(); print(maj+'.'+min);")
ifeq ($(PYVER), 3.7)
RASPBIAN    ?= $(abspath $(NC_DIR)/../multistrap-raspbian64-buster)
NUMPY_INCLUDE        := NUMPY_INCLUDE=$(RASPBIAN)/usr/include/python$(PYVER)m/
PYTHON_SYSCONFIGDATA := _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata_m_linux_aarch64-linux-gnu
else
RASPBIAN    ?= $(abspath $(NC_DIR)/../multistrap-raspbian64-bullseye)
NUMPY_INCLUDE        := NUMPY_INCLUDE=$(RASPBIAN)/usr/include/python$(PYVER)/
PYTHON_SYSCONFIGDATA := _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata__linux_aarch64-linux-gnu
endif

TOOLCHAIN_DIR ?= ${TFDIR}/bazel-$(shell basename "${TFDIR}")/external/aarch64_linux_toolchain
TOOLCHAIN   ?= $(TOOLCHAIN_DIR)/bin/aarch64-linux-gnu-
CFLAGS      := -march=armv8-a -mtune=cortex-a53 -D_GLIBCXX_USE_CXX11_ABI=0 -isystem $(TOOLCHAIN_DIR)/lib/gcc/aarch64-linux-gnu/8.3.0/include -isystem $(TOOLCHAIN_DIR)/lib/gcc/aarch64-linux-gnu/8.3.0/include-fixed -isystem $(TOOLCHAIN_DIR)/aarch64-linux-gnu/include/c++/8.3.0/ -isystem $(TOOLCHAIN_DIR)/aarch64-linux-gnu/libc/usr/include/ -isystem $(RASPBIAN)/usr/include -isystem /usr/include/ -no-canonical-prefixes -fno-canonical-system-headers
CXXFLAGS    := $(CFLAGS)
LDFLAGS     := -Wl,-rpath-link,$(RASPBIAN)/lib/aarch64-linux-gnu/ -Wl,-rpath-link,$(RASPBIAN)/usr/lib/aarch64-linux-gnu/

SOX_CFLAGS  :=
SOX_LDFLAGS := $(RASPBIAN)/usr/lib/aarch64-linux-gnu/libsox.so

PYTHON_PACKAGES      :=
PYTHON_PATH          := PYTHONPATH=$(RASPBIAN)/usr/lib/python$(PYVER)/:$(RASPBIAN)/usr/lib/python3/dist-packages/
PYTHON_PLATFORM_NAME := --plat-name linux_aarch64
NODE_PLATFORM_TARGET := --target_arch=arm64 --target_platform=linux
TOOLCHAIN_LDD_OPTS   := --root $(RASPBIAN)/
endif # ($(TARGET),rpi3-armv8)

ifeq ($(TARGET),ios-simulator)
CFLAGS          := -isysroot $(shell xcrun -sdk iphonesimulator13.5 -show-sdk-path)
SOX_CFLAGS      :=
SOX_LDFLAGS     :=
LDFLAGS         :=
endif

ifeq ($(TARGET),ios-arm64)
CFLAGS          := -target arm64-apple-ios -isysroot $(shell xcrun -sdk iphoneos13.5 -show-sdk-path)
SOX_CFLAGS      :=
SOX_LDFLAGS     :=
LDFLAGS         :=
endif

ifeq ($(TARGET),darwin-arm64)
CFLAGS                  := -mmacosx-version-min=11.0 -target arm64-apple-macos11
LDFLAGS                 := -mmacosx-version-min=11.0 -target arm64-apple-macos11

SOX_CFLAGS              := $(shell pkg-config --cflags sox)
SOX_LDFLAGS             := $(shell pkg-config --libs sox) -framework CoreAudio -lz
endif

# -Wl,--no-as-needed is required to force linker not to evict libs it thinks we
# dont need ; will fail the build on OSX because that option does not exists
ifeq ($(OS),Linux)
LDFLAGS_NEEDED := -Wl,--no-as-needed
LDFLAGS_RPATH  := -Wl,-rpath,\$$ORIGIN
endif
ifeq ($(OS),Darwin)
CXXFLAGS       += -stdlib=libc++ -std=c++17
LDFLAGS_NEEDED := -stdlib=libc++ -std=c++17
LDFLAGS_RPATH  := -Wl,-rpath,@executable_path
endif

CFLAGS   += $(EXTRA_CFLAGS)
CXXFLAGS += $(EXTRA_CXXFLAGS)
LIBS     := $(LINK_STT) $(EXTRA_LIBS)
LDFLAGS_DIRS := $(LINK_PATH_STT) $(EXTRA_LDFLAGS)
LDFLAGS  += $(LDFLAGS_NEEDED) $(LDFLAGS_RPATH) $(LDFLAGS_DIRS) $(LIBS)

AS      := $(TOOLCHAIN)$(TOOL_AS)
CC      := $(TOOLCHAIN)$(TOOL_CC)
CXX     := $(TOOLCHAIN)$(TOOL_CXX)
LD      := $(TOOLCHAIN)$(TOOL_LD)
LDD     := $(TOOLCHAIN)$(TOOL_LDD) $(TOOLCHAIN_LDD_OPTS)
LIBEXE  := $(TOOLCHAIN)$(TOOL_LIBEXE)

RPATH_PYTHON         := '-Wl,-rpath,\$$ORIGIN/lib/' $(LDFLAGS_RPATH)
RPATH_NODEJS         := '-Wl,-rpath,$$\$$ORIGIN/../'
META_LD_LIBRARY_PATH := LD_LIBRARY_PATH
ifeq ($(OS),Darwin)
META_LD_LIBRARY_PATH := DYLD_LIBRARY_PATH
RPATH_PYTHON         := '-Wl,-rpath,@loader_path/lib/' $(LDFLAGS_RPATH)
RPATH_NODEJS         := '-Wl,-rpath,@loader_path/../'
endif

# Takes care of looking into bindings built (SRC_FILE, can contain a wildcard)
# for missing dependencies and copying those dependencies into the
# TARGET_LIB_DIR. If supplied, MANIFEST_IN will be echo'ed to a list of
# 'include x.so'.
#
# On OSX systems, this will also take care of calling install_name_tool to set
# proper path for those dependencies, using @rpath/lib.
define copy_missing_libs
    SRC_FILE=$(1); \
    TARGET_LIB_DIR=$(2); \
    MANIFEST_IN=$(3); \
    echo "Analyzing $$SRC_FILE copying missing libs to $$TARGET_LIB_DIR"; \
    echo "Maybe outputting to $$MANIFEST_IN"; \
    \
    (mkdir $$TARGET_LIB_DIR || true); \
    missing_libs=""; \
    for lib in $$SRC_FILE; do \
        if [ "$(OS)" = "Darwin" ]; then \
            new_missing="$$( (for f in $$(otool -L $$lib 2>/dev/null | tail -n +2 | awk '{ print $$1 }' | grep -v '$$lib'); do ls -hal $$f; done;) 2>&1 | grep 'No such' | cut -d':' -f2 | xargs basename -a)"; \
            missing_libs="$$missing_libs $$new_missing"; \
        elif [ "$(OS)" = "${CI_MSYS_VERSION}" ]; then \
            missing_libs="libstt.so libkenlm.so"; \
        else \
            missing_libs="$$missing_libs $$($(LDD) $$lib | grep 'not found' | awk '{ print $$1 }')"; \
        fi; \
    done; \
    \
    echo "Missing libs = $$missing_libs"; \
    for missing in $$missing_libs; do \
        find $(SO_SEARCH) -type f -name "$$missing" -exec cp {} $$TARGET_LIB_DIR \; ; \
        chmod +w $$TARGET_LIB_DIR/*.so ; \
        if [ ! -z "$$MANIFEST_IN" ]; then \
            echo "include $$TARGET_LIB_DIR/$$missing" >> $$MANIFEST_IN; \
        fi; \
    done; \
    \
    if [ "$(OS)" = "Darwin" ]; then \
        for lib in $$SRC_FILE; do \
            for dep in $$( (for f in $$(otool -L $$lib 2>/dev/null | tail -n +2 | awk '{ print $$1 }' | grep -v '$$lib'); do ls -hal $$f; done;) 2>&1 | grep 'No such' | cut -d':' -f2 ); do \
                if [ "$$dep" != "/usr/lib/libc++.1.dylib" ] && [ "$$dep" != "/usr/lib/libSystem.B.dylib" ]; then \
                    dep_basename=$$(basename "$$dep"); \
                    echo "install_name_tool -change "$$dep" "@rpath/$$dep_basename" "$$lib""; \
                    install_name_tool -change "$$dep" "@rpath/$$dep_basename" "$$lib"; \
                fi; \
            done; \
        done; \
    fi;
endef

SWIG_DIST_URL ?=
ifeq ($(SWIG_DIST_URL),)
ifeq ($(findstring Linux,$(OS)),Linux)
SWIG_DIST_URL := "https://github.com/coqui-ai/STT/releases/download/v1.3.0/ds-swig.linux.amd64.tar.gz"
else ifeq ($(findstring Darwin,$(OS)),Darwin)
SWIG_DIST_URL := "https://github.com/coqui-ai/STT/releases/download/v1.3.0/ds-swig.darwin.amd64.tar.gz"
else ifeq ($(findstring _NT,$(OS)),_NT)
SWIG_DIST_URL := "https://github.com/coqui-ai/STT/releases/download/v1.3.0/ds-swig.win.amd64.tar.gz"
else
$(error There is no prebuilt SWIG available for your platform. Please produce one and set SWIG_DIST_URL.)
endif # findstring()
endif # ($(SWIG_DIST_URL),)

# Should point to native_client/ subdir by default
SWIG_ROOT ?= $(abspath $(shell dirname "$(lastword $(MAKEFILE_LIST))"))/ds-swig
ifeq ($(findstring _NT,$(OS)),_NT)
SWIG_ROOT ?= $(shell cygpath -u "$(SWIG_ROOT)")
endif
SWIG_LIB ?= $(SWIG_ROOT)/share/swig/4.1.0/

SWIG_BIN := swig$(PLATFORM_EXE_SUFFIX)
DS_SWIG_BIN := ds-swig$(PLATFORM_EXE_SUFFIX)
DS_SWIG_BIN_PATH := $(SWIG_ROOT)/bin

DS_SWIG_ENV := SWIG_LIB="$(SWIG_LIB)" PATH="$(DS_SWIG_BIN_PATH):${PATH}"

$(DS_SWIG_BIN_PATH)/swig:
	mkdir -p $(SWIG_ROOT)
	curl -sSL "$(SWIG_DIST_URL)" | tar -C $(SWIG_ROOT) -zxf -
	ln -s $(DS_SWIG_BIN) $(DS_SWIG_BIN_PATH)/$(SWIG_BIN)

ds-swig: $(DS_SWIG_BIN_PATH)/swig
	$(DS_SWIG_ENV) swig -version
	$(DS_SWIG_ENV) swig -swiglib
