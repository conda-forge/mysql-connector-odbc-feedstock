#!/bin/bash

set -euxo pipefail

export LDFLAGS=`echo "${LDFLAGS}" | sed "s|-Wl,-dead_strip_dylibs||g"`

declare -a _cmake_args

_cmake_args+=(-S${SRC_DIR})
_cmake_args+=(-GNinja)
_cmake_args+=(-DCMAKE_CXX_STANDARD=17)
_cmake_args+=(-DCMAKE_BUILD_TYPE=Release)
_cmake_args+=(-DCOMPILATION_COMMENT=conda-forge)
_cmake_args+=(-DCMAKE_FIND_FRAMEWORK=LAST)
_cmake_args+=(-DWITH_UNIXODBC=ON)
_cmake_args+=(-DCMAKE_INSTALL_PREFIX=${PREFIX})
_cmake_args+=(-DMYSQLCLIENT_STATIC_LINKING=OFF)
_cmake_args+=(-DBUNDLE_DEPENDENCIES=OFF)
_cmake_args+=(-DDISABLE_GUI=ON)

# Copy-pasted from https://github.com/conda-forge/mysql-feedstock/blob/master/recipe/build.sh
if [[ $target_platform == osx-arm64 ]] && [[ ${CONDA_BUILD_CROSS_COMPILATION:0} == 1 ]]; then
    # Build all intermediate codegen binaries for the build platform
    # xref: https://cmake.org/pipermail/cmake/2013-January/053252.html
    env -u SDKROOT -u CONDA_BUILD_SYSROOT -u CMAKE_PREFIX_PATH \
        -u CXXFLAGS -u CPPFLAGS -u CFLAGS -u LDFLAGS \
        cmake "${_cmake_args[@]}" \
            -B build.codegen \
            -DCMAKE_C_COMPILER=$CC_FOR_BUILD \
            -DCMAKE_CXX_COMPILER=$CXX_FOR_BUILD \
            -DProtobuf_PROTOC_EXECUTABLE=$BUILD_PREFIX/bin/protoc \
            -DCMAKE_EXE_LINKER_FLAGS="-Wl,-rpath,$BUILD_PREFIX/lib" \
            -DMYSQL_LIB=fake.so \
            -DODBC_CONFIG=fake
    cmake --build build.codegen -- \
        uca9dump \
        myodbc-installer

    # Copy uca9dump to target build directory to prevent it from being built again
    cp build.codegen/bin/uca9dump ${BUILD_PREFIX}/bin

    # Tell CMake about our cross toolchains
    _cmake_args+=(${CMAKE_ARGS})

    # The MySQL CMake files use TRY_RUN/CHECK_C_SOURCE_RUNS to inspect certain
    # properties about the build environment. Since we are cross compiling, we
    # cannot run these executables (which target the host platform) on the
    # build platform, so we tell CMake about their results explicitly:

    ## Tell the build system that stack grows in the opposite direction on osx-arm64
    _cmake_args+=(-DSTACK_DIRECTION=-1)

    _cmake_args+=(-DHAVE_LLVM_LIBCPP=1)

    ## 11.1 SDK does support CLOCK_GETTIME with CLOCK_MONOTONIC and CLOCK_REALTIME as arguments
    _cmake_args+=(-DHAVE_CLOCK_GETTIME=0)
    _cmake_args+=(-DHAVE_CLOCK_REALTIME=0)
fi

# Ensure we don't pick up mysql from BUILD_PREFIX in the target case
rm -f ${BUILD_PREFIX}/bin/mysql_config

mkdir -p build
pushd build
cmake "${_cmake_args[@]}"
ninja
# Manually install libraries as `ninja install` also installs the tests
cp lib/libmyodbc8w.so $PREFIX/lib/libmyodbc8w${SHLIB_EXT}
cp lib/libmyodbc8a.so $PREFIX/lib/libmyodbc8a${SHLIB_EXT}
cp bin/myodbc-installer $PREFIX/bin/myodbc-installer
