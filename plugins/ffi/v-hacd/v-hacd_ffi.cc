#include "v-hacd_ffi.h"

#define ENABLE_VHACD_IMPLEMENTATION 1

#include "VHACD.h"

static VHACD::IVHACD* vhacdImpl = VHACD::CreateVHACD();

ConvexHull* makeConvexHull(const VHACD::IVHACD::ConvexHull& in) {
  ConvexHull* out = new ConvexHull();
  out->index = in.m_meshId;
  out->volume = in.m_volume;
  out->center[0] = in.m_center[0];
  out->center[1] = in.m_center[1];
  out->center[2] = in.m_center[2];
  out->aabb_min[0] = in.mBmin[0];
  out->aabb_min[1] = in.mBmin[1];
  out->aabb_min[2] = in.mBmin[2];
  out->aabb_max[0] = in.mBmax[0];
  out->aabb_max[1] = in.mBmax[1];
  out->aabb_max[2] = in.mBmax[2];
  out->indices_size = in.m_triangles.size() * 3;
  out->vertices_size = in.m_points.size() * 3;
  out->indices = new uint32_t[out->indices_size];
  int oi = 0;
  for (int i = 0; i < in.m_triangles.size(); i++) {
    out->indices[oi++] = in.m_triangles[i].mI0;
    out->indices[oi++] = in.m_triangles[i].mI1;
    out->indices[oi++] = in.m_triangles[i].mI2;
  }
  assert(oi == out->indices_size);
  out->vertices = new float[out->vertices_size];
  oi = 0;
  for (int i = 0; i < in.m_points.size(); i++) {
    out->vertices[oi++] = in.m_points[i].mX;
    out->vertices[oi++] = in.m_points[i].mY;
    out->vertices[oi++] = in.m_points[i].mZ;
  }
  assert(oi == out->vertices_size);
  return out;
}

void freeConvexHull(ConvexHull* hull) {
  delete []hull->indices;
  delete []hull->vertices;
  delete hull;
}

class ConvexHullResult {
 public:
  ~ConvexHullResult() {
    for (auto& it : hulls_) {
      freeConvexHull(it);
    }
    hulls_.clear();
  }
  int GetNumConvexHulls() {
    return hulls_.size();
  }

  ConvexHull* GetConvexHull(int i) {
    return hulls_[i];
  }

  bool Compute(const float* const points,
               const uint32_t countPoints,
               const uint32_t* const triangles,
               const uint32_t countTriangles,
               const VHACD::IVHACD::Parameters& parameters) {
    bool r = vhacdImpl->Compute(points, countPoints, triangles, countTriangles, parameters);
    if (!r) {
      return r;
    }
    hulls_.resize(vhacdImpl->GetNConvexHulls());
    for (int i = 0; i < vhacdImpl->GetNConvexHulls(); i++) {
      VHACD::IVHACD::ConvexHull in;
      r = vhacdImpl->GetConvexHull(i, in);
      if (!r) {
        return r;
      }
      hulls_[i] = makeConvexHull(in);
    }
    // We have a copy of the convex hull data that we own. Relaese cached results in the global vhacdImpl.
    vhacdImpl->Clean();
    return true;
  }

 private:
  std::vector<ConvexHull*> hulls_;
};

FFI_PLUGIN_EXPORT ConvexHullResult* compute_convex_hull(const float* const points,
                                                        const uint32_t countPoints,
                                                        const uint32_t* const triangles,
                                                        const uint32_t countTriangles) {
  ConvexHullResult* result = new ConvexHullResult();
  // TODO(johnmccutchan): Expose some parameters.
  VHACD::IVHACD::Parameters params;
  bool r = result->Compute(points, countPoints, triangles, countTriangles, params);
  assert(r);
  return result;
}

FFI_PLUGIN_EXPORT void destroy_convex_hull_result(ConvexHullResult* result) {
  delete result;
}

FFI_PLUGIN_EXPORT int convex_hull_result_get_num_convex_hulls(ConvexHullResult* result) {
  return result->GetNumConvexHulls();
}

FFI_PLUGIN_EXPORT ConvexHull* convex_hull_result_get_convex_hull(ConvexHullResult* result, int index) {
  return result->GetConvexHull(index);
}