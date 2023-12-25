#!/usr/bin/env bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

set -ex

# Edit these variables to fit the environment.
ENGINE_DIR=~/projects/flutter/engine/src
IMPELLERC=$ENGINE_DIR/out/host_debug_unopt_arm64/impellerc

function build_physics {
  pushd $SCRIPT_DIR/deps/flutter_bullet
  pushd native
  cmake .
  make -j 4
  popd
  dart run ffigen --config ffigen.yaml
  popd

  # The code that loads the native lib via `DynamicLibrary.open` is located in
  # `deps/flutter_bullet/lib/flutter_bullet.dart`.
  #
  # Copy the compiled lib to gen, renaming it to the lookup name.
  #
  # The XCode project has a "Copy Files" build phase which grabs
  # `gen/libflutter_bullet.dylib` and places it under `//Frameworks/native`
  # within the app bundle.
  mkdir -p $SCRIPT_DIR/build/macos/Build/Products/Debug/cabal.app/Contents/Frameworks/native
  cp \
    $SCRIPT_DIR/deps/flutter_bullet/native/libflutter_bullet.1.0.0.dylib \
    $SCRIPT_DIR/gen/libflutter_bullet.dylib
}

function build_jolt {
  pushd $SCRIPT_DIR/plugins/ffi/jolt
  cmake --config=Release .
  make -j 4
  popd
  dart run ffigen --config $SCRIPT_DIR/plugins/ffi/jolt.ffigen.yaml
}

function build_v_hacd {
  pushd $SCRIPT_DIR/plugins/ffi/v-hacd
  cmake --config=Release .
  make -j 4
  popd
  dart run ffigen --config $SCRIPT_DIR/plugins/ffi/v-hacd.ffigen.yaml
}


function build_shaders {
  mkdir -p $SCRIPT_DIR/gen
  $IMPELLERC \
    --include=$ENGINE_DIR/flutter/impeller/compiler/shader_lib \
    --runtime-stage-metal \
    --sl=gen/cabal.shaderbundle \
    --shader-bundle=\{\"TextureFragment\":\ \{\"type\":\ \"fragment\",\ \"file\":\ \"$SCRIPT_DIR/shaders/flutter_gpu_texture.frag\"\},\ \"TextureVertex\":\ \{\"type\":\ \"vertex\",\ \"file\":\ \"$SCRIPT_DIR/shaders/flutter_gpu_texture.vert\"\}\}
}

# build_physics
build_shaders
build_jolt
build_v_hacd

set +x

echo
echo
echo "Build successful!"
