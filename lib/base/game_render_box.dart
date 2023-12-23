import 'package:cabal/base/game.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// Drives a [Game].
class GameRenderBox extends RenderBox {
  GameRenderBox(this.game) {
    _frameTicker = Ticker(_tick);
  }

  Game game;
  late Ticker _frameTicker;
  Duration _previousTime = Duration.zero;
  double _remainingFixedUpdateSeconds = 0;

  void _tick(Duration currentTime) {
    final dt = (_previousTime == Duration.zero
                ? Duration.zero
                : currentTime - _previousTime)
            .inMilliseconds /
        Duration.millisecondsPerSecond;
    _previousTime = currentTime;

    if (game.enableFixedUpdate) {
      _remainingFixedUpdateSeconds += dt;

      final int fixedTicks =
          _remainingFixedUpdateSeconds ~/ Game.fixedTickIntervalSeconds;
      for (int i = 0; i < fixedTicks; i++) {
        game.fixedUpdate();
      }
      _remainingFixedUpdateSeconds -=
          fixedTicks * Game.fixedTickIntervalSeconds;
    }

    game.update(dt);

    markNeedsPaint();
  }

  @override
  void attach(covariant PipelineOwner owner) {
    super.attach(owner);
    game.preload().then((_) {
      game.start();
      _frameTicker.start();
    });
  }

  @override
  void detach() {
    super.detach();
    _frameTicker.stop();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return constraints.biggest;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas.translate(offset.dx, offset.dy);
    game.render(context.canvas, size);
  }
}
