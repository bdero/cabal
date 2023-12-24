import 'dart:ui';

import 'package:cabal/physics/physics.dart' as phys;
import 'package:oxygen/oxygen.dart' as oxy;

import 'package:cabal/base/components/camera_component.dart';
import 'package:cabal/base/components/mesh_component.dart';
import 'package:cabal/base/components/rigid_body_component.dart';
import 'package:cabal/base/components/transform_component.dart';
import 'package:cabal/base/game.dart';
import 'package:cabal/base/systems/physics_system.dart';
import 'package:cabal/base/systems/render_system.dart';

/// Interface for implementing a game driven by ECS systems.
///
/// This is much more "batteries included" than the mostly abstract [Game]
/// class, as it automatically instantiates an ECS world and registers various
/// components and systems to drive scene rendering and physics.
abstract class ECSGame extends Game {
  ECSGame()
      : _world = oxy.World(),
        physicsWorld = phys.World();

  final oxy.World _world;
  final phys.World physicsWorld;
  RenderSystem? _renderSystem;

  double _dt = 0;

  @override
  void start() {
    enableFixedUpdate = false;

    _world.registerComponent(() => TransformComponent());
    _world.registerComponent(() => CameraComponent());
    _world.registerComponent(() => MeshComponent());
    _world.registerComponent(() => RigidBodyComponent(physicsWorld));

    startECS(_world);

    _world.registerSystem(PhysicsSystem(physicsWorld));
    _renderSystem = RenderSystem();
    _world.registerSystem(_renderSystem!);

    _world.init();
  }

  /// Register game-specific components and systems, and create game-specific
  /// entities before the world begins.
  ///
  /// This method is called once after preloading has completed and all of the
  /// base components have been registered, but before the physics or render
  /// systems have been registered.
  void startECS(oxy.World world);

  @override
  void fixedUpdate() {}

  @override
  void update(double dt) {
    _dt = dt;
  }

  @override
  void render(Canvas canvas, Size size) {
    _renderSystem!.canvas = canvas;
    _renderSystem!.canvasSize = size;
    _world.execute(_dt);
  }
}
