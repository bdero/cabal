part of '../ecs.dart';

// ComponentTypes are globally registered. This is done to ensure that
// if we move an entity between worlds their component type ids are stable.
final Map<ComponentType, ComponentFactory> _componentFactories =
    <ComponentType, ComponentFactory>{};

/// Register a component type with factory.
ComponentType<V> registerComponentType<V>(ComponentFactory<V> factory) {
  final int id = _getNextComponentId();
  final componentType = ComponentType<V>._(id, factory);
  _componentFactories[componentType] = factory;
  return componentType;
}

void _testOnlyResetTypes() {
  _componentFactories.clear();
}
