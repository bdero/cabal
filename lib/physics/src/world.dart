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
        calloc.allocate(ffi.sizeOf<jolt.BodyConfig>());
    settings._copyToConfig(config);
    final nativeBody = jolt.bindings.world_create_body(_nativeWorld, config);
    calloc.free(config);
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

  void _rayCast(Vector3 start, Vector3 end, OnRayHit onRayHit) {
    double closure(
        Object body, double fraction, ffi.Pointer<ffi.Float> normal) {
      assert(body is Body);
      RayHit hit = RayHit(body as Body,
          Vector3.fromFloat32List(normal.asTypedList(3)), fraction, start, end);
      return onRayHit(hit);
    }

    final callback = ffi.NativeCallable<
            ffi.Float Function(
                ffi.Handle, ffi.Float, ffi.Pointer<ffi.Float>)>.isolateLocal(
        closure,
        exceptionalReturn: 0.0);

    final ffi.Pointer<jolt.RayCastConfig> native_config =
        calloc.allocate(ffi.sizeOf<jolt.RayCastConfig>());

    copyVector3(start, native_config.ref.start);
    copyVector3(end, native_config.ref.end);
    native_config.ref.cb = callback.nativeFunction;

    jolt.bindings.world_raycast(_nativeWorld, native_config);

    calloc.free(native_config);

    callback.close();
  }
}
