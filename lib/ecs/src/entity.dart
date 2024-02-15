part of '../ecs.dart';

// Entity holds a set of components.
class Entity {
  final World world;
  final int id;
  final String? name;
  final Map<ComponentType, ComponentInstance> _components =
      <ComponentType, ComponentInstance>{};

  Entity._(this.world, this.id, [this.name]);

  /// Check if this entity has this component.
  bool has(ComponentType c) {
    return _components.containsKey(c);
  }

  /// Returns an instance of component type.
  ComponentInstance<V> getComponent<V>(ComponentType<V> ct) {
    if (_components.containsKey(ct)) {
      return _components[ct] as ComponentInstance<V>;
    }
    final instance = world._createComponentInstance(ct);
    _components[ct] = instance;
    world._streamControllerEntityComponentAdd.add(EntityComponentAdd(this, ct));
    return instance;
  }

  void remove<V>(ComponentInstance<V> instance) {
    final ct = instance.type;
    if (!_components.containsKey(ct)) {
      return;
    }
    assert(identical(_components[ct], instance));
    _components.remove(ct);
    world._streamControllerEntityComponentRemove
        .add(EntityComponentRemove(this, ct));
  }
}
