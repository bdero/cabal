import 'package:cabal/base/game.dart';
import 'package:flutter/material.dart';

class CabalGame extends Game {
  @override
  Future<void> preload() async {
    debugPrint("preloading");
    return Future.value();
  }

  @override
  void start() {
    debugPrint("start");
  }

  @override
  void fixedUpdate() {
    debugPrint("fixedUpdate");
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
