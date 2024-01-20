import 'dart:developer';
import 'dart:ui' as ui;

import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:oxygen/oxygen.dart' as oxy;
import 'package:vector_math/vector_math.dart' as vm;

import 'package:cabal/base/components/camera_component.dart';
import 'package:cabal/base/components/mesh_component.dart';
import 'package:cabal/base/components/transform_component.dart';
import 'package:cabal/base/surface.dart';

class RenderSystem extends oxy.System {
  Surface surface = Surface();

  late oxy.Query cameraQuery;
  late oxy.Query meshQuery;

  // The canvas and size are managed/set by ECSGame (or your money back).
  ui.Canvas? canvas;
  ui.Size canvasSize = ui.Size.zero;

  @override
  void init() {
    cameraQuery = createQuery([
      oxy.Has<CameraComponent>(),
      oxy.Has<TransformComponent>(),
    ]);
    meshQuery = createQuery([
      oxy.Has<MeshComponent>(),
      oxy.Has<TransformComponent>(),
    ]);
  }

  @override
  void execute(double delta) {
    //--------------------------------------------------------------------------
    /// Compute the view/perspective transform.
    ///

    if (cameraQuery.entities.isEmpty) {
      log("The world does not have a valid camera. Cannot render.");
    }
    final camera = cameraQuery.entities[0].get<CameraComponent>()!.camera!;
    final cameraTransform =
        cameraQuery.entities[0].get<TransformComponent>()!.matrix;

    final viewProjectionTransform =
        camera.getTransform(canvasSize.width / canvasSize.height) *
            vm.Matrix4.inverted(cameraTransform);

    //--------------------------------------------------------------------------
    /// Prepare the RenderPass.
    ///

    /// Create the command buffer. This will be used to submit all encoded
    /// commands at the end.
    final commandBuffer = gpu.gpuContext.createCommandBuffer();

    final gpu.RenderTarget renderTarget =
        surface.getNextRenderTarget(canvasSize);

    /// Add a render pass encoder to the command buffer so that we can start
    /// encoding commands.
    final encoder = commandBuffer.createRenderPass(renderTarget);
    encoder.setDepthWriteEnable(true);
    encoder.setDepthCompareOperation(gpu.CompareFunction.less);

    //--------------------------------------------------------------------------
    /// Record all of the drawing commands.
    ///

    final transientsBuffer = gpu.gpuContext.createHostBuffer();

    // When a RigidBody is attached, drive the Entity's transform.
    for (final entity in meshQuery.entities) {
      final transform = entity.get<TransformComponent>()!;
      final mesh = entity.get<MeshComponent>()!;

      mesh.mesh!.draw(encoder, transientsBuffer,
          viewProjectionTransform * transform.matrix);
    }

    commandBuffer.submit();

    //--------------------------------------------------------------------------
    /// Draw the color texture to the Flutter Canvas.
    ///

    final image = renderTarget.colorAttachments[0].texture.asImage();
    canvas!.drawImage(image, ui.Offset.zero, ui.Paint());
  }
}
