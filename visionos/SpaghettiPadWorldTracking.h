// The app's ARKit session, and the device pose the compositor renders from.
//
// Compositor Services will hand out drawables whether or not anything tells it
// where the wearer's head is, and the Simulator will happily present them. A
// headset will not: a drawable presented without a device anchor is dropped,
// and `com.apple.CompositorNonUI` says so on every frame. So this is not an
// enhancement to the frame loop — it is the part of it that makes a headset
// show anything at all.
//
// Only the compositor thread may touch a WorldTracking instance's query:
// ar_world_tracking_provider_query_device_anchor_at_timestamp is declared
// AR_MT_UNSAFE. Session() is safe from anywhere once Start() has returned.
#pragma once

#import <ARKit/ARKit.h>

#import <simd/simd.h>

#import <CoreFoundation/CoreFoundation.h>

#import <atomic>

namespace spaghettipad {

// What a query returned, kept together because a pose is only meaningful
// alongside whether it was tracked.
struct DevicePose {
    // Hand this to cp_drawable_set_device_anchor. Nil when the query failed, in
    // which case the drawable gets no anchor and the headset drops the frame —
    // which is better than presenting one drawn from a pose nothing vouches for.
    ar_device_anchor_t anchor = nil;
    // origin -> device. Identity when `anchor` is nil, so callers that compose
    // it degrade to the head-locked behaviour rather than to nonsense.
    simd_float4x4 originFromDevice = matrix_identity_float4x4;
    ar_device_anchor_tracking_state_t state = ar_device_anchor_tracking_state_untracked;
    bool valid = false;
};

class WorldTracking {
public:
    // Creates the session and runs world tracking. Idempotent, and safe to call
    // from any thread. Returns false only when the provider could not be
    // created or is unsupported; a provider that fails asynchronously reports
    // itself through the session's state-change handler and shows up as failed
    // queries.
    bool Start();

    // True once Start() has run the session.
    bool IsRunning() const { return running_.load(std::memory_order_acquire); }

    // The predicted device pose for `time`, which is mach absolute time in
    // seconds — cp_time_to_cf_time_interval of the frame's own presentation
    // time. Compositor thread only.
    DevicePose PoseAtTime(CFTimeInterval time);

    // The one ar_session_t this app will ever own. ARKit permits a single
    // session, so Phase 5's accessory tracking has to join this one rather than
    // create a second; SpaghettiPad_ARSession() exposes it for exactly that.
    ar_session_t Session() const { return session_; }

    // There is deliberately no Stop(). The session outlives every immersive
    // space: stopping it when the wearer closes the space would reset the world
    // origin under a game they left running, and the next open would find the
    // room somewhere else.

private:
    ar_session_t session_ = nil;
    ar_world_tracking_provider_t provider_ = nil;
    std::atomic<bool> running_{false};
};

// The process-wide instance. One session, one provider, one owner.
WorldTracking& SharedWorldTracking();

// "tracked", "orientation only" or "untracked", for logs that have to be
// readable months later by someone holding a headset.
const char* TrackingStateName(ar_device_anchor_tracking_state_t state);

// Rigid-transform helpers shared by the compositor. Both assume their argument
// is a rotation plus a translation, which every transform ARKit and Compositor
// Services hand out is.
simd_float3 TransformTranslation(simd_float4x4 transform);

// Where a pose is looking, flattened onto the horizontal plane and normalised.
// Used to place content in front of the wearer without inheriting the pitch and
// roll of whatever they happened to be doing with their head at the time.
simd_float3 HorizontalForward(simd_float4x4 transform);

} // namespace spaghettipad
