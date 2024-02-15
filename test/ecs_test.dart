import 'package:cabal/ecs/ecs.dart';
import 'package:test/expect.dart';
import 'package:vector_math/vector_math.dart';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'dart:math';

class TestComponent extends ComponentInstance<bool> {
  TestComponent(super.type);
  bool? _data;

  @override
  void set(bool? data) {
    _data = data;
  }

  @override
  bool? get() {
    return _data;
  }
}

class TestComponentFactory extends ComponentFactory<bool> {
  @override
  ComponentInstance<bool> allocInstance(ComponentType<bool> type) {
    return TestComponent(type);
  }

  @override
  void freeInstance(ComponentInstance<bool> instance) {}
}

class TestSystem extends System {
  TestSystem(super.world);

  @override
  void tick(double dt) {
    totalTickTime += dt;
  }

  double totalTickTime = 0.0;
}

class FixedFilter extends Filter {
  final bool result;

  FixedFilter(this.result);

  @override
  bool match(Entity entity) {
    return result;
  }
}

main() {
  tearDown(() {
    TestOnly.reset();
  });

  test('component factory executed', () {
    final ComponentType<bool> testComponentType =
        registerComponentType(TestComponentFactory());

    final World world = World();

    final Entity entity = world.addEntity();

    final ComponentInstance<bool> inst = entity.getComponent(testComponentType);

    expect(inst, isNotNull);

    final ComponentInstance<bool> inst2 =
        entity.getComponent(testComponentType);

    expect(identical(inst, inst2), isTrue);
  });

  test('systems tick', () {
    final World world = World();

    final TestSystem system = TestSystem(world);

    // Tick before adding the system.
    world.tick(0.5);
    expect(system.totalTickTime, equals(0.0));

    // Tick after adding the system.
    world.addSystem(system);
    world.tick(0.5);
    expect(system.totalTickTime, equals(0.5));

    // Tick after removing the system.
    world.removeSystem(system);
    world.tick(0.5);
    expect(system.totalTickTime, equals(0.5));
  });

  test('query', () {
    final World world = World();
    final Query q = Query(world, [FixedFilter(true)]);

    expect(q.entities.length, equals(0));

    final Entity e = world.addEntity();

    expect(q.entities.length, equals(1));
    expect(q.entities[0], equals(e));

    world.removeEntity(e);

    expect(q.entities.length, equals(0));
  });
}
