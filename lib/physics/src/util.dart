part of '../physics.dart';

void copyVector3(Vector3 input, ffi.Array<ffi.Float> out, [int outOffset = 0]) {
  out[outOffset + 0] = input[0];
  out[outOffset + 1] = input[1];
  out[outOffset + 2] = input[2];
}

void copyQuaternion(Quaternion input, ffi.Array<ffi.Float> out,
    [int outOffset = 0]) {
  out[outOffset + 0] = input[0];
  out[outOffset + 1] = input[1];
  out[outOffset + 2] = input[2];
  out[outOffset + 3] = input[3];
}
