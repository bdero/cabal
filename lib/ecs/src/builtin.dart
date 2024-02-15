part of '../ecs.dart';

class Vector3Component extends ComponentInstance<Vector3> {
  Vector3Component(super.type);
  Vector3? _data;

  @override
  void set(Vector3? data) {
    _data = data;
  }

  @override
  Vector3? get() {
    return _data;
  }
}

class Vector3ComponentFactory extends ComponentFactory<Vector3> {
  @override
  ComponentInstance<Vector3> allocInstance(ComponentType<Vector3> type) {
    assert(type._factory == this);
    return Vector3Component(type);
  }

  @override
  void freeInstance(ComponentInstance<Vector3> instance) {}
}

class Float32ListComponent extends ComponentInstance<Float32List> {
  Float32ListComponent(this._data, super.type);
  final Float32List _data;

  @override
  void set(Float32List? data) {
    assert(data != null);
    assert(data != null && _data.length == data.length);
    for (int i = 0; i < _data.length; i++) {
      _data[i] = data![i];
    }
  }

  @override
  Float32List? get() {
    return _data;
  }
}

class Float4ComponentFactory extends ComponentFactory<Float32List> {
  @override
  ComponentInstance<Float32List> allocInstance(
      ComponentType<Float32List> type) {
    assert(identical(type._factory, this));
    return Float32ListComponent(Float32List(4), type);
  }

  @override
  void freeInstance(ComponentInstance<Float32List> instance) {}
}

class Float16ComponentFactory extends ComponentFactory<Float32List> {
  @override
  ComponentInstance<Float32List> allocInstance(
      ComponentType<Float32List> type) {
    assert(identical(type._factory, this));
    return Float32ListComponent(Float32List(16), type);
  }

  @override
  void freeInstance(ComponentInstance<Float32List> instance) {}
}

/// Vector3 component type.
late ComponentType<Vector3> vector3ComponentType;
// Float32List of length 4 component type.
late ComponentType<Float32List> float4ComponentType;
// Float32List of length 16 component type.
late ComponentType<Float32List> float16ComponentType;

registerBuiltins(World world) {
  vector3ComponentType = registerComponentType(Vector3ComponentFactory());
  float4ComponentType = registerComponentType(Float4ComponentFactory());
  float16ComponentType = registerComponentType(Float16ComponentFactory());
}
