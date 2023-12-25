import 'dart:ffi' as ffi;
import 'dart:typed_data';
import 'dart:collection';
import 'package:ffi/ffi.dart';
import 'package:vector_math/vector_math.dart';

// Generated code.
import 'src/v-hacd_ffi.dart' as hacd;

class ConvexHull {
  ConvexHull._(this._native);

  ffi.Pointer<hacd.ConvexHull> _native;

  late final int _numTriangles = _native.ref.indices_size ~/ 3;
  late final int _numVertices = _native.ref.vertices_size ~/ 3;
  late final UnmodifiableFloat32ListView _vertices =
      UnmodifiableFloat32ListView(
          _native.ref.vertices.asTypedList(_native.ref.vertices_size));
  late final UnmodifiableUint32ListView _indices =
      new UnmodifiableUint32ListView(
          _native.ref.indices.asTypedList(_native.ref.indices_size));

  int get numTriangles {
    return _numTriangles;
  }

  int get numVertices {
    return _numVertices;
  }

  UnmodifiableFloat32ListView get vertexData {
    return _vertices;
  }

  UnmodifiableUint32ListView get indexData {
    return _indices;
  }
}

class ConvexHullDecomposition implements ffi.Finalizable {
  static final _finalizer = ffi.NativeFinalizer(
      hacd.bindings.addresses.destroy_convex_hull_result.cast());

  ffi.Pointer<hacd.ConvexHullResult> _native;

  final List<ConvexHull?> _hulls = <ConvexHull?>[];

  ConvexHullDecomposition._(this._native) {
    _finalizer.attach(this, _native.cast(), detach: this);
  }

  static final unwrappedComputeConvexHull = hacd.dylib.lookupFunction<
      ffi.Pointer<hacd.ConvexHullResult> Function(
          ffi.Pointer<ffi.Float>, ffi.Int, ffi.Pointer<ffi.Uint32>, ffi.Int),
      ffi.Pointer<hacd.ConvexHullResult> Function(Float32List, int, Uint32List,
          int)>('compute_convex_hull', isLeaf: true);

  factory ConvexHullDecomposition(Float32List vertices, Uint32List indices) {
    final native = unwrappedComputeConvexHull(
        vertices, vertices.length ~/ 3, indices, indices.length ~/ 3);
    final result = ConvexHullDecomposition._(native);
    result._hulls.length =
        hacd.bindings.convex_hull_result_get_num_convex_hulls(native);
    return result;
  }

  int get length {
    return _hulls.length;
  }

  ConvexHull operator [](int i) {
    if (i < 0 || i >= _hulls.length) {
      throw IndexError.withLength(i, _hulls.length);
    }
    if (_hulls[i] != null) {
      return _hulls[i]!;
    }
    _hulls[i] = ConvexHull._(
        hacd.bindings.convex_hull_result_get_convex_hull(_native, i));
    return _hulls[i]!;
  }
}
