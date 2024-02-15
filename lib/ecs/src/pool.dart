part of '../ecs.dart';

/// PoolingComponentFactory will pool component instances for future use.
class PoolingComponentFactory<V> extends ComponentFactory<V> {
  final Queue<ComponentInstance<V>> _freeList = Queue<ComponentInstance<V>>();
  final ComponentFactory<V> _innerFactory;
  int _size = 0;

  PoolingComponentFactory(this._innerFactory);

  @override
  ComponentInstance<V> allocInstance(ComponentType<V> type) {
    if (_freeList.isEmpty) {
      // Need to allocate more. Double the size each time.
      _extendBy(type, _size == 0 ? 1 : _size);
    }
    assert(_freeList.isNotEmpty);
    final instance = _freeList.removeFirst();
    return instance;
  }

  @override
  void freeInstance(ComponentInstance<V> instance) {
    _freeList.addLast(instance);
  }

  _extendBy(ComponentType<V> componentType, int count) {
    for (int i = 0; i < count; i++) {
      _freeList.addLast(_innerFactory.allocInstance(componentType));
    }
    _size += count;
  }
}
