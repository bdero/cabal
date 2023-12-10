#!/usr/bin/env bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

set -ex

#git submodule update --init --recursive

# Edit these variables to fit the environment.
ENGINE_DIR=~/projects/flutter/engine/src
IMPELLERC=$ENGINE_DIR/out/host_debug_unopt_arm64/impellerc

pushd $SCRIPT_DIR/deps/flutter_bullet
pushd native
cmake .
make -j 4
popd
dart run ffigen --config ffigen.yaml
popd

# Coordinate with the macOS/iOS `DynamicLibrary.open` path in `deps/flutter_bullet/lib/flutter_bullet.dart`.
mkdir -p $SCRIPT_DIR/build/macos/Build/Products/Debug/cabal.app/Contents/Frameworks/native
cp $SCRIPT_DIR/deps/flutter_bullet/native/libflutter_bullet.1.0.0.dylib \
   $SCRIPT_DIR/build/macos/Build/Products/Debug/cabal.app/Contents/Frameworks/native/libflutter_bullet.dylib
