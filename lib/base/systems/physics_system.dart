import 'package:oxygen/oxygen.dart' as oxy;
import 'package:cabal/physics/physics.dart' as phys;
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
      final rigidBody = entity.get<RigidBodyComponent>()!.rigidBody!;
      transform.matrix = rigidBody.worldTransform;
    }
  }
}
