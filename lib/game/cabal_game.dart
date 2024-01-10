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

class BoxSpawner {
  BoxSpawner() {
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

  void spawnBox(oxy.World world, phys.World physicsWorld, vm.Vector3 p,
      [vm.Quaternion? q]) {
    final boxExtents = vm.Vector3(1, 1, 1);

    final cubeMesh = Mesh(
        geometry: CuboidGeometry(boxExtents),
        material: UnlitMaterial(colorTexture: boxTexture));

    final box = phys.BoxShape(phys.BoxShapeSettings(boxExtents / 2));
    final body = physicsWorld.createRigidBody(
        phys.BodySettings(box)..motionType = phys.MotionType.dynamic)
      ..position = p;
    if (q != null) {
      body.rotation = q!;
    }

    world!.createEntity()
      ..add<TransformComponent, vm.Matrix4>()
      ..add<MeshComponent, Mesh>(cubeMesh)
      ..add<RigidBodyComponent, phys.RigidBody>(body);
  }

  late gpu.Texture boxTexture;
}

final BoxSpawner boxSpawner = new BoxSpawner();

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

    boxSpawner.spawnBox(world!, physicsWorld, vm.Vector3(0, 10, 0),
        vm.Quaternion.euler(1, 1, 1));
    time -= threshold;
  }
}

enum SceneType {
  fallingBoxes(1, 'Falling Boxes'),
  wall(2, 'Wall'),
  pyramid(3, 'Pyramid');

  const SceneType(this.id, this.label);

  final int id;
  final String label;
}

class CabalGame extends ECSGame {
  CabalGame(this.scene);

  final SceneType scene;

  @override
  Future<void> preload() async {
    return Future.value();
  }

  @override
  void startECS(oxy.World world) {
    print('starting ${scene.label}');

    //--------------------------------------------------------------------------
    /// Setup camera.
    ///

    world.createEntity()
      ..add<TransformComponent, vm.Matrix4>(vm.Matrix4.identity())
      ..add<CameraComponent, Camera>(Camera(
          fovRadiansY: 60 * vm.degrees2Radians,
          position: vm.Vector3(8, 8, 8),
          target: vm.Vector3(0, 2, 0)));

    switch (scene) {
      case SceneType.fallingBoxes:
        //--------------------------------------------------------------------------
        /// Create static floor and box spawner.
        ///
        final floorPlane =
            phys.BoxShape(phys.BoxShapeSettings(vm.Vector3(100, 1, 100)));
        final floor = physicsWorld.createRigidBody(
            phys.BodySettings(floorPlane)..motionType = phys.MotionType.static);
        world.createEntity().add<RigidBodyComponent, phys.RigidBody>(floor);

        world.registerSystem(BoxSpawnSystem(physicsWorld));
      case SceneType.wall:
        //--------------------------------------------------------------------------
        /// Create static floor and wall.
        ///
        final floorPlane =
            phys.BoxShape(phys.BoxShapeSettings(vm.Vector3(100, 1, 100)));
        final floor = physicsWorld.createRigidBody(
            phys.BodySettings(floorPlane)..motionType = phys.MotionType.static);
        world.createEntity().add<RigidBodyComponent, phys.RigidBody>(floor);
        const int wallSize = 5;
        for (int i = 0; i < wallSize; i++) {
          for (int j = 0; j < wallSize; j++) {
            const double size = 1.15;
            const double x = 0;
            final double y = j * size + 1.2;
            final double z = i * size;
            boxSpawner.spawnBox(world!, physicsWorld, vm.Vector3(x, y, z));
          }
        }
      case SceneType.pyramid:
        //--------------------------------------------------------------------------
        /// Create static floor and pyramid.
        ///
        final floorPlane =
            phys.BoxShape(phys.BoxShapeSettings(vm.Vector3(100, 1, 100)));
        final floor = physicsWorld.createRigidBody(
            phys.BodySettings(floorPlane)..motionType = phys.MotionType.static);
        world.createEntity().add<RigidBodyComponent, phys.RigidBody>(floor);

        const int pyramidHeight = 5;
        for (int i = 0; i < pyramidHeight; i++) {
          for (var j = i; j < pyramidHeight - 1; j++) {
            const double size = 1.15;
            const double x = 0;
            final double y = (pyramidHeight - j) * size + 1.2 - 2.0;
            final double z = i * size;
            boxSpawner.spawnBox(world!, physicsWorld, vm.Vector3(x, y, z));
            boxSpawner.spawnBox(world!, physicsWorld, vm.Vector3(x, y, -z));
          }
        }
    }
  }
}
