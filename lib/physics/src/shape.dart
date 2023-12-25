part of '../physics.dart';

class Shape implements ffi.Finalizable {
  static final _finalizer =
      ffi.NativeFinalizer(jolt.bindings.addresses.destroy_shape.cast());

  ffi.Pointer<jolt.CollisionShape> _nativeShape;

  Shape._(this._nativeShape) {
    _finalizer.attach(this, _nativeShape.cast(), detach: this);
    jolt.bindings.shape_set_dart_owner(_nativeShape, this);
  }
}

// We currenlty only have a single config instance.
final ffi.Pointer<jolt.ConvexShapeConfig> _convexShapeConfig =
    jolt.bindings.get_convex_shape_config();

class ConvexShapeSettings {
  // Uniform density of the interior of the convex object (kg / m^3)
  double density = 1000.0;

  _copyToConvexShapeConfig(
      ffi.Pointer<jolt.ConvexShapeConfig> convexShapeConfig) {
    convexShapeConfig.ref.density = density;
  }
}

class ConvexShape extends Shape {
  ConvexShape._(ffi.Pointer<jolt.CollisionShape> nativeShape)
      : super._(nativeShape);
}

class BoxShapeSettings extends ConvexShapeSettings {
  BoxShapeSettings(this.halfExtents);

  // Box will be sized 2 * halfExtents centered at 0.
  Vector3 halfExtents;

  @override
  _copyToConvexShapeConfig(
      ffi.Pointer<jolt.ConvexShapeConfig> convexShapeConfig) {
    super._copyToConvexShapeConfig(convexShapeConfig);
    convexShapeConfig.ref.type = jolt.ConvexShapeConfigType.kBox;
    convexShapeConfig.ref.payload[0] = halfExtents[0];
    convexShapeConfig.ref.payload[1] = halfExtents[1];
    convexShapeConfig.ref.payload[2] = halfExtents[2];
  }
}

class BoxShape extends ConvexShape {
  BoxShape._(ffi.Pointer<jolt.CollisionShape> nativeShape)
      : super._(nativeShape);

  factory BoxShape(BoxShapeSettings settings) {
    settings._copyToConvexShapeConfig(_convexShapeConfig);
    final nativeShape =
        jolt.bindings.create_convex_shape(_convexShapeConfig, ffi.nullptr, 0);
    return BoxShape._(nativeShape);
  }
}

class SphereShapeSettings extends ConvexShapeSettings {
  SphereShapeSettings(this.radius);

  // Radius of the sphere.
  double radius;

  @override
  _copyToConvexShapeConfig(
      ffi.Pointer<jolt.ConvexShapeConfig> convexShapeConfig) {
    super._copyToConvexShapeConfig(convexShapeConfig);
    convexShapeConfig.ref.type = jolt.ConvexShapeConfigType.kSphere;
    convexShapeConfig.ref.payload[0] = radius;
  }
}

class SphereShape extends ConvexShape {
  SphereShape._(ffi.Pointer<jolt.CollisionShape> nativeShape)
      : super._(nativeShape);

  factory SphereShape(SphereShapeSettings settings) {
    settings._copyToConvexShapeConfig(_convexShapeConfig);
    final nativeShape =
        jolt.bindings.create_convex_shape(_convexShapeConfig, ffi.nullptr, 0);
    return SphereShape._(nativeShape);
  }
}

class CapsuleShapeSettings extends ConvexShapeSettings {
  // Radius is the same at the top and bottom of the capsule.
  CapsuleShapeSettings(this.halfHeight, this.topRadius)
      : bottomRadius = topRadius;

  // Radius is different at the top and bottom of the capsule.
  CapsuleShapeSettings.tapered(
      this.halfHeight, this.topRadius, this.bottomRadius);

  double halfHeight;
  double topRadius;
  double bottomRadius;

  @override
  _copyToConvexShapeConfig(
      ffi.Pointer<jolt.ConvexShapeConfig> convexShapeConfig) {
    super._copyToConvexShapeConfig(convexShapeConfig);
    convexShapeConfig.ref.type = jolt.ConvexShapeConfigType.kCapsule;
    convexShapeConfig.ref.payload[0] = halfHeight;
    convexShapeConfig.ref.payload[1] = topRadius;
    convexShapeConfig.ref.payload[2] = bottomRadius;
  }
}

class CapsuleShape extends ConvexShape {
  CapsuleShape._(ffi.Pointer<jolt.CollisionShape> nativeShape)
      : super._(nativeShape);

  factory CapsuleShape(CapsuleShapeSettings settings) {
    settings._copyToConvexShapeConfig(_convexShapeConfig);
    final nativeShape =
        jolt.bindings.create_convex_shape(_convexShapeConfig, ffi.nullptr, 0);
    return CapsuleShape._(nativeShape);
  }
}

class ConvexHullShapeSettings extends ConvexShapeSettings {
  ConvexHullShapeSettings(this.points);

  @override
  _copyToConvexShapeConfig(
      ffi.Pointer<jolt.ConvexShapeConfig> convexShapeConfig) {
    super._copyToConvexShapeConfig(convexShapeConfig);
    convexShapeConfig.ref.type = jolt.ConvexShapeConfigType.kConvexHull;
  }

  Float32List points;
}

class ConvexHullShape extends ConvexShape {
  ConvexHullShape._(ffi.Pointer<jolt.CollisionShape> nativeShape)
      : super._(nativeShape);

  static final unwrappedCreateConvexShape = jolt.dylib.lookupFunction<
      ffi.Pointer<jolt.CollisionShape> Function(
          ffi.Pointer<jolt.ConvexShapeConfig>, ffi.Pointer<ffi.Float>, ffi.Int),
      ffi.Pointer<jolt.CollisionShape> Function(
          ffi.Pointer<jolt.ConvexShapeConfig>,
          Float32List,
          int)>('create_convex_shape', isLeaf: true);

  factory ConvexHullShape(ConvexHullShapeSettings settings) {
    settings._copyToConvexShapeConfig(_convexShapeConfig);
    final nativeShape = unwrappedCreateConvexShape(
        _convexShapeConfig, settings.points, settings.points.length ~/ 3);
    return ConvexHullShape._(nativeShape);
  }
}
