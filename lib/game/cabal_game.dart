import 'dart:typed_data';

import 'package:cabal/physics/physics.dart' as phys;
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

ByteData uint32(List<int> values) {
  return Uint32List.fromList(values).buffer.asByteData();
}

class BoxSpawnSystem extends oxy.System {
  static const double threshold = 0.1;

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
    final body = physicsWorld.createRigidBody(
        phys.BodySettings(box)..motionType = phys.MotionType.dynamic)
      ..position = vm.Vector3(0, 10, 0)
      ..rotation = vm.Quaternion.euler(1, 1, 1);

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
    /// Create static floor and box spawner.
    ///

    final floorPlane = phys.BoxShape(vm.Vector3(100, 1, 100));
    final floor = physicsWorld.createRigidBody(
        phys.BodySettings(floorPlane)..motionType = phys.MotionType.static);
    world.createEntity().add<RigidBodyComponent, phys.RigidBody>(floor);

    world.registerSystem(BoxSpawnSystem(physicsWorld));
  }
}
