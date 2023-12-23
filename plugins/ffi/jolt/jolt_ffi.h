#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#if _WIN32
#include <windows.h>
#else
#include <pthread.h>
#include <unistd.h>
#endif

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

#include "dart_api_dl.h"

// TODO: Try and play tricks around including C++ object definitions and alias the C types with them.
#ifdef __cplusplus
#define class_type class
#else
#define class_type struct
#endif 

#ifdef __cplusplus
extern "C" {
#endif

typedef class_type World World;
typedef class_type CollisionShape CollisionShape;
typedef class_type WorldBody WorldBody;

// Configuration for a body when it si created.
struct BodyConfig {
  CollisionShape* shape;
  float position[4];
  float rotation[4];
  float linear_velocity[4];
  float angular_velocity[4];
  int motion_type;
  int motion_quality;
};

// World.
FFI_PLUGIN_EXPORT World* create_world();

// NOTE: There is only one instance of a BodyConfig available right now.
FFI_PLUGIN_EXPORT BodyConfig* world_get_body_config(World* world);

FFI_PLUGIN_EXPORT WorldBody* world_create_body(World* world, BodyConfig* conifg);

FFI_PLUGIN_EXPORT void world_add_body(World* world, WorldBody* body, int activation);

FFI_PLUGIN_EXPORT void world_remove_body(World* world, WorldBody* body);

FFI_PLUGIN_EXPORT int world_step(World* world, float dt);

FFI_PLUGIN_EXPORT void destroy_world(World* world);

// Shapes.
FFI_PLUGIN_EXPORT CollisionShape* create_box_shape(float hx, float hy, float hz);

FFI_PLUGIN_EXPORT CollisionShape* create_sphere_shape(float radius);

FFI_PLUGIN_EXPORT void shape_set_dart_owner(CollisionShape* shape, Dart_Handle owner);

FFI_PLUGIN_EXPORT Dart_Handle shape_get_dart_owner(CollisionShape* shape);

FFI_PLUGIN_EXPORT void destroy_shape(CollisionShape* shape);

// Bodies.
FFI_PLUGIN_EXPORT void body_set_position(WorldBody* body, float* v4);

FFI_PLUGIN_EXPORT void body_set_rotation(WorldBody* body, float* q4);

FFI_PLUGIN_EXPORT void body_get_position(WorldBody* body, float* v4);

FFI_PLUGIN_EXPORT void body_get_rotation(WorldBody* body, float* q4);

FFI_PLUGIN_EXPORT void body_get_world_matrix(WorldBody* body, float* m16);

FFI_PLUGIN_EXPORT void body_get_com_matrix(WorldBody* body, float* m16);

FFI_PLUGIN_EXPORT void destroy_body(WorldBody* body);

#ifdef __cplusplus
}
#endif
