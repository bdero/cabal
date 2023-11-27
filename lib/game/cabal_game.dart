import 'package:cabal/base/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bullet/flutter_bullet.dart' as phys;
import 'package:vector_math/vector_math.dart' as vm;

class CabalGame extends Game {
  phys.World? world;

  @override
  Future<void> preload() async {
    debugPrint("preloading");
    return Future.value();
  }

  @override
  void start() {
    world = phys.World();

    // Create a unit box
    var box = phys.BoxShape(vm.Vector3(.5, .5, .5));

    // Create a static plane in the X-Z axis.
    var plane = phys.StaticPlaneShape(vm.Vector3(0, 1, 0), 0);

    // Make a dynamic body with mass 1.0 with the box shape.
    // Place it 10 units in the air.
    var dynamicBody = phys.RigidBody(1.0, box, vm.Vector3(0, 10, 0));

    // Make a static body (mass == 0.0) with the static plane shape
    // place it at the origin.
    var floorBody = phys.RigidBody(0.0, plane, vm.Vector3(0, 0, 0));

    world!.addBody(dynamicBody);
    world!.addBody(floorBody);
  }

  @override
  void fixedUpdate() {
    world?.step(Game.fixedTickIntervalSeconds);
  }

  @override
  void update(double dt) {
    debugPrint("update: dt=$dt");
  }

  @override
  void render(Canvas canvas, Size size) {
    debugPrint("render");
    final paint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(size.width, size.height), 100, paint);
  }
}
