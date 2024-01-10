#!/usr/bin/env python3

# Builds cabal native bits.

import os
import shutil
import tempfile
import zipfile
import sys
import subprocess
import json
import shlex
from enum import Enum

print('CONFIG_START')

script_directory = os.path.dirname(os.path.abspath(sys.argv[0]))
print('SCRIPT_DIR=%s' % script_directory)

engine_src_directory = os.environ.get('ENGINE_SRC_DIR')
if engine_src_directory == None:
  engine_src_directory = os.path.abspath(os.path.join(script_directory, '../engine/src'))
  print('no ENGINE_SRC_DIR environment variable set, defaulting to: %s' % engine_src_directory)
else:
  print('ENGINE_SRC_DIR=%s' % engine_src_directory)

engine_out_directory = os.environ.get('ENGINE_OUT_DIR')
if engine_out_directory == None:
  engine_out_directory = 'out/host_debug_unopt'
  print('no ENGINE_OUT_DIR environment variable set, defaulting to: %s' % engine_out_directory)
else:
  print('ENGINE_OUT_DIR=%s' % engine_out_directory)

engine_out_directory = os.path.abspath(os.path.join(engine_src_directory, engine_out_directory))

impellerc_path = os.environ.get('IMPELLERC')
if impellerc_path == None:
  impellerc_path = os.path.abspath(os.path.join(engine_out_directory, 'impellerc'))
  print('no IMPELLERC environment variable set, defaulting to: %s' % impellerc_path)
else:
  print('IMPELLERC=%s' % impellerc_path)

gen_directory = os.path.join(script_directory, 'gen')

print('CONFIG_END')

def build_cmake(dir):
  subprocess.call(['cmake', '.'], cwd=os.path.join(script_directory, dir));
  subprocess.call(['make', '-j', '4'], cwd=os.path.join(script_directory, dir))

def inputs_newer(inputs, output):
  output_path = os.path.join(script_directory, output)
  output_mtime = 0
  try:
    output_mtime = os.path.getmtime(output_path)
  except OSError as e:
    output_mtime = 0
  
  for input in inputs:
    input_path = os.path.join(script_directory, input)
    input_mtime = 0
    try:
      input_mtime = os.path.getmtime(input_path)
    except OSError as e:
      print('missing input file: %s', input_path)
      raise e
    if input_mtime > output_mtime:
      return True
  return False
  
def generate_ffi(config_file, inputs, output_file):
  inputs.append(config_file)
  if inputs_newer(inputs, output_file) == False:
    print('skipping ffigen for %s' % config_file)
    return
  config_path = os.path.join(script_directory, config_file)
  subprocess.call('dart run ffigen --config %s' % config_path, shell=True, stderr=sys.stderr, stdout=sys.stdout)

def generate_ffi_plugin(plugin, output):
  config_file = 'plugins/ffi/%s.ffigen.yaml' % plugin
  inputs = [
    'plugins/ffi/%s/%s_ffi.h' % (plugin, plugin),
    'plugins/ffi/%s/dart_api_dl.h' % plugin,
    'plugins/ffi/%s/dart_api.h' % plugin,
  ]
  generate_ffi(config_file, inputs, output)

class ShaderType(Enum):
  VERTEX = 1,
  FRAGMENT = 2


def build_shader_bundle(bundle_name, shaders):
  os.makedirs(gen_directory, exist_ok=True)
  data = {}
  for shader in shaders:
    (shader_name, shader_type, shader_path) = shader
    shader_suffix = ''
    shader_json_type = ''
    if shader_type == ShaderType.VERTEX:
      shader_suffix = 'Vertex'
      shader_json_type = 'vertex'
    elif shader_type == ShaderType.FRAGMENT:
      shader_suffix = 'Fragment'
      shader_json_type = 'fragment'
    else:
      raise NotImplementedError('Unsupported shader type: %s' % shader_type)
    shader_name = shader_name + shader_suffix
    shader_path = os.path.join(script_directory, shader_path)
    data[shader_name] = {
      'type': shader_json_type,
      'file': shader_path
    }
  data_json = json.dumps(data)
  data_json = data_json.replace('"', '\\"').replace('{', '\{').replace('}', '\}').replace(' ', '\ ')
  command = ' '.join([impellerc_path,
                   '--include=%s/flutter/impeller/compiler/shader_lib' % engine_src_directory,
                   '--sl=%s/%s.shaderbundle' % (gen_directory, bundle_name),
                   '--shader-bundle=%s' % data_json,
                   ])
  subprocess.call(command, shell=True)
  
def build_cabal(argv):
  build_cmake('plugins/ffi/jolt')
  build_cmake('plugins/ffi/v-hacd')
  generate_ffi_plugin('jolt', 'lib/physics/src/jolt_ffi_generated.dart')
  generate_ffi_plugin('v-hacd', 'lib/util/src/v-hacd_generated.dart')
  build_shader_bundle('cabal', [
    ('Texture', ShaderType.VERTEX, 'shaders/flutter_gpu_texture.vert'),
    ('Texture', ShaderType.FRAGMENT, 'shaders/flutter_gpu_texture.frag')])

if __name__ == '__main__':
  os.chdir(script_directory)
  build_cabal(sys.argv)
