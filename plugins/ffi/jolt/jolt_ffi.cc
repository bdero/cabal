#include "jolt_ffi.h"
#include "dart_api.h"
#include "dart_api_dl.h"

#include <mutex>
#include <thread>

// The Jolt headers don't include Jolt.h. Always include Jolt.h before including
// any other Jolt header. You can use Jolt.h in your precompiled header to speed
// up compilation.
#include <Jolt/Jolt.h>

// Jolt includes
#include <Jolt/Core/Factory.h>
#include <Jolt/Core/JobSystemSingleThreaded.h>
#include <Jolt/Core/JobSystemThreadPool.h>
#include <Jolt/Core/TempAllocator.h>
#include <Jolt/Geometry/Indexify.h>
#include <Jolt/Physics/Body/BodyActivationListener.h>
#include <Jolt/Physics/Body/BodyCreationSettings.h>
#include <Jolt/Physics/Body/MassProperties.h>
#include <Jolt/Physics/Collision/BroadPhase/BroadPhaseLayerInterfaceMask.h>
#include <Jolt/Physics/Collision/BroadPhase/ObjectVsBroadPhaseLayerFilterMask.h>
#include <Jolt/Physics/Collision/ObjectLayerPairFilterMask.h>
#include <Jolt/Physics/Collision/CastResult.h>
#include <Jolt/Physics/Collision/RayCast.h>
#include <Jolt/Physics/Collision/Shape/BoxShape.h>
#include <Jolt/Physics/Collision/Shape/SphereShape.h>
#include <Jolt/Physics/Collision/Shape/ScaledShape.h>
#include <Jolt/Physics/Collision/Shape/RotatedTranslatedShape.h>
#include <Jolt/Physics/Collision/Shape/OffsetCenterOfMassShape.h>
#include <Jolt/Physics/Collision/Shape/TaperedCapsuleShape.h>
#include <Jolt/Physics/Collision/Shape/ConvexHullShape.h>
#include <Jolt/Physics/Collision/Shape/MeshShape.h>
#include <Jolt/Physics/Collision/Shape/StaticCompoundShape.h>
#include <Jolt/Physics/EActivation.h>
#include <Jolt/Physics/PhysicsSettings.h>
#include <Jolt/Physics/PhysicsSystem.h>
#include <Jolt/RegisterTypes.h>
#include <Jolt/Physics/Body/BodyLock.h>

// Disable common warnings triggered by Jolt, you can use
// JPH_SUPPRESS_WARNING_PUSH / JPH_SUPPRESS_WARNING_POP to store and restore the
// warning state
JPH_SUPPRESS_WARNINGS

static void NoopFinalizer(void *isolate_callback_data, void *peer) {
  // We must pass in a non-null callback to Dart_NewWeakPersistentHandle_DL.
}

// All Jolt symbols are in the JPH namespace
using namespace JPH;

std::once_flag init_jph_flag;

void init_jph_once() {
  std::call_once(init_jph_flag, []() {
    // Register allocation hook
    RegisterDefaultAllocator();

    // Create a factory
    Factory::sInstance = new Factory();

    // Register all Jolt physics types
    RegisterTypes();
  });
}

constexpr uint32 LayerFilterMoving = 1;
constexpr uint32 LayerFilterStatic = 2;
constexpr uint32 LayerFilterSensor = 4;
constexpr uint32 LayerFilterAll = LayerFilterMoving | LayerFilterStatic | LayerFilterSensor;

FFI_PLUGIN_EXPORT uint8_t* native_malloc(int byte_size) {
  return reinterpret_cast<uint8_t*>(malloc(byte_size));
}

FFI_PLUGIN_EXPORT void native_free(void* p) {
  free(p);
}

class World {
public:
  World() {
    temp_allocator_ = std::make_unique<TempAllocatorImpl>(10 * 1024 * 1024);
    job_system_ = std::make_unique<JobSystemThreadPool>(cMaxPhysicsJobs, cMaxPhysicsBarriers, thread::hardware_concurrency() - 1);

    // Configure our broad phase layers.
    bp_layer_interface_ = std::make_unique<BroadPhaseLayerInterfaceMask>(2);
    // Layer 0 holds moving and sensor objects.
    bp_layer_interface_->ConfigureLayer(BroadPhaseLayer(0), LayerFilterMoving|LayerFilterSensor, 0);
    // Layer 1 holds static objects.
    bp_layer_interface_->ConfigureLayer(BroadPhaseLayer(1), LayerFilterStatic, 0);

    object_vs_broad_phase_layer_filter_ =
        std::make_unique<ObjectVsBroadPhaseLayerFilterMask>(
            *bp_layer_interface_);

    object_vs_object_layer_pair_filter_ =
        std::make_unique<ObjectLayerPairFilterMask>();
    physics_system_ = std::make_unique<PhysicsSystem>();
    physics_system_->Init(cMaxBodies, cNumBodyMutexes, cMaxBodyPairs,
                          cMaxContactConstraints, *bp_layer_interface_,
                          *object_vs_broad_phase_layer_filter_,
                          *object_vs_object_layer_pair_filter_);
  }

  ~World() { }

  TempAllocator *temp_allocator() { return temp_allocator_.get(); }

  JobSystem *job_system() { return job_system_.get(); }

  PhysicsSystem &physics_system() { return *physics_system_; }

  Dart_Handle GetDartOwnerForBody(const BodyID& id) {
    return reinterpret_cast<Dart_Handle>(body_interface().GetUserData(id));
  }

  BodyInterface &body_interface() {
    return physics_system_->GetBodyInterface();
  }


private:
  std::unique_ptr<TempAllocator> temp_allocator_;
  std::unique_ptr<JobSystem> job_system_;
  std::unique_ptr<BroadPhaseLayerInterfaceMask> bp_layer_interface_;
  std::unique_ptr<ObjectVsBroadPhaseLayerFilterMask>
      object_vs_broad_phase_layer_filter_;
  std::unique_ptr<ObjectLayerPairFilterMask>
      object_vs_object_layer_pair_filter_;
  std::unique_ptr<PhysicsSystem> physics_system_;

  // This is the max amount of rigid bodies that you can add to the physics
  // system. If you try to add more you'll get an error. Note: This value is low
  // because this is a simple test. For a real project use something in the
  // order of 65536.
  static const int cMaxBodies = 65536;

  // This determines how many mutexes to allocate to protect rigid bodies from
  // concurrent access. Set it to 0 for the default settings.
  static const int cNumBodyMutexes = 0;

  // This is the max amount of body pairs that can be queued at any time (the
  // broad phase will detect overlapping body pairs based on their bounding
  // boxes and will insert them into a queue for the narrowphase). If you make
  // this buffer too small the queue will fill up and the broad phase jobs will
  // start to do narrow phase work. This is slightly less efficient. Note: This
  // value is low because this is a simple test. For a real project use
  // something in the order of 65536.
  static const uint cMaxBodyPairs = 65536;

  // This is the maximum size of the contact constraint buffer. If more contacts
  // (collisions between bodies) are detected than this number then these
  // contacts will be ignored and bodies will start interpenetrating / fall
  // through the world. Note: This value is low because this is a simple test.
  // For a real project use something in the order of 10240.
  static const uint cMaxContactConstraints = 10240;
};

class CollisionShape {
public:
  explicit CollisionShape(Ref<Shape> shape) : shape_(shape) {
  }

  ~CollisionShape() {
    if (shape_ != nullptr) {
      Dart_DeleteWeakPersistentHandle_DL(reinterpret_cast<Dart_WeakPersistentHandle>(shape_->GetUserData()));
    }
  }

  static void SetDartOwner(CollisionShape *shape, Dart_Handle owner) {
    shape->shape_->SetUserData(reinterpret_cast<int64_t>(
        Dart_NewWeakPersistentHandle_DL(owner, nullptr, 0, NoopFinalizer)));
  }

  static Dart_Handle GetDartOwner(CollisionShape *shape) {
    return Dart_HandleFromWeakPersistent_DL(reinterpret_cast<Dart_WeakPersistentHandle>(shape->shape_->GetUserData()));
  }

  Shape *shape() { return shape_; }

private:
  Ref<Shape> shape_;
};

class WorldBody {
public:
  WorldBody(World *world, Body *body) : world_(world), body_(body) {
  }

  ~WorldBody() {
    if (owner_ != nullptr) {
      Dart_DeleteWeakPersistentHandle_DL(owner_);
    }
  }

  static void SetDartOwner(WorldBody *body, Dart_Handle owner) {
    body->body_->SetUserData(reinterpret_cast<int64_t>(
        Dart_NewWeakPersistentHandle_DL(owner, nullptr, 0, NoopFinalizer)));
  }

  static Dart_Handle GetDartOwner(WorldBody *body) {
    return Dart_HandleFromWeakPersistent_DL(reinterpret_cast<Dart_WeakPersistentHandle>(body->body_->GetUserData()));
  }

  World *world() { return world_; }

  BodyInterface &interface() { return world_->body_interface(); }

  const BodyID& id() { return body_->GetID(); }

  const Shape *shape() { return body_->GetShape(); }

  void SetPosition(float *v4) {
    interface().SetPosition(id(), *reinterpret_cast<Vec3 *>(v4),
                            EActivation::DontActivate);
  }

  void SetRotation(float *q4) {
    interface().SetRotation(id(), *reinterpret_cast<Quat *>(q4),
                            EActivation::DontActivate);
  }

  void GetPosition(float *v4) {
    *reinterpret_cast<Vec3 *>(v4) = interface().GetPosition(id());
  }

  void GetRotation(float *q4) {
    *reinterpret_cast<Quat *>(q4) = interface().GetRotation(id());
  }

  void GetWorldMatrix(float* m16) {
    *reinterpret_cast<Mat44*>(m16) = interface().GetWorldTransform(id());
  }

  void GetCOMMatrix(float* m16) {
    *reinterpret_cast<Mat44*>(m16) = interface().GetCenterOfMassTransform(id());
  }

private:
  Body *body() { return body_; }

  World *world_;
  Body *body_;
  Dart_WeakPersistentHandle owner_ = nullptr;
};

FFI_PLUGIN_EXPORT World *create_world() {
  init_jph_once();
  return new World();
}

FFI_PLUGIN_EXPORT int world_step(World *world, float dt) {
  // TODO(johnmccutchan): Collision steps needs to be configurable.
  EPhysicsUpdateError error = world->physics_system().Update(
      dt, 1, world->temp_allocator(), world->job_system());
  return (int)error;
}

FFI_PLUGIN_EXPORT void world_raycast(World* world,
                                     RayCastConfig* config) {
  const NarrowPhaseQuery& query = world->physics_system().GetNarrowPhaseQuery();

  RRayCast in_ray;
  float* s3 = &config->start[0];
  float* e3 = &config->end[0];
  in_ray.mOrigin.Set(s3[0], s3[1], s3[2]);
  in_ray.mDirection.Set(e3[0] - s3[0], e3[1] - s3[1], e3[2] - s3[2]);

  class Collector : public CastRayCollector {
    public:
    Collector(World* world, RayCastConfig* config, const RRayCast& in_ray) : world_(world), config_(config), in_ray_(in_ray) {}

    void AddHit(const RayCastResult &inResult) override {
      const auto& id = inResult.mBodyID;
      float n[3] = { 0.0f, 0.0f, 0.0f };
      {
        // Populate normal.
        const BodyLockInterfaceLocking& lock_interface	= world_->physics_system().GetBodyLockInterface();
        BodyLockRead lock(lock_interface, id);
        if (!lock.Succeeded()) {
          // Body has been deleted out from under us.
          return;
        }
        const Body& body = lock.GetBody();
        *reinterpret_cast<Vec3*>(&n[0]) = body.GetWorldSpaceSurfaceNormal(inResult.mSubShapeID2, in_ray_.GetPointOnRay(inResult.mFraction));
      }

      Dart_Handle owner = world_->GetDartOwnerForBody(id);
      
      // TODO(johnmccutchan): Include subshape id in cb.        
      float early_out_fraction = config_->cb(owner, inResult.mFraction, n);
      if (GetEarlyOutFraction() > early_out_fraction) {
        UpdateEarlyOutFraction(early_out_fraction);
      }
      ResetEarlyOutFraction(early_out_fraction);
    }

    private:
    World* world_;
    RayCastConfig* config_;
    const RRayCast& in_ray_;
  };
    
  Collector collector(world, config, in_ray);
  RayCastSettings settings;
  query.CastRay(in_ray, settings, collector);
}

FFI_PLUGIN_EXPORT void destroy_world(World *world) {
  delete world;
}

FFI_PLUGIN_EXPORT void world_add_body(World* world, WorldBody* body, int activation) {
  world->body_interface().AddBody(body->id(),  static_cast<EActivation>(activation));
}

FFI_PLUGIN_EXPORT void world_remove_body(World* world, WorldBody* body) {
  world->body_interface().RemoveBody(body->id());
}

void assert_shape_result(const char* kind, const JPH::ShapeSettings::ShapeResult& result) {
  // TODO(johnmccutchan): Find out how to throw this as an exception into Dart.
  if (result.HasError()) {
    fprintf(stderr, "Shape %s creation failed: %s\n", kind, result.GetError().c_str());
  }
  assert(!result.HasError());
}

FFI_PLUGIN_EXPORT CollisionShape* create_decorated_shape(DecoratedShapeConfig* config) {
 switch (config->type) {
  case kScaled: {
    ScaledShapeSettings settings;
    settings.mInnerShapePtr = config->inner_shape->shape();
    settings.mScale.Set(config->v3[0], config->v3[1], config->v3[2]);
    auto result = settings.Create();
    assert_shape_result("scaled", result);
    return new CollisionShape(result.Get());
  }
  case kTransformed: {
    RotatedTranslatedShapeSettings settings;
    settings.mInnerShapePtr = config->inner_shape->shape();
    settings.mPosition.Set(config->v3[0], config->v3[1], config->v3[2]);
    settings.mRotation.Set(config->q4[0], config->q4[1], config->q4[2], config->q4[3]);
    auto result = settings.Create();
    assert_shape_result("transformed", result);
    return new CollisionShape(result.Get());
  }
  case kOffsetCenterOfMass: {
    OffsetCenterOfMassShapeSettings settings;
    settings.mInnerShapePtr = config->inner_shape->shape();
    settings.mOffset.Set(config->v3[0], config->v3[1], config->v3[2]);
    auto result = settings.Create();
    assert_shape_result("offset", result);
    return new CollisionShape(result.Get());
  }
  default: {
        fprintf(stderr, "Unknown DecoratedShapeConfigType: %d\n", config->type);
      assert(false);
      return nullptr;
  }
 }
}

FFI_PLUGIN_EXPORT CollisionShape* create_mesh_shape(float* vertices, int num_vertices, uint32_t* triangles, int num_triangles) {
  MeshShapeSettings settings;
  settings.mTriangleVertices.reserve(num_vertices);
  for (int i = 0; i < num_vertices; i++) {
    settings.mTriangleVertices.push_back(Float3(vertices[i * 3 + 0], vertices[i * 3 + 1], vertices[i * 3 + 2]));
  }
  settings.mIndexedTriangles.reserve(num_triangles);
  for (int i = 0; i < num_triangles; i++) {
    settings.mIndexedTriangles.push_back(IndexedTriangle(triangles[i * 3 + 0], triangles[i * 3 + 1], triangles[i * 3 + 2]));
  }
  auto result = settings.Create();
  assert_shape_result("mesh", result);
  return new CollisionShape(result.Get());
}

FFI_PLUGIN_EXPORT CollisionShape* create_compound_shape(CompoundShapeConfig* shapes, int num_shapes) {
  StaticCompoundShapeSettings settings;
  for (int i = 0; i < num_shapes; i++) {
    const auto& per_shape = shapes[i];
    settings.AddShape(
      Vec3(per_shape.position[0], per_shape.position[1], per_shape.position[2]),
      Quat(per_shape.rotation[0], per_shape.rotation[1], per_shape.rotation[2], per_shape.rotation[3]),
      per_shape.shape->shape());
  }
  auto result = settings.Create();
  assert_shape_result("compound", result);
  return new CollisionShape(result.Get());
}

FFI_PLUGIN_EXPORT CollisionShape* create_convex_shape(ConvexShapeConfig* config, float* points, int num_points) {
  switch (config->type) {
    case kBox: {
      BoxShapeSettings settings(Vec3(config->payload[0], config->payload[1], config->payload[2]));
      settings.SetDensity(config->density);
      auto result = settings.Create();
      assert_shape_result("box", result);
      return new CollisionShape(result.Get());
      break;
    }
    case kSphere: {
      SphereShapeSettings settings(config->payload[0]);
      settings.SetDensity(config->density);
      auto result = settings.Create();
      // TODO(johnmccutchan): Throw an error if result.HasError().
      assert_shape_result("sphere", result);
      return new CollisionShape(result.Get());
      break;
    }
    case kCapsule: {
      TaperedCapsuleShapeSettings settings(config->payload[0], config->payload[1], config->payload[2]);
      settings.SetDensity(config->density);
      auto result = settings.Create();
      assert_shape_result("capsule", result);
      return new CollisionShape(result.Get());
      break;
    }
    case kConvexHull: {
      Array<Vec3> copiedPoints;
      copiedPoints.reserve(num_points);
      for (int i = 0; i < num_points; i++) {
        copiedPoints.push_back(Vec3(points[i * 3 + 0], points[i * 3 + 1], points[i * 3 + 2]));
      }
      ConvexHullShapeSettings settings(copiedPoints);
      settings.SetDensity(config->density);
      auto result = settings.Create();
      assert_shape_result("convex hull", result);
      return new CollisionShape(result.Get());
      break;
    }
    case kUnknownConvexShape:
    default: {
      fprintf(stderr, "Unknown ConvexShapeConfigType: %d\n", config->type);
      assert(false);
      return nullptr;
    }
  }
}

FFI_PLUGIN_EXPORT void shape_set_dart_owner(CollisionShape *shape,
                                            Dart_Handle owner) {
  CollisionShape::SetDartOwner(shape, owner);
}

FFI_PLUGIN_EXPORT Dart_Handle shape_get_dart_owner(CollisionShape *shape) {
  return CollisionShape::GetDartOwner(shape);
}

FFI_PLUGIN_EXPORT void shape_get_center_of_mass(CollisionShape* shape, float* v3) {
  *reinterpret_cast<Vec3 *>(v3) = shape->shape()->GetCenterOfMass();
}

FFI_PLUGIN_EXPORT void shape_get_local_bounds(CollisionShape* shape, float* min3, float* max3) {
  AABox box = shape->shape()->GetLocalBounds();
  *reinterpret_cast<Vec3 *>(min3) = box.mMin;
  *reinterpret_cast<Vec3 *>(max3) = box.mMax;
}

FFI_PLUGIN_EXPORT void destroy_shape(CollisionShape *shape) { delete shape; }

void toJolt(BodyConfig *config, BodyCreationSettings *settings) {
  settings->SetShape(config->shape->shape());
  settings->mOverrideMassProperties =
      EOverrideMassProperties::CalculateMassAndInertia;
  settings->mMotionType = static_cast<EMotionType>(config->motion_type);
  settings->mMotionQuality =
      static_cast<EMotionQuality>(config->motion_quality);
  settings->mPosition.SetComponent(0, config->position[0]);
  settings->mPosition.SetComponent(1, config->position[1]);
  settings->mPosition.SetComponent(2, config->position[2]);
  settings->mRotation.Set(config->rotation[0], config->rotation[1],
                          config->rotation[2], config->rotation[3]);
  if (settings->mMotionType == EMotionType::Static) {
    settings->mObjectLayer = ObjectLayerPairFilterMask::sGetObjectLayer(LayerFilterStatic, LayerFilterMoving);
  } else {
    settings->mObjectLayer = ObjectLayerPairFilterMask::sGetObjectLayer(LayerFilterMoving, LayerFilterAll);
  }
}

FFI_PLUGIN_EXPORT WorldBody *world_create_body(World *world,
                                               BodyConfig *config) {
  BodyCreationSettings settings;
  toJolt(config, &settings);
  Body *body = world->body_interface().CreateBody(settings);
  return new WorldBody(world, body);
}

FFI_PLUGIN_EXPORT void body_set_position(WorldBody *body, float *v4) {
  body->SetPosition(v4);
}

FFI_PLUGIN_EXPORT void body_set_rotation(WorldBody *body, float *q4) {
  body->SetRotation(q4);
}

FFI_PLUGIN_EXPORT void body_get_position(WorldBody *body, float *v4) {
  body->GetPosition(v4);
}

FFI_PLUGIN_EXPORT void body_get_rotation(WorldBody *body, float *q4) {
  body->GetRotation(q4);
}

FFI_PLUGIN_EXPORT void body_get_world_matrix(WorldBody* body, float* m16) {
  body->GetWorldMatrix(m16);
}

FFI_PLUGIN_EXPORT void body_get_com_matrix(WorldBody* body, float* m16) {
  body->GetCOMMatrix(m16);
}

FFI_PLUGIN_EXPORT void body_set_active(WorldBody* body, bool activate) {
  if (activate) {
    body->interface().ActivateBody(body->id());
  } else {
    body->interface().DeactivateBody(body->id());
  }
}

FFI_PLUGIN_EXPORT bool body_get_active(WorldBody* body) {
  return body->interface().IsActive(body->id());
}

FFI_PLUGIN_EXPORT void destroy_body(WorldBody *body) { delete body; }

FFI_PLUGIN_EXPORT void set_body_dart_owner(WorldBody* body, Dart_Handle owner) {
  WorldBody::SetDartOwner(body, owner);
}

FFI_PLUGIN_EXPORT Dart_Handle get_body_dart_owner(WorldBody* body) {
  return WorldBody::GetDartOwner(body);
}
