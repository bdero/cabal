import 'package:flutter_gpu/gpu.dart' as gpu;

final gpu.ShaderLibrary library =
    gpu.ShaderLibrary.fromAsset('gen/cabal.shaderbundle')!;
