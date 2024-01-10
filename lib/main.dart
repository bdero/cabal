import 'package:cabal/base/game_widget.dart';
import 'package:cabal/game/cabal_game.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const AppWidget());
}

class CabalSceneSelector extends StatefulWidget {
  const CabalSceneSelector({super.key});

  @override
  State<CabalSceneSelector> createState() => _CabalSceneSelectorState();
}

class _CabalSceneSelectorState extends State<CabalSceneSelector> {
  static const SceneType _defaultScene = SceneType.fallingBoxes;
  SceneType scene = _defaultScene;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      DropdownMenu<SceneType>(
        initialSelection: _defaultScene,
        label: const Text('Scene'),
        onSelected: (SceneType? newScene) {
          if (newScene == null) {
            return;
          }
          setState(() {
            scene = newScene;
            print('switched scenes to $scene');
          });
        },
        dropdownMenuEntries: SceneType.values
            .map<DropdownMenuEntry<SceneType>>((SceneType scene) {
          return DropdownMenuEntry<SceneType>(
            value: scene,
            label: scene.label,
          );
        }).toList(),
      ),
      Expanded(
          child: GameWidget(
              key: ValueKey(scene), gameFactory: () => CabalGame(scene))),
    ]);
  }
}

class AppWidget extends StatelessWidget {
  const AppWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: '🤫 cabal 🤫',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: Scaffold(body: CabalSceneSelector()));
  }
}
