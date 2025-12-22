# Makefile for Yocto Exporter

UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

# Default to osx
LIB_PATH_REL = osx
LIB_YOCTO_TARGET = $(LIB_PATH_REL)/libyocto-static.a
LIB_YAPI_TARGET = $(LIB_PATH_REL)/yapi/libyapi-static.a

ifeq ($(UNAME_S),Linux)
    ifeq ($(UNAME_M),x86_64)
        LIB_PATH_REL = linux/x86_64
    endif
    ifeq ($(UNAME_M),aarch64)
        LIB_PATH_REL = linux/aarch64
    endif
    ifneq (,$(filter $(UNAME_M),i386 i686))
        LIB_PATH_REL = linux/i386
    endif
    ifneq (,$(filter $(UNAME_M),armv7l armv7))
        LIB_PATH_REL = linux/armhf
        EXTRA_MAKE_FLAGS = OPTS_ARMHF="-DBUILD_ARMHF -D_GNU_SOURCE"
    endif
    LIB_YOCTO_TARGET = $(LIB_PATH_REL)/libyocto-static.a
    LIB_YAPI_TARGET = $(LIB_PATH_REL)/yapi/libyapi-static.a
endif

LIB_DIR = yoctolib_cpp/Binaries/$(LIB_PATH_REL)
YAPI_LIB_DIR = yoctolib_cpp/Binaries/$(LIB_PATH_REL)/yapi

LIB_YOCTO = $(LIB_DIR)/libyocto-static.a
LIB_YAPI = $(YAPI_LIB_DIR)/libyapi-static.a

# Cache directories for Go (to avoid Seatbelt issues)
GO_CACHE_DIR = $(PWD)/.cache
GOMODCACHE = $(GO_CACHE_DIR)/go-mod
GOCACHE = $(GO_CACHE_DIR)/go-build

all: build

# Ensure submodules or dependencies are present
yoctolib_cpp:
	@echo "yoctolib_cpp directory missing. Please clone it or download it."
	@exit 1

# Build the static libraries using the provided GNUmakefile
# We explicitly target the static libraries to avoid building dynamic ones or requiring xcodebuild
$(LIB_YOCTO): yoctolib_cpp
	cd yoctolib_cpp/Binaries && $(MAKE) -f GNUmakefile $(LIB_YOCTO_TARGET) $(LIB_YAPI_TARGET) $(EXTRA_MAKE_FLAGS)

# Go build command
build: $(LIB_YOCTO)
	@mkdir -p $(GOMODCACHE) $(GOCACHE)
	export GOMODCACHE=$(GOMODCACHE) && \
	export GOCACHE=$(GOCACHE) && \
	CGO_CFLAGS="-I$(PWD)/yoctolib_cpp/Sources" \
	CGO_CXXFLAGS="-I$(PWD)/yoctolib_cpp/Sources" \
	CGO_LDFLAGS="-L$(PWD)/$(LIB_DIR) -L$(PWD)/$(YAPI_LIB_DIR) -lyocto-static -lyapi-static" \
	go build -o yocto-exporter

clean:
	cd yoctolib_cpp/Binaries && $(MAKE) -f GNUmakefile clean
	rm -f yocto-exporter
	rm -rf $(GO_CACHE_DIR)

.PHONY: all build clean