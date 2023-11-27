#!/bin/sh
set -ex

pushd deps/flutter_bullet
pushd flutter_bullet_library
cmake .
make -j 4
popd
dart run ffigen --config ffigen.yaml
popd
cp deps/flutter_bullet/flutter_bullet_library/libflutter_bullet.1.0.0.dylib \
   ./build/macos/Build/Products/Debug/cabal.app/Contents/Frameworks
