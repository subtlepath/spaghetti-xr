// ARKit world tracking for the compositor. See SpaghettiPadWorldTracking.h for
// why this exists at all.
//
// Everything here is the C ARKit API rather than the Swift one, because the
// caller is the Objective-C++ frame loop and the pose has to be queried inside
// it, between the drawable arriving and the views being encoded. Reaching back
// into Swift for that would put an actor hop in the middle of a frame.

#import "SpaghettiPadWorldTracking.h"

#import "SpaghettiPadBridge.h"

#import <Foundation/Foundation.h>

#import <os/log.h>

#import <mutex>

namespace spaghettipad {
namespace {

os_log_t TrackingLog() {
    static os_log_t log =
        os_log_create("com.subtlepath.spaghettipad", "tracking");
    return log;
}

const char* AuthorizationName(ar_authorization_type_t type) {
    if (type == ar_authorization_type_none) {
        return "none";
    }
    if (type == ar_authorization_type_world_sensing) {
        return "world sensing";
    }
    if (type == ar_authorization_type_hand_tracking) {
        return "hand tracking";
    }
    return "several";
}

const char* ProviderStateName(ar_data_provider_state_t state) {
    switch (state) {
        case ar_data_provider_state_initialized:
            return "initialized";
        case ar_data_provider_state_running:
            return "running";
        case ar_data_provider_state_paused:
            return "paused";
        case ar_data_provider_state_stopped:
            return "stopped";
    }
    return "unknown";
}

} // namespace

const char* TrackingStateName(ar_device_anchor_tracking_state_t state) {
    switch (state) {
        case ar_device_anchor_tracking_state_untracked:
            return "untracked";
        case ar_device_anchor_tracking_state_orientation_tracked:
            return "orientation only";
        case ar_device_anchor_tracking_state_tracked:
            return "tracked";
    }
    return "unknown";
}

bool WorldTracking::Start() {
    // Only the compositor thread starts this today, and only one compositor
    // exists at a time — but "safe to call from any thread" is a promise the
    // header makes, and a promise kept by a comment is not kept.
    static std::mutex startMutex;
    std::lock_guard<std::mutex> lock(startMutex);

    if (running_.load(std::memory_order_acquire)) {
        return true;
    }

    // Reported rather than assumed: this is the difference between a headset
    // that will present frames and one that will not, and the Simulator and a
    // real device are not obliged to agree about it.
    if (!ar_world_tracking_provider_is_supported()) {
        os_log_error(TrackingLog(),
                     "world tracking is unsupported here, so no drawable can "
                     "carry a device anchor");
        return false;
    }

    ar_world_tracking_configuration_t configuration =
        ar_world_tracking_configuration_create();
    provider_ = ar_world_tracking_provider_create(configuration);
    if (provider_ == nil) {
        os_log_error(TrackingLog(), "could not create the world tracking provider");
        return false;
    }

    session_ = ar_session_create();
    if (session_ == nil) {
        os_log_error(TrackingLog(), "could not create the ARKit session");
        provider_ = nil;
        return false;
    }

    // A provider can fail long after it is run — most often unauthorized — and
    // the only symptom at the frame loop would be queries that quietly stop
    // succeeding. This is the one place ARKit says why.
    ar_session_set_data_provider_state_change_handler(
        session_, dispatch_get_main_queue(),
        ^(ar_data_providers_t, ar_data_provider_state_t state, ar_error_t error,
          ar_data_provider_t) {
            if (error == nil) {
                os_log(TrackingLog(), "world tracking is %{public}s",
                       ProviderStateName(state));
                return;
            }
            CFErrorRef cfError = ar_error_copy_cf_error(error);
            os_log_error(TrackingLog(),
                         "world tracking is %{public}s: %{public}@",
                         ProviderStateName(state), (__bridge NSError*)cfError);
            if (cfError != nullptr) {
                CFRelease(cfError);
            }
        });

    ar_data_providers_t providers = ar_data_providers_create();
    ar_data_providers_add_data_provider(providers, provider_);
    ar_session_run(session_, providers);
    running_.store(true, std::memory_order_release);

    // The authorization requirement is read from ARKit rather than guessed at,
    // because guessing it wrong is what puts an unnecessary usage-description
    // string in a shipping Info.plist — or leaves out a necessary one.
    os_log(TrackingLog(),
           "world tracking running: required authorization %{public}s, provider "
           "%{public}s",
           AuthorizationName(ar_world_tracking_provider_get_required_authorization_type()),
           ProviderStateName(ar_data_provider_get_state(provider_)));
    return true;
}

DevicePose WorldTracking::PoseAtTime(CFTimeInterval time) {
    DevicePose pose;
    if (!running_.load(std::memory_order_acquire)) {
        return pose;
    }

    // A fresh anchor per query, not one reused across frames. The compositor
    // reads the anchor it was given when it presents, which is after the next
    // frame has already been drawn — so a single reused object would have the
    // following frame's prediction in it by the time this frame was reprojected
    // against it. This matches what queryDeviceAnchor(atTimestamp:) hands back
    // in Swift, which is a new object every call.
    ar_device_anchor_t anchor = ar_device_anchor_create();
    if (ar_world_tracking_provider_query_device_anchor_at_timestamp(
            provider_, time, anchor) != ar_device_anchor_query_status_success) {
        return pose;
    }

    pose.anchor = anchor;
    pose.originFromDevice = ar_device_anchor_get_origin_from_anchor_transform(anchor);
    pose.state = ar_device_anchor_get_tracking_state(anchor);
    pose.valid = true;
    return pose;
}

WorldTracking& SharedWorldTracking() {
    static WorldTracking tracking;
    return tracking;
}

simd_float3 TransformTranslation(simd_float4x4 transform) {
    return simd_make_float3(transform.columns[3].x, transform.columns[3].y,
                            transform.columns[3].z);
}

simd_float3 HorizontalForward(simd_float4x4 transform) {
    // ARKit and Compositor Services both use a right-handed system with -Z
    // forward, so the third column is backwards and its negation is the gaze.
    const simd_float3 forward = -simd_make_float3(
        transform.columns[2].x, transform.columns[2].y, transform.columns[2].z);

    simd_float3 flat = simd_make_float3(forward.x, 0.0f, forward.z);
    if (simd_length(flat) > 1.0e-3f) {
        return simd_normalize(flat);
    }

    // Looking straight up or straight down: the gaze has no horizontal part to
    // keep, but the head's own up vector does, and it points where the wearer
    // would be looking if they levelled off.
    const simd_float3 up = simd_make_float3(
        transform.columns[1].x, transform.columns[1].y, transform.columns[1].z);
    flat = simd_make_float3(forward.y > 0.0f ? -up.x : up.x, 0.0f,
                            forward.y > 0.0f ? -up.z : up.z);
    if (simd_length(flat) > 1.0e-3f) {
        return simd_normalize(flat);
    }
    return simd_make_float3(0.0f, 0.0f, -1.0f);
}

} // namespace spaghettipad

// ------------------------------------------------------------------- bridge

void* SpaghettiPad_ARSession(void) {
    spaghettipad::WorldTracking& tracking = spaghettipad::SharedWorldTracking();
    if (!tracking.IsRunning()) {
        return nullptr;
    }
    return (__bridge void*)tracking.Session();
}
