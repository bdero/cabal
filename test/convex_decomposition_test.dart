import 'package:cabal/util/convex_decomposition.dart';
import 'package:vector_math/vector_math.dart';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'dart:math';

main() {
  group('convex hull decomposition', () {
    test('integration', () {
      // Request the convex hull of a single triangle.
      final chd = ConvexHullDecomposition(
          Float32List.fromList([
            1.0,
            0.0,
            1.0,
            1.0,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
          ]),
          Uint32List.fromList([0, 1, 2]));
      expect(chd.length, equals(1));
      final ch = chd[0];
      expect(ch, isNotNull);
      // Haven't verified the output yet:
      expect(ch.numVertices, equals(7));
      expect(ch.numTriangles, equals(10));
    });
  });
}
