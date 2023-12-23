import 'package:flutter/material.dart';

typedef OverlayCallback = bool Function(Game game, String name);

/// Mostly abstract interface for implementing a game.
///
/// The only implemented functionality this class provides is overlay
/// management.
abstract class Game {
  // 4 fixedUpdate ticks per frame at 60 fps refresh rate.
  static const double fixedTickIntervalSeconds = 1 / 240;

  bool enableFixedUpdate = true;

  Future<void> preload();

  /// Called once after preloading has finished, before any update callbacks.
  void start();

  /// Fixed tickrate update for numeric physics. The fixed tick interval is
  /// defined by [fixedTickIntervalSeconds].
  void fixedUpdate();

  /// Variable-rate update. Called once per frame. Always called after
  /// [fixedUpdate].
  void update(double dt);

  /// Draw the game. Called once per frame after update.
  void render(Canvas canvas, Size size);

  late OverlayCallback _overlayCallback;
  void initCallbacks(OverlayCallback overlayCallback) {
    _overlayCallback = overlayCallback;
  }

  bool setOverlay(String name) {
    return _overlayCallback(this, name);
  }
}
