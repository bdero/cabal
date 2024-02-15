part of '../ecs.dart';

/// A system typically iterates over a set of entities and performs a
/// transformation on their data.
abstract class System {
  final World world;

  System(this.world);

  void tick(double dt);

  // TODO(johnmccutchan): Introduce some way of ordering Systems.
}
