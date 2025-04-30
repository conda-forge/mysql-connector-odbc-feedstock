#!/bin/bash

set -euxo pipefail

export CFLAGS="${CFLAGS} -Wno-int-conversion"

if [[ "${target_platform}" == linux-* ]]; then
    export CMAKE_ARGS="${CMAKE_ARGS} -DHAVE_CLOCK_GETTIME_EXITCODE=0 -DHAVE_CLOCK_REALTIME_EXITCODE=0 -DSTACK_DIRECTION=-1 -DHAVE_LLVM_LIBCPP_EXITCODE=1"
elif [[ "${target_platform}" == "osx-arm64" ]]; then
    export CMAKE_ARGS="${CMAKE_ARGS} -DHAVE_CLOCK_GETTIME_EXITCODE=0 -DHAVE_CLOCK_REALTIME_EXITCODE=0 -DSTACK_DIRECTION=1 -DHAVE_LLVM_LIBCPP_EXITCODE=0"
fi
if [[ "${target_platform}" != "${build_platform}" ]]; then
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
        export CFLAGS="-Wno-int-conversion"
        export LDFLAGS="-L${BUILD_PREFIX}/lib"
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

        if [[ "${target_platform}" == linux-* ]]; then
          # We don't want to use this to detect the native mysql
          rm $BUILD_PREFIX/bin/mysql_config
          rm $BUILD_PREFIX/bin/odbc_config
        fi
    )
fi

mkdir -p build
pushd build

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
cp lib/libmyodbc9w.so $PREFIX/lib/libmyodbc9w${SHLIB_EXT}
cp lib/libmyodbc9a.so $PREFIX/lib/libmyodbc9a${SHLIB_EXT}
cp bin/myodbc-installer $PREFIX/bin/myodbc-installer
