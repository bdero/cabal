part of '../ecs.dart';

/// Event fired when an entity has a component added.
class EntityComponentAdd {
  final Entity entity;
  final ComponentType componentType;

  EntityComponentAdd(this.entity, this.componentType);
}

/// Event fired when an entity has a component removed.
class EntityComponentRemove {
  final Entity entity;
  final ComponentType componentType;

  EntityComponentRemove(this.entity, this.componentType);
}

class World {
  final Map<int, Entity> _entities = <int, Entity>{};
  final Set<System> _systems = <System>{};
  final StreamController<EntityComponentAdd>
      _streamControllerEntityComponentAdd =
      StreamController<EntityComponentAdd>.broadcast();
  final StreamController<EntityComponentRemove>
      _streamControllerEntityComponentRemove =
      StreamController<EntityComponentRemove>.broadcast();
  final StreamController<Entity> _streamControllerEntityAdd =
      StreamController<Entity>.broadcast();
  final StreamController<Entity> _streamControllerEntityRemove =
      StreamController<Entity>.broadcast();

  UnmodifiableListView<Entity> get entities {
    return UnmodifiableListView(_entities.values);
  }

  /// Adds an entity to the world and returns it.
  Entity addEntity([String? name]) {
    int id = _getNextEntityId();
    Entity e = Entity._(this, id, name);
    assert(!_entities.containsKey(id));
    _entities[id] = e;
    _streamControllerEntityAdd.add(e);
    return e;
  }

  /// Lookup an entity by id.
  Entity? lookupEntity(int id) {
    return _entities[id];
  }

  void removeEntity(Entity e) {
    if (!_entities.containsKey(e.id)) {
      return;
    }
    _entities.remove(e.id);
    _streamControllerEntityRemove.add(e);
  }

  ComponentInstance<V> _createComponentInstance<V>(ComponentType<V> type) {
    ComponentFactory<V>? factory =
        _componentFactories[type] as ComponentFactory<V>?;
    if (factory == null) {
      throw UnsupportedError('Unrecognized ComponentType: $type');
    }
    return factory.allocInstance(type);
  }

  void addSystem(System system) {
    assert(!_systems.contains(system));
    _systems.add(system);
  }

  void removeSystem(System system) {
    assert(_systems.contains(system));
    _systems.remove(system);
  }

  void tick(double dt) {
    for (final System system in _systems) {
      system.tick(dt);
    }
  }

  /// Stream of components being added to entities.
  Stream<EntityComponentAdd> get onEntityComponentAdd {
    return _streamControllerEntityComponentAdd.stream;
  }

  /// Stream of components being removed from entities.
  Stream<EntityComponentRemove> get onEntityComponentRemove {
    return _streamControllerEntityComponentRemove.stream;
  }

  /// Stream of entities being added to the world.
  Stream<Entity> get onEntityAdd {
    return _streamControllerEntityAdd.stream;
  }

  /// Stream of entities being removed from the world.
  Stream<Entity> get onEntityRemove {
    return _streamControllerEntityRemove.stream;
  }
}
