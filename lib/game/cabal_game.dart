import 'dart:math';
import 'dart:typed_data';

import 'package:cabal/base/camera.dart';
import 'package:cabal/base/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bullet/physics3d.dart' as phys;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart' as vm;
import 'package:cabal/flatbuffers/mesh_example.fb_generated.dart' as mesh_fb;
import 'package:image/image.dart' as img;
import 'package:flat_buffers/flat_buffers.dart' as fb;

ByteData float32(List<double> values) {
  return Float32List.fromList(values).buffer.asByteData();
}

ByteData uint16(List<int> values) {
  return Uint16List.fromList(values).buffer.asByteData();
}

ByteData uint32(List<int> values) {
  return Uint32List.fromList(values).buffer.asByteData();
}

ByteData float32Mat(vm.Matrix4 matrix) {
  return matrix.storage.buffer.asByteData();
}

Future<gpu.Texture?> loadRGBA(String name) async {
  ByteData data = await rootBundle.load(name);
  var image = img.decodePng(data.buffer.asUint8List())!;
  final texture = gpu.gpuContext.createTexture(
      gpu.StorageMode.hostVisible, image.width, image.height,
      format: gpu.PixelFormat.r8g8b8a8UNormInt);
  // The input PNG _must_ have an alpha channel, otherwise the format/size will
  // mismatch.
  texture!.overwrite(
      image.getBytes(order: img.ChannelOrder.rgba).buffer.asByteData());
  return texture;
}

class Surface {
  final int _maxFramesInFlight = 2;
  final List<gpu.RenderTarget> _renderTargets = [];
  int _cursor = 0;
  Size _previousSize = const Size(0, 0);

  getNextRenderTarget(Size size) {
    if (size != _previousSize) {
      _cursor = 0;
      _renderTargets.clear();
      _previousSize = size;
    }
    if (_cursor == _renderTargets.length) {
      final gpu.Texture? colorTexture = gpu.gpuContext.createTexture(
          gpu.StorageMode.devicePrivate,
          size.width.toInt(),
          size.height.toInt(),
          enableRenderTargetUsage: true,
          enableShaderReadUsage: true,
          coordinateSystem: gpu.TextureCoordinateSystem.renderToTexture);
      if (colorTexture == null) {
        throw Exception("Failed to create Surface color texture!");
      }
      final gpu.Texture? depthTexture = gpu.gpuContext.createTexture(
          gpu.StorageMode.deviceTransient,
          size.width.toInt(),
          size.height.toInt(),
          format: gpu.gpuContext.defaultDepthStencilFormat,
          enableRenderTargetUsage: true,
          coordinateSystem: gpu.TextureCoordinateSystem.renderToTexture);
      if (depthTexture == null) {
        throw Exception("Failed to create Surface depth texture!");
      }
      final renderTarget = gpu.RenderTarget.singleColor(
        gpu.ColorAttachment(texture: colorTexture),
        depthStencilAttachment: gpu.DepthStencilAttachment(
            texture: depthTexture, depthClearValue: 1.0),
      );
      _renderTargets.add(renderTarget);
    }
    gpu.RenderTarget result = _renderTargets[_cursor];
    _cursor = (_cursor + 1) % _maxFramesInFlight;
    return result;
  }
}

class FlutterLogo {
  FlutterLogo(phys.World world) {
    // Create a 2x2x2 box.
    var box = phys.BoxShape(vm.Vector3(1, 1, 1));

    // Make a dynamic body with mass 1.0 with the box shape.
    // Place it 10 units in the air.
    _dynamicBody = phys.RigidBody(1.0, box)
      ..xform.origin = vm.Vector3(0, 10, 0)
      ..xform.rotation = vm.Quaternion.random(Random());
    world.addBody(_dynamicBody!);
  }

  FlutterLogo.transform(this._transform) {
    _phaseOffset = Random().nextDouble() * 2 * pi;
    _rotationAxis =
        (vm.Vector3.random(Random()) - vm.Vector3(0.5, 0.5, 0.5)).normalized();
  }

  phys.RigidBody? _dynamicBody;
  vm.Matrix4 _transform = vm.Matrix4.identity();
  double _phaseOffset = 0;
  vm.Vector3 _rotationAxis = vm.Vector3.zero();

  vm.Matrix4 getTransform(double time) {
    if (_dynamicBody != null) {
      var modelMatrix = vm.Matrix4.fromFloat32List(_dynamicBody!.xform.storage);
      // Hack to fix the physics transform. Make the translation positional.
      return modelMatrix.clone()..setEntry(3, 3, 1);
    }
    vm.Matrix4 result = _transform.clone();
    result.rotate(_rotationAxis, time);
    vm.Matrix4.translation(vm.Vector3(0.0, 0.0, sin(_phaseOffset + time)));
    return result;
  }

  void setTransform(vm.Matrix4 transform) {
    _transform = transform;
  }
}

class CabalGame extends Game {
  double elapsedSeconds = 0;
  phys.World? world;
  gpu.ShaderLibrary? shaderLibrary;
  Surface surface = Surface();

  gpu.Texture? baseColorTexture;
  gpu.Texture? normalTexture;
  gpu.Texture? occlusionRoughnessMetallicTexture;
  gpu.DeviceBuffer? verticesBuffer;
  gpu.DeviceBuffer? indicesBuffer;
  int numVertices = 0;
  int numIndices = 0;

  List<FlutterLogo> logos = [];

  @override
  Future<void> preload() async {
    debugPrint("preloading");

    /// Load a shader bundle asset.
    shaderLibrary = gpu.ShaderLibrary.fromAsset('gen/cabal.shaderbundle')!;
    if (shaderLibrary == null) {
      throw Exception("FATAL: Failed to load shader library!");
    }

    baseColorTexture = await loadRGBA('assets/flutter_logo_BaseColor_rgba.png');
    normalTexture = await loadRGBA('assets/flutter_logo_Normal_rgba.png');
    occlusionRoughnessMetallicTexture = await loadRGBA(
        'assets/flutter_logo_OcclusionRoughnessMetallic_rgba.png');

    final modelFB = await rootBundle.load('assets/flutter_logo.model');
    mesh_fb.Mesh mesh = mesh_fb.Mesh(modelFB.buffer.asUint8List());
    final indices = Uint16List.fromList(mesh.indices!);
    final mverts = mesh.vertices!;

    final Float32List vertices = Float32List(11 * mverts.length);
    for (int i = 0; i < mverts.length; i++) {
      vertices[11 * i + 0] = (mverts[i].position.x);
      vertices[11 * i + 1] = (mverts[i].position.y);
      vertices[11 * i + 2] = (mverts[i].position.z);
      vertices[11 * i + 3] = (mverts[i].normal.x);
      vertices[11 * i + 4] = (mverts[i].normal.y);
      vertices[11 * i + 5] = (mverts[i].normal.z);
      vertices[11 * i + 6] = (mverts[i].tangent.x);
      vertices[11 * i + 7] = (mverts[i].tangent.y);
      vertices[11 * i + 8] = (mverts[i].tangent.z);
      vertices[11 * i + 9] = (mverts[i].textureCoords.x);
      vertices[11 * i + 10] = (mverts[i].textureCoords.y);
    }

    numIndices = mesh.indices!.length;
    numVertices = mesh.vertices!.length;

    indicesBuffer =
        gpu.gpuContext.createDeviceBufferWithCopy(indices.buffer.asByteData());
    verticesBuffer =
        gpu.gpuContext.createDeviceBufferWithCopy(vertices.buffer.asByteData());
  }

  void fire() {
    logos.add(FlutterLogo(world!));
  }

  @override
  void start() {
    world = phys.World();

    // Create a static plane in the X-Z axis.
    var plane = phys.StaticPlaneShape(vm.Vector3(0, 1, 0), 0);

    // Make a static body (mass == 0.0) with the static plane shape
    // place it at the origin.
    var floorBody = phys.RigidBody(0.0, plane);

    world!.addBody(floorBody);

    const max = 2;
    for (int x = -max; x <= max; x++) {
      for (int y = -max; y <= max; y++) {
        for (int z = -max; z <= max; z++) {
          final vm.Vector3 position =
              vm.Vector3(x.toDouble(), y.toDouble(), z.toDouble()) * 5;
          vm.Matrix4 transform = vm.Matrix4.translation(position) *
              vm.Matrix4.rotationX(Random().nextDouble() * pi * 2) *
              vm.Matrix4.rotationY(Random().nextDouble() * pi * 2) *
              vm.Matrix4.rotationZ(Random().nextDouble() * pi * 2);
          logos.add(FlutterLogo.transform(transform));
        }
      }
    }

    //fire();
    //
    //ServicesBinding.instance.keyboard.addHandler((event) {
    //  if (event is KeyDownEvent) {
    //    debugPrint("fire");
    //    fire();
    //  }
    //  return false;
    //});
  }

  @override
  void fixedUpdate() {
    //world?.step(Game.fixedTickIntervalSeconds);
  }

  @override
  void update(double dt) {
    elapsedSeconds += dt/4;
  }

  @override
  void render(Canvas canvas, Size size) {
    /// Create a RenderPipeline using shaders from the asset.
    final vertex = shaderLibrary!['MeshVertex']!;
    final fragment = shaderLibrary!['MeshFragment']!;
    final pipeline = gpu.gpuContext.createRenderPipeline(vertex, fragment);

    /// Create the command buffer. This will be used to submit all encoded
    /// commands at the end.
    final commandBuffer = gpu.gpuContext.createCommandBuffer();

    final gpu.RenderTarget target = surface.getNextRenderTarget(size);

    /// Add a render pass encoder to the command buffer so that we can start
    /// encoding commands.
    final encoder = commandBuffer.createRenderPass(target);

    encoder.bindPipeline(pipeline);

    encoder.setDepthWriteEnable(true);
    encoder.setDepthCompareOperation(gpu.CompareFunction.less);

    /// Append quick geometry and uniforms to a host buffer that will be
    /// automatically uploaded to the GPU later on.
    final transients = gpu.HostBuffer();

    final camera = Camera(
        fovRadiansY: 60 * vm.degrees2Radians,
        position: vm.Vector3(
              sin(elapsedSeconds / 4),
              1,
              cos(elapsedSeconds / 4),
            ) *
            13.0,
        target: vm.Vector3(0, 2, 0));
    var viewProjectionMatrix = camera.getTransform(size.width / size.height);

    final mvpSlot = pipeline.vertexShader.getUniformSlot('mvp')!;
    final exposureData = transients.emplace(float32(<double>[1]));

    for (final logo in logos) {
      var modelMatrix = logo.getTransform(elapsedSeconds).scaled(0.02);
      final mvp =
          transients.emplace(float32Mat(viewProjectionMatrix * modelMatrix));

      /// Bind the vertex and index buffer.
      encoder.bindVertexBuffer(
          gpu.BufferView(verticesBuffer!,
              offsetInBytes: 0, lengthInBytes: verticesBuffer!.sizeInBytes),
          numVertices);
      encoder.bindIndexBuffer(
          gpu.BufferView(indicesBuffer!,
              offsetInBytes: 0, lengthInBytes: indicesBuffer!.sizeInBytes),
          gpu.IndexType.int16,
          numIndices);

      /// Bind the host buffer data we just created to the vertex shader's uniform
      /// slots. Although the locations are specified in the shader and are
      /// predictable, we can optionally fetch the uniform slots by name for
      /// convenience.
      encoder.bindUniform(mvpSlot, mvp);

      final exposureSlot = pipeline.fragmentShader.getUniformSlot('exposure')!;
      encoder.bindUniform(exposureSlot, exposureData);

      // Why is this 4 values?
      final cameraPosData = transients.emplace(float32(<double>[
        camera.position.x,
        camera.position.y,
        camera.position.z,
        camera.position.z
      ]));
      final cameraPosSlot =
          pipeline.fragmentShader.getUniformSlot('camera_position')!;
      encoder.bindUniform(cameraPosSlot, cameraPosData);

      final baseColorSlot =
          pipeline.fragmentShader.getUniformSlot('base_color_texture')!;
      encoder.bindTexture(baseColorSlot, baseColorTexture!);
      final normalSlot =
          pipeline.fragmentShader.getUniformSlot('normal_texture')!;
      encoder.bindTexture(normalSlot, normalTexture!);
      final ormSlot = pipeline.fragmentShader
          .getUniformSlot('occlusion_roughness_metallic_texture')!;
      encoder.bindTexture(ormSlot, occlusionRoughnessMetallicTexture!);

      /// And finally, we append a draw call.
      encoder.draw();
    }

    /// Submit all of the previously encoded passes. Passes are encoded in the
    /// same order they were created in.
    commandBuffer.submit();

    /// Wrap the Flutter GPU texture as a ui.Image and draw it like normal!
    final image = target.colorAttachments[0].texture.asImage();

    canvas.drawImage(image, Offset.zero, Paint());
  }
}
