// Steering a kart with two tracked Sense controllers held like a wheel.
//
// The PS VR2 Sense pair reaches this app twice over, by two unrelated paths that
// know nothing about each other:
//
//   - GameController merges them into one combined gamepad — the log names it
//     `PlayStation VR2 Sense Controllers (L/R)` — which SDL opens and the
//     engine's control deck binds to port 0. That path carries buttons and
//     sticks and no pose at all.
//   - ARKit's accessory tracking reports each controller separately, as an
//     `ar_accessory_anchor_t` carrying a world transform and a chirality. That
//     path carries pose and no buttons.
//
// This file is the second path. It exists because the first one cannot be made
// to answer where a wearer's hands are, and because two hands whose heights
// differ is a steering wheel.
//
// The measurement is one number: the angle above horizontal of the vector from
// the left hand to the right hand. Right hand higher is a wheel turned
// anticlockwise, which is a left turn. Deliberately *not* the raw height
// difference — the same 10 cm is a gentle lean with the hands wide and a hard
// turn with them close, so the difference is divided by the separation before
// the arcsine, which makes the angle independent of how far apart a wearer
// happens to hold their hands. It is also independent of which way they are
// facing: y is gravity in ARKit's world origin, and chirality names the hands
// rather than the room.
#pragma once

#import <ARKit/ARKit.h>

#import <simd/simd.h>

namespace spaghettipad {

// The steering axis in the N64's own units, as the engine's control deck will
// write it into an OSContPad. MAX_AXIS_RANGE is 85.0f upstream
// (LUS:include/ship/controller/controldevice/controller/mapping/ControllerAxisDirectionMapping.h).
inline constexpr int kN64StickMax = 85;

// Owns the accessory-tracking provider and the axis it produces.
//
// Reads of Axis() come from the engine thread, inside the control deck's pad
// read. Every write comes from the provider's own update queue. Nothing here
// touches the compositor thread, and deliberately so: the wheel angle needs no
// device pose, so it never has to reach for the AR_MT_UNSAFE world-tracking
// query the compositor owns.
class AccessorySteering {
public:
    // Creates the accessory-tracking provider so WorldTracking::Start() can add
    // it to the one ar_session_run this app performs. Returns nil when the
    // feature cannot be had here — unsupported, too old a visionOS, or an
    // authorization this bundle has not declared — having said why in the log.
    //
    // Returning nil is a supported outcome, not a failure: the caller runs the
    // session with world tracking alone, exactly as it did before this file
    // existed. Nothing about steering is allowed to cost the headset its device
    // anchors.
    ar_data_provider_t CreateProvider();

    // Follows GCSpatialAccessory connections and hands the provider the set of
    // accessories to track. Safe to call before the session runs; the first
    // sweep is deferred until it has.
    void StartWatchingAccessories();

    // The settings menu's three controls.
    void SetEnabled(bool enabled);
    void SetSensitivity(float sensitivity);

    // Takes the wearer's current hand angle as straight ahead. Steering is
    // measured as a delta from this, so a wearer who holds the pair with a
    // natural tilt is not fighting a permanent turn.
    void Recenter();

    // The axis to apply, or false when steering should not be touched — off,
    // unsupported, not both hands held and tracked, or a sample too stale to
    // act on. Engine thread.
    bool Axis(int* outStickX) const;

    // Takes one round of anchor updates and republishes the axis. Public only
    // because the provider's update block calls it; the provider's own serial
    // queue is the only caller, and the anchor collections are AR_MT_UNSAFE, so
    // calling it from anywhere else is a data race.
    void IngestAnchors(ar_accessory_anchors_t added, ar_accessory_anchors_t updated,
                       ar_accessory_anchors_t removed);

private:
    void PublishFromAnchors();

    ar_accessory_tracking_provider_t provider_ = nil;
};

AccessorySteering& SharedAccessorySteering();

// The wheel angle in radians for a left and a right hand position: positive
// when the right hand is higher, which is a left turn. Returns false when the
// hands are too close together for the angle to mean anything.
//
// Free and pure so it can be reasoned about — and tested — without a headset,
// an ARKit session, or a pair of controllers.
bool WheelAngle(simd_float3 leftHand, simd_float3 rightHand, float* outRadians);

} // namespace spaghettipad
