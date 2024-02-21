#!/bin/bash

set -euxo pipefail

mkdir -p build
pushd build

export CFLAGS="${CFLAGS} -Wno-int-conversion"

if [[ $target_platform == osx-arm64 ]] && [[ $CONDA_BUILD_CROSS_COMPILATION == 1 ]]; then
  export CMAKE_ARGS="${CMAKE_ARGS} -DHAVE_CLOCK_GETTIME_EXITCODE=0 -DHAVE_CLOCK_REALTIME_EXITCODE=0 -DSTACK_DIRECTION=1"
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
