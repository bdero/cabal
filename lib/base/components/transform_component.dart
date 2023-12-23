import 'package:oxygen/oxygen.dart' as oxy;
import 'package:vector_math/vector_math.dart' as vm;

class TransformComponent extends oxy.Component<vm.Matrix4> {
  vm.Matrix4 matrix = vm.Matrix4.identity();

  @override
  void init([vm.Matrix4? data]) {
    matrix = data ?? vm.Matrix4.identity();
  }

  @override
  void reset() {
    matrix = vm.Matrix4.identity();
  }
}
