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

enum ConvexShapeConfigType {
  kUnknown,
  kBox,
  kSphere,
  kCapsule,
  kConvexHull,
};

struct ConvexShapeConfig {
  ConvexShapeConfigType type = kUnknown;
  float density = 0.0;
  // kBox:
  // payload is the half extents.
  // kSphere:
  // payload[0] is the radius.
  // kCapsule:
  // payload[0] is half height, payload[1] is top radius, payload[2] is bottom radius.
  // kConvexHull:
  // payload is not used.
  float payload[3];
};

struct CompoundShapeConfig {
  CollisionShape* shape;
  float position[3];
  float rotation[4];
};

struct RayCastConfig {
  float start[3];
  float end[3];
  float (*cb)(Dart_Handle body, float fraction, const float* n);
};

FFI_PLUGIN_EXPORT uint8_t* native_malloc(int byte_size);

FFI_PLUGIN_EXPORT void native_free(void* p);

// World.
FFI_PLUGIN_EXPORT World* create_world();

FFI_PLUGIN_EXPORT WorldBody* world_create_body(World* world, BodyConfig* conifg);

FFI_PLUGIN_EXPORT void world_add_body(World* world, WorldBody* body, int activation);

FFI_PLUGIN_EXPORT void world_remove_body(World* world, WorldBody* body);

FFI_PLUGIN_EXPORT int world_step(World* world, float dt);

FFI_PLUGIN_EXPORT void world_raycast(World* world,
                                     RayCastConfig* config);

FFI_PLUGIN_EXPORT void destroy_world(World* world);

FFI_PLUGIN_EXPORT CollisionShape* create_convex_shape(ConvexShapeConfig* config, float* points, int num_points);

FFI_PLUGIN_EXPORT CollisionShape* create_compound_shape(CompoundShapeConfig* shapes, int num_shapes);

FFI_PLUGIN_EXPORT CollisionShape* create_mesh_shape(float* vertices, int num_vertices, uint32_t* triangles, int num_triangles);

FFI_PLUGIN_EXPORT void shape_get_center_of_mass(CollisionShape* shape, float* v3);

FFI_PLUGIN_EXPORT void shape_get_local_bounds(CollisionShape* shape, float* min3, float* max3);

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

FFI_PLUGIN_EXPORT void body_set_active(WorldBody* body, bool activate);

FFI_PLUGIN_EXPORT bool body_get_active(WorldBody* body);

FFI_PLUGIN_EXPORT void set_body_dart_owner(WorldBody* body, Dart_Handle owner);

FFI_PLUGIN_EXPORT Dart_Handle get_body_dart_owner(WorldBody* body);

FFI_PLUGIN_EXPORT void destroy_body(WorldBody* body);

#ifdef __cplusplus
}
#endif
