# Makefile for Yocto Exporter

GOOS := $(shell go env GOOS)
GOARCH := $(shell go env GOARCH)

# Try to detect the number of CPUs to run make jobs in parallel
NPROCS = 1
ifeq ($(GOOS),darwin)
    NPROCS = $(shell sysctl -n hw.ncpu)
else ifeq ($(GOOS),linux)
    NPROCS = $(shell nproc)
endif
MAKEFLAGS += -j$(NPROCS)

# Default to osx
LIB_PATH_REL = osx
LIB_YOCTO_TARGET = $(LIB_PATH_REL)/libyocto-static.a
LIB_YAPI_TARGET = $(LIB_PATH_REL)/yapi/libyapi-static.a

ifeq ($(GOOS),linux)
    ifeq ($(GOARCH),amd64)
        LIB_PATH_REL = linux/x86_64
    endif
    ifeq ($(GOARCH),arm64)
        LIB_PATH_REL = linux/aarch64
    endif
    ifeq ($(GOARCH),386)
        LIB_PATH_REL = linux/i386
    endif
    ifeq ($(GOARCH),arm)
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

# Calculate version
# Allow VERSION to be set from environment/command line, otherwise try git
VERSION ?= $(shell git describe --tags --always --long 2>/dev/null || echo "dev")
LDFLAGS := -X main.version=$(VERSION)

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
	go build -ldflags "$(LDFLAGS)" -o yocto-exporter

version:
	@echo $(VERSION)

clean:
	cd yoctolib_cpp/Binaries && $(MAKE) -f GNUmakefile clean
	rm -f yocto-exporter
	rm -rf $(GO_CACHE_DIR)

.PHONY: all build clean
