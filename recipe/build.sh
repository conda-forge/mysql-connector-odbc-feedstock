#!/bin/bash

set -euxo pipefail

if [[ $target_platform == osx-arm64 ]]; then
    CMAKE_ARGS="${CMAKE_ARGS} -DSTACK_DIRECTION=-1 -DHAVE_CLOCK_GETTIME=0 -DHAVE_CLOCK_GETTIME=0"
fi

mkdir build
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
cp lib/libmyodbc8w.so $PREFIX/lib/libmyodbc8w${SHLIB_EXT}
cp lib/libmyodbc8a.so $PREFIX/lib/libmyodbc8a${SHLIB_EXT}
cp bin/myodbc-installer $PREFIX/bin/myodbc-installer
