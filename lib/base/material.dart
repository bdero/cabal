import 'package:cabal/base/shaders.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;

abstract class Material {
  late gpu.Shader _vertexShader;
  late gpu.Shader _fragmentShader;
  gpu.RenderPipeline? _pipeline;

  void setShaders(gpu.Shader vertexShader, gpu.Shader fragmentShader) {
    _vertexShader = vertexShader;
    _fragmentShader = fragmentShader;
    _pipeline = null;
  }

  void bind(gpu.RenderPass pass) {
    _pipeline ??=
        gpu.gpuContext.createRenderPipeline(_vertexShader, _fragmentShader);
    pass.bindPipeline(_pipeline!);
  }
}

class UnlitMaterial extends Material {
  UnlitMaterial() {
    setShaders(library['TextureVertex']!, library['TextureFragment']!);
  }

  gpu.Texture? _color;

  setColorTexture(gpu.Texture color) {
    _color = color;
  }

  @override
  void bind(gpu.RenderPass pass) {
    pass.bindTexture(_fragmentShader.getUniformSlot('tex')!, _color!);
    super.bind(pass);
  }
}
