// Two tracked Sense controllers, read as a steering wheel. See
// SpaghettiPadAccessorySteering.h for what is being measured and why.
//
// The C ARKit API rather than the Swift one, for the same reason
// SpaghettiPadWorldTracking.mm gives: the consumer is the Objective-C++ engine
// bridge, and an actor hop does not belong between a wearer's hands and the
// kart.

#import "SpaghettiPadAccessorySteering.h"

#import "SpaghettiPadBridge.h"
// For TransformTranslation, which is the same rigid-transform helper the
// compositor uses; a pose is a pose whether it came from a head or a hand.
#import "SpaghettiPadWorldTracking.h"

#import <Foundation/Foundation.h>
#import <GameController/GameController.h>
#import <QuartzCore/QuartzCore.h>

#import <os/log.h>

#import <algorithm>
#import <atomic>
#import <cmath>

namespace spaghettipad {
namespace {

os_log_t SteeringLog() {
    static os_log_t log = os_log_create("com.subtlepath.spaghettipad", "steering");
    return log;
}

// ------------------------------------------------------- tuning, and its source
//
// The retired iOS tilt path (ios/SpaghettiPadShell.mm, still live in the iOS
// lane) settled on a one-pole filter at alpha 0.18 fed at exactly 60 Hz, a
// deadzone of 0.035 of full travel, and full lock at 0.45 rad of device roll.
// Two of those three carry over unchanged. The third does not, and pretending
// otherwise would be the wrong kind of consistency:
//
//   - The filter does carry over, but not as a bare alpha. 0.18 per sample only
//     means what it meant if the samples arrive 60 times a second, and accessory
//     tracking does not promise that rate. What was actually tuned is the time
//     constant that alpha-at-60-Hz implies, so that is what is written down and
//     alpha is recovered from the measured interval each update. A wearer on a
//     90 Hz feed then gets the smoothing that was tuned on a phone, rather than
//     a third less of it.
//
//   - The deadzone carries over unchanged. It is expressed in normalised travel,
//     not in radians, so it does not care what the input was.
//
//   - Full lock does not carry over. 0.45 rad is 26 degrees, tuned for a wrist
//     rolling a phone; the same 26 degrees across a wheel held in two hands is
//     about 9 cm of vertical hand travel each way, which is inside the noise a
//     pair of unsupported arms produce while a person concentrates on a race.
//     0.70 rad — 40 degrees, roughly 14 cm each way at a typical grip width — is
//     a deliberate movement. **This number is a considered guess and has never
//     been felt by anyone.** The sensitivity slider spans 0.5x to 2.0x, so a
//     wearer can reach 80 degrees or 20 degrees without a rebuild, and what they
//     land on is the number that should replace this one.
constexpr double kTiltFilterAlpha60Hz = 0.18;
constexpr double kTiltFilterRateHz = 60.0;
constexpr double kDeadzone = 0.035;
constexpr double kFullLockRadians = 0.70;

// The continuous time constant behind alpha-at-60-Hz. Derived rather than
// written as a rounded literal so the two can never disagree: for a one-pole
// filter, alpha = 1 - exp(-dt / tau), so tau = -dt / ln(1 - alpha). At 0.18 and
// 60 Hz that is ~84 ms.
const double kFilterTimeConstant =
    -(1.0 / kTiltFilterRateHz) / std::log(1.0 - kTiltFilterAlpha60Hz);

// Below this the hands are close enough together that the angle between them is
// mostly noise — and a wearer whose hands are touching is not holding a wheel.
// 15 cm is narrower than any grip someone would drive with and wide enough that
// tracking jitter cannot swing the angle far.
constexpr float kMinHandSeparation = 0.15f;

// How long a published axis outlives the update that produced it. The update
// handler stops firing when tracking is lost or the wearer puts a controller
// down, and without this the kart would hold the last turn it was given. Two
// frames at 60 Hz, which is short enough to feel like a release and long enough
// that an ordinary gap between updates does not stutter the steering.
constexpr double kMaxAxisAge = 0.033;

const char* ChiralityName(ar_accessory_chirality_t chirality) {
    switch (chirality) {
        case ar_accessory_chirality_left:
            return "left";
        case ar_accessory_chirality_right:
            return "right";
        case ar_accessory_chirality_unspecified:
            return "unspecified";
    }
    return "unknown";
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

// Whether this bundle has declared the usage string an authorization needs.
//
// A privacy-gated provider whose usage description is missing does not fail
// politely; the system terminates the app when the permission is first
// requested. Since this provider joins the session world tracking runs in, that
// termination would take the whole headset picture with it — so the check
// happens before the provider is ever created, and a missing string costs the
// wearer steering rather than the app its life.
bool BundleDeclaresAuthorization(ar_authorization_type_t type) {
    if (type == ar_authorization_type_none) {
        return true;
    }

    NSString* key = nil;
    if (type == ar_authorization_type_world_sensing) {
        key = @"NSWorldSensingUsageDescription";
    } else if (type == ar_authorization_type_hand_tracking) {
        key = @"NSHandsTrackingUsageDescription";
    }
    if (key == nil) {
        return false;
    }

    id value = [[NSBundle mainBundle] objectForInfoDictionaryKey:key];
    return [value isKindOfClass:[NSString class]] && [(NSString*)value length] > 0;
}

// One hand, as the update handler last saw it.
struct HandSample {
    simd_float3 position = simd_make_float3(0.0f, 0.0f, 0.0f);
    bool usable = false;
};

// The provider's own serial queue. Every mutable field below is touched only
// from here, which is what lets them be plain members instead of guarded ones;
// the two atomics at the bottom are the whole of the boundary with the engine
// thread.
dispatch_queue_t SteeringQueue() {
    static dispatch_queue_t queue = dispatch_queue_create(
        "com.subtlepath.spaghettipad.steering",
        dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL,
                                                QOS_CLASS_USER_INTERACTIVE, 0));
    return queue;
}

struct SteeringState {
    // Queue-confined.
    HandSample left;
    HandSample right;
    double filtered = 0.0;
    double reference = 0.0;
    bool referenceValid = false;
    double lastUpdateTime = 0.0;
    bool loggedFirstAngle = false;

    // The boundary with the engine thread. Two atomics rather than one packed
    // word: they are written back to back and read back to back, so the worst
    // an interleaving can produce is an axis judged against the previous
    // update's timestamp — one sample of extra latency on a signal that is
    // already filtered, and never a wrong sign or a stuck wheel.
    std::atomic<int> axis{0};
    std::atomic<bool> active{false};
    std::atomic<double> publishedAt{0.0};

    // Read on the queue, written by the menu.
    std::atomic<bool> enabled{false};
    std::atomic<float> sensitivity{1.0f};
    std::atomic<bool> recenterRequested{false};
};

SteeringState& State() {
    static SteeringState state;
    return state;
}

void PublishInactive() {
    SteeringState& state = State();
    state.active.store(false, std::memory_order_release);
    state.axis.store(0, std::memory_order_release);
}

} // namespace

// ------------------------------------------------------------------- the angle

bool WheelAngle(simd_float3 leftHand, simd_float3 rightHand, float* outRadians) {
    const simd_float3 span = rightHand - leftHand;
    const float separation = simd_length(span);
    if (separation < kMinHandSeparation) {
        return false;
    }

    // y is gravity: ARKit's world origin is levelled, so the vertical component
    // of the left-to-right vector is the wheel's tilt no matter which way the
    // wearer has turned in the room. Dividing by the separation before the
    // arcsine is what makes this an angle rather than a height — the same hand
    // offset means a harder turn from a narrow grip, which is what a wheel does.
    const float sine = std::clamp(span.y / separation, -1.0f, 1.0f);
    if (outRadians != nullptr) {
        *outRadians = std::asin(sine);
    }
    return true;
}

// ------------------------------------------------------------------ the provider

ar_data_provider_t AccessorySteering::CreateProvider() {
    // Everything this file needs beyond the pose itself — enumerating the two
    // controllers separately, and handing the provider a new set as they connect
    // — arrived in visionOS 27. On 26 the pair is only ever the one combined
    // gamepad GameController reports, which has no hands to compare.
    if (@available(visionOS 27.0, *)) {
    } else {
        os_log(SteeringLog(),
               "6DoF steering needs visionOS 27; the Sense pair stays an "
               "ordinary gamepad on this system");
        return nil;
    }

    if (!ar_accessory_tracking_provider_is_supported()) {
        os_log(SteeringLog(),
               "accessory tracking is unsupported here, so there are no hand "
               "positions to steer with");
        return nil;
    }

    const ar_authorization_type_t authorization =
        ar_accessory_tracking_provider_get_required_authorization_type();
    if (!BundleDeclaresAuthorization(authorization)) {
        os_log_error(SteeringLog(),
                     "accessory tracking requires %{public}s authorization and "
                     "this bundle declares no usage string for it; declining to "
                     "add the provider rather than risk the session world "
                     "tracking runs in",
                     AuthorizationName(authorization));
        return nil;
    }

    // Created with no accessories at all: none are connected this early, and the
    // set is replaced through update_accessories every time the spatial
    // accessories change. A provider tracking nothing is the resting state, not
    // an error.
    ar_accessory_tracking_configuration_t configuration =
        ar_accessory_tracking_configuration_create();
    ar_accessories_t empty = ar_accessories_create();
    ar_accessory_tracking_configuration_set_accessories(configuration, empty);

    provider_ = ar_accessory_tracking_provider_create(configuration);
    if (provider_ == nil) {
        os_log_error(SteeringLog(), "could not create the accessory tracking provider");
        return nil;
    }

    os_log(SteeringLog(),
           "accessory tracking provider created: required authorization %{public}s",
           AuthorizationName(authorization));
    return provider_;
}

namespace {

// Which hand an anchor belongs to. Held chirality first — it is what the wearer
// is actually doing — falling back to what the controller was built to be, which
// is what a Sense controller reports when it is tracked but not yet gripped.
ar_accessory_chirality_t AnchorChirality(ar_accessory_anchor_t anchor) {
    const ar_accessory_chirality_t held = ar_accessory_anchor_get_held_chirality(anchor);
    if (held != ar_accessory_chirality_unspecified) {
        return held;
    }
    ar_accessory_t accessory = ar_accessory_anchor_get_accessory(anchor);
    if (accessory == nil) {
        return ar_accessory_chirality_unspecified;
    }
    return ar_accessory_get_inherent_chirality(accessory);
}

// Where the hand is, as opposed to where the anchor's origin is.
//
// The grip location is the point the controller is designed to be held at, and
// it is what a wheel is made of. It is offset from the anchor origin in the
// anchor's own frame, so it rotates with the wearer's wrist rather than sitting
// at a fixed distance in the room — which is exactly why using it beats using
// the origin and calling the difference constant. `ar_transform_correction_none`
// because this is going to a game's steering, not to something being drawn: the
// rendered correction exists to line virtual geometry up with a physical object
// under reprojection, and there is no geometry here.
simd_float3 GripPosition(ar_accessory_anchor_t anchor) {
    const simd_float4x4 originFromAnchor =
        ar_accessory_anchor_get_origin_from_anchor_transform(anchor);
    const simd_float4x4 anchorFromGrip =
        ar_accessory_anchor_get_anchor_from_location_transform_with_correction(
            anchor, ar_accessory_location_name_grip, ar_transform_correction_none);

    // A grip more than half a metre from its own anchor is not a grip; that
    // would mean the location was not available and something unspecified came
    // back. The anchor origin is the honest answer in that case.
    const simd_float3 offset = TransformTranslation(anchorFromGrip);
    if (!std::isfinite(simd_length(offset)) || simd_length(offset) > 0.5f) {
        return TransformTranslation(originFromAnchor);
    }
    return TransformTranslation(simd_mul(originFromAnchor, anchorFromGrip));
}

// A hand worth steering with: tracked, positioned rather than merely oriented,
// and actually in someone's hand. An untracked controller reports a stale pose
// rather than no pose, so taking the state on trust would steer from wherever a
// controller was last seen.
bool AnchorIsUsable(ar_accessory_anchor_t anchor) {
    if (!ar_accessory_anchor_is_tracked(anchor) || !ar_accessory_anchor_is_held(anchor)) {
        return false;
    }
    const ar_accessory_anchor_tracking_state_t state =
        ar_accessory_anchor_get_tracking_state(anchor);
    return state == ar_accessory_anchor_tracking_state_position_orientation_tracked ||
           state == ar_accessory_anchor_tracking_state_position_orientation_tracked_low_accuracy;
}

} // namespace

void AccessorySteering::IngestAnchors(ar_accessory_anchors_t added,
                                      ar_accessory_anchors_t updated,
                                      ar_accessory_anchors_t removed) {
    const auto absorb = ^(ar_accessory_anchor_t anchor) {
      HandSample sample;
      sample.usable = AnchorIsUsable(anchor);
      if (sample.usable) {
          sample.position = GripPosition(anchor);
      }

      switch (AnchorChirality(anchor)) {
          case ar_accessory_chirality_left:
              State().left = sample;
              break;
          case ar_accessory_chirality_right:
              State().right = sample;
              break;
          case ar_accessory_chirality_unspecified:
              // A controller whose hand is unknown cannot be half of a wheel.
              break;
      }
      return true;
    };

    if (added != nil) {
        ar_accessory_anchors_enumerate_anchors(added, absorb);
    }
    if (updated != nil) {
        ar_accessory_anchors_enumerate_anchors(updated, absorb);
    }
    if (removed != nil) {
        ar_accessory_anchors_enumerate_anchors(removed, ^(ar_accessory_anchor_t anchor) {
          switch (AnchorChirality(anchor)) {
              case ar_accessory_chirality_left:
                  State().left = HandSample{};
                  break;
              case ar_accessory_chirality_right:
                  State().right = HandSample{};
                  break;
              case ar_accessory_chirality_unspecified:
                  break;
          }
          return true;
        });
    }

    PublishFromAnchors();
}

void AccessorySteering::PublishFromAnchors() {
    SteeringState& state = State();

    if (!state.left.usable || !state.right.usable) {
        state.referenceValid = false;
        state.filtered = 0.0;
        PublishInactive();
        return;
    }

    float radians = 0.0f;
    if (!WheelAngle(state.left.position, state.right.position, &radians)) {
        PublishInactive();
        return;
    }

    const double now = CACurrentMediaTime();
    const double interval = state.lastUpdateTime > 0.0
                                ? std::clamp(now - state.lastUpdateTime, 1.0e-3, 0.1)
                                : 1.0 / kTiltFilterRateHz;
    state.lastUpdateTime = now;

    if (state.recenterRequested.exchange(false, std::memory_order_acq_rel)) {
        state.referenceValid = false;
    }

    if (!state.referenceValid) {
        state.reference = radians;
        state.filtered = 0.0;
        state.referenceValid = true;
        state.active.store(true, std::memory_order_release);
        state.axis.store(0, std::memory_order_release);
        state.publishedAt.store(now, std::memory_order_release);
        os_log(SteeringLog(), "steering centred at %.1f degrees of hand tilt",
               radians * 180.0 / M_PI);
        return;
    }

    const double delta = std::remainder(radians - state.reference, 2.0 * M_PI);

    // alpha recovered from the interval actually observed, so the smoothing is
    // the one that was tuned rather than the one the sample rate happens to give.
    const double alpha = 1.0 - std::exp(-interval / kFilterTimeConstant);
    state.filtered += (delta - state.filtered) * alpha;

    double normalized =
        state.filtered * state.sensitivity.load(std::memory_order_acquire) / kFullLockRadians;
    if (std::abs(normalized) < kDeadzone) {
        normalized = 0.0;
    }
    normalized = std::clamp(normalized, -1.0, 1.0);

    // Right hand higher is a wheel turned anticlockwise, which is a left turn,
    // and left is negative on an N64 stick. The sign lives here, once.
    const int stickX = static_cast<int>(std::lround(-normalized * kN64StickMax));

    state.axis.store(stickX, std::memory_order_release);
    state.active.store(true, std::memory_order_release);
    state.publishedAt.store(now, std::memory_order_release);

    if (!state.loggedFirstAngle) {
        state.loggedFirstAngle = true;
        os_log(SteeringLog(),
               "first steering sample: hands %.0f mm apart, %.1f degrees of "
               "tilt, stick x %d",
               simd_length(state.right.position - state.left.position) * 1000.0f,
               delta * 180.0 / M_PI, stickX);
    }
}

void AccessorySteering::StartWatchingAccessories() {
    if (provider_ == nil) {
        return;
    }

    if (@available(visionOS 27.0, *)) {
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            // The update handler is installed and removed with the setting, not
            // here: ARKit disables routine anchor updates entirely while no
            // handler is set, which is the difference between a feature that is
            // off and one that is merely ignored.
            dispatch_async(dispatch_get_main_queue(), ^{
                NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
                void (^refresh)(NSNotification*) = ^(NSNotification* note) {
                    (void)note;
                    SharedAccessorySteering().StartWatchingAccessories();
                };
                [center addObserverForName:GCSpatialAccessoryDidConnectNotification
                                    object:nil
                                     queue:[NSOperationQueue mainQueue]
                                usingBlock:refresh];
                [center addObserverForName:GCSpatialAccessoryDidDisconnectNotification
                                    object:nil
                                     queue:[NSOperationQueue mainQueue]
                                usingBlock:refresh];
            });
        });

        NSArray<GCSpatialAccessory*>* accessories = [GCSpatialAccessory spatialAccessories];
        if (accessories.count == 0) {
            os_log(SteeringLog(), "no spatial accessories are connected");
            ar_accessory_tracking_provider_update_accessories(
                provider_, ar_accessories_create(), ^(bool, ar_error_t) {
                });
            return;
        }

        // Each load is asynchronous and they complete in no particular order, so
        // the collection is only handed over once the last one has answered.
        __block NSUInteger outstanding = accessories.count;
        ar_accessories_t loaded = ar_accessories_create();
        ar_accessory_tracking_provider_t provider = provider_;

        for (GCSpatialAccessory* accessory in accessories) {
            ar_accessory_load_from_device(
                accessory, ^(id<GCDevice> device, bool successful, ar_error_t error,
                             ar_accessory_t loadedAccessory) {
                  if (successful && loadedAccessory != nil) {
                      ar_accessories_add_accessory(loaded, loadedAccessory);
                      os_log(SteeringLog(),
                             "spatial accessory loaded for tracking: %{public}s (%{public}s)",
                             device.vendorName.UTF8String ?: "unnamed",
                             ChiralityName(ar_accessory_get_inherent_chirality(loadedAccessory)));
                  } else {
                      CFErrorRef cfError = error != nil ? ar_error_copy_cf_error(error) : nullptr;
                      os_log_error(SteeringLog(),
                                   "could not load spatial accessory %{public}s for "
                                   "tracking: %{public}@",
                                   device.vendorName.UTF8String ?: "unnamed",
                                   (__bridge NSError*)cfError);
                      if (cfError != nullptr) {
                          CFRelease(cfError);
                      }
                  }

                  if (--outstanding > 0) {
                      return;
                  }

                  const size_t count = ar_accessories_get_count(loaded);
                  ar_accessory_tracking_provider_update_accessories(
                      provider, loaded, ^(bool success, ar_error_t updateError) {
                        if (success) {
                            os_log(SteeringLog(), "tracking %zu spatial accessor%{public}s",
                                   count, count == 1 ? "y" : "ies");
                            return;
                        }
                        CFErrorRef cfError =
                            updateError != nil ? ar_error_copy_cf_error(updateError) : nullptr;
                        os_log_error(SteeringLog(),
                                     "could not hand the provider its accessories: %{public}@",
                                     (__bridge NSError*)cfError);
                        if (cfError != nullptr) {
                            CFRelease(cfError);
                        }
                      });
                });
        }
    }
}

void AccessorySteering::SetEnabled(bool enabled) {
    SteeringState& state = State();
    if (state.enabled.exchange(enabled, std::memory_order_acq_rel) == enabled) {
        return;
    }

    if (provider_ == nil) {
        os_log(SteeringLog(),
               "6DoF steering %{public}s, but no accessory tracking provider "
               "exists, so nothing will move",
               enabled ? "enabled" : "disabled");
        return;
    }

    if (@available(visionOS 27.0, *)) {
        if (!enabled) {
            // Clearing the handler is what stops ARKit producing anchors at all,
            // so an off switch costs nothing rather than costing a little.
            ar_accessory_tracking_provider_set_update_handler(provider_, SteeringQueue(), nil);
            PublishInactive();
            os_log(SteeringLog(), "6DoF steering disabled; anchor updates stopped");
            return;
        }

        SteeringState& s = State();
        s.left = HandSample{};
        s.right = HandSample{};
        s.referenceValid = false;
        s.filtered = 0.0;
        s.lastUpdateTime = 0.0;
        s.loggedFirstAngle = false;

        ar_accessory_tracking_provider_set_update_handler(
            provider_, SteeringQueue(),
            ^(ar_accessory_anchors_t added, ar_accessory_anchors_t updated,
              ar_accessory_anchors_t removed) {
              SharedAccessorySteering().IngestAnchors(added, updated, removed);
            });
        os_log(SteeringLog(), "6DoF steering enabled; watching for anchor updates");
    }
}

void AccessorySteering::SetSensitivity(float sensitivity) {
    State().sensitivity.store(std::clamp(sensitivity, 0.1f, 4.0f), std::memory_order_release);
}

void AccessorySteering::Recenter() {
    State().recenterRequested.store(true, std::memory_order_release);
    os_log(SteeringLog(), "steering recentre requested");
}

bool AccessorySteering::Axis(int* outStickX) const {
    const SteeringState& state = State();
    if (!state.enabled.load(std::memory_order_acquire) ||
        !state.active.load(std::memory_order_acquire)) {
        return false;
    }

    // Expiry, and the reason it is checked on this side: the update handler
    // announces every sample it takes, but it cannot announce the samples it
    // stops taking. A controller set down mid-race leaves the last angle sitting
    // in the atomic, and without this the kart would hold that turn forever.
    if (CACurrentMediaTime() - state.publishedAt.load(std::memory_order_acquire) > kMaxAxisAge) {
        return false;
    }

    if (outStickX != nullptr) {
        *outStickX = state.axis.load(std::memory_order_acquire);
    }
    return true;
}

AccessorySteering& SharedAccessorySteering() {
    static AccessorySteering steering;
    return steering;
}

} // namespace spaghettipad

// ------------------------------------------------------------------- bridge

void SpaghettiPad_AttachAccessoryTracking(void* arSession) {
    // The provider joined the session before it was run — see
    // WorldTracking::Start() — because ARKit permits one session and composing
    // it once is safer than re-running it under a live compositor. What is left
    // for this entry point is the half that could not happen that early: the
    // controllers themselves, which connect whenever a wearer switches them on.
    (void)arSession;
    spaghettipad::SharedAccessorySteering().StartWatchingAccessories();
}

void SpaghettiPad_SetMotionSteeringEnabled(int enabled) {
    spaghettipad::SharedAccessorySteering().SetEnabled(enabled != 0);
}

void SpaghettiPad_SetMotionSensitivity(float sensitivity) {
    spaghettipad::SharedAccessorySteering().SetSensitivity(sensitivity);
}

void SpaghettiPad_RecenterMotionSteering(void) {
    spaghettipad::SharedAccessorySteering().Recenter();
}

int SpaghettiPad_MotionSteeringAxis(int* outStickX) {
    return spaghettipad::SharedAccessorySteering().Axis(outStickX) ? 1 : 0;
}
