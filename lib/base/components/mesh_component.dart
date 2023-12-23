import 'package:oxygen/oxygen.dart' as oxy;

import 'package:cabal/base/mesh.dart';

class MeshComponent extends oxy.Component<Mesh> {
  Mesh? mesh;

  @override
  void init([Mesh? data]) {
    mesh = data;
  }

  @override
  void reset() {
    mesh = null;
  }
}
