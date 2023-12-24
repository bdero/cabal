part of '../physics.dart';

enum Activation {
  // Activate the body.
  forceActivation,
  // Leave activation state as it is (will not deactive an active body).
  dontActivate,
}

// PhysicsLayers determine which other objects can collide with an object.
enum PhysicsLayer {
  // Moving objects.
  // Collides with everything.
  moving,
  // Non moving objects.
  // Collides with moving.
  nonMoving,
  // Sensor objects.
  // Collides with everything.
  sensor,
}

/// Physics world that can be populated with rigid bodies.
class World implements ffi.Finalizable {
  static final _finalizer =
      ffi.NativeFinalizer(jolt.bindings.addresses.destroy_world.cast());

  ffi.Pointer<jolt.World> _nativeWorld;

  final Set<Body> _bodies = Set<Body>();

  World._(this._nativeWorld) {
    _finalizer.attach(this, _nativeWorld.cast(), detach: this);
  }

  factory World() {
    final nativeWorld = jolt.bindings.create_world();
    return World._(nativeWorld);
  }

  // Step the simulation forward by dt.
  void step(double dt) {
    jolt.bindings.world_step(_nativeWorld, dt);
  }

  RigidBody createRigidBody(BodySettings settings) {
    final ffi.Pointer<jolt.BodyConfig> config =
        jolt.bindings.world_get_body_config(_nativeWorld);
    settings._copyToConfig(config);
    final nativeBody = jolt.bindings.world_create_body(_nativeWorld, config);
    return RigidBody._(this, nativeBody, settings.shape);
  }

  void addBody(Body body,
      {Activation activation = Activation.forceActivation}) {
    if (!_bodies.add(body)) {
      // Already added.
      return;
    }
    jolt.bindings
        .world_add_body(_nativeWorld, body._nativeBody, activation.index);
  }

  void removeBody(Body body) {
    if (!_bodies.remove(body)) {
      // Not added.
      return;
    }
    jolt.bindings.world_remove_body(_nativeWorld, body._nativeBody);
  }
}
