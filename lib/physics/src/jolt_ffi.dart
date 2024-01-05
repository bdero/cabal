import 'dart:io';
import 'dart:ffi' as ffi;
import 'jolt_ffi_generated.dart';
export 'jolt_ffi_generated.dart'
    show
        World,
        CollisionShape,
        WorldBody,
        BodyConfig,
        ConvexShapeConfig,
        ConvexShapeConfigType,
        CompoundShapeConfig,
        RayCastConfig,
        DecoratedShapeConfigType,
        DecoratedShapeConfig;

final ffi.DynamicLibrary dylib = () {
  const String _libPath = 'plugins/ffi/jolt';
  const String _libName = 'JoltFFI';
  if (Platform.isMacOS || Platform.isIOS) {
    return ffi.DynamicLibrary.open('$_libPath/lib$_libName.dylib');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return ffi.DynamicLibrary.open('$_libPath/lib$_libName.so');
  }
  if (Platform.isWindows) {
    return ffi.DynamicLibrary.open('$_libPath/$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

Jolt _initBindings() {
  Jolt bindings = Jolt(dylib);
  int r = bindings.Dart_InitializeApiDL(ffi.NativeApi.initializeApiDLData);
  if (r != 0) {
    throw new UnsupportedError('Dart_InitializeApiDL returned $r');
  }
  return bindings;
}

final Jolt bindings = _initBindings();
