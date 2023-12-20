// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

uniform float exposure;
uniform vec3 camera_position;

uniform sampler2D base_color_texture;
uniform sampler2D normal_texture;
uniform sampler2D occlusion_roughness_metallic_texture;

in vec3 v_position;
in mat3 v_tangent_space;
in vec2 v_texture_coords;

out vec4 frag_color;

#include <impeller/constants.glsl>

const float kPi = 3.14159265358979323846;

const vec3 kLightNormal = normalize(vec3(2.0, 5.0, -5.0));
const vec3 kLightColor = vec3(1.0, 0.8, 0.8) * 3.0;

const vec3 kHighlightNormal = normalize(vec3(-2.0, -3.0, 0.0));
const vec3 kHighlightColor = vec3(1.0, 0.1, 0.0) * 1.5;

const float kGamma = 2.2;

// Convert from sRGB to linear space.
// This can be removed once Impeller supports sRGB texture inputs.
vec3 SampleSRGB(sampler2D tex, vec2 uv) {
  vec3 color = texture(tex, uv).rgb;
  return pow(color, vec3(kGamma));
}

//------------------------------------------------------------------------------
/// Lighting equation.
/// See also: https://learnopengl.com/PBR/Lighting
///

vec3 FresnelSchlick(float cos_theta, vec3 reflectance) {
  return reflectance +
         (1.0 - reflectance) * pow(clamp(1.0 - cos_theta, 0.0, 1.0), 5.0);
}

float DistributionGGX(vec3 normal, vec3 half_vector, float roughness) {
  float a = roughness * roughness;
  float a2 = a * a;
  float NdotH = max(dot(normal, half_vector), 0.0);
  float NdotH2 = NdotH * NdotH;

  float num = a2;
  float denom = (NdotH2 * (a2 - 1.0) + 1.0);
  denom = kPi * denom * denom;

  return num / denom;
}

float GeometrySchlickGGX(float NdotV, float roughness) {
  float r = (roughness + 1.0);
  float k = (r * r) / 8.0;

  float num = NdotV;
  float denom = NdotV * (1.0 - k) + k;

  return num / denom;
}

float GeometrySmith(vec3 normal, vec3 camera_normal, vec3 light_normal,
                    float roughness) {
  float camera_ggx =
      GeometrySchlickGGX(max(dot(normal, camera_normal), 0.0), roughness);
  float light_ggx =
      GeometrySchlickGGX(max(dot(normal, light_normal), 0.0), roughness);
  return camera_ggx * light_ggx;
}

vec3 LightFormula(vec3 light_color, vec3 camera_normal, vec3 light_normal,
                  vec3 albedo, vec3 normal, float metallic, float roughness,
                  vec3 reflectance) {
  vec3 half_vector = normalize(camera_normal + light_normal);

  // Cook-Torrance BRDF.
  float distribution = DistributionGGX(normal, half_vector, roughness);
  float geometry =
      GeometrySmith(normal, camera_normal, light_normal, roughness);
  vec3 fresnel =
      FresnelSchlick(max(dot(half_vector, camera_normal), 0.0), reflectance);

  vec3 kS = fresnel;
  vec3 kD = vec3(1.0) - kS;
  kD *= 1.0 - metallic;

  vec3 numerator = distribution * geometry * fresnel;
  float denominator = 4.0 * max(dot(normal, camera_normal), 0.0) *
                          max(dot(normal, light_normal), 0.0) +
                      0.0001;
  vec3 specular = numerator / denominator;

  float NdotL = max(dot(normal, light_normal), 0.0);
  return (kD * albedo / kPi + specular) * light_color * NdotL;
}

void main() {
  vec3 albedo = SampleSRGB(base_color_texture, v_texture_coords);
  vec3 normal =
      normalize(v_tangent_space *
                (texture(normal_texture, v_texture_coords).rgb * 2.0 - 1.0));
  vec3 orm =
      texture(occlusion_roughness_metallic_texture, v_texture_coords).rgb;
  float occlusion = orm.r;
  float roughness = orm.g;
  float metallic = orm.b;

  vec3 camera_normal = normalize(camera_position - v_position);

  vec3 reflectance = mix(vec3(0.04), albedo, metallic);

  vec3 out_radiance =
      LightFormula(kLightColor, camera_normal, kLightNormal, albedo, normal,
                   metallic, roughness, reflectance);
  out_radiance +=
      LightFormula(kHighlightColor, camera_normal, kHighlightNormal, albedo,
                   normal, metallic, roughness, reflectance);

  vec3 ambient = vec3(0.03) * albedo * occlusion;
  vec3 out_color = ambient + out_radiance;

  // Tone mapping.
  out_color = vec3(1.0) - exp(-out_color * exposure);

#ifndef IMPELLER_TARGET_METAL
  out_color = pow(out_color, vec3(1.0 / kGamma));
#endif

  frag_color = vec4(out_color, 1.0);
}
