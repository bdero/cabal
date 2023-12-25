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

// NOTE: All vertex data is encoded as 3 floats, packed x, y, z.
// NOTE: All triangle data is encoded as 3 uint32_ts, packed i0, i1, i2.
struct ConvexHull {
  // Index in the decomposition.
  int index;
  // Center of the convex hull.
  float center[3];
  // AABB min of the convex hull.
  float aabb_min[3];
  // AABB max of the convex hull.
  float aabb_max[3];

  // A triangle mesh defines the convex hull boundary.

  // Vertices of the triangles.
  float* vertices;
  uint32_t vertices_size;
  // Indices of the triangles.
  uint32_t* indices;
  uint32_t indices_size;

  // Volume of the convex hull.
  double volume;
};

typedef class_type ConvexHullResult ConvexHullResult;

FFI_PLUGIN_EXPORT ConvexHullResult* compute_convex_hull(const float* const points,
                                    const uint32_t countPoints,
                                    const uint32_t* const triangles,
                                    const uint32_t countTriangles);

FFI_PLUGIN_EXPORT void destroy_convex_hull_result(ConvexHullResult* result);

FFI_PLUGIN_EXPORT int convex_hull_result_get_num_convex_hulls(ConvexHullResult* result);

FFI_PLUGIN_EXPORT ConvexHull* convex_hull_result_get_convex_hull(ConvexHullResult* result, int index);

#ifdef __cplusplus
}
#endif
