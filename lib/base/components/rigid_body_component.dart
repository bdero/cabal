import 'package:oxygen/oxygen.dart' as oxy;
import 'package:cabal/physics/physics.dart' as phys;

class RigidBodyComponent extends oxy.Component<phys.RigidBody> {
  RigidBodyComponent(this.physicsWorld);

  phys.World physicsWorld;
  phys.RigidBody? rigidBody;

  @override
  void init([phys.RigidBody? data]) {
    rigidBody = data;
    physicsWorld.addBody(rigidBody!);
  }

  @override
  void reset() {
    if (rigidBody == null) {
      return;
    }
    physicsWorld.removeBody(rigidBody!);
    rigidBody = null;
  }
}
