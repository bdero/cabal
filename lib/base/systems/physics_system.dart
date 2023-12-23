import 'package:oxygen/oxygen.dart' as oxy;
import 'package:flutter_bullet/physics3d.dart' as phys;
import 'package:vector_math/vector_math.dart' as vm;

import 'package:cabal/base/components/rigid_body_component.dart';
import 'package:cabal/base/components/transform_component.dart';

class PhysicsSystem extends oxy.System {
  PhysicsSystem(this.physicsWorld);

  phys.World physicsWorld;

  late oxy.Query rigidBodySyncQuery;

  @override
  void init() {
    rigidBodySyncQuery = createQuery([
      oxy.Has<RigidBodyComponent>(),
      oxy.Has<TransformComponent>(),
    ]);
  }

  @override
  void execute(double delta) {
    physicsWorld.step(delta);

    // When a RigidBody is attached, drive the Entity's transform.
    for (final entity in rigidBodySyncQuery.entities) {
      final transform = entity.get<TransformComponent>()!;
      final rigidBody = entity.get<RigidBodyComponent>()!;
      var modelMatrix =
          vm.Matrix4.fromFloat32List(rigidBody.rigidBody!.xform.storage);
      // Hack to fix the physics transform. Make the translation positional.
      transform.matrix = modelMatrix.clone()..setEntry(3, 3, 1);
    }
  }
}
