part of '../ecs.dart';

@visibleForTesting
class TestOnly {
  static reset() {
    _testOnlyResetId();
    _testOnlyResetTypes();
  }
}
