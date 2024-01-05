part of '../physics.dart';

// TODO(johnmccutchan):
// - shapeCast.
// - collideShape.
// - collidePoint.
// - plumb support for subshapeid.

final class RayHit {
  // Body that was hit by the ray.
  final Body body;
  // Normal vector at point of hit. In world space.
  final Vector3 normal;
  // Fraction along
  final double fraction;
  // Start of ray.
  final Vector3 _start;
  // End of ray.
  final Vector3 _end;

  // TODO(johnmccutchan): Include triangle mesh index information.

  RayHit(this.body, this.normal, this.fraction, this._start, this._end);

  Vector3 get point {
    Vector3 r = Vector3.zero();
    Vector3.mix(_start, _end, fraction, r);
    return r;
  }

  String toString() {
    return 'RayHit $fraction ($point) normal $normal';
  }
}

// Callback invoked for each object that a ray hits. Must return the
// fraction (values between 0.0 and 1.0 which interpolate between ray start
// and ray end) that future hits must beat (be less than). The return value
// acts as a filter for future hits in the same rayCast.
// Two examples:
// * Keeping track of the smallest fraction and returning that will
// will allow you to filter for the closest hit.
// * Always returning 1.0 will not filter any hits and your callback will
// be invoked for every Collidable that the ray hits.
typedef OnRayHit = double Function(RayHit hit);

// Perform a ray cast into world. The ray moves from start to end.
void rayCast(World world, Vector3 start, Vector3 end, OnRayHit onRayHit) {
  world._rayCast(start, end, onRayHit);
}
