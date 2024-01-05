import 'package:cabal/physics/physics.dart';
import 'package:test/expect.dart';
import 'package:vector_math/vector_math.dart';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'dart:math';

main() {
  // Create a physics world. Gravity is -Y.
  late World world;

  setUp(() {
    world = new World();
  });

  // // 1/60.
  final dt = 0.0625;

  group('Body', () {
    test('position', () {
      final plane = BoxShape(BoxShapeSettings(Vector3(100, 1, 100)));
      final ground = world.createRigidBody(
          BodySettings(plane)..position = Vector3(1.0, 0.0, 0));
      expect(ground.position, equals(Vector3(1.0, 0.0, 0)));
      final p = Vector3(0, 10, 0);
      ground.position = p;
      expect(ground.position, equals(p));
    });

    test('rotation', () {
      final plane = BoxShape(BoxShapeSettings(Vector3(100, 1, 100)));
      final ground = world.createRigidBody(BodySettings(plane)
        ..rotation = Quaternion.axisAngle(Vector3(0, 1, 0), pi / 2.0));
      expect(ground.rotation.storage,
          equals(Quaternion.axisAngle(Vector3(0, 1, 0), pi / 2.0).storage));
      final q = Quaternion.axisAngle(Vector3(1, 0, 0), pi / 2.0);
      ground.rotation = q;
      expect(ground.rotation.storage, equals(q.storage));
    });
  });

  test('matrix', () {
    var unitCube = BoxShape(BoxShapeSettings(Vector3(0.5, 0.5, 0.5)));
    var box = world.createRigidBody(BodySettings(unitCube));
    expect(box.worldTransform, equals(Matrix4.identity()));
  });

  test('gravity', () {
    var sphere = SphereShape(SphereShapeSettings(1));
    var ball = world.createRigidBody(BodySettings(sphere)
      ..position = Vector3(0, 10, 0)
      ..motionType = MotionType.dynamic);
    world.addBody(ball);
    expect(ball.position.y, equals(10));
    world.step(dt);
    expect(ball.position.y, lessThan(10));
  });

  test('body settles', () {
    var unitCube = BoxShape(BoxShapeSettings(Vector3(0.5, 0.5, 0.5)));
    var box = world.createRigidBody(BodySettings(unitCube)
      ..position = Vector3(0, 2, 0)
      ..motionType = MotionType.dynamic);
    world.addBody(box);
    final plane = BoxShape(BoxShapeSettings(Vector3(100, 1, 100)));
    final ground = world.createRigidBody(BodySettings(plane)
      ..position = Vector3(0.0, -1.0, 0)
      ..motionType = MotionType.static);
    world.addBody(ground);

    // Drop a box onto a larger (static) box. Eventually the box should
    // be automatically deactivated.
    while (box.active) {
      world.step(dt);
    }
  });

  test('boxes stack', () {
    var unitCube = BoxShape(BoxShapeSettings(Vector3(2.0, 2.0, 2.0)));
    var box0 = world.createRigidBody(BodySettings(unitCube)
      ..position = Vector3(0, 6.0, 0)
      ..motionType = MotionType.dynamic);
    var box1 = world.createRigidBody(BodySettings(unitCube)
      ..position = Vector3(0, 3.0, 0)
      ..motionType = MotionType.dynamic);
    world.addBody(box0);
    world.addBody(box1);
    final plane = BoxShape(BoxShapeSettings(Vector3(100, 1, 100)));
    final ground = world.createRigidBody(BodySettings(plane)
      ..position = Vector3(0.0, -1.0, 0)
      ..motionType = MotionType.static);
    world.addBody(ground);

    while (box0.active || box1.active) {
      world.step(dt);
    }
    print(box0.position);
    print(box1.position);
  });

  test('convex hull shape', () {
    var settings = ConvexHullShapeSettings(Float32List.fromList([
      -2.0,
      0.0,
      0.0,
      0.0,
      -2.0,
      0.0,
      0.0,
      0.0,
      -2.0,
      2.0,
      0.0,
      0.0,
      0.0,
      2.0,
      0.0,
      0.0,
      0.0,
      2.0
    ]));
    var unitCube = ConvexHullShape(settings);
    var box = world.createRigidBody(BodySettings(unitCube)
      ..position = Vector3(0, 2, 0)
      ..motionType = MotionType.dynamic);
    world.addBody(box);
    final plane = BoxShape(BoxShapeSettings(Vector3(100, 1, 100)));
    final ground = world.createRigidBody(BodySettings(plane)
      ..position = Vector3(0.0, -1.0, 0)
      ..motionType = MotionType.static);
    world.addBody(ground);

    // Drop a box onto a larger (static) box. Eventually the box should
    // be automatically deactivated.
    while (box.active) {
      world.step(dt);
    }
  });

  test('compound shape', () {
    var unitCube = BoxShape(BoxShapeSettings(Vector3(2.0, 2.0, 2.0)));
    var compoundShape = CompoundShape(CompoundShapeSettings()
      ..addShape(unitCube, Vector3(0.0, 0.0, 0.0), Quaternion.identity())
      ..addShape(unitCube, Vector3(0.0, 2.0, 0.0), Quaternion.identity()));
    expect(compoundShape.localBounds.min, equals(Vector3(-2, -3, -2)));
    expect(compoundShape.localBounds.max, equals(Vector3(2, 3, 2)));
  });

  test('mesh shape', () {
    var triangleMesh = MeshShape(MeshShapeSettings(
        Float32List.fromList([0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0]),
        Uint32List.fromList([0, 1, 2, 0, 2, 3])));
    expect(triangleMesh.localBounds.min, equals(Vector3(0, 0, 0)));
    expect(triangleMesh.localBounds.max, equals(Vector3(1, 1, 0)));
  });

  test('raycast', () {
    final plane = BoxShape(BoxShapeSettings(Vector3(100, 1, 100)));
    final ground = world
        .createRigidBody(BodySettings(plane)..position = Vector3(0.0, 0.0, 0));
    expect(ground.position, equals(Vector3(0.0, 0.0, 0)));
    world.addBody(ground);
    int count = 0;
    rayCast(world, Vector3(0, 10, 0), Vector3(0, -10, 0), (RayHit hit) {
      expect(identical(hit.body, ground), isTrue);
      expect(hit.normal, equals(Vector3(0, 1, 0)));
      count++;
      return hit.fraction;
    });
    expect(count, equals(1));
  });

  test('scaled shape', () {
    var unitCube = BoxShape(BoxShapeSettings(Vector3(0.5, 0.5, 0.5)));
    var scaledCube =
        ScaledShape(ScaledShapeSettings(unitCube, Vector3(4, 4, 4)));
    expect(scaledCube.localBounds.min, equals(Vector3(-2, -2, -2)));
    expect(scaledCube.localBounds.max, equals(Vector3(2, 2, 2)));
    var box = world.createRigidBody(BodySettings(scaledCube)
      ..position = Vector3(0, 8, 0)
      ..motionType = MotionType.dynamic);
    world.addBody(box);
    final plane = BoxShape(BoxShapeSettings(Vector3(100, 1, 100)));
    final ground = world.createRigidBody(BodySettings(plane)
      ..position = Vector3(0.0, -1.0, 0)
      ..motionType = MotionType.static);
    world.addBody(ground);

    while (box.active) {
      world.step(dt);
    }

    // Box has center near 2.0.
    expect(2.0 - box.position.y, lessThan(0.03));
  });

  test('transformed shape', () {
    var unitCube = BoxShape(BoxShapeSettings(Vector3(0.5, 0.5, 0.5)));
    var transformedCube = TransformedShape(TransformedShapeSettings(unitCube,
        Vector3(0, 0, 0), Quaternion.axisAngle(Vector3(0, 1, 0), pi * 0.25)));
    final minX = transformedCube.localBounds.min.x;
    final maxX = transformedCube.localBounds.max.x;
    // Rotated around the Y axis so the Y bounds don't change.
    expect(transformedCube.localBounds.min.y, equals(-0.5));
    expect(transformedCube.localBounds.max.y, equals(0.5));
    // Shape is symmetric so the z == x after rotation.
    expect(transformedCube.localBounds.min.z, equals(minX));
    expect(transformedCube.localBounds.max.z, equals(maxX));
  });

  test('offset center of mass shape', () {
    var unitCube = BoxShape(BoxShapeSettings(Vector3(0.5, 0.5, 0.5)));
    var offsetCube = OffsetCenterOfMassShape(
        OffsetCenterOfMassShapeSettings(unitCube, Vector3(0, 1, 0)));
    expect(offsetCube.localBounds.min, equals(Vector3(-0.5, -1.5, -0.5)));
    expect(offsetCube.localBounds.max, equals(Vector3(0.5, -0.5, 0.5)));
  });
}
