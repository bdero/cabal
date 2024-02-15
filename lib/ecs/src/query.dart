part of '../ecs.dart';

/// A filter allows a [Query] to be able to filter down entities.
abstract class Filter {
  Filter();

  /// Method for matching an [Entity] against this filter.
  bool match(Entity entity);
}

class Has extends Filter {
  final ComponentType _componentType;
  Has(this._componentType);

  @override
  bool match(Entity entity) => entity.has(_componentType);
}

class HasNot extends Filter {
  final ComponentType _componentType;
  HasNot(this._componentType);

  @override
  bool match(Entity entity) => !entity.has(_componentType);
}

/// A Query is a way to retrieve a set entities that satisfy a set of Filters.
class Query {
  final World world;

  Query(this.world, this._filters);

  /// The filters used by this query.
  final Iterable<Filter> _filters;

  final List<Entity> _entities = [];

  /// Entities that are found through [_filters].
  List<Entity> get entities {
    // TODO(johnmccutchan): Computing this every time we access the entities
    // is not efficient. Subscribe to the streams and progressively update
    // the query.
    _update();
    return List.unmodifiable(_entities);
  }

  void _update() {
    _entities.clear();
    for (final entity in world._entities.values) {
      if (_match(entity)) {
        _entities.add(entity);
      }
    }
  }

  /// Check if the given entity matches against the query.
  bool _match(Entity entity) =>
      _filters.every((filter) => filter.match(entity));
}
