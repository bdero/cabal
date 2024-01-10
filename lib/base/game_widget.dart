import 'package:cabal/base/game.dart';
import 'package:cabal/base/game_render_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

typedef GameFactory = Game Function();

typedef OverlayWidgetFactory = Widget Function(Game);

class GameWidget extends StatefulWidget {
  const GameWidget(
      {required this.gameFactory,
      this.overlays = const <String, OverlayWidgetFactory>{},
      super.key});

  final GameFactory gameFactory;
  final Map<String, OverlayWidgetFactory> overlays;

  @override
  State<GameWidget> createState() => _GameWidgetState();
}

class _GameWidgetState extends State<GameWidget> {
  Widget? overlayWidget;

  bool setOverlay(Game game, String? name) {
    if (name == null) {
      overlayWidget = null;
      return true;
    }

    final overlay = widget.overlays[name];
    if (overlay == null) {
      return false;
    }

    setState(() {
      overlayWidget = overlay(game);
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      GameRenderObjectWidget(
        gameFactory: widget.gameFactory,
        overlayCallback: setOverlay,
      ),
      if (overlayWidget != null) overlayWidget!,
    ]);
  }
}

class GameRenderObjectWidget extends LeafRenderObjectWidget {
  const GameRenderObjectWidget(
      {required this.gameFactory, required this.overlayCallback, super.key});

  final GameFactory gameFactory;
  final OverlayCallback overlayCallback;

  @override
  RenderObject createRenderObject(BuildContext context) {
    print('createRenderObject');
    Game game = gameFactory()..initCallbacks(overlayCallback);

    return RenderConstrainedBox(
      child: GameRenderBox(game),
      additionalConstraints: const BoxConstraints.expand(),
    );
  }
}
