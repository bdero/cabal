#include "jolt_ffi.h"

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
#include <Jolt/Physics/Body/BodyActivationListener.h>
#include <Jolt/Physics/Body/BodyCreationSettings.h>
#include <Jolt/Physics/Body/MassProperties.h>
#include <Jolt/Physics/Collision/BroadPhase/BroadPhaseLayerInterfaceMask.h>
#include <Jolt/Physics/Collision/BroadPhase/ObjectVsBroadPhaseLayerFilterMask.h>
#include <Jolt/Physics/Collision/ObjectLayerPairFilterMask.h>
#include <Jolt/Physics/Collision/Shape/BoxShape.h>
#include <Jolt/Physics/Collision/Shape/SphereShape.h>
#include <Jolt/Physics/EActivation.h>
#include <Jolt/Physics/PhysicsSettings.h>
#include <Jolt/Physics/PhysicsSystem.h>
#include <Jolt/RegisterTypes.h>

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

class World {
public:
  World() {
    temp_allocator_ = std::make_unique<TempAllocatorImpl>(10 * 1024 * 1024);
    job_system_ = std::make_unique<JobSystemThreadPool>(cMaxPhysicsJobs, cMaxPhysicsBarriers, thread::hardware_concurrency() - 1);
    // TODO(johnmccutchan): The number of layers must be configurable.
    bp_layer_interface_ = std::make_unique<BroadPhaseLayerInterfaceMask>(2);
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

  BodyInterface &body_interface() {
    return physics_system_->GetBodyInterface();
  }

  BodyConfig *body_config() { return &body_config_; }

private:
  std::unique_ptr<TempAllocator> temp_allocator_;
  std::unique_ptr<JobSystem> job_system_;
  std::unique_ptr<BroadPhaseLayerInterfaceMask> bp_layer_interface_;
  std::unique_ptr<ObjectVsBroadPhaseLayerFilterMask>
      object_vs_broad_phase_layer_filter_;
  std::unique_ptr<ObjectLayerPairFilterMask>
      object_vs_object_layer_pair_filter_;
  std::unique_ptr<PhysicsSystem> physics_system_;
  BodyConfig body_config_;

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
  }

  static void SetDartOwner(Shape *shape, Dart_Handle owner) {
    Dart_WeakPersistentHandle weak_ref =
        Dart_NewWeakPersistentHandle_DL(owner, nullptr, 0, NoopFinalizer);
    shape->SetUserData(reinterpret_cast<uint64_t>(weak_ref));
  }

  static Dart_Handle GetDartOwner(Shape *shape) {
    return Dart_HandleFromWeakPersistent_DL(
        reinterpret_cast<Dart_WeakPersistentHandle>(shape->GetUserData()));
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
  }

  static void SetDartOwner(WorldBody *body, Dart_Handle owner) {
    Dart_WeakPersistentHandle weak_ref =
        Dart_NewWeakPersistentHandle_DL(owner, nullptr, 0, NoopFinalizer);
    body->body()->SetUserData(reinterpret_cast<uint64_t>(weak_ref));
  }

  static Dart_Handle GetDartOwner(WorldBody *body) {
    return Dart_HandleFromWeakPersistent_DL(
        reinterpret_cast<Dart_WeakPersistentHandle>(
            body->body()->GetUserData()));
  }

  World *world() { return world_; }

  BodyInterface &interface() { return world_->body_interface(); }

  Body *body() { return body_; }

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
    *reinterpret_cast<Vec3 *>(v4) = body_->GetPosition();
  }

  void GetRotation(float *q4) {
    *reinterpret_cast<Quat *>(q4) = body_->GetRotation();
  }

  void GetWorldMatrix(float* m16) {
    *reinterpret_cast<Mat44*>(m16) = body_->GetWorldTransform();
  }

  void GetCOMMatrix(float* m16) {
    *reinterpret_cast<Mat44*>(m16) = body_->GetCenterOfMassTransform();
  }

private:
  World *world_;
  Body *body_;
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

FFI_PLUGIN_EXPORT void destroy_world(World *world) {
  delete world;
}

FFI_PLUGIN_EXPORT void world_add_body(World* world, WorldBody* body, int activation) {
  world->body_interface().AddBody(body->id(),  static_cast<EActivation>(activation));
}

FFI_PLUGIN_EXPORT void world_remove_body(World* world, WorldBody* body) {
  world->body_interface().RemoveBody(body->id());
}

FFI_PLUGIN_EXPORT BodyConfig *world_get_body_config(World *world) {
  return world->body_config();
}

FFI_PLUGIN_EXPORT CollisionShape *create_box_shape(float hx, float hy,
                                                   float hz) {
  BoxShapeSettings box_shape_settings(Vec3(hx, hy, hz));
  auto result = box_shape_settings.Create();
  // TODO(johnmccutchan): Throw an error if result.HasError().
  return new CollisionShape(result.Get());
}

FFI_PLUGIN_EXPORT CollisionShape *create_sphere_shape(float radius) {
  SphereShapeSettings sphere_shape_settings(radius);
  auto result = sphere_shape_settings.Create();
  // TODO(johnmccutchan): Throw an error if result.HasError().
  return new CollisionShape(result.Get());
}

FFI_PLUGIN_EXPORT void shape_set_dart_owner(CollisionShape *shape,
                                            Dart_Handle owner) {
  CollisionShape::SetDartOwner(shape->shape(), owner);
}

FFI_PLUGIN_EXPORT Dart_Handle shape_get_dart_owner(CollisionShape *shape) {
  return CollisionShape::GetDartOwner(shape->shape());
}

FFI_PLUGIN_EXPORT void destroy_shape(CollisionShape *shape) { delete shape; }

void toJolt(BodyConfig *config, BodyCreationSettings *settings) {
  if (config->shape != nullptr) {
    settings->SetShape(config->shape->shape());
    settings->mOverrideMassProperties =
        EOverrideMassProperties::CalculateMassAndInertia;
  } else {
    settings->SetShape(nullptr);
    settings->mOverrideMassProperties =
        EOverrideMassProperties::MassAndInertiaProvided;
  }
  settings->mMotionType = static_cast<EMotionType>(config->motion_type);
  settings->mMotionQuality =
      static_cast<EMotionQuality>(config->motion_quality);
  settings->mPosition.SetComponent(0, config->position[0]);
  settings->mPosition.SetComponent(1, config->position[1]);
  settings->mPosition.SetComponent(2, config->position[2]);
  settings->mRotation.Set(config->rotation[0], config->rotation[1],
                          config->rotation[2], config->rotation[3]);
}

FFI_PLUGIN_EXPORT WorldBody *world_create_body(World *world,
                                               BodyConfig *config) {
  BodyCreationSettings settings;
  toJolt(config, &settings);
  Body *body = world->body_interface().CreateBody(settings);
  return new WorldBody(world, body);
}

FFI_PLUGIN_EXPORT void set_owner_body(WorldBody *body, Dart_Handle owner) {
  WorldBody::SetDartOwner(body, owner);
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

FFI_PLUGIN_EXPORT void destroy_body(WorldBody *body) { delete body; }