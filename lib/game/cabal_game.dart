import 'dart:typed_data';

import 'package:flutter_bullet/physics3d.dart' as phys;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:oxygen/oxygen.dart' as oxy;
import 'package:vector_math/vector_math.dart' as vm;

import 'package:cabal/base/components/camera_component.dart';
import 'package:cabal/base/components/mesh_component.dart';
import 'package:cabal/base/components/rigid_body_component.dart';
import 'package:cabal/base/geometry.dart';
import 'package:cabal/base/material.dart';
import 'package:cabal/base/mesh.dart';
import 'package:cabal/base/camera.dart';
import 'package:cabal/base/components/transform_component.dart';
import 'package:cabal/base/ecs_game.dart';

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

class BoxSpawnSystem extends oxy.System {
  static const double threshold = 1;

  BoxSpawnSystem(this.physicsWorld);

  phys.World physicsWorld;
  double time = 1;
  late gpu.Texture boxTexture;

  @override
  void init() {
    boxTexture = gpu.gpuContext.createTexture(gpu.StorageMode.hostVisible, 5, 5,
        enableShaderReadUsage: true)!;
    boxTexture.overwrite(uint32(<int>[
      0xFFFFFFFF, 0x00000000, 0xFFFFFFFF, 0x00000000, 0xFFFFFFFF, //
      0x00000000, 0xFFFFFFFF, 0x00000000, 0xFFFFFFFF, 0x00000000, //
      0xFFFFFFFF, 0x00000000, 0xFFFFFFFF, 0x00000000, 0xFFFFFFFF, //
      0x00000000, 0xFFFFFFFF, 0x00000000, 0xFFFFFFFF, 0x00000000, //
      0xFFFFFFFF, 0x00000000, 0xFFFFFFFF, 0x00000000, 0xFFFFFFFF, //
    ]));
  }

  @override
  void execute(double delta) {
    time += delta;
    if (time < threshold) {
      return;
    }

    final boxExtents = vm.Vector3(1, 1, 1);

    final cubeMesh = Mesh(
        geometry: CuboidGeometry(boxExtents),
        material: UnlitMaterial(colorTexture: boxTexture));

    final box = phys.BoxShape(boxExtents / 2);
    final body = phys.RigidBody(1, box)
      ..xform.origin = vm.Vector3(0, 10, 0)
      ..xform.rotation = vm.Quaternion.euler(1, 1, 1);

    world!.createEntity()
      ..add<TransformComponent, vm.Matrix4>()
      ..add<MeshComponent, Mesh>(cubeMesh)
      ..add<RigidBodyComponent, phys.RigidBody>(body);

    time -= threshold;
  }
}

class CabalGame extends ECSGame {
  @override
  Future<void> preload() async {
    return Future.value();
  }

  @override
  void startECS(oxy.World world) {
    //--------------------------------------------------------------------------
    /// Setup camera.
    ///

    world.createEntity()
      ..add<TransformComponent, vm.Matrix4>(vm.Matrix4.identity())
      ..add<CameraComponent, Camera>(Camera(
          fovRadiansY: 60 * vm.degrees2Radians,
          position: vm.Vector3(8, 8, 8),
          target: vm.Vector3(0, 2, 0)));

    //--------------------------------------------------------------------------
    /// Create spawner.
    ///

    world.registerSystem(BoxSpawnSystem(physicsWorld));
  }
}
