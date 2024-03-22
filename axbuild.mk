wamr-version := ca364eb5d7a42992748f4e3b57f2761995b9c2e4
wamr-dir := $(APP)/wasm-micro-runtime-$(wamr-version)

CMAKE = cmake

ARCH ?= x86_64
ARCH_UPPER ?= $(shell echo $(ARCH) | tr '[a-z]' '[A-Z]')
C_COMPILER := $(shell which $(CC))
CXX_COMPILER := $(shell which $(CC))
AR := $(shell which $(AR))
RANLIB := $(shell which $(RANLIB))
CROSS_COMPILE_PATH := $(shell dirname $(C_COMPILER))/..
C_INCLUDE_DIR := -isystem $(CROSS_COMPILE_PATH)/$(ARCH)-linux-musl/include/ -isystem $(CROSS_COMPILE_PATH)/lib/gcc/$(ARCH)-linux-musl/11.2.1/include/
CPP_INCLUDE_DIR := -I$(CROSS_COMPILE_PATH)/$(ARCH)-linux-musl/include/c++/11.2.1/ -I$(CROSS_COMPILE_PATH)/$(ARCH)-linux-musl/include/c++/11.2.1/$(ARCH)-linux-musl/ $(C_INCLUDE_DIR)

WASI_NN ?= 0
WASI_NN_LOG_LEVEL ?= 1
WAMR_BUILD_WASI_EPHEMERAL_NN ?= 0

app-objs := wamr.o
wamr_product_dir = $(wamr-dir)/product-mini/platforms/ruxos
wamr_product_build = $(wamr_product_dir)/build

$(wamr-dir):
	@echo "Download wamr source code"
	wget https://github.com/intel/wasm-micro-runtime/archive/$(wamr-version).tar.gz -P $(APP)
	tar -zxf $(APP)/$(wamr-version).tar.gz -C $(APP) && rm -f $(APP)/$(wamr-version).tar.gz
	cd $(wamr-dir) && git init && git add .
	patch -p1 -N -d $(wamr-dir) --no-backup-if-mismatch -r - < $(APP)/wamr.patch

$(APP)/$(app-objs): build_wamr
build_wamr: $(wamr-dir) $(APP)/axbuild.mk
	mkdir -p $(wamr_product_dir) && cp -r $(wamr_product_dir)/../linux/* $(wamr_product_dir) && cp $(APP)/CMakeLists.txt $(APP)/*.cmake $(wamr_product_dir)
	mkdir -p $(wamr_product_build) && cd $(wamr_product_build) && \
		$(CMAKE) -DCMAKE_TOOLCHAIN_FILE=../$(ARCH)_toolchain.cmake .. \
			-DCMAKE_C_COMPILER=$(C_COMPILER) -DCMAKE_CXX_COMPILER=$(CXX_COMPILER) -DCMAKE_AR=$(AR) -DCMAKE_RANLIB=$(RANLIB) \
			-DCMAKE_C_FLAGS="-DNN_LOG_LEVEL=$(WASI_NN_LOG_LEVEL) -D__builtin___clear_cache=// $(CFLAGS) $(C_INCLUDE_DIR) " \
			-DCMAKE_CXX_FLAGS="-DNN_LOG_LEVEL=$(WASI_NN_LOG_LEVEL) -D\"strtoll_l(s, e, b, l)=strtoll(s, e, b)\" -D\"strtoull_l(s, e, b, l)=strtoull(s, e, b)\" $(CFLAGS) $(CPP_INCLUDE_DIR) " \
			-DWAMR_BUILD_TARGET=$(ARCH_UPPER) \
			-DWAMR_DISABLE_HW_BOUND_CHECK=1 \
			-DWAMR_DISABLE_WRITE_GS_BASE=1 \
			-DWAMR_BUILD_WASI_NN=$(WASI_NN) \
			-DWAMR_BUILD_WASI_EPHEMERAL_NN=$(WAMR_BUILD_WASI_EPHEMERAL_NN) \
			-DFLATBUFFERS_LOCALE_INDEPENDENT=1 \
			-UMADV_HUGEPAGE && \
		$(MAKE) -j17
	mkdir -p $(wamr_product_build)/libgcc && cd $(wamr_product_build)/libgcc && \
		ln -s -f $(CROSS_COMPILE_PATH)/lib/gcc/*-linux-musl/*/libgcc.a ./ && \
		$(AR) x libgcc.a _clrsbsi2.o
ifeq ($(WASI_NN), 1)
	$(LD) -o $(app-objs) -nostdlib -static -no-pie -r -e main \
		$(wamr_product_build)/libiwasm.a \
		$(wamr_product_build)/tensorflow-lite/libtensorflow-lite.a \
		$(CROSS_COMPILE_PATH)/*-linux-musl/lib/libstdc++.a \
		$(CROSS_COMPILE_PATH)/*-linux-musl/lib/libatomic.a \
		$(CROSS_COMPILE_PATH)/lib/gcc/*-linux-musl/*/libgcc_eh.a \
		$(wamr_product_build)/libgcc/_clrsbsi2.o \
		$(wamr_product_build)/_deps/xnnpack-build/libXNNPACK.a \
		$(wamr_product_build)/_deps/cpuinfo-build/libcpuinfo.a \
		$(wamr_product_build)/pthreadpool/libpthreadpool.a \
		$(wamr_product_build)/_deps/ruy-build/ruy/*.a \
		$(wamr_product_build)/_deps/flatbuffers-build/libflatbuffers.a \
		$(wamr_product_build)/_deps/farmhash-build/libfarmhash.a \
		$(wamr_product_build)/_deps/fft2d-build/libfft2d_fftsg.a \
		$(wamr_product_build)/_deps/fft2d-build/libfft2d_fftsg2d.a \
		$(wamr_product_build)/tensorflow-lite/CMakeFiles/tensorflow-lite.dir/kernels/deprecated_backends.cc.o 
else 
	cp $(wamr_product_build)/libiwasm.a $(app-objs)
endif

clean_c::
	rm -rf $(wamr_product_build)/_deps
	rm -rf $(wamr_product_build)/CMakeFiles
	rm -rf $(wamr_product_build)/tmp
	rm -rf $(wamr_product_build)/pthreadpool
	rm -rf $(wamr_product_build)/flatbuffers-flatc
	find $(wamr_product_build) -maxdepth 1 -type f -exec rm {} \;

.PHONY: build_wamr clean_c
