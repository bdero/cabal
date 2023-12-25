import 'dart:io';
import 'dart:ffi' as ffi;
import 'v-hacd_generated.dart';
export 'v-hacd_generated.dart' show ConvexHull, ConvexHullResult;

final ffi.DynamicLibrary dylib = () {
  const String _libPath = 'plugins/ffi/v-hacd';
  const String _libName = 'V_HACDFFI';
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

VHAVC _initBindings() {
  VHAVC bindings = VHAVC(dylib);
  int r = bindings.Dart_InitializeApiDL(ffi.NativeApi.initializeApiDLData);
  if (r != 0) {
    throw new UnsupportedError('Dart_InitializeApiDL returned $r');
  }
  return bindings;
}

final VHAVC bindings = _initBindings();
