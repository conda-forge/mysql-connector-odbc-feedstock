#!/bin/bash

set -euxo pipefail

mkdir -p build
pushd build

export CFLAGS="${CFLAGS} -Wno-int-conversion"

if [[ $target_platform == osx-arm64 ]] && [[ "${CONDA_BUILD_CROSS_COMPILATION:-0}" == 1 ]]; then
    export CMAKE_ARGS="${CMAKE_ARGS} -DHAVE_CLOCK_GETTIME_EXITCODE=0 -DHAVE_CLOCK_REALTIME_EXITCODE=0 -DSTACK_DIRECTION=1 -DHAVE_LLVM_LIBCPP_EXITCODE=0"

    # Build all intermediate codegen binaries for the build platform
    # xref: https://cmake.org/pipermail/cmake/2013-January/053252.html
    export OPENSSL_ROOT_DIR=$BUILD_PREFIX
    echo "#### Cross-compiling some binaries for osx-64"
    (
        unset SDKROOT
        unset CONDA_BUILD_SYSROOT
        unset CMAKE_PREFIX_PATH
        unset CXXFLAGS
        unset CPPFLAGS
        unset CFLAGS
        unset LDFLAGS
	mkdir -p build-build
	pushd build-build
        cmake \
            -GNinja \
            -DWITH_UNIXODBC=ON \
            -DCMAKE_INSTALL_PREFIX=${BUILD_PREFIX} \
            -DMYSQLCLIENT_STATIC_LINKING=OFF \
            -DBUNDLE_DEPENDENCIES=OFF \
            -DDISABLE_GUI=ON \
            -DCMAKE_PREFIX_PATH=$BUILD_PREFIX \
            -DCMAKE_C_COMPILER=$CC_FOR_BUILD \
            -DCMAKE_CXX_COMPILER=$CXX_FOR_BUILD \
            -DProtobuf_PROTOC_EXECUTABLE=$BUILD_PREFIX/bin/protoc \
            -DCMAKE_EXE_LINKER_FLAGS="-Wl,-rpath,$BUILD_PREFIX/lib -L$BUILD_PREFIX/lib" \
            ..
        ninja
	cp ./bin/uca9dump ${BUILD_PREFIX}/bin
	popd
    )
fi

cmake ${CMAKE_ARGS} \
	-GNinja \
	-DWITH_UNIXODBC=ON \
	-DCMAKE_INSTALL_PREFIX=${PREFIX} \
	-DMYSQLCLIENT_STATIC_LINKING=OFF \
	-DBUNDLE_DEPENDENCIES=OFF \
	-DDISABLE_GUI=ON \
	..
ninja
# Manually install libraries as `ninja install` also installs the tests
cp lib/libmyodbc8w.so $PREFIX/lib/libmyodbc8w${SHLIB_EXT}
cp lib/libmyodbc8a.so $PREFIX/lib/libmyodbc8a${SHLIB_EXT}
cp bin/myodbc-installer $PREFIX/bin/myodbc-installer
