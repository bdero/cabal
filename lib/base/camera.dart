import 'dart:math';

import 'package:vector_math/vector_math.dart' as vm;

vm.Matrix4 _matrix4LookAt(
    vm.Vector3 position, vm.Vector3 target, vm.Vector3 up) {
  vm.Vector3 forward = (target - position).normalized();
  vm.Vector3 right = up.cross(forward).normalized();
  up = forward.cross(right).normalized();

  return vm.Matrix4(
    right.x, up.x, forward.x, 0.0, //
    right.y, up.y, forward.y, 0.0, //
    right.z, up.z, forward.z, 0.0, //
    -right.dot(position), -up.dot(position), -forward.dot(position), 1.0, //
  );
}

vm.Matrix4 _matrix4Perspective(
    double fovRadiansY, double aspectRatio, double zNear, double zFar) {
  double height = tan(fovRadiansY * 0.5);
  double width = height * aspectRatio;

  return vm.Matrix4(
    1.0 / width,
    0.0,
    0.0,
    0.0,
    0.0,
    1.0 / height,
    0.0,
    0.0,
    0.0,
    0.0,
    zFar / (zFar - zNear),
    1.0,
    0.0,
    0.0,
    -(zFar * zNear) / (zFar - zNear),
    0.0,
  );
}

class Camera {
  Camera(
      {this.fovRadiansY = 45 * vm.degrees2Radians,
      vm.Vector3? position,
      vm.Vector3? target,
      vm.Vector3? up})
      : position = position ?? vm.Vector3(0, 0, -5),
        target = target ?? vm.Vector3(0, 0, 0),
        up = up ?? vm.Vector3(0, 1, 0);

  double fovRadiansY;
  vm.Vector3 position;
  vm.Vector3 target;
  vm.Vector3 up;

  vm.Matrix4 getTransform(double aspectRatio) {
    return _matrix4Perspective(fovRadiansY, aspectRatio, 0.1, 1000) *
        _matrix4LookAt(position, target, up);
  }
}
