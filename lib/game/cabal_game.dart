import 'dart:typed_data';

import 'package:cabal/base/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bullet/physics3d.dart' as phys;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart' as vm;
import 'package:vector_math/vector_math_64.dart' as vm64;

ByteData float32(List<double> values) {
  return Float32List.fromList(values).buffer.asByteData();
}

ByteData uint16(List<int> values) {
  return Uint16List.fromList(values).buffer.asByteData();
}

ByteData uint32(List<int> values) {
  return Uint32List.fromList(values).buffer.asByteData();
}

ByteData float32Mat(Matrix4 matrix) {
  return Float32List.fromList(matrix.storage).buffer.asByteData();
}

class CabalGame extends Game {
  double elapsedSeconds = 0;
  phys.World? world;

  @override
  Future<void> preload() async {
    debugPrint("preloading");
    return Future.value();
  }

  late phys.BoxShape box;
  late phys.StaticPlaneShape plane;
  late phys.RigidBody dynamicBody;
  late phys.RigidBody floorBody;

  @override
  void start() {
    world = phys.World();

    // TODO: Physics crashes at around the 16 tick mark if we don't hold on to
    //       all resources. We don't need to store locals once this is fixed.

    // Create a unit box
    box = phys.BoxShape(vm.Vector3(.5, .5, .5));

    // Create a static plane in the X-Z axis.
    plane = phys.StaticPlaneShape(vm.Vector3(0, 1, 0), 0);

    // Make a dynamic body with mass 1.0 with the box shape.
    // Place it 10 units in the air.
    dynamicBody = phys.RigidBody(1.0, box)..xform.origin = vm.Vector3(0, 10, 0);

    // Make a static body (mass == 0.0) with the static plane shape
    // place it at the origin.
    floorBody = phys.RigidBody(0.0, plane);

    world!.addBody(dynamicBody);
    world!.addBody(floorBody);
  }

  @override
  void fixedUpdate() {
    debugPrint("step");

    world?.step(Game.fixedTickIntervalSeconds);
  }

  @override
  void update(double dt) {
    debugPrint("update: dt=$dt");

    elapsedSeconds += dt;
  }

  @override
  void render(Canvas canvas, Size size) {
    /// Allocate a new renderable texture.
    final gpu.Texture? renderTexture = gpu.gpuContext.createTexture(
        gpu.StorageMode.devicePrivate, size.width.toInt(), size.height.toInt(),
        enableRenderTargetUsage: true,
        enableShaderReadUsage: true,
        coordinateSystem: gpu.TextureCoordinateSystem.renderToTexture);
    if (renderTexture == null) {
      return;
    }

    final gpu.Texture? depthTexture = gpu.gpuContext.createTexture(
        gpu.StorageMode.deviceTransient,
        size.width.toInt(),
        size.height.toInt(),
        format: gpu.gpuContext.defaultDepthStencilFormat,
        enableRenderTargetUsage: true,
        coordinateSystem: gpu.TextureCoordinateSystem.renderToTexture);
    if (depthTexture == null) {
      return;
    }

    /// Create the command buffer. This will be used to submit all encoded
    /// commands at the end.
    final commandBuffer = gpu.gpuContext.createCommandBuffer();

    /// Define a render target. This is just a collection of attachments that a
    /// RenderPass will write to.
    final renderTarget = gpu.RenderTarget.singleColor(
      gpu.ColorAttachment(texture: renderTexture),
      depthStencilAttachment: gpu.DepthStencilAttachment(
          texture: depthTexture, depthClearValue: 1.0),
    );

    /// Add a render pass encoder to the command buffer so that we can start
    /// encoding commands.
    final encoder = commandBuffer.createRenderPass(renderTarget);

    /// Load a shader bundle asset.
    final library = gpu.ShaderLibrary.fromAsset('gen/cabal.shaderbundle')!;

    /// Create a RenderPipeline using shaders from the asset.
    final vertex = library['TextureVertex']!;
    final fragment = library['TextureFragment']!;
    final pipeline = gpu.gpuContext.createRenderPipeline(vertex, fragment);

    encoder.bindPipeline(pipeline);

    encoder.setDepthWriteEnable(true);
    encoder.setDepthCompareOperation(gpu.CompareFunction.less);

    /// Append quick geometry and uniforms to a host buffer that will be
    /// automatically uploaded to the GPU later on.
    final transients = gpu.HostBuffer();
    final vertices = transients.emplace(float32(<double>[
      -1, -1, -1, /* */ 0, 0, /* */ 1, 0, 0, 1, //
      1, -1, -1, /*  */ 1, 0, /* */ 0, 1, 0, 1, //
      1, 1, -1, /*   */ 1, 1, /* */ 0, 0, 1, 1, //
      -1, 1, -1, /*  */ 0, 1, /* */ 0, 0, 0, 1, //
      -1, -1, 1, /*  */ 0, 0, /* */ 0, 1, 1, 1, //
      1, -1, 1, /*   */ 1, 0, /* */ 1, 0, 1, 1, //
      1, 1, 1, /*    */ 1, 1, /* */ 1, 1, 0, 1, //
      -1, 1, 1, /*   */ 0, 1, /* */ 1, 1, 1, 1, //
    ]));
    final indices = transients.emplace(uint16(<int>[
      0, 1, 3, 3, 1, 2, //
      1, 5, 2, 2, 5, 6, //
      5, 4, 6, 6, 4, 7, //
      4, 0, 7, 7, 0, 3, //
      3, 2, 7, 7, 2, 6, //
      4, 5, 0, 0, 5, 1, //
    ]));
    final mvp = transients.emplace(float32Mat(vm64.Matrix4(
          0.5 * size.height / size.width, 0, 0, 0, //
          0, 0.5, 0, 0, //
          0, 0, 0.2, 0, //
          0, 0, 0.5, 1, //
        ) *
        vm64.Matrix4.rotationX(elapsedSeconds) *
        vm64.Matrix4.rotationY(elapsedSeconds * 1.27) *
        vm64.Matrix4.rotationZ(elapsedSeconds * 0.783)));
        //vm64.Matrix4.fromList(dynamicBody.xform.storage)));

    /// Bind the vertex and index buffer.
    encoder.bindVertexBuffer(vertices, 8);
    encoder.bindIndexBuffer(indices, gpu.IndexType.int16, 36);

    /// Bind the host buffer data we just created to the vertex shader's uniform
    /// slots. Although the locations are specified in the shader and are
    /// predictable, we can optionally fetch the uniform slots by name for
    /// convenience.
    final mvpSlot = pipeline.vertexShader.getUniformSlot('mvp')!;
    encoder.bindUniform(mvpSlot, mvp);

    final sampledTexture = gpu.gpuContext.createTexture(
        gpu.StorageMode.hostVisible, 5, 5,
        enableShaderReadUsage: true);
    sampledTexture!.overwrite(uint32(<int>[
      0xFFFFFFFF, 0x00000000, 0xFFFFFFFF, 0x00000000, 0xFFFFFFFF, //
      0x00000000, 0xFFFFFFFF, 0x00000000, 0xFFFFFFFF, 0x00000000, //
      0xFFFFFFFF, 0x00000000, 0xFFFFFFFF, 0x00000000, 0xFFFFFFFF, //
      0x00000000, 0xFFFFFFFF, 0x00000000, 0xFFFFFFFF, 0x00000000, //
      0xFFFFFFFF, 0x00000000, 0xFFFFFFFF, 0x00000000, 0xFFFFFFFF, //
    ]));

    final texSlot = pipeline.fragmentShader.getUniformSlot('tex')!;
    encoder.bindTexture(texSlot, sampledTexture);

    /// And finally, we append a draw call.
    encoder.draw();

    /// Submit all of the previously encoded passes. Passes are encoded in the
    /// same order they were created in.
    commandBuffer.submit();

    /// Wrap the Flutter GPU texture as a ui.Image and draw it like normal!
    final image = renderTexture.asImage();

    canvas.drawImage(image, Offset.zero, Paint());
  }
}
