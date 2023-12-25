import 'package:cabal/physics/physics.dart';
import 'package:vector_math/vector_math.dart';
import 'package:test/test.dart';
import 'dart:math';

main() {
  // Create a physics world. Gravity is -Y.
  final world = World();

  // // 1/60.
  final dt = 0.0625;

  group('Body', () {
    test('position', () {
      final plane = BoxShape(Vector3(100, 1, 100));
      final ground = world.createRigidBody(
          BodySettings(plane)..position = Vector3(1.0, 0.0, 0));
      expect(ground.position, equals(Vector3(1.0, 0.0, 0)));
      final p = Vector3(0, 10, 0);
      ground.position = p;
      expect(ground.position, equals(p));
    });

    test('rotation', () {
      final plane = BoxShape(Vector3(100, 1, 100));
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
    var unitCube = BoxShape(Vector3(0.5, 0.5, 0.5));
    var box = world.createRigidBody(BodySettings(unitCube));
    expect(box.worldTransform, equals(Matrix4.identity()));
  });

  test('gravity', () {
    var sphere = SphereShape(1);
    var ball = world.createRigidBody(BodySettings(sphere)
      ..position = Vector3(0, 10, 0)
      ..motionType = MotionType.dynamic);
    world.addBody(ball);
    expect(ball.position.y, equals(10));
    world.step(dt);
    expect(ball.position.y, lessThan(10));
  });

  test('body settles', () {
    var unitCube = BoxShape(Vector3(0.5, 0.5, 0.5));
    var box = world.createRigidBody(BodySettings(unitCube)
      ..position = Vector3(0, 2, 0)
      ..motionType = MotionType.dynamic);
    world.addBody(box);
    final plane = BoxShape(Vector3(100, 1, 100));
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
    var unitCube = BoxShape(Vector3(2.0, 2.0, 2.0));
    var box0 = world.createRigidBody(BodySettings(unitCube)
      ..position = Vector3(0, 6.0, 0)
      ..motionType = MotionType.dynamic);
    var box1 = world.createRigidBody(BodySettings(unitCube)
      ..position = Vector3(0, 3.0, 0)
      ..motionType = MotionType.dynamic);
    world.addBody(box0);
    world.addBody(box1);
    final plane = BoxShape(Vector3(100, 1, 100));
    final ground = world.createRigidBody(BodySettings(plane)
      ..position = Vector3(0.0, -1.0, 0)
      ..motionType = MotionType.static);
    world.addBody(ground);

    while (box0.active || box1.active) {
      world.step(dt);
      print(box1.position.y);
    }
    print(box0.position);
    print(box1.position);
  });
}
