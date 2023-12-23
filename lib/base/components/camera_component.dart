import 'package:oxygen/oxygen.dart' as oxy;

import 'package:cabal/base/camera.dart';

class CameraComponent extends oxy.Component<Camera> {
  Camera? camera;

  @override
  void init([Camera? data]) {
    camera = data;
  }

  @override
  void reset() {
    camera = null;
  }
}
