part of '../ecs.dart';

/// A ComponentType<V> is a registered component of type V.
class ComponentType<V> {
  final int id;
  final ComponentFactory<V> _factory;
  ComponentType._(this.id, this._factory);
}

/// A ComponentFactory is responsible for allocating and freeing component
/// instances.
abstract class ComponentFactory<V> {
  /// Returns a free instance
  ComponentInstance<V> allocInstance(ComponentType<V> type);

  /// Marks instance as no longer being used.
  void freeInstance(ComponentInstance<V> instance);
}

/// An instance of a component.
abstract class ComponentInstance<V> {
  final ComponentType<V> type;

  ComponentInstance(this.type);

  // mustCallSuper.
  void dispose() {
    type._factory.freeInstance(this);
  }

  void set(V? data);

  V? get();
}
