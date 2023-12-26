#!/usr/bin/env bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

set -ex

# Edit these variables to fit the environment.
ENGINE_DIR=~/projects/flutter/engine/src
IMPELLERC=$ENGINE_DIR/out/host_debug_unopt_arm64/impellerc

function build_jolt {
  pushd $SCRIPT_DIR/plugins/ffi/jolt
  cmake .
  make -j 4
  popd
  dart run ffigen --config $SCRIPT_DIR/plugins/ffi/jolt.ffigen.yaml
}

function build_v_hacd {
  pushd $SCRIPT_DIR/plugins/ffi/v-hacd
  cmake .
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

build_jolt
build_v_hacd
build_shaders

set +x

echo
echo
echo "Build successful!"
