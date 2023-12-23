import "package:flutter_gpu/gpu.dart" as gpu;
import 'package:vector_math/vector_math.dart' as vm;

import 'package:cabal/base/geometry.dart';
import 'package:cabal/base/material.dart';

class Mesh {
  Mesh({required this.geometry, required this.material});

  Geometry geometry;
  Material material;

  void draw(
      gpu.RenderPass pass, gpu.HostBuffer transientsBuffer, vm.Matrix4 mvp) {
    pass.clearBindings();
    geometry.bind(pass);
    material.bind(pass, transientsBuffer, mvp);
    pass.draw();
  }
}
