part of '../ecs.dart';

// We support 1024 components.
const int _componentIdMin = 0;
const int _componentIdMax = 1 << 10;
// We support 32-bits or 4B entities.
const int _entityIdMin = 1 << 10;
const int _entityIdMax = 1 << 42;

int _nextComponentId = _componentIdMin;
int _nextEntityId = _entityIdMin;

int _getNextEntityId() {
  if (_nextEntityId == _entityIdMax) {
    // TODO(johnmccutchan): Start using a generation counter.
    throw StateError("Too many entities created registered.");
  }
  return _nextEntityId++;
}

int _getNextComponentId() {
  if (_nextComponentId == _componentIdMax) {
    throw StateError("Too many components registered.");
  }
  return _nextComponentId++;
}

void _testOnlyResetId() {
  _nextComponentId = _componentIdMin;
  _nextEntityId = _entityIdMin;
}
