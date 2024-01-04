part of '../physics.dart';

class Shape implements ffi.Finalizable {
  static final _finalizer =
      ffi.NativeFinalizer(jolt.bindings.addresses.destroy_shape.cast());

  ffi.Pointer<jolt.CollisionShape> _nativeShape;

  Shape._(this._nativeShape) {
    _finalizer.attach(this, _nativeShape.cast(), detach: this);
    jolt.bindings.shape_set_dart_owner(_nativeShape, this);
    assert(identical(jolt.bindings.shape_get_dart_owner(_nativeShape), this));
  }

  static final unwrappedGetCenterOfMass = jolt.dylib.lookupFunction<
      ffi.Void Function(
          ffi.Pointer<jolt.CollisionShape>, ffi.Pointer<ffi.Float>),
      void Function(ffi.Pointer<jolt.CollisionShape>,
          Float32List)>('shape_get_center_of_mass', isLeaf: true);

  Vector3 get centerOfMass {
    Vector3 r = Vector3.zero();
    unwrappedGetCenterOfMass(_nativeShape, r.storage);
    return r;
  }

  static final unwrappedGetLocalBounds = jolt.dylib.lookupFunction<
      ffi.Void Function(ffi.Pointer<jolt.CollisionShape>,
          ffi.Pointer<ffi.Float>, ffi.Pointer<ffi.Float>),
      void Function(ffi.Pointer<jolt.CollisionShape>, Float32List,
          Float32List)>('shape_get_local_bounds', isLeaf: true);

  Aabb3 get localBounds {
    Aabb3 r = Aabb3();
    unwrappedGetLocalBounds(_nativeShape, r.min.storage, r.max.storage);
    return r;
  }
}

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
    ffi.Pointer<jolt.ConvexShapeConfig> config =
        calloc.allocate(ffi.sizeOf<jolt.ConvexShapeConfig>());
    settings._copyToConvexShapeConfig(config);
    final nativeShape =
        jolt.bindings.create_convex_shape(config, ffi.nullptr, 0);
    calloc.free(config);
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
    ffi.Pointer<jolt.ConvexShapeConfig> config =
        calloc.allocate(ffi.sizeOf<jolt.ConvexShapeConfig>());
    settings._copyToConvexShapeConfig(config);
    final nativeShape =
        jolt.bindings.create_convex_shape(config, ffi.nullptr, 0);
    calloc.free(config);
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
    ffi.Pointer<jolt.ConvexShapeConfig> config =
        calloc.allocate(ffi.sizeOf<jolt.ConvexShapeConfig>());
    settings._copyToConvexShapeConfig(config);
    final nativeShape =
        jolt.bindings.create_convex_shape(config, ffi.nullptr, 0);
    calloc.free(config);
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
    ffi.Pointer<jolt.ConvexShapeConfig> config =
        calloc.allocate(ffi.sizeOf<jolt.ConvexShapeConfig>());
    settings._copyToConvexShapeConfig(config);
    final nativeShape = unwrappedCreateConvexShape(
        config, settings.points, settings.points.length ~/ 3);
    calloc.free(config);
    return ConvexHullShape._(nativeShape);
  }
}

class CompoundShapeSettings {
  _copyToCompoundShapeConfig(
      List<ffi.Pointer<jolt.CompoundShapeConfig>> configs) {
    for (int i = 0; i < _shapes.length; i++) {
      configs[i].ref.position[0] = _positions[i].x;
      configs[i].ref.position[1] = _positions[i].y;
      configs[i].ref.position[2] = _positions[i].z;
      configs[i].ref.rotation[0] = _rotations[i].x;
      configs[i].ref.rotation[1] = _rotations[i].y;
      configs[i].ref.rotation[2] = _rotations[i].z;
      configs[i].ref.rotation[3] = _rotations[i].w;
      configs[i].ref.shape = _shapes[i]._nativeShape;
    }
  }

  final List<Shape> _shapes = [];
  final List<Vector3> _positions = [];
  final List<Quaternion> _rotations = [];

  int get length {
    return _shapes.length;
  }

  void addShape(Shape shape, Vector3 position, Quaternion rotation) {
    _shapes.add(shape);
    _positions.add(position);
    _rotations.add(rotation);
  }
}

class CompoundShape extends Shape {
  CompoundShape._(ffi.Pointer<jolt.CollisionShape> nativeShape)
      : super._(nativeShape);

  factory CompoundShape(CompoundShapeSettings settings) {
    ffi.Pointer<jolt.CompoundShapeConfig> configs = calloc
        .allocate(ffi.sizeOf<jolt.CompoundShapeConfig>() * settings.length);
    int configsAddress = configs.address;
    List<ffi.Pointer<jolt.CompoundShapeConfig>> configs_array =
        List<ffi.Pointer<jolt.CompoundShapeConfig>>.filled(settings.length,
            ffi.Pointer<jolt.CompoundShapeConfig>.fromAddress(0));
    for (int i = 0; i < settings.length; i++) {
      configs_array[i] = ffi.Pointer<jolt.CompoundShapeConfig>.fromAddress(
          configsAddress + ffi.sizeOf<jolt.CompoundShapeConfig>() * i);
    }
    settings._copyToCompoundShapeConfig(configs_array);
    final nativeShape = jolt.bindings.create_compound_shape(
        ffi.Pointer<jolt.CompoundShapeConfig>.fromAddress(configsAddress),
        settings.length);
    calloc.free(configs);
    return CompoundShape._(nativeShape);
  }
}

final emptyUint32List = Uint32List(0);

class MeshShapeSettings {
  Float32List vertices;
  Uint32List indices;

  MeshShapeSettings(this.vertices, this.indices) {
    assert(vertices.length % 3 == 0);
    assert(indices.length % 3 == 0);
  }
}

class MeshShape extends Shape {
  MeshShape._(ffi.Pointer<jolt.CollisionShape> nativeShape)
      : super._(nativeShape);

  static final unwrappedCreateMeshShape = jolt.dylib.lookupFunction<
      ffi.Pointer<jolt.CollisionShape> Function(
          ffi.Pointer<ffi.Float>, ffi.Int, ffi.Pointer<ffi.Uint32>, ffi.Int),
      ffi.Pointer<jolt.CollisionShape> Function(Float32List, int, Uint32List,
          int)>('create_mesh_shape', isLeaf: true);

  factory MeshShape(MeshShapeSettings settings) {
    final nativeShape = unwrappedCreateMeshShape(
        settings.vertices,
        settings.vertices.length ~/ 3,
        settings.indices,
        settings.indices.length ~/ 3);
    return MeshShape._(nativeShape);
  }
}
