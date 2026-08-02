// The Compositor Services half of the visionOS shell.
//
// SwiftUI's CompositorLayer hands over a cp_layer_renderer_t and nothing else:
// no view, no CAMetalLayer, no run loop. Everything the headset shows inside an
// immersive space is drawn by the loop below, on its own thread, paced against
// the compositor's predicted frame timing.
//
// What it draws is the engine's latest finished frame, on a flat screen hanging
// in a room. The engine renders into a ring of textures owned by
// SpaghettiPadRenderSurface.mm; this file only shows them, and draws the room
// around them. Until the engine has produced its first frame — no game data,
// immersive space opened on its own — it draws the test pattern instead, so the
// space is never simply black and so the per-eye geometry stays checkable
// without game data.
//
// The frame lifecycle, per-view render passes, foveation and present around
// both are the same either way, which is why they live here and not in the
// engine bridge.
//
// Every drawable carries an ARKit device anchor (SpaghettiPadWorldTracking.h),
// without which a headset drops the frame outright. Setting it also changes what
// the compositor's own matrices mean: cp_view_get_transform becomes a view's
// place relative to the head rather than in the world, so everything with a
// fixed position in the room composes it with the pose behind that anchor.
//
// Neither picture is a hardcoded left/right image. The screen's corners, the
// room, and the pattern's reticle are points in space put through each view's
// own matrices, so the two eyes differ because the compositor's geometry says
// they differ. A picture that faked the difference could not tell a working
// stereo path from a broken one.

#import "SpaghettiPadBridge.h"
#import "SpaghettiPadWorldTracking.h"

#import <CompositorServices/CompositorServices.h>
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

#import <os/log.h>
#import <simd/simd.h>

#import <pthread.h>

#import <atomic>
#import <chrono>
#import <cmath>
#import <cstdint>
#import <mutex>
#import <thread>
#import <vector>

namespace {

using spaghettipad::DevicePose;

os_log_t CompositorLog() {
    static os_log_t log =
        os_log_create("com.subtlepath.spaghettipad", "compositor");
    return log;
}

// ------------------------------------------------------------------ pattern

// One axis-aligned rectangle, in a view's normalised space: (0,0) is the top
// left of that view's viewport and (1,1) the bottom right. Laid out to match
// PatternRect in the shader source below.
struct PatternRect {
    simd_float2 center;
    simd_float2 halfSize;
    simd_float4 color;
};

// setVertexBytes caps a single inline buffer at 4 KiB; at 32 bytes per rect the
// pattern has room to grow well past what it uses.
constexpr size_t kMaxPatternRects = 96;

// Where the reticle sits, in metres ahead of the wearer. Near enough that its
// per-eye disparity is obvious rather than a sub-pixel difference, far enough
// to remain a plausible thing to look at.
constexpr float kReticleDistanceMetres = 0.6f;

// One sweep of the liveness bar. Two captures taken more than a moment apart
// disagree about where the bar is, which is what separates a running render
// loop from one stalled frame left on screen.
constexpr uint64_t kSweepPeriodFrames = 180;

const char* const kPatternShaderSource = R"METAL(
#include <metal_stdlib>
using namespace metal;

struct PatternRect {
    float2 center;
    float2 half_size;
    float4 color;
};

struct Varyings {
    float4 position [[position]];
    float4 color;
};

vertex Varyings pattern_vertex(uint vertex_id [[vertex_id]],
                               uint instance_id [[instance_id]],
                               constant PatternRect* rects [[buffer(0)]],
                               constant float& depth [[buffer(1)]]) {
    const float2 corners[6] = {
        float2(-1.0, -1.0), float2(1.0, -1.0), float2(-1.0,  1.0),
        float2( 1.0, -1.0), float2(1.0,  1.0), float2(-1.0,  1.0)
    };
    PatternRect rect = rects[instance_id];
    float2 unit = rect.center + corners[vertex_id] * rect.half_size;

    Varyings out;
    // Normalised view space is y-down; clip space is y-up.
    out.position = float4(unit.x * 2.0 - 1.0, 1.0 - unit.y * 2.0, depth, 1.0);
    out.color = rect.color;
    return out;
}

fragment float4 pattern_fragment(Varyings in [[stage_in]]) {
    return in.color;
}
)METAL";

simd_float4 EyeColor(size_t viewIndex) {
    switch (viewIndex) {
        case 0:
            return simd_make_float4(1.00f, 0.52f, 0.06f, 1.0f); // left: amber
        case 1:
            return simd_make_float4(0.06f, 0.62f, 1.00f, 1.0f); // right: cyan
        default:
            return simd_make_float4(1.00f, 0.10f, 0.60f, 1.0f); // unexpected
    }
}

// Where one view puts a point, and how deep. Everything the pattern needs to
// know about that view's geometry, and the only place the compositor's own
// matrices are read.
struct Projected {
    simd_float2 position; // normalised view space
    float depth;          // clip-space z after the perspective divide
    bool valid;
};

// Everything a view puts in front of the wearer goes through this: the one
// place the compositor's own matrices are read, and the reason both pictures
// below differ between the eyes without being told to.
//
// cp_view_get_transform is documented as device-from-view, not world-from-view:
// where an eye sits relative to the head, not where it sits in the room. That
// distinction had no consequences while no device anchor was set, because device
// space was then the whole of the world. It has consequences now, and getting it
// wrong would leave the world attached to the wearer's face while the compositor
// reprojected against a pose that said otherwise.
simd_float4x4 ViewProjection(cp_drawable_t drawable, cp_view_t view,
                             size_t viewIndex, simd_float4x4 originFromDevice) {
    const simd_float4x4 projection = cp_drawable_compute_projection(
        drawable, cp_axis_direction_convention_right_up_back, viewIndex);
    const simd_float4x4 worldFromView =
        simd_mul(originFromDevice, cp_view_get_transform(view));
    return simd_mul(projection, simd_inverse(worldFromView));
}

// The four tangents bounding one view's frustum: left, right, up, down, as
// positive magnitudes measured from the view axis.
//
// Read back out of the compositor's own projection rather than from
// cp_view_get_tangents, which says what is wanted in one call and has been
// deprecated since visionOS 2.0 in favour of exactly this matrix. Nothing about
// the matrix's depth convention matters here — Mode B builds its own near and
// far from what the game asked for — so only the four terms describing the
// frustum's shape are read, and they invert exactly.
bool EyeTangents(cp_drawable_t drawable, size_t viewIndex, float tangents[4]) {
    const simd_float4x4 projection = cp_drawable_compute_projection(
        drawable, cp_axis_direction_convention_right_up_back, viewIndex);

    const float scaleX = projection.columns[0][0];
    const float offsetX = projection.columns[2][0];
    const float scaleY = projection.columns[1][1];
    const float offsetY = projection.columns[2][1];
    if (!(scaleX > 0.0f) || !(scaleY > 0.0f)) {
        return false;
    }

    tangents[0] = (1.0f - offsetX) / scaleX; // left
    tangents[1] = (1.0f + offsetX) / scaleX; // right
    tangents[2] = (1.0f + offsetY) / scaleY; // up
    tangents[3] = (1.0f - offsetY) / scaleY; // down

    for (size_t index = 0; index < 4; ++index) {
        if (!(tangents[index] > 0.0f) || !std::isfinite(tangents[index])) {
            return false;
        }
    }
    return true;
}

Projected ProjectPoint(simd_float4x4 viewProjection, simd_float3 point) {
    const simd_float4 clip =
        simd_mul(viewProjection, simd_make_float4(point.x, point.y, point.z, 1.0f));

    Projected result = {};
    if (!(clip.w > 0.0f)) {
        return result;
    }
    const simd_float3 ndc = clip.xyz / clip.w;
    result.position = simd_make_float2(ndc.x * 0.5f + 0.5f, 0.5f - ndc.y * 0.5f);
    result.depth = ndc.z;
    result.valid = true;
    return result;
}

// Builds the pattern for one view. Sizes are given in units of view width so
// the shapes stay square; `aspect` converts them for the vertical axis.
class PatternBuilder {
public:
    PatternBuilder(std::vector<PatternRect>& rects, float aspect)
        : rects_(rects), aspect_(aspect) {}

    void Add(simd_float2 center, float width, float height, simd_float4 color) {
        if (rects_.size() >= kMaxPatternRects) {
            return;
        }
        rects_.push_back({center,
                          simd_make_float2(width * 0.5f, height * 0.5f * aspect_),
                          color});
    }

    // A hollow rectangle drawn as four bars, so the pattern behind it shows
    // through the middle.
    void AddOutline(simd_float2 center, float size, float thickness,
                    simd_float4 color) {
        const float half = size * 0.5f;
        Add(simd_make_float2(center.x, center.y - half * aspect_), size, thickness,
            color);
        Add(simd_make_float2(center.x, center.y + half * aspect_), size, thickness,
            color);
        Add(simd_make_float2(center.x - half, center.y), thickness, size, color);
        Add(simd_make_float2(center.x + half, center.y), thickness, size, color);
    }

private:
    std::vector<PatternRect>& rects_;
    float aspect_;
};

void BuildPattern(std::vector<PatternRect>& rects, size_t viewIndex, float aspect,
                  Projected reticle, uint64_t frameIndex) {
    rects.clear();
    PatternBuilder pattern(rects, aspect);

    const simd_float4 eye = EyeColor(viewIndex);
    const simd_float4 grid = simd_make_float4(0.20f, 0.22f, 0.26f, 1.0f);
    const simd_float4 white = simd_make_float4(0.90f, 0.90f, 0.90f, 1.0f);

    // A grid, so distortion, foveation and resolution are all visible at a
    // glance rather than inferred.
    for (int column = 1; column < 8; ++column) {
        pattern.Add(simd_make_float2(column / 8.0f, 0.5f), 0.003f, 1.0f, grid);
    }
    for (int row = 1; row < 6; ++row) {
        pattern.Add(simd_make_float2(0.5f, row / 6.0f), 1.0f, 0.003f, grid);
    }

    // The border carries this view's identity: colour and, for a capture that
    // loses colour, a run of tick marks one longer per view.
    constexpr float kBorder = 0.02f;
    pattern.Add(simd_make_float2(0.5f, 0.0f), 1.0f, kBorder, eye);
    pattern.Add(simd_make_float2(0.5f, 1.0f), 1.0f, kBorder, eye);
    pattern.Add(simd_make_float2(0.0f, 0.5f), kBorder, 1.0f, eye);
    pattern.Add(simd_make_float2(1.0f, 0.5f), kBorder, 1.0f, eye);
    // Well inside the view, not tucked into a corner. These sat at 8% across and
    // 86% down until a headset was worn, and there they were invisible: a Vision
    // Pro renders a good deal more than it shows, and the corners of the drawable
    // fall outside what reaches the wearer's eye. The Simulator shows the whole
    // rendered view, so nothing about that was visible before.
    for (size_t tick = 0; tick <= viewIndex; ++tick) {
        pattern.Add(simd_make_float2(0.44f + 0.06f * tick, 0.68f), 0.03f, 0.03f,
                    eye);
    }

    // The liveness bar. Its position is the only thing in the pattern that
    // depends on how long the loop has been running.
    const float sweep =
        static_cast<float>(frameIndex % kSweepPeriodFrames) / kSweepPeriodFrames;
    pattern.Add(simd_make_float2(sweep, 0.5f), 0.012f, 1.0f, eye);

    // The reticle: one point in space, seen from this view. Its horizontal
    // offset between the two eyes is the disparity the compositor reports, not
    // a constant chosen here, so a stereo path that has collapsed to a single
    // eye shows up as two identical images.
    if (reticle.valid) {
        pattern.AddOutline(reticle.position, 0.14f, 0.006f, white);
        pattern.Add(reticle.position, 0.09f, 0.006f, white);
        pattern.Add(reticle.position, 0.006f, 0.09f, white);
    }
}

// ------------------------------------------------------------------- screen

// Where the engine's picture hangs, in metres, and how wide it is. Two metres is
// far enough that the eyes converge comfortably and near enough that 1.6 m —
// about 44 degrees of arc — reads as a large screen rather than a distant one.
// Whether it is comfortable for a whole race is a device measurement, not a
// number that can be settled here.
constexpr float kScreenDistanceMetres = 2.0f;
constexpr float kScreenWidthMetres = 1.6f;
constexpr float kScreenAspect = 16.0f / 9.0f;

const char* const kScreenShaderSource = R"METAL(
#include <metal_stdlib>
using namespace metal;

struct ScreenVaryings {
    float4 position [[position]];
    float2 uv;
};

vertex ScreenVaryings screen_vertex(uint vertex_id [[vertex_id]],
                                    constant float4x4& model_view_projection [[buffer(0)]],
                                    constant float2& half_extent [[buffer(1)]]) {
    const float2 corners[6] = {
        float2(-1.0,  1.0), float2( 1.0,  1.0), float2(-1.0, -1.0),
        float2( 1.0,  1.0), float2( 1.0, -1.0), float2(-1.0, -1.0)
    };
    float2 corner = corners[vertex_id];
    // The screen's own space: a rectangle in the XY plane, facing +Z. Where that
    // plane sits in the room is the model half of the matrix.
    float4 local = float4(corner.x * half_extent.x, corner.y * half_extent.y, 0.0, 1.0);

    ScreenVaryings out;
    out.position = model_view_projection * local;
    // Metal texture space is y-down, so the top of the screen is v = 0.
    out.uv = float2(corner.x * 0.5 + 0.5, 0.5 - corner.y * 0.5);
    return out;
}

fragment float4 screen_fragment(ScreenVaryings in [[stage_in]],
                                texture2d<float> image [[texture(0)]],
                                sampler image_sampler [[sampler(0)]]) {
    // Opaque on purpose: this is a fully immersive space, so anything asking to
    // be blended would be blended with nothing.
    return float4(image.sample(image_sampler, in.uv).rgb, 1.0);
}
)METAL";

// -------------------------------------------------------------------- Mode B

// Where the compositor's reprojection is told Mode B's picture is, in metres.
// The same distance Mode A's screen hangs at, because that is a distance this
// headset has demonstrably reprojected in comfort for whole sessions. It is a
// single plane standing in for a world of real depths, so distant scenery will
// swim slightly under head motion until the engine's own depth buffer is
// carried across; what it buys is that the picture exists at all.
constexpr float kEyeContentDistanceMetres = 2.0f;

// Mode B's present, which is deliberately the least interesting shader in this
// file. The engine has already drawn this eye through this eye's own frustum, so
// the picture is already in the view's normalised coordinates: there is no model
// matrix, no view matrix, no projection, and nothing here to get wrong. Any
// geometry at this stage would be a second opinion about where things are, and
// the whole point of Mode B is that the engine now holds the only one.
const char* const kEyeShaderSource = R"METAL(
#include <metal_stdlib>
using namespace metal;

struct EyeVaryings {
    float4 position [[position]];
    float2 uv;
};

vertex EyeVaryings eye_vertex(uint vertex_id [[vertex_id]],
                              constant float& depth [[buffer(0)]]) {
    const float2 corners[6] = {
        float2(-1.0,  1.0), float2( 1.0,  1.0), float2(-1.0, -1.0),
        float2( 1.0,  1.0), float2( 1.0, -1.0), float2(-1.0, -1.0)
    };
    float2 corner = corners[vertex_id];

    EyeVaryings out;
    // The depth is real and it is written, and both halves were learned on a
    // wearer's face. This quad first sat at z = 0.0 with depth writes off, which
    // leaves every pixel of the view at the far plane — and the compositor's
    // reprojection treats a far-plane pixel as nothing there and shows black,
    // exactly as it showed the old far-plane clip-space sky as a void while the
    // depth-writing floor grid stayed visible. Moving the vertex to z = 0.5 with
    // writes still off changed nothing, which is how the write half was proved.
    // The value passed in is this view's own projection of a point 2 m ahead —
    // the distance the compositor has demonstrably reprojected in comfort for
    // every Mode A session — because the value is what reprojection holds the
    // picture still against, not merely what survives clipping.
    out.position = float4(corner, depth, 1.0);
    // Metal texture space is y-down, so the top of the image is v = 0.
    out.uv = float2(corner.x * 0.5 + 0.5, 0.5 - corner.y * 0.5);
    return out;
}

fragment float4 eye_fragment(EyeVaryings in [[stage_in]],
                             texture2d<float> image [[texture(0)]],
                             sampler image_sampler [[sampler(0)]]) {
    // Opaque on purpose: this is a fully immersive space, so anything asking to
    // be blended would be blended with nothing.
    return float4(image.sample(image_sampler, in.uv).rgb, 1.0);
}
)METAL";

// Where the screen hangs, decided once from the pose the wearer had when the
// space opened: kScreenDistanceMetres straight ahead of them, at their own
// height, upright, facing back at them. Pitch and roll are dropped, so a screen
// placed while glancing down at the floor is still level.
//
// It is then left there. That is the whole of the difference a device anchor
// makes to this app — the picture stops following the wearer's face — and it is
// also what makes the anchor checkable on a Simulator that renders one eye:
// turn the head, and a world-locked screen moves in the view while a head-locked
// one does not.
simd_float4x4 PlaceScreen(simd_float4x4 originFromDevice) {
    const simd_float3 head = spaghettipad::TransformTranslation(originFromDevice);
    const simd_float3 forward = spaghettipad::HorizontalForward(originFromDevice);
    const simd_float3 up = simd_make_float3(0.0f, 1.0f, 0.0f);
    // The screen's +Z faces the wearer, which is the direction they are looking
    // back along.
    const simd_float3 normal = -forward;
    const simd_float3 right = simd_normalize(simd_cross(up, normal));
    const simd_float3 center = head + forward * kScreenDistanceMetres;

    simd_float4x4 worldFromScreen;
    worldFromScreen.columns[0] = simd_make_float4(right.x, right.y, right.z, 0.0f);
    worldFromScreen.columns[1] = simd_make_float4(up.x, up.y, up.z, 0.0f);
    worldFromScreen.columns[2] = simd_make_float4(normal.x, normal.y, normal.z, 0.0f);
    worldFromScreen.columns[3] = simd_make_float4(center.x, center.y, center.z, 1.0f);
    return worldFromScreen;
}

// The frame the game's camera is nailed to.
//
// Mode B declares that the wearer's head *is* the game's camera. That is a
// statement about one particular head pose — the one they had when the world was
// placed — and every later pose is then a movement away from it, which is where
// the six degrees of freedom come from: lean in and the camera leans in, because
// the camera is a thing they are wearing rather than a thing the game is driving.
//
// Levelled the same way the screen is, and for the same reason: a world placed
// while glancing down at the floor should not tilt the horizon for the rest of
// the session. Nothing about pitch or roll is kept, only where the wearer was
// and which way they were facing.
simd_float4x4 PlaceRecentre(simd_float4x4 originFromDevice) {
    const simd_float3 head = spaghettipad::TransformTranslation(originFromDevice);
    const simd_float3 forward = spaghettipad::HorizontalForward(originFromDevice);
    const simd_float3 up = simd_make_float3(0.0f, 1.0f, 0.0f);
    // Right-up-back, matching both Compositor Services' convention and Mario
    // Kart 64's camera space: the game looks down -z and so does this.
    const simd_float3 back = -forward;
    const simd_float3 right = simd_normalize(simd_cross(up, back));

    simd_float4x4 worldFromRecentre;
    worldFromRecentre.columns[0] = simd_make_float4(right.x, right.y, right.z, 0.0f);
    worldFromRecentre.columns[1] = simd_make_float4(up.x, up.y, up.z, 0.0f);
    worldFromRecentre.columns[2] = simd_make_float4(back.x, back.y, back.z, 0.0f);
    worldFromRecentre.columns[3] = simd_make_float4(head.x, head.y, head.z, 1.0f);
    return worldFromRecentre;
}

// -------------------------------------------------------------- environment

// A fully immersive space replaces the room the wearer is standing in. Leaving
// what replaces it black is not neutral: with nothing but a screen in view there
// is nothing for head motion to register against, and a picture that moves with
// no fixed surroundings is the shape of the problem that makes people ill. So
// the space gets a floor and a graded sky — dim enough that the game is still
// the brightest thing in it, and world-locked, which is the point.

// Where the floor goes, which took two measurements to get right and is still
// not a measurement of the floor itself.
//
// The first version drew it at the world origin, assuming visionOS puts that
// origin on the ground. The Simulator reported the head at (0.00, 0.00, 0.00),
// so there the origin is the head and a floor at the origin would be at eye
// level; the rule became "a nominal 1.5 m below the head". Then an Apple Vision
// Pro reported the head **0.95 m above** the origin, which makes that rule bury
// the floor half a metre underground.
//
// So neither constant is right on its own, and the two platforms disagree about
// what the origin means. The rule below asks the pose rather than assuming: a
// head well above the origin is standing or sitting over a ground-referenced
// origin, and the origin is the floor. A head at the origin means the origin is
// the head, and the floor is a nominal distance below it. Both branches log
// which one they took and the height they took it from.
//
// Measuring the real floor needs plane detection, which requires world-sensing
// authorization and returns nothing on the Simulator, so it is not attempted.
constexpr float kNominalEyeHeightMetres = 1.5f;

// Above this, the origin is treated as ground-referenced. Well clear of both
// numbers seen so far — 0.00 m on the Simulator, 0.95 m on a headset.
constexpr float kGroundOriginThresholdMetres = 0.5f;

// Half the floor's extent. Large enough that its edge is never the nearest thing
// to look at, and the fade below reaches zero well before it.
constexpr float kFloorHalfExtentMetres = 24.0f;

// Half the sky box's extent. Outside the floor, so the two never intersect, and
// far enough that it reads as distance rather than as a wall.
constexpr float kSkyRadiusMetres = 40.0f;

const char* const kEnvironmentShaderSource = R"METAL(
#include <metal_stdlib>
using namespace metal;

struct SkyVaryings {
    float4 position [[position]];
    float3 direction;
};

struct FloorVaryings {
    float4 position [[position]];
    float2 ground;  // metres from the room's centre, on the floor plane
};

// A large box around the wearer, drawn as ordinary world geometry.
//
// This was a full-viewport triangle emitting clip coordinates directly, with
// its ray reconstructed by unprojecting. On an Apple Vision Pro that produced
// nothing at all — grid lines on a void — while the Simulator drew it correctly,
// and two attempts at the reconstruction changed nothing. The floor, which is
// world geometry put through the same view projection, rendered perfectly
// throughout. So the sky is now the same kind of object as the floor: whatever
// the headset dislikes about a hand-built clip-space triangle, it cannot dislike
// this, because it is already drawing one.
//
// Far enough away to sit outside the floor and to read as sky rather than as a
// wall. No cull mode is set anywhere in this file, so the inward-facing half of
// the box rasterizes without needing a winding order chosen for it.
vertex SkyVaryings sky_vertex(uint vertex_id [[vertex_id]],
                              constant float4x4& clip_from_world [[buffer(0)]],
                              constant float3& centre [[buffer(1)]],
                              constant float& radius [[buffer(2)]]) {
    // Two triangles per face, six faces, in the unit cube around the origin.
    const float3 corners[36] = {
        float3(-1,-1,-1), float3( 1,-1,-1), float3( 1, 1,-1),
        float3(-1,-1,-1), float3( 1, 1,-1), float3(-1, 1,-1),
        float3(-1,-1, 1), float3( 1, 1, 1), float3( 1,-1, 1),
        float3(-1,-1, 1), float3(-1, 1, 1), float3( 1, 1, 1),
        float3(-1,-1,-1), float3(-1, 1,-1), float3(-1, 1, 1),
        float3(-1,-1,-1), float3(-1, 1, 1), float3(-1,-1, 1),
        float3( 1,-1,-1), float3( 1,-1, 1), float3( 1, 1, 1),
        float3( 1,-1,-1), float3( 1, 1, 1), float3( 1, 1,-1),
        float3(-1, 1,-1), float3( 1, 1,-1), float3( 1, 1, 1),
        float3(-1, 1,-1), float3( 1, 1, 1), float3(-1, 1, 1),
        float3(-1,-1,-1), float3( 1,-1, 1), float3( 1,-1,-1),
        float3(-1,-1,-1), float3(-1,-1, 1), float3( 1,-1, 1)
    };
    float3 world = centre + corners[vertex_id] * radius;

    SkyVaryings out;
    out.position = clip_from_world * float4(world, 1.0);
    out.direction = world - centre;
    return out;
}

fragment float4 sky_fragment(SkyVaryings in [[stage_in]]) {
    float3 direction = normalize(in.direction);

    // Linear, not display, values: the drawable is bgra8Unorm_srgb and encodes
    // on write, so these are roughly a third of what they look like written out.
    //
    // Chosen against a headset rather than a screenshot. The first set was read
    // off a Simulator capture and was far too bright; the correction that
    // followed went too far the other way and a wearer reported no sky at all,
    // which is a useless thing for a room to be. A Simulator capture is a poor
    // instrument for this and the person wearing it is the right one.
    const float3 zenith  = float3(0.0090, 0.0110, 0.0200);
    const float3 horizon = float3(0.0320, 0.0400, 0.0640);
    const float3 nadir   = float3(0.0130, 0.0160, 0.0270);

    // Two smooth ramps away from the horizon, so the brightest band is at eye
    // level and nothing has an edge in it.
    float above = smoothstep(0.0, 0.55, direction.y);
    float below = smoothstep(0.0, 0.40, -direction.y);
    float3 colour = mix(mix(horizon, zenith, above), nadir, below);
    return float4(colour, 1.0);
}

vertex FloorVaryings floor_vertex(uint vertex_id [[vertex_id]],
                                  constant float4x4& clip_from_world [[buffer(0)]],
                                  constant float3& centre [[buffer(1)]],
                                  constant float& half_extent [[buffer(2)]]) {
    const float2 corners[6] = {
        float2(-1.0, -1.0), float2( 1.0, -1.0), float2(-1.0,  1.0),
        float2( 1.0, -1.0), float2( 1.0,  1.0), float2(-1.0,  1.0)
    };
    float2 corner = corners[vertex_id] * half_extent;
    float4 world = float4(centre.x + corner.x, centre.y, centre.z + corner.y, 1.0);

    FloorVaryings out;
    out.position = clip_from_world * world;
    out.ground = corner;
    return out;
}

// One set of grid lines, antialiased by how fast the coordinate is changing
// across this pixel rather than by a fixed width — otherwise the lines alias
// into noise a few metres out, which is worse than no lines at all.
float grid(float2 ground, float spacing, float width) {
    float2 cell = ground / spacing;
    float2 distance = abs(fract(cell - 0.5) - 0.5) / fwidth(cell);
    return 1.0 - smoothstep(0.0, width, min(distance.x, distance.y));
}

fragment float4 floor_fragment(FloorVaryings in [[stage_in]]) {
    // A metre grid, with every fifth line brighter so distance is readable.
    float fine = grid(in.ground, 1.0, 1.2) * 0.35;
    float coarse = grid(in.ground, 5.0, 1.4) * 0.65;
    float line = max(fine, coarse);

    // Faded out long before the floor's own edge, so the room has no visible
    // boundary to notice.
    float fade = 1.0 - smoothstep(6.0, 15.0, length(in.ground));
    float alpha = line * fade;
    if (alpha < 0.004) {
        // Nothing to show here, and no depth worth writing for it either.
        discard_fragment();
    }
    return float4(float3(0.140, 0.175, 0.260) * alpha, alpha);
}
)METAL";

// ---------------------------------------------------------------- compositor

class Compositor {
public:
    bool Start(cp_layer_renderer_t layerRenderer);
    void Stop();
    // True while the render thread is live. False either after Stop() or after
    // the thread noticed its renderer invalidated and exited on its own — the
    // Digital Crown path, which no SwiftUI code is told about.
    bool Running() const {
        return thread_.joinable() && !finished_.load(std::memory_order_acquire);
    }

private:
    bool BuildPipeline();
    void RenderLoop();
    void RenderFrame();
    DevicePose AnchorDrawable(cp_drawable_t drawable);
    void EncodeViews(cp_drawable_t drawable, id<MTLCommandBuffer> commandBuffer,
                     id<MTLTexture> engineFrame,
                     id<MTLTexture> const stereoFrames[SPAGHETTIPAD_EYE_COUNT],
                     const DevicePose& pose);
    void EncodeEnvironment(id<MTLRenderCommandEncoder> encoder,
                           simd_float4x4 viewProjection);
    void EncodeScreen(id<MTLRenderCommandEncoder> encoder,
                      simd_float4x4 viewProjection, id<MTLTexture> engineFrame);
    void EncodePattern(id<MTLRenderCommandEncoder> encoder,
                       simd_float4x4 viewProjection, simd_float4x4 originFromDevice,
                       size_t viewIndex, const MTLViewport& viewport);
    void EncodeEye(id<MTLRenderCommandEncoder> encoder, cp_drawable_t drawable,
                   size_t viewIndex, id<MTLTexture> eyeFrame);
    void PublishViews(cp_drawable_t drawable, const DevicePose& pose);
    void LogTopology(cp_drawable_t drawable);
    void LogStereo(cp_drawable_t drawable, const DevicePose& pose);

    cp_layer_renderer_t layerRenderer_ = nil;
    id<MTLDevice> device_ = nil;
    id<MTLCommandQueue> queue_ = nil;
    id<MTLRenderPipelineState> patternPipeline_ = nil;
    id<MTLRenderPipelineState> screenPipeline_ = nil;
    id<MTLRenderPipelineState> skyPipeline_ = nil;
    id<MTLRenderPipelineState> floorPipeline_ = nil;
    id<MTLRenderPipelineState> eyePipeline_ = nil;
    id<MTLSamplerState> screenSampler_ = nil;
    id<MTLDepthStencilState> depthState_ = nil;
    // Mode B's picture fills its view, so it needs no depth *test* — but it must
    // write depth, and the reasoning that said otherwise inverted the facts. Not
    // writing does not mean "saying nothing": it leaves every pixel at the far
    // plane the pass cleared to, and the compositor's reprojection treats a
    // far-plane pixel as nothing there and shows black. That is what made Mode B
    // present black through every correct measurement of the pipeline behind it,
    // and it is the same mechanism that once showed the far-plane clip-space sky
    // as a void while the depth-writing floor grid beside it stayed visible.
    id<MTLDepthStencilState> eyeDepthState_ = nil;

    std::thread thread_;
    std::atomic<bool> stopping_{false};
    std::atomic<bool> finished_{false};
    std::chrono::steady_clock::time_point lastRateSample_{};
    uint32_t displayRate_ = 0;
    uint64_t frameIndex_ = 0;
    uint64_t engineFrames_ = 0;
    uint64_t engineGeneration_ = 0;
    uint64_t anchoredDrawables_ = 0;
    uint64_t unanchoredDrawables_ = 0;

    // Where the room is. Fixed once the first tracked pose arrives, and left
    // alone afterwards: a screen that re-placed itself would be following the
    // wearer again, slowly.
    simd_float4x4 worldFromScreen_ = matrix_identity_float4x4;
    // Where the game's camera is, for Mode B. Placed at the same moment and from
    // the same pose as the screen, so switching modes mid-session does not move
    // the world.
    simd_float4x4 worldFromRecentre_ = matrix_identity_float4x4;
    simd_float3 roomCentre_ =
        simd_make_float3(0.0f, -kNominalEyeHeightMetres, 0.0f);
    bool roomPlaced_ = false;

    // The last pose any drawable was anchored to, kept for the periodic
    // measurement below rather than for rendering: every frame renders from the
    // pose it queried itself.
    DevicePose lastPose_;
    ar_device_anchor_tracking_state_t trackingState_ =
        ar_device_anchor_tracking_state_untracked;
    bool loggedTracking_ = false;
    bool loggedRateMapMismatch_ = false;
    bool loggedTopology_ = false;
    bool loggedStereo_ = false;
    bool loggedFirstEngineFrame_ = false;
    bool loggedFirstStereoFrame_ = false;
    bool loggedStereoRefused_ = false;
    uint64_t stereoFrames_ = 0;

    // Which branch each view actually took, counted at the encoder rather than
    // where the frame was fetched. The black-frame investigation spent an
    // evening trusting `Mode B: drawing the game in stereo`, which is logged
    // once, on the first stereo frame, and says nothing about the thousands
    // after it. These are logged with the periodic counters so a session's log
    // states what was encoded, all session long.
    uint64_t eyeEncodes_ = 0;
    uint64_t screenEncodes_ = 0;
    uint64_t patternEncodes_ = 0;
    uint64_t viewEncodeSkips_ = 0;

    // Command buffers that came back from the GPU with an error. Nothing on the
    // CPU side of this file would otherwise notice one: every frame would encode,
    // present and commit exactly as if it had worked, and the wearer would see
    // black. The first few are logged in full from the completion handler, which
    // runs off the render thread, so the counter is atomic.
    std::atomic<uint64_t> commandBufferErrors_{0};

    // Whether the views last published to the engine were usable for Mode B,
    // kept to log transitions and their reason. The surface has been seen
    // flipping stereo -> flat -> stereo within a session and nothing recorded
    // whether that was the wearer's toggle or this report collapsing on its own.
    int publishedViewsValid_ = -1; // -1 never published, else 0/1
    std::vector<PatternRect> rects_;
};

bool Compositor::BuildPipeline() {
    device_ = cp_layer_renderer_get_device(layerRenderer_);
    if (device_ == nil) {
        os_log_error(CompositorLog(), "the layer renderer has no Metal device");
        return false;
    }

    // The engine's textures are sampled by this device's command buffers, so
    // the two must be the same object, not merely two handles to one GPU.
    // visionOS has a single GPU and this has always held; it is checked rather
    // than assumed because a mismatch would show as corruption, not an error.
    id<MTLDevice> engineDevice =
        (__bridge id<MTLDevice>)SpaghettiPad_RenderMetalDevice();
    if (engineDevice != device_) {
        os_log_error(CompositorLog(),
                     "the engine renders on %{public}@ but the compositor draws "
                     "on %{public}@; its frames cannot be shown",
                     engineDevice.name, device_.name);
        return false;
    }

    queue_ = [device_ newCommandQueue];
    if (queue_ == nil) {
        os_log_error(CompositorLog(), "could not create a Metal command queue");
        return false;
    }

    cp_layer_renderer_configuration_t configuration =
        cp_layer_renderer_get_configuration(layerRenderer_);

    // Compiled from source rather than a metallib: these are a handful of
    // trivial functions, and this keeps the visionOS lane free of a Metal build
    // rule that CMake's Xcode generator would have to be taught.
    auto buildProgram = [&](const char* source, NSString* vertex, NSString* fragment,
                            NSString* label,
                            bool blend = false) -> id<MTLRenderPipelineState> {
        NSError* error = nil;
        id<MTLLibrary> library = [device_ newLibraryWithSource:@(source)
                                                       options:nil
                                                         error:&error];
        if (library == nil) {
            os_log_error(CompositorLog(),
                         "%{public}@ shaders did not compile: %{public}@", label,
                         error.localizedDescription);
            return nil;
        }

        MTLRenderPipelineDescriptor* descriptor =
            [[MTLRenderPipelineDescriptor alloc] init];
        descriptor.label = label;
        descriptor.vertexFunction = [library newFunctionWithName:vertex];
        descriptor.fragmentFunction = [library newFunctionWithName:fragment];
        descriptor.colorAttachments[0].pixelFormat =
            cp_layer_renderer_configuration_get_color_format(configuration);
        descriptor.depthAttachmentPixelFormat =
            cp_layer_renderer_configuration_get_depth_format(configuration);
        if (blend) {
            // Premultiplied: the floor's fragment shader already scales its
            // colour by the coverage it reports, so the grid lines fade out
            // without darkening the sky behind them on the way.
            descriptor.colorAttachments[0].blendingEnabled = YES;
            descriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorOne;
            descriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
            descriptor.colorAttachments[0].destinationRGBBlendFactor =
                MTLBlendFactorOneMinusSourceAlpha;
            descriptor.colorAttachments[0].destinationAlphaBlendFactor =
                MTLBlendFactorOneMinusSourceAlpha;
        }

        id<MTLRenderPipelineState> pipeline =
            [device_ newRenderPipelineStateWithDescriptor:descriptor error:&error];
        if (pipeline == nil) {
            os_log_error(CompositorLog(), "%{public}@ pipeline failed: %{public}@",
                         label, error.localizedDescription);
        }
        return pipeline;
    };

    patternPipeline_ = buildProgram(kPatternShaderSource, @"pattern_vertex",
                                    @"pattern_fragment", @"SpaghettiPad test pattern");
    screenPipeline_ = buildProgram(kScreenShaderSource, @"screen_vertex",
                                   @"screen_fragment", @"SpaghettiPad screen");
    skyPipeline_ = buildProgram(kEnvironmentShaderSource, @"sky_vertex",
                                @"sky_fragment", @"SpaghettiPad sky");
    floorPipeline_ = buildProgram(kEnvironmentShaderSource, @"floor_vertex",
                                  @"floor_fragment", @"SpaghettiPad floor", true);
    eyePipeline_ = buildProgram(kEyeShaderSource, @"eye_vertex", @"eye_fragment",
                                @"SpaghettiPad eye");
    if (patternPipeline_ == nil || screenPipeline_ == nil || skyPipeline_ == nil ||
        floorPipeline_ == nil || eyePipeline_ == nil) {
        return false;
    }

    // The engine renders 1080p and the screen occupies rather less than that
    // many pixels per eye, so this is a minification: linear filtering is what
    // keeps the picture from crawling as the head moves.
    MTLSamplerDescriptor* sampler = [[MTLSamplerDescriptor alloc] init];
    sampler.minFilter = MTLSamplerMinMagFilterLinear;
    sampler.magFilter = MTLSamplerMinMagFilterLinear;
    sampler.sAddressMode = MTLSamplerAddressModeClampToEdge;
    sampler.tAddressMode = MTLSamplerAddressModeClampToEdge;
    screenSampler_ = [device_ newSamplerStateWithDescriptor:sampler];

    // visionOS is reverse-Z: 1 is the near plane, 0 the far one, which is why
    // the pass below clears depth to 0 rather than 1.
    //
    // GreaterEqual rather than Greater: every rect of the pattern sits on one
    // plane, so a strict test rejects each one after the first and the earliest
    // draw wins instead of the latest. That is backwards for a flat overlay —
    // it hid the reticle behind the sweep bar — and equal-depth ties should go
    // to whatever was drawn last.
    MTLDepthStencilDescriptor* depth = [[MTLDepthStencilDescriptor alloc] init];
    depth.depthCompareFunction = MTLCompareFunctionGreaterEqual;
    depth.depthWriteEnabled = YES;
    depthState_ = [device_ newDepthStencilStateWithDescriptor:depth];

    MTLDepthStencilDescriptor* eyeDepth = [[MTLDepthStencilDescriptor alloc] init];
    eyeDepth.depthCompareFunction = MTLCompareFunctionAlways;
    // See the declaration: a depth that is not written is a depth left at the
    // far plane, and the compositor shows a far-plane pixel as black.
    eyeDepth.depthWriteEnabled = YES;
    eyeDepthState_ = [device_ newDepthStencilStateWithDescriptor:eyeDepth];

    os_log(CompositorLog(),
           "compositor ready on %{public}@: layout %u, colour format %lu, "
           "depth format %lu, foveation %{public}s",
           device_.name,
           (unsigned)cp_layer_renderer_configuration_get_layout(configuration),
           (unsigned long)cp_layer_renderer_configuration_get_color_format(
               configuration),
           (unsigned long)cp_layer_renderer_configuration_get_depth_format(
               configuration),
           cp_layer_renderer_configuration_get_foveation_enabled(configuration)
               ? "on"
               : "off");
    return true;
}

// Records what the compositor actually handed over the first time it hands over
// anything. The Simulator and a real headset disagree here — most of all about
// how many views exist — and that difference is exactly what must not be
// guessed at from the other side of a build.
void Compositor::LogTopology(cp_drawable_t drawable) {
    const size_t views = cp_drawable_get_view_count(drawable);
    os_log(CompositorLog(),
           "first drawable: %zu view(s), %zu texture(s), %zu rasterization rate "
           "map(s)",
           views, cp_drawable_get_texture_count(drawable),
           cp_drawable_get_rasterization_rate_map_count(drawable));

    for (size_t index = 0; index < views; ++index) {
        cp_view_t view = cp_drawable_get_view(drawable, index);
        cp_view_texture_map_t map = cp_view_get_view_texture_map(view);
        const MTLViewport viewport = cp_view_texture_map_get_viewport(map);
        const simd_float4x4 transform = cp_view_get_transform(view);
        os_log(CompositorLog(),
               "  view %zu: texture %zu slice %zu viewport %.0fx%.0f at "
               "(%.0f,%.0f), eye offset (%.4f, %.4f, %.4f) m",
               index, cp_view_texture_map_get_texture_index(map),
               cp_view_texture_map_get_slice_index(map), viewport.width,
               viewport.height, viewport.originX, viewport.originY,
               transform.columns[3].x, transform.columns[3].y,
               transform.columns[3].z);

        // The three numbers that are easy to conflate and expensive to: the
        // viewport above is in the rate map's screen space, the drawable is
        // allocated at its physical size, and only the second is a resolution
        // anything should be rendered at. They are logged together because the
        // one time they were not, the engine rendered at the first.
        id<MTLTexture> colour = cp_drawable_get_color_texture(
            drawable, cp_view_texture_map_get_texture_index(map));
        const size_t rateMapCount =
            cp_drawable_get_rasterization_rate_map_count(drawable);
        id<MTLRasterizationRateMap> rateMap =
            rateMapCount > 0 ? cp_drawable_get_rasterization_rate_map(
                                   drawable, index < rateMapCount ? index : rateMapCount - 1)
                             : nil;
        if (rateMap != nil) {
            const MTLSize screen = rateMap.screenSize;
            const MTLSize physical = [rateMap physicalSizeForLayer:0];
            os_log(CompositorLog(),
                   "  view %zu: colour texture %lux%lu, rate map screen "
                   "%lux%lu -> physical %lux%lu; the engine renders the last of these",
                   index, (unsigned long)colour.width, (unsigned long)colour.height,
                   (unsigned long)screen.width, (unsigned long)screen.height,
                   (unsigned long)physical.width, (unsigned long)physical.height);
        } else {
            os_log(CompositorLog(),
                   "  view %zu: colour texture %lux%lu, no rate map, so the "
                   "viewport is already physical",
                   index, (unsigned long)colour.width, (unsigned long)colour.height);
        }
    }

    if (views < 2) {
        os_log(CompositorLog(),
               "this drawable has fewer than two views, so nothing rendered here "
               "is evidence of stereo");
    }
}

// The stereo measurement, taken once the room has somewhere to be.
//
// Phase 4's gate is a *measured* separation, so this reports numbers rather than
// a verdict: how far apart the compositor puts the two eyes, and how far apart
// the two eyes therefore put the centre of the screen. The second is the one
// that matters, because an eye offset that never reached the projection would
// still print correctly here while both eyes drew the same picture.
//
// On a Simulator that reports one view, both are refused rather than reported as
// zero: a separation of zero and no second eye to separate from are different
// statements, and only one of them is a measurement.
void Compositor::LogStereo(cp_drawable_t drawable, const DevicePose& pose) {
    const size_t views = cp_drawable_get_view_count(drawable);
    if (views < 2) {
        os_log(CompositorLog(),
               "stereo separation is not measurable here: this drawable reports "
               "%zu view(s)",
               views);
        return;
    }

    const simd_float3 left =
        spaghettipad::TransformTranslation(cp_view_get_transform(cp_drawable_get_view(drawable, 0)));
    const simd_float3 right =
        spaghettipad::TransformTranslation(cp_view_get_transform(cp_drawable_get_view(drawable, 1)));
    const float separation = simd_distance(left, right);

    const simd_float3 screenCentre =
        spaghettipad::TransformTranslation(worldFromScreen_);
    const Projected leftPoint = ProjectPoint(
        ViewProjection(drawable, cp_drawable_get_view(drawable, 0), 0,
                       pose.originFromDevice),
        screenCentre);
    const Projected rightPoint = ProjectPoint(
        ViewProjection(drawable, cp_drawable_get_view(drawable, 1), 1,
                       pose.originFromDevice),
        screenCentre);

    os_log(CompositorLog(),
           "measured stereo: eyes %.1f mm apart, screen centre at %.4f and %.4f "
           "across each view (disparity %.4f of a view width)",
           (double)(separation * 1000.0f), (double)leftPoint.position.x,
           (double)rightPoint.position.x,
           (double)(leftPoint.position.x - rightPoint.position.x));

    if (!leftPoint.valid || !rightPoint.valid) {
        os_log_error(CompositorLog(),
                     "the screen centre is behind at least one eye, so the "
                     "disparity above is not a measurement");
    }
}

// The room: a graded sky at the far plane and a floor under it, both put through
// this view's own matrices. Drawn before anything else, so everything with a
// real position in the room lands on top of it.
void Compositor::EncodeEnvironment(id<MTLRenderCommandEncoder> encoder,
                                   simd_float4x4 viewProjection) {
    float skyRadius = kSkyRadiusMetres;
    [encoder setRenderPipelineState:skyPipeline_];
    [encoder setVertexBytes:&viewProjection length:sizeof(viewProjection) atIndex:0];
    [encoder setVertexBytes:&roomCentre_ length:sizeof(roomCentre_) atIndex:1];
    [encoder setVertexBytes:&skyRadius length:sizeof(skyRadius) atIndex:2];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:36];

    float halfExtent = kFloorHalfExtentMetres;
    [encoder setRenderPipelineState:floorPipeline_];
    [encoder setVertexBytes:&viewProjection length:sizeof(viewProjection) atIndex:0];
    [encoder setVertexBytes:&roomCentre_ length:sizeof(roomCentre_) atIndex:1];
    [encoder setVertexBytes:&halfExtent length:sizeof(halfExtent) atIndex:2];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
}

// One screen-sized quad hanging where the room put it, showing the engine's
// latest finished frame. Its corners are world points put through this view's
// own matrices, so the left and right eyes see it from where they actually are —
// which is the whole of the stereo claim this phase can make, and none of it is
// checkable on a Simulator that reports one view.
void Compositor::EncodeScreen(id<MTLRenderCommandEncoder> encoder,
                              simd_float4x4 viewProjection,
                              id<MTLTexture> engineFrame) {
    simd_float4x4 modelViewProjection = simd_mul(viewProjection, worldFromScreen_);
    const float halfWidth = kScreenWidthMetres * 0.5f;
    simd_float2 halfExtent =
        simd_make_float2(halfWidth, halfWidth / kScreenAspect);

    [encoder setRenderPipelineState:screenPipeline_];
    [encoder setVertexBytes:&modelViewProjection
                     length:sizeof(modelViewProjection)
                    atIndex:0];
    [encoder setVertexBytes:&halfExtent length:sizeof(halfExtent) atIndex:1];
    [encoder setFragmentTexture:engineFrame atIndex:0];
    [encoder setFragmentSamplerState:screenSampler_ atIndex:0];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
}

void Compositor::EncodePattern(id<MTLRenderCommandEncoder> encoder,
                               simd_float4x4 viewProjection,
                               simd_float4x4 originFromDevice, size_t viewIndex,
                               const MTLViewport& viewport) {
    // The reticle stays a fixed distance in front of the wearer's head rather
    // than at a fixed point in the room, which is what it was before a device
    // anchor existed and what it has to stay: it is there to show that the two
    // eyes disagree about where a nearby point is, and a point the wearer has
    // walked away from cannot show that.
    const simd_float4 aheadOfTheHead =
        simd_make_float4(0.0f, 0.0f, -kReticleDistanceMetres, 1.0f);
    const simd_float4 inTheRoom = simd_mul(originFromDevice, aheadOfTheHead);
    const Projected reticle =
        ProjectPoint(viewProjection, simd_make_float3(inTheRoom.x, inTheRoom.y,
                                                      inTheRoom.z));
    BuildPattern(rects_, viewIndex,
                 static_cast<float>(viewport.width / viewport.height), reticle,
                 frameIndex_);
    if (rects_.empty()) {
        return;
    }

    // The fallback is strictly inside the clip volume for the same reason the
    // eye quad's depth is: a primitive emitted at exactly z = 0 — the far plane
    // under reverse-Z — rasterizes on the Simulator and not on the headset, so a
    // pattern drawn before the reticle projects would be invisible exactly when
    // it is most needed.
    float depth = reticle.valid ? reticle.depth : 0.5f;
    [encoder setRenderPipelineState:patternPipeline_];
    [encoder setVertexBytes:rects_.data()
                     length:rects_.size() * sizeof(PatternRect)
                    atIndex:0];
    [encoder setVertexBytes:&depth length:sizeof(depth) atIndex:1];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle
                vertexStart:0
                vertexCount:6
              instanceCount:rects_.size()];
}

// Mode B's present: one eye's finished picture, across the whole of that eye's
// view. No geometry, no matrices, no room — the engine drew this through this
// eye's own frustum, so it is already where it belongs.
//
// The one thing computed here is the quad's depth, and it is computed rather
// than chosen: kEyeContentDistanceMetres pushed through this view's own
// projection, so the value written is whatever *this* drawable's reverse-Z
// mapping says 2 m is. A constant picked by hand would be a claim about the
// compositor's near plane, which is not this file's to make.
void Compositor::EncodeEye(id<MTLRenderCommandEncoder> encoder,
                           cp_drawable_t drawable, size_t viewIndex,
                           id<MTLTexture> eyeFrame) {
    const simd_float4x4 projection = cp_drawable_compute_projection(
        drawable, cp_axis_direction_convention_right_up_back, viewIndex);
    const simd_float4 clip = simd_mul(
        projection,
        simd_make_float4(0.0f, 0.0f, -kEyeContentDistanceMetres, 1.0f));
    float depth = 0.5f;
    if (clip.w > 0.0f) {
        const float projected = clip.z / clip.w;
        if (std::isfinite(projected) && projected > 0.0f && projected <= 1.0f) {
            depth = projected;
        }
    }

    [encoder setRenderPipelineState:eyePipeline_];
    [encoder setDepthStencilState:eyeDepthState_];
    [encoder setVertexBytes:&depth length:sizeof(depth) atIndex:0];
    [encoder setFragmentTexture:eyeFrame atIndex:0];
    [encoder setFragmentSamplerState:screenSampler_ atIndex:0];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
}

// Tells the engine where the eyes are for this frame, which is the whole of what
// Mode B needs from the compositor and the only thing it cannot work out itself.
//
// Two conversions happen here and both matter. The transform Compositor Services
// hands over is device-from-view — where an eye sits relative to the head — so
// it composes with the device anchor to reach the world, and then with the
// recentre pose to reach the frame the game's camera is nailed to. And it is
// inverted before it is sent, because the engine needs eye-from-world rather
// than world-from-eye: it is transforming points into the eye, not placing the
// eye in the world.
void Compositor::PublishViews(cp_drawable_t drawable, const DevicePose& pose) {
    SpaghettiPadEyeView views[SPAGHETTIPAD_EYE_COUNT] = {};
    uint32_t eyeWidth = 0;
    uint32_t eyeHeight = 0;

    const size_t viewCount = cp_drawable_get_view_count(drawable);
    const size_t reportable =
        viewCount < SPAGHETTIPAD_EYE_COUNT ? viewCount : SPAGHETTIPAD_EYE_COUNT;

    if (pose.valid && roomPlaced_) {
        const simd_float4x4 recentreFromOrigin = simd_inverse(worldFromRecentre_);

        for (size_t index = 0; index < reportable; ++index) {
            cp_view_t view = cp_drawable_get_view(drawable, index);

            if (!EyeTangents(drawable, index, views[index].tangents)) {
                continue;
            }

            const simd_float4x4 recentreFromEye = simd_mul(
                recentreFromOrigin,
                simd_mul(pose.originFromDevice, cp_view_get_transform(view)));
            const simd_float4x4 eyeFromRecentre = simd_inverse(recentreFromEye);
            memcpy(views[index].eyeFromRecentre, &eyeFromRecentre,
                   sizeof(views[index].eyeFromRecentre));
            views[index].valid = 1;

            cp_view_texture_map_t map = cp_view_get_view_texture_map(view);
            const MTLViewport viewport = cp_view_texture_map_get_viewport(map);
            uint32_t width = 0;
            uint32_t height = 0;
            if (viewport.width > 0.0 && viewport.height > 0.0) {
                width = (uint32_t)llround(viewport.width);
                height = (uint32_t)llround(viewport.height);
            }

            // The viewport is the right number for the passes above and the
            // wrong one to send here, and the difference is foveation. With a
            // rasterization rate map attached, a viewport is in the map's
            // *screen* space — the uncompressed grid, which an Apple Vision Pro
            // reports as 4493 x 3604 — and the map compresses it on the way into
            // the drawable, so the GPU only ever rasterizes the smaller physical
            // extent. The engine's texture has no rate map. Sizing it from the
            // screen space therefore renders the whole logical grid at full
            // density: sixteen megapixels an eye, thirty-two a frame, against
            // Mode A's two, which is not a resolution a headset has ever asked
            // anyone for. What the engine wants is what the map compresses to.
            const size_t rateMapCount =
                cp_drawable_get_rasterization_rate_map_count(drawable);
            if (rateMapCount > 0) {
                id<MTLRasterizationRateMap> rateMap =
                    cp_drawable_get_rasterization_rate_map(
                        drawable, index < rateMapCount ? index : rateMapCount - 1);
                if (rateMap != nil) {
                    const MTLSize physical = [rateMap physicalSizeForLayer:0];
                    if (physical.width > 0 && physical.height > 0) {
                        width = (uint32_t)physical.width;
                        height = (uint32_t)physical.height;
                    }
                }
            }

            if (width > 0 && height > 0) {
                eyeWidth = width;
                eyeHeight = height;
            }
        }
    }

    // A drawable with fewer views than eyes is the Simulator, which renders the
    // left one only. Passing the count through rather than padding is what stops
    // Mode B running against a frustum for an eye that does not exist — and a
    // one-eyed "stereo" frame is exactly the result this project refuses to
    // treat as evidence of stereo.
    SpaghettiPad_RenderPublishViews(views, (uint32_t)viewCount, eyeWidth, eyeHeight);

    // The engine's Mode B follows this report, so a report that collapses
    // mid-session flips the surface stereo -> flat under a wearer who touched
    // nothing. Logged on transition, with the reason, because a session has been
    // seen flipping and nothing recorded whether that was the toggle or this.
    if (viewCount >= SPAGHETTIPAD_EYE_COUNT) {
        const int valid =
            (views[0].valid && views[SPAGHETTIPAD_EYE_COUNT - 1].valid) ? 1 : 0;
        if (valid != publishedViewsValid_) {
            const int previous = publishedViewsValid_;
            publishedViewsValid_ = valid;
            if (valid) {
                if (previous == 0) {
                    os_log(CompositorLog(),
                           "per-eye views are valid again at compositor frame "
                           "%llu; Mode B may resume",
                           (unsigned long long)frameIndex_);
                }
            } else {
                os_log(CompositorLog(),
                       "per-eye views went invalid at compositor frame %llu "
                       "(pose %{public}s, room %{public}s); the engine will fall "
                       "back to Mode A until they return",
                       (unsigned long long)frameIndex_,
                       pose.valid ? "valid" : "invalid",
                       roomPlaced_ ? "placed" : "not placed");
            }
        }
    }

    if (viewCount < SPAGHETTIPAD_EYE_COUNT && !loggedStereoRefused_) {
        loggedStereoRefused_ = true;
        os_log(CompositorLog(),
               "Mode B is unavailable here: this drawable reports %zu view(s), so "
               "there is no second eye to render one",
               viewCount);
    }
}

// The per-view render passes. This is the part that has to be right for every
// layout the compositor might hand back, and it is deliberately unchanged from
// the phase that only had a test pattern to draw: what the engine added is one
// branch inside the encoder, not a different frame.
void Compositor::EncodeViews(cp_drawable_t drawable,
                             id<MTLCommandBuffer> commandBuffer,
                             id<MTLTexture> engineFrame,
                             id<MTLTexture> const stereoFrames[SPAGHETTIPAD_EYE_COUNT],
                             const DevicePose& pose) {
    const size_t viewCount = cp_drawable_get_view_count(drawable);
    const size_t rateMapCount =
        cp_drawable_get_rasterization_rate_map_count(drawable);

    // Under the shared layout every view lands in one texture, so only the
    // first pass over a given slice may clear it. Under dedicated and layered
    // layouts each view has its own destination and every pass clears.
    std::vector<uint64_t> cleared;

    // Fewer rate maps than views means the maps are layers of one map, selected
    // by a render_target_array_index this renderer does not emit — so every view
    // after the first would rasterize through the first view's foveation. That
    // is not a subtle error: on an Apple Vision Pro it warped the right eye
    // while leaving the left eye clean, and it is invisible on a Simulator that
    // reports one view and no foveation at all. The configuration now asks for a
    // layout that cannot produce it; this says so if one ever does.
    if (rateMapCount > 0 && rateMapCount < viewCount && !loggedRateMapMismatch_) {
        loggedRateMapMismatch_ = true;
        os_log_error(CompositorLog(),
                     "%zu view(s) but only %zu rasterization rate map(s): every "
                     "view after the first is being rasterized through another "
                     "eye's foveation",
                     viewCount, rateMapCount);
    }

    for (size_t index = 0; index < viewCount; ++index) {
        cp_view_t view = cp_drawable_get_view(drawable, index);
        cp_view_texture_map_t map = cp_view_get_view_texture_map(view);
        const size_t textureIndex = cp_view_texture_map_get_texture_index(map);
        const size_t slice = cp_view_texture_map_get_slice_index(map);
        const MTLViewport viewport = cp_view_texture_map_get_viewport(map);
        if (viewport.width <= 0.0 || viewport.height <= 0.0) {
            ++viewEncodeSkips_;
            continue;
        }

        const uint64_t destination = (textureIndex << 32) | slice;
        bool first = true;
        for (uint64_t seen : cleared) {
            if (seen == destination) {
                first = false;
                break;
            }
        }
        if (first) {
            cleared.push_back(destination);
        }
        const MTLLoadAction load = first ? MTLLoadActionClear : MTLLoadActionLoad;

        MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
        pass.colorAttachments[0].texture =
            cp_drawable_get_color_texture(drawable, textureIndex);
        pass.colorAttachments[0].slice = slice;
        pass.colorAttachments[0].loadAction = load;
        pass.colorAttachments[0].storeAction = MTLStoreActionStore;
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0.02, 0.02, 0.03, 1.0);

        id<MTLTexture> depthTexture =
            cp_drawable_get_depth_texture(drawable, textureIndex);
        if (depthTexture != nil) {
            pass.depthAttachment.texture = depthTexture;
            pass.depthAttachment.slice = slice;
            pass.depthAttachment.loadAction = load;
            // The compositor reprojects the presented frame using this depth
            // buffer, so it has to survive the pass.
            pass.depthAttachment.storeAction = MTLStoreActionStore;
            pass.depthAttachment.clearDepth = 0.0;
        }
        if (rateMapCount > 0) {
            pass.rasterizationRateMap = cp_drawable_get_rasterization_rate_map(
                drawable, index < rateMapCount ? index : rateMapCount - 1);
        }

        id<MTLRenderCommandEncoder> encoder =
            [commandBuffer renderCommandEncoderWithDescriptor:pass];
        if (encoder == nil) {
            ++viewEncodeSkips_;
            continue;
        }
        id<MTLTexture> eyeFrame =
            index < SPAGHETTIPAD_EYE_COUNT ? stereoFrames[index] : nil;

        encoder.label = eyeFrame != nil    ? @"SpaghettiPad eye"
                        : engineFrame != nil ? @"SpaghettiPad screen"
                                             : @"SpaghettiPad test pattern";
        [encoder setViewport:viewport];
        [encoder setDepthStencilState:depthState_];

        const simd_float4x4 viewProjection =
            ViewProjection(drawable, view, index, pose.originFromDevice);

        if (eyeFrame != nil) {
            // Mode B. No room, and no screen to hang anything on: the engine has
            // drawn this eye's whole view, sky and ground included, because in
            // this mode the game's own world is the environment. Anything drawn
            // around it here would be a second world competing with the first.
            ++eyeEncodes_;
            EncodeEye(encoder, drawable, index, eyeFrame);
        } else if (engineFrame != nil) {
            // The room, then the screen in it. The test pattern gets neither: it
            // is a full-view overlay measured in the view's own coordinates, and
            // putting a room behind it would change the picture the Phase 2
            // evidence was captured from.
            ++screenEncodes_;
            EncodeEnvironment(encoder, viewProjection);
            EncodeScreen(encoder, viewProjection, engineFrame);
        } else {
            ++patternEncodes_;
            EncodePattern(encoder, viewProjection, pose.originFromDevice, index,
                          viewport);
        }
        [encoder endEncoding];
    }
}

// Gives one drawable the pose it was drawn from, and decides where the room is
// the first time that pose is trustworthy.
//
// The time queried is this drawable's own predicted presentation time, not the
// frame's trackable-anchor time. Those are different clocks for different jobs
// and CompositorServices says which is which: trackable anchor time is for
// registering content against real-world objects, and the note under it reads
// "For predicting ARKit device anchor use presentation time".
DevicePose Compositor::AnchorDrawable(cp_drawable_t drawable) {
    cp_frame_timing_t timing = cp_drawable_get_frame_timing(drawable);
    const CFTimeInterval presentation =
        cp_time_to_cf_time_interval(cp_frame_timing_get_presentation_time(timing));

    const DevicePose pose = spaghettipad::SharedWorldTracking().PoseAtTime(presentation);
    if (!pose.valid) {
        ++unanchoredDrawables_;
        // Left unset deliberately. A headset drops a drawable with no anchor,
        // which is the correct outcome for a frame drawn from a pose nothing
        // vouches for; presenting it against a stale one would show the wearer a
        // world that had come loose.
        return pose;
    }

    cp_drawable_set_device_anchor(drawable, pose.anchor);
    ++anchoredDrawables_;
    lastPose_ = pose;

    if (pose.state != trackingState_ || !loggedTracking_) {
        trackingState_ = pose.state;
        loggedTracking_ = true;
        const simd_float3 head =
            spaghettipad::TransformTranslation(pose.originFromDevice);
        os_log(CompositorLog(),
               "device anchor %{public}s at compositor frame %llu: head at "
               "(%.2f, %.2f, %.2f) m in world space",
               spaghettipad::TrackingStateName(pose.state),
               (unsigned long long)frameIndex_, (double)head.x, (double)head.y,
               (double)head.z);
    }

    // Placed from a fully tracked pose only: an orientation-only pose has no
    // position to put a room around, and a room placed from one would be in the
    // wrong part of the world for the rest of the session.
    if (!roomPlaced_ && pose.state == ar_device_anchor_tracking_state_tracked) {
        worldFromScreen_ = PlaceScreen(pose.originFromDevice);
        // Placed from the same pose and at the same moment as the screen, so
        // switching between the modes mid-session does not move the world.
        worldFromRecentre_ = PlaceRecentre(pose.originFromDevice);
        const simd_float3 head =
            spaghettipad::TransformTranslation(pose.originFromDevice);
        const bool groundOrigin = head.y > kGroundOriginThresholdMetres;
        const float floorHeight =
            groundOrigin ? 0.0f : head.y - kNominalEyeHeightMetres;
        roomCentre_ = simd_make_float3(head.x, floorHeight, head.z);
        roomPlaced_ = true;

        const simd_float3 centre =
            spaghettipad::TransformTranslation(worldFromScreen_);
        os_log(CompositorLog(),
               "room placed: a %.2f m screen centred (%.2f, %.2f, %.2f) m, %.2f m "
               "ahead of the wearer",
               (double)kScreenWidthMetres, (double)centre.x, (double)centre.y,
               (double)centre.z, (double)kScreenDistanceMetres);
        os_log(CompositorLog(),
               "floor drawn at y = %.2f m, %.2f m below the head, because the head "
               "is %.2f m above the world origin and that origin is therefore "
               "%{public}s; nothing here measures the real floor",
               (double)floorHeight, (double)(head.y - floorHeight), (double)head.y,
               groundOrigin ? "treated as the ground"
                            : "where the head started");
    }
    return pose;
}

void Compositor::RenderFrame() {
    cp_frame_t frame = cp_layer_renderer_query_next_frame(layerRenderer_);
    if (frame == nullptr) {
        return;
    }

    // Anything that does not depend on the wearer's pose belongs here: the
    // compositor times this phase to decide how early to wake the next frame.
    cp_frame_start_update(frame);
    ++frameIndex_;
    cp_frame_end_update(frame);

    cp_frame_timing_t timing = cp_frame_predict_timing(frame);
    if (timing == nullptr) {
        return;
    }
    cp_time_wait_until(cp_frame_timing_get_optimal_input_time(timing));

    cp_drawable_array_t drawables = cp_frame_query_drawables(frame);
    const size_t drawableCount =
        drawables == nullptr ? 0 : cp_drawable_array_get_count(drawables);
    if (drawableCount == 0) {
        // A cancelled frame; the frame itself is no longer valid to touch.
        return;
    }

    cp_frame_start_submission(frame);

    // The latest frame the engine has finished, borrowed for exactly as long as
    // the GPU needs it. Null until the engine has produced one, which is what
    // keeps the test pattern reachable with no game data.
    uint64_t generation = 0;

    // Mode B first. A stereo frame answers for both eyes or for neither: the
    // surface publishes one only once every eye of it has been written, so a
    // second eye that is missing here means the frame is flat, not that it is
    // half drawn.
    id<MTLTexture> stereoFrames[SPAGHETTIPAD_EYE_COUNT] = { nil };
    bool haveStereo = true;
    for (size_t eye = 0; eye < SPAGHETTIPAD_EYE_COUNT && haveStereo; ++eye) {
        stereoFrames[eye] = (__bridge id<MTLTexture>)SpaghettiPad_RenderLatestStereoFrame(
            (int)eye, &generation);
        haveStereo = stereoFrames[eye] != nil;
    }
    if (!haveStereo) {
        for (size_t eye = 0; eye < SPAGHETTIPAD_EYE_COUNT; ++eye) {
            if (stereoFrames[eye] != nil) {
                // Borrowed and not used. Handing it straight back is not
                // optional: an unreleased borrow pins a ring slot for good and
                // the engine runs out of buffers a few frames later.
                SpaghettiPad_RenderReleaseFrame((__bridge void*)stereoFrames[eye], nullptr);
                stereoFrames[eye] = nil;
            }
        }
    }

    id<MTLTexture> engineFrame = nil;
    if (haveStereo) {
        ++stereoFrames_;
        ++engineFrames_;
        engineGeneration_ = generation;
        if (!loggedFirstStereoFrame_) {
            loggedFirstStereoFrame_ = true;
            os_log(CompositorLog(),
                   "Mode B: drawing the game in stereo, %lu x %lu per eye "
                   "(engine frame %llu, compositor frame %llu)",
                   (unsigned long)stereoFrames[0].width,
                   (unsigned long)stereoFrames[0].height,
                   (unsigned long long)generation,
                   (unsigned long long)frameIndex_);
        }
    } else {
        engineFrame = (__bridge id<MTLTexture>)SpaghettiPad_RenderLatestFrame(&generation);
    }

    if (engineFrame != nil) {
        ++engineFrames_;
        engineGeneration_ = generation;
        if (!loggedFirstEngineFrame_) {
            loggedFirstEngineFrame_ = true;
            os_log(CompositorLog(),
                   "showing the engine on a %.2f m screen %.2f m ahead, from a "
                   "%lu x %lu frame (engine frame %llu, compositor frame %llu)",
                   (double)kScreenWidthMetres, (double)kScreenDistanceMetres,
                   (unsigned long)engineFrame.width,
                   (unsigned long)engineFrame.height,
                   (unsigned long long)generation,
                   (unsigned long long)frameIndex_);
        }
    }

    id<MTLCommandBuffer> commandBuffer = [queue_ commandBuffer];
    commandBuffer.label = @"SpaghettiPad frame";

    // A command buffer that faults on the GPU still encodes, presents and
    // commits without a single CPU-side symptom; the wearer just sees black.
    // Ruled in or out by measurement rather than assumed absent.
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> completed) {
        if (completed.error == nil) {
            return;
        }
        const uint64_t count =
            commandBufferErrors_.fetch_add(1, std::memory_order_relaxed) + 1;
        if (count <= 3) {
            os_log_error(CompositorLog(),
                         "a frame's command buffer failed on the GPU: %{public}@",
                         completed.error.localizedDescription);
        }
    }];

    for (size_t index = 0; index < drawableCount; ++index) {
        cp_drawable_t drawable = cp_drawable_array_get_drawable(drawables, index);
        if (drawable == nullptr) {
            continue;
        }
        if (!loggedTopology_) {
            loggedTopology_ = true;
            LogTopology(drawable);
        }

        // Before the views are encoded, because it is the pose they are encoded
        // from, and before the present, because the compositor reprojects this
        // frame against it.
        const DevicePose pose = AnchorDrawable(drawable);
        if (roomPlaced_ && !loggedStereo_) {
            loggedStereo_ = true;
            LogStereo(drawable, pose);
        }

        // What the engine will render its *next* frames from. Published from the
        // same pose the views below are encoded with, so the engine's picture and
        // the compositor's reprojection of it are talking about the same head.
        PublishViews(drawable, pose);

        EncodeViews(drawable, commandBuffer, engineFrame, stereoFrames, pose);
        cp_drawable_encode_present(drawable, commandBuffer);
    }

    // Handed back before the commit, because that is when a completion handler
    // may still be attached. The engine cannot reuse these textures until then.
    if (engineFrame != nil) {
        SpaghettiPad_RenderReleaseFrame((__bridge void*)engineFrame,
                                        (__bridge void*)commandBuffer);
    }
    for (size_t eye = 0; eye < SPAGHETTIPAD_EYE_COUNT; ++eye) {
        if (stereoFrames[eye] != nil) {
            SpaghettiPad_RenderReleaseFrame((__bridge void*)stereoFrames[eye],
                                            (__bridge void*)commandBuffer);
        }
    }

    [commandBuffer commit];
    cp_frame_end_submission(frame);

    // Measured over the interval below rather than assumed: the Simulator
    // presents at 60 Hz and a headset at 90 or more, and the engine derives its
    // own interpolation rate from this number.
    if (frameIndex_ % 600 == 1 && frameIndex_ > 1) {
        const auto now = std::chrono::steady_clock::now();
        const double seconds =
            std::chrono::duration<double>(now - lastRateSample_).count();
        if (seconds > 0.0) {
            displayRate_ = (uint32_t)llround(600.0 / seconds);
            SpaghettiPad_RenderSetDisplayRate(displayRate_);
        }
        lastRateSample_ = now;
    } else if (frameIndex_ == 1) {
        lastRateSample_ = std::chrono::steady_clock::now();
    }

    if (frameIndex_ % 600 == 1) {
        // Four separate counts, because they are four separate claims. The
        // compositor's own rate says nothing about whether the engine is
        // keeping up, a compositor happily re-presenting one stale frame would
        // look identical on the first two numbers alone, and a drawable that
        // never got an anchor is one a headset would have thrown away.
        os_log(CompositorLog(),
               "compositor is live: %llu frames presented at %u Hz, %llu of them "
               "showing the engine (%llu in stereo), which has finished %llu; "
               "%llu drawables anchored, %llu not",
               (unsigned long long)frameIndex_, displayRate_,
               (unsigned long long)engineFrames_,
               (unsigned long long)stereoFrames_,
               (unsigned long long)engineGeneration_,
               (unsigned long long)anchoredDrawables_,
               (unsigned long long)unanchoredDrawables_);

        // What was actually encoded, per view, which the counters above cannot
        // say: a session that reads "in stereo" at the fetch can still have
        // encoded something else, and this line is the difference between
        // knowing which branch ran and trusting a first-frame log line about it.
        os_log(CompositorLog(),
               "view encodes so far: %llu eye (Mode B), %llu screen, %llu "
               "pattern, %llu skipped; %llu command buffer(s) failed on the GPU",
               (unsigned long long)eyeEncodes_,
               (unsigned long long)screenEncodes_,
               (unsigned long long)patternEncodes_,
               (unsigned long long)viewEncodeSkips_,
               (unsigned long long)commandBufferErrors_.load(
                   std::memory_order_relaxed));

        // Where the wearer is, and where the screen is *from where they are*.
        // The second number is the whole of the world-locking claim in a form
        // that can be read rather than looked at: a screen fixed in the room
        // changes its offset from a head that moves, and a head-locked one
        // reports the same offset forever. It starts at (0, 0, -2).
        if (roomPlaced_) {
            const simd_float3 head =
                spaghettipad::TransformTranslation(lastPose_.originFromDevice);
            const simd_float4 screenInDeviceSpace = simd_mul(
                simd_inverse(lastPose_.originFromDevice),
                simd_make_float4(worldFromScreen_.columns[3].x,
                                 worldFromScreen_.columns[3].y,
                                 worldFromScreen_.columns[3].z, 1.0f));
            os_log(CompositorLog(),
                   "the wearer's head is at (%.2f, %.2f, %.2f) m and the screen "
                   "is (%.2f, %.2f, %.2f) m from it",
                   (double)head.x, (double)head.y, (double)head.z,
                   (double)screenInDeviceSpace.x, (double)screenInDeviceSpace.y,
                   (double)screenInDeviceSpace.z);
        }
    }
}

void Compositor::RenderLoop() {
    pthread_setname_np("spaghettipad.compositor");

    // Started here rather than at launch: this is the only thread that queries
    // it, ARKit's query is documented thread-unsafe, and nothing before the
    // immersive space opens has any use for a head pose. Started before the
    // pipeline so the provider has the whole of that compilation to converge —
    // world tracking does not answer immediately.
    if (!spaghettipad::SharedWorldTracking().Start()) {
        os_log_error(CompositorLog(),
                     "no world tracking, so no drawable will carry a device "
                     "anchor and a headset will present nothing; the Simulator "
                     "will still show a head-locked picture");
    }

    if (!BuildPipeline()) {
        os_log_error(CompositorLog(),
                     "compositor thread exiting before its first frame");
        return;
    }

    // This loop is the only thing that ever consumes an engine frame, so its
    // lifetime is exactly the answer to "is anything watching?" — which is what
    // the game loop idles on while the immersive space is closed.
    SpaghettiPad_RenderSetLive(1);

    while (!stopping_.load(std::memory_order_relaxed)) {
        switch (cp_layer_renderer_get_state(layerRenderer_)) {
            case cp_layer_renderer_state_paused:
                // The immersive space is open but not visible. Blocks until it
                // comes back or is torn down, so this is not a spin.
                cp_layer_renderer_wait_until_running(layerRenderer_);
                break;
            case cp_layer_renderer_state_running:
                RenderFrame();
                break;
            case cp_layer_renderer_state_invalidated:
                os_log(CompositorLog(),
                       "layer renderer invalidated after %llu frames",
                       (unsigned long long)frameIndex_);
                SpaghettiPad_RenderSetLive(0);
                return;
        }
    }
    SpaghettiPad_RenderSetLive(0);
    os_log(CompositorLog(), "compositor stopped after %llu frames",
           (unsigned long long)frameIndex_);
}

bool Compositor::Start(cp_layer_renderer_t layerRenderer) {
    if (thread_.joinable()) {
        if (!finished_.load(std::memory_order_acquire)) {
            os_log_error(CompositorLog(), "a compositor is already running");
            return false;
        }
        // The previous layer was torn down without a matching stop. The system
        // can close an immersive space on its own, so the thread that noticed
        // its renderer go invalid is reaped here rather than leaking a
        // never-joined thread that would also block the next open.
        thread_.join();
    }
    layerRenderer_ = layerRenderer;
    stopping_.store(false, std::memory_order_relaxed);
    finished_.store(false, std::memory_order_release);
    frameIndex_ = 0;
    displayRate_ = 0;
    engineFrames_ = 0;
    engineGeneration_ = 0;
    anchoredDrawables_ = 0;
    unanchoredDrawables_ = 0;
    // The room is placed again on every open. The wearer may have walked into
    // another room since the last one, and a screen left where it was would be
    // behind them — which is the one way a world-locked screen can be worse than
    // a head-locked one.
    roomPlaced_ = false;
    lastPose_ = DevicePose();
    // Until a tracked pose says otherwise, the room sits where it sat before
    // any of this existed: two metres along the origin's own -Z. With no device
    // anchor that is the head-locked picture Phase 3 shipped, so a compositor
    // that never gets a pose degrades to what worked rather than to a screen
    // edge-on at the wearer's nose.
    worldFromScreen_ = PlaceScreen(matrix_identity_float4x4);
    roomCentre_ = simd_make_float3(0.0f, -kNominalEyeHeightMetres, 0.0f);
    trackingState_ = ar_device_anchor_tracking_state_untracked;
    loggedTracking_ = false;
    loggedTopology_ = false;
    loggedStereo_ = false;
    loggedFirstEngineFrame_ = false;
    loggedFirstStereoFrame_ = false;
    loggedStereoRefused_ = false;
    loggedRateMapMismatch_ = false;
    stereoFrames_ = 0;
    eyeEncodes_ = 0;
    screenEncodes_ = 0;
    patternEncodes_ = 0;
    viewEncodeSkips_ = 0;
    commandBufferErrors_.store(0, std::memory_order_relaxed);
    publishedViewsValid_ = -1;
    rects_.reserve(kMaxPatternRects);
    thread_ = std::thread([this] {
        RenderLoop();
        finished_.store(true, std::memory_order_release);
    });
    return true;
}

void Compositor::Stop() {
    if (!thread_.joinable()) {
        return;
    }
    stopping_.store(true, std::memory_order_relaxed);
    // A stop requested while the loop is inside wait_until_running or
    // wait_until only lands once that call returns; both are bounded by the
    // compositor tearing the layer down, which is what closing the immersive
    // space does.
    thread_.join();
    layerRenderer_ = nil;
    patternPipeline_ = nil;
    screenPipeline_ = nil;
    skyPipeline_ = nil;
    floorPipeline_ = nil;
    eyePipeline_ = nil;
    screenSampler_ = nil;
    depthState_ = nil;
    eyeDepthState_ = nil;
    queue_ = nil;
    device_ = nil;
}

std::mutex gCompositorMutex;
Compositor gCompositor;

} // namespace

// ------------------------------------------------------------------- bridge

int SpaghettiPad_StartCompositor(void* layerRenderer) {
    if (layerRenderer == nullptr) {
        os_log_error(CompositorLog(), "start called without a layer renderer");
        return 0;
    }
    std::lock_guard<std::mutex> lock(gCompositorMutex);
    return gCompositor.Start((__bridge cp_layer_renderer_t)layerRenderer) ? 1 : 0;
}

void SpaghettiPad_StopCompositor(void) {
    std::lock_guard<std::mutex> lock(gCompositorMutex);
    gCompositor.Stop();
}

int SpaghettiPad_CompositorRunning(void) {
    std::lock_guard<std::mutex> lock(gCompositorMutex);
    return gCompositor.Running() ? 1 : 0;
}
