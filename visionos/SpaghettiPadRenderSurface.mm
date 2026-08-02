// The surface the engine renders into, and the handover to the compositor.
//
// On every other Apple platform the engine's Fast3D Metal backend asks SDL for
// the window's CAMetalLayer and calls -nextDrawable once per frame. visionOS has
// no SDL window — SDL2's UIKit video driver is written against UIScreen, which
// is API_UNAVAILABLE(visionos), so SDL_VIDEO is off — and no CAMetalLayer, since
// Compositor Services owns the display. This file is what stands in for that
// layer: a small ring of textures, one acquired per engine frame, handed to the
// compositor when the GPU has finished with it.
//
// Two threads meet here and neither may block the other for long: the engine
// thread runs the game loop at its own pace, and the compositor thread runs at
// the headset's. The ring is what keeps them independent — the compositor always
// shows the latest finished frame rather than waiting for the next one, and the
// engine never draws into a texture the compositor is still reading.
//
// Ordering across the two Metal queues is by completion, not by hope: a texture
// is published only from its command buffer's completion handler, so everything
// written into it is visible before anything is told it exists.
//
// ------------------------------------------------------------------- Mode B
//
// A frame is one texture in Mode A and one per eye in Mode B, and the difference
// runs through everything below. A ring slot therefore holds a whole frame rather
// than a texture: the engine fills its eyes one at a time, and the slot becomes
// visible to the compositor only once every eye of it has been written. Half a
// stereo frame is not a frame — showing it would put one eye a frame ahead of the
// other, which is the one artefact a headset cannot forgive.

#import "SpaghettiPadBridge.h"

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

#import <os/log.h>

#import <atomic>
#import <chrono>
#import <condition_variable>
#import <cstddef>
#import <cstdint>
#import <cstring>
#import <mutex>

namespace {

os_log_t SurfaceLog() {
    static os_log_t log =
        os_log_create("com.subtlepath.spaghettipad", "surface");
    return log;
}

// Three: one being drawn, one published, one the compositor may still be
// reading. Two would make the engine wait for the compositor on every frame.
constexpr size_t kRingDepth = 3;

// Both eyes of a stereo frame, or the single picture of a flat one. The array in
// every slot is sized for stereo and only its first entry is used in Mode A,
// which costs nothing until Mode B allocates.
constexpr size_t kEyeCount = SPAGHETTIPAD_EYE_COUNT;

// Mode A's flat frame. The engine renders 16:9 and the compositor shows it on a
// screen roughly 1.6 m wide two metres away — about 44 degrees of arc. At the
// Vision Pro's angular resolution that is on the order of 1,600 pixels across,
// so 1080p is the first standard size that does not throw detail away, and going
// higher would cost fill rate the engine has better uses for.
constexpr uint32_t kFlatWidth = 1920;
constexpr uint32_t kFlatHeight = 1080;

// Mode B has no size of its own to choose: it renders one eye's viewport, and
// the compositor is the only thing that knows how big that is. These are what
// the surface reports until it has been told, and they exist so that a question
// asked before the first drawable has an answer rather than a zero.
constexpr uint32_t kFallbackEyeWidth = 1920;
constexpr uint32_t kFallbackEyeHeight = 1824;

// Metres per game unit: how big Mario Kart 64's world is when a real person is
// standing in it.
//
// Nothing in the ROM says. The number below comes from the karts — about 25
// units across a kart that ought to read as roughly 1.4 m of go-kart — and it is
// therefore a starting point for someone wearing the headset to argue with,
// not a measurement. It is the single control over whether the world feels like
// a race track or a tabletop, and it is deliberately here in the shell rather
// than compiled into the engine so that changing it is not a rebuild of Fast3D.
constexpr float kDefaultMetresPerGameUnit = 0.055f;

struct Slot {
    id<MTLTexture> texture[kEyeCount] = { nil };   // what the engine renders into
    id<MTLTexture> srgbView[kEyeCount] = { nil };  // the same pixels, for the compositor
    bool engineBusy[kEyeCount] = { false };        // acquired, GPU not finished
    unsigned writtenEyes = 0;                      // eyes the GPU has finished
    unsigned compositorUses = 0;                   // borrows in flight

    // How many eyes *this frame* has, fixed when the slot was reserved.
    //
    // Not read from the ring, deliberately. The ring can be allocated for stereo
    // while a particular frame is flat — Mode B declines a frame whenever it
    // cannot get a slot in time, and the engine then draws that one frame the
    // flat way. Asking the ring how many eyes to wait for would leave that frame
    // waiting forever for a second eye nothing was going to draw, and the
    // compositor would sit on the last stereo frame while the game ran on.
    unsigned eyes = 1;
};

// One per process, and deliberately never destroyed: a command buffer completion
// handler can outlive the immersive space that scheduled it, and an engine
// thread that is idling still holds a texture. Nothing here is large enough to be
// worth the lifetime problem.
class RenderSurface {
  public:
    static RenderSurface& Shared() {
        // Leaked rather than a plain function-local static, which would be
        // destroyed at exit while a completion handler could still be pending.
        static RenderSurface* instance = new RenderSurface();
        return *instance;
    }

    id<MTLDevice> Device();

    // ------------------------------------------------------------ engine side
    void SurfaceSize(uint32_t* width, uint32_t* height) const;
    id<MTLTexture> Acquire();
    void Publish(id<MTLTexture> texture, id<MTLCommandBuffer> commandBuffer);
    bool StereoEnabled() const;
    bool BeginStereoFrame();
    bool BeginEye(int eye, SpaghettiPadEyeView* view);
    float WorldScale() const;

    // -------------------------------------------------------- compositor side
    id<MTLTexture> LatestFrame(int eye, uint64_t* generation);
    void ReleaseFrame(id<MTLTexture> srgbView, id<MTLCommandBuffer> commandBuffer);
    void SetLive(bool live);
    bool IsLive() const;
    void SetDisplayRate(uint32_t hertz);
    uint32_t DisplayRate() const;
    void SetStereoRequested(bool requested);
    bool StereoRequested() const;
    void SetWorldScale(float metresPerGameUnit);
    void PublishViews(const SpaghettiPadEyeView views[kEyeCount], uint32_t width,
                      uint32_t height);

  private:
    bool EnsureRingLocked();
    void ReleaseRingLocked();
    ptrdiff_t IndexOfLocked(id<MTLTexture> texture, bool srgb, size_t* eye) const;
    bool SlotFreeLocked(size_t index) const;

    mutable std::mutex mutex_;
    std::condition_variable free_;
    id<MTLDevice> device_ = nil;
    Slot slots_[kRingDepth];
    ptrdiff_t published_ = -1;
    bool publishedIsStereo_ = false;
    uint64_t generation_ = 0;
    uint64_t acquired_ = 0;

    // The ring as it is currently allocated. A change to either forces a
    // reallocation, which is why they are recorded rather than recomputed.
    bool ringIsStereo_ = false;
    uint32_t ringWidth_ = 0;
    uint32_t ringHeight_ = 0;

    // Bumped on every reallocation. A command buffer submitted against the old
    // ring can complete after the new one exists, and its handler would then find
    // a live texture at the same slot and eye and publish a frame nothing wrote.
    // Comparing this is what tells "still the frame I submitted" from "the same
    // index in a different ring".
    uint64_t ringGeneration_ = 0;

    // The frame the engine is filling right now, and how far into it it is.
    ptrdiff_t building_ = -1;
    bool buildingIsStereo_ = false;
    int currentEye_ = 0;

    // What the compositor last reported, and the copy latched for the frame the
    // engine is building. They are separate on purpose: the two eyes of one frame
    // must be drawn from one head pose, and the compositor keeps moving.
    SpaghettiPadEyeView reportedViews_[kEyeCount] = {};
    SpaghettiPadEyeView latchedViews_[kEyeCount] = {};
    bool haveReportedViews_ = false;
    uint32_t reportedEyeWidth_ = kFallbackEyeWidth;
    uint32_t reportedEyeHeight_ = kFallbackEyeHeight;

    std::atomic<bool> live_{ false };
    // Mode B is the default. It is what an immersive space is for — the owner's
    // objection on 2026-08-01 was that a flat screen in a synthetic room "might
    // as well" be a window — and it costs nothing to default to, because a
    // drawable with fewer than two views never reports the geometry it needs and
    // the engine falls back to Mode A on its own.
    std::atomic<bool> stereoRequested_{ true };
    std::atomic<float> worldScale_{ kDefaultMetresPerGameUnit };
    // Until the compositor has measured itself, the safest answer is the rate
    // every visionOS display has at least: 90 Hz is a device-only number and
    // claiming it before it has been seen would be a guess.
    std::atomic<uint32_t> displayRate_{ 60 };

    bool loggedStereoStart_ = false;
};

id<MTLDevice> RenderSurface::Device() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (device_ == nil) {
        device_ = MTLCreateSystemDefaultDevice();
        if (device_ == nil) {
            os_log_error(SurfaceLog(), "no Metal device is available");
        }
    }
    return device_;
}

// True when the engine should be drawing in stereo: the mode is on *and* the
// compositor has something truthful to say about where the eyes are. Both halves
// matter — Mode B with a guessed frustum is worse than Mode A with a real one.
bool RenderSurface::StereoEnabled() const {
    if (!stereoRequested_.load(std::memory_order_acquire)) {
        return false;
    }
    std::lock_guard<std::mutex> lock(mutex_);
    return haveReportedViews_;
}

// What the engine should size its framebuffers to.
//
// The ring's own dimensions once it exists, and what the ring is about to be
// built as before that. Answering with anything else would have Fast3D allocate
// its game framebuffer at one size while rendering into a texture of another,
// which Metal reports as a mismatched render pass rather than as a wrong answer
// from here.
void RenderSurface::SurfaceSize(uint32_t* width, uint32_t* height) const {
    std::lock_guard<std::mutex> lock(mutex_);

    uint32_t reportWidth = kFlatWidth;
    uint32_t reportHeight = kFlatHeight;
    if (slots_[0].texture[0] != nil) {
        reportWidth = ringWidth_;
        reportHeight = ringHeight_;
    } else if (stereoRequested_.load(std::memory_order_acquire) && haveReportedViews_) {
        reportWidth = reportedEyeWidth_;
        reportHeight = reportedEyeHeight_;
    }

    if (width != nullptr) {
        *width = reportWidth;
    }
    if (height != nullptr) {
        *height = reportHeight;
    }
}

void RenderSurface::ReleaseRingLocked() {
    for (size_t index = 0; index < kRingDepth; ++index) {
        for (size_t eye = 0; eye < kEyeCount; ++eye) {
            slots_[index].texture[eye] = nil;
            slots_[index].srgbView[eye] = nil;
            slots_[index].engineBusy[eye] = false;
        }
        slots_[index].writtenEyes = 0;
        slots_[index].compositorUses = 0;
    }
    published_ = -1;
    building_ = -1;
    ringWidth_ = 0;
    ringHeight_ = 0;
    ++ringGeneration_;
}

// Called with the lock held. Builds the ring the current mode needs, tearing
// down one built for the other mode or another size first.
bool RenderSurface::EnsureRingLocked() {
    const bool wantStereo = stereoRequested_.load(std::memory_order_acquire) && haveReportedViews_;
    const uint32_t wantWidth = wantStereo ? reportedEyeWidth_ : kFlatWidth;
    const uint32_t wantHeight = wantStereo ? reportedEyeHeight_ : kFlatHeight;

    if (slots_[0].texture[0] != nil) {
        if (ringIsStereo_ == wantStereo && ringWidth_ == wantWidth && ringHeight_ == wantHeight) {
            return true;
        }
        // A mode or resolution change. Anything the compositor still holds is
        // released by its own completion handler against slots that no longer
        // exist, which is why those handlers capture an index and re-check rather
        // than capturing a texture.
        os_log(SurfaceLog(),
               "reallocating the render surface: %{public}s %u x %u -> %{public}s %u x %u",
               ringIsStereo_ ? "stereo" : "flat", ringWidth_, ringHeight_,
               wantStereo ? "stereo" : "flat", wantWidth, wantHeight);
        ReleaseRingLocked();
    }

    if (device_ == nil) {
        device_ = MTLCreateSystemDefaultDevice();
    }
    if (device_ == nil) {
        return false;
    }
    if (wantWidth == 0 || wantHeight == 0) {
        return false;
    }

    // BGRA8Unorm rather than its sRGB form, because that is the format the
    // engine's Metal backend has always rendered into: the CAMetalLayer it uses
    // elsewhere is set to exactly this. Its shaders write display-encoded values
    // directly, so a target that re-encoded them would be wrong.
    //
    // The compositor's own drawable is sRGB, and sampling these bytes as if they
    // were linear would brighten every frame. The view below is the fix, and it
    // is a view rather than a second texture: same pixels, read back through the
    // decode that the drawable's encode undoes exactly.
    MTLTextureDescriptor* descriptor = [MTLTextureDescriptor
        texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
                                     width:wantWidth
                                    height:wantHeight
                                 mipmapped:NO];
    descriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead |
                       MTLTextureUsagePixelFormatView;
    descriptor.storageMode = MTLStorageModePrivate;

    const size_t eyes = wantStereo ? kEyeCount : 1;
    for (size_t index = 0; index < kRingDepth; ++index) {
        for (size_t eye = 0; eye < eyes; ++eye) {
            id<MTLTexture> texture = [device_ newTextureWithDescriptor:descriptor];
            if (texture == nil) {
                os_log_error(SurfaceLog(),
                             "could not allocate render surface %zu, eye %zu", index, eye);
                ReleaseRingLocked();
                return false;
            }
            texture.label = [NSString stringWithFormat:@"SpaghettiPad frame %zu eye %zu",
                                                       index, eye];
            slots_[index].texture[eye] = texture;
            slots_[index].srgbView[eye] =
                [texture newTextureViewWithPixelFormat:MTLPixelFormatBGRA8Unorm_sRGB];
            if (slots_[index].srgbView[eye] == nil) {
                os_log_error(SurfaceLog(),
                             "could not create an sRGB view of surface %zu, eye %zu", index, eye);
                ReleaseRingLocked();
                return false;
            }
        }
    }

    ringIsStereo_ = wantStereo;
    ringWidth_ = wantWidth;
    ringHeight_ = wantHeight;

    os_log(SurfaceLog(),
           "render surface ready on %{public}@: %{public}s, %u x %u per eye, %zu eye(s), "
           "%zu buffers (%.1f MiB)",
           device_.name, wantStereo ? "stereo" : "flat", wantWidth, wantHeight, eyes,
           kRingDepth,
           (double)(wantWidth * (uint64_t)wantHeight * 4 * eyes * kRingDepth) / (1024.0 * 1024.0));
    return true;
}

ptrdiff_t RenderSurface::IndexOfLocked(id<MTLTexture> texture, bool srgb, size_t* eye) const {
    for (size_t index = 0; index < kRingDepth; ++index) {
        for (size_t candidate = 0; candidate < kEyeCount; ++candidate) {
            id<MTLTexture> held =
                srgb ? slots_[index].srgbView[candidate] : slots_[index].texture[candidate];
            if (held != nil && held == texture) {
                if (eye != nullptr) {
                    *eye = candidate;
                }
                return static_cast<ptrdiff_t>(index);
            }
        }
    }
    return -1;
}

bool RenderSurface::SlotFreeLocked(size_t index) const {
    const Slot& slot = slots_[index];
    if (slot.compositorUses > 0 || static_cast<ptrdiff_t>(index) == published_) {
        return false;
    }
    for (size_t eye = 0; eye < kEyeCount; ++eye) {
        if (slot.engineBusy[eye]) {
            return false;
        }
    }
    return true;
}

// Opens a stereo frame: reserves one slot for both eyes and latches the pose the
// two of them will share.
bool RenderSurface::BeginStereoFrame() {
    std::unique_lock<std::mutex> lock(mutex_);

    // Every refusal below leaves the engine to draw this frame flat, so none of
    // them may leave a half-reserved stereo frame behind: Acquire would then
    // hand back an eye of it and the frame would sit unpublished forever,
    // waiting for a second eye nobody is going to draw.
    buildingIsStereo_ = false;

    if (!stereoRequested_.load(std::memory_order_acquire) || !haveReportedViews_) {
        return false;
    }
    if (!EnsureRingLocked() || !ringIsStereo_) {
        return false;
    }

    for (;;) {
        for (size_t index = 0; index < kRingDepth; ++index) {
            if (index == static_cast<size_t>(building_) || !SlotFreeLocked(index)) {
                continue;
            }
            building_ = static_cast<ptrdiff_t>(index);
            buildingIsStereo_ = true;
            slots_[index].writtenEyes = 0;
            slots_[index].eyes = kEyeCount;
            currentEye_ = 0;
            // One pose for both eyes. Rendering the second eye against a fresher
            // head pose than the first sounds like an improvement and is not: it
            // is exactly the shear that makes a stereo pair impossible to fuse.
            memcpy(latchedViews_, reportedViews_, sizeof(latchedViews_));

            if (!loggedStereoStart_) {
                loggedStereoStart_ = true;
                os_log(SurfaceLog(),
                       "Mode B: first stereo frame, %u x %u per eye, tangents "
                       "L%.3f R%.3f U%.3f D%.3f / L%.3f R%.3f U%.3f D%.3f",
                       ringWidth_, ringHeight_, (double)latchedViews_[0].tangents[0],
                       (double)latchedViews_[0].tangents[1], (double)latchedViews_[0].tangents[2],
                       (double)latchedViews_[0].tangents[3], (double)latchedViews_[1].tangents[0],
                       (double)latchedViews_[1].tangents[1], (double)latchedViews_[1].tangents[2],
                       (double)latchedViews_[1].tangents[3]);
            }
            return true;
        }

        if (free_.wait_for(lock, std::chrono::seconds(1)) == std::cv_status::timeout) {
            os_log_error(SurfaceLog(),
                         "waited a second for a free stereo frame after %llu frames; "
                         "the GPU is not retiring work",
                         (unsigned long long)acquired_);
            return false;
        }
    }
}

bool RenderSurface::BeginEye(int eye, SpaghettiPadEyeView* view) {
    if (eye < 0 || eye >= static_cast<int>(kEyeCount)) {
        return false;
    }
    std::lock_guard<std::mutex> lock(mutex_);
    if (building_ < 0 || !buildingIsStereo_) {
        return false;
    }
    if (!latchedViews_[eye].valid) {
        return false;
    }
    currentEye_ = eye;
    if (view != nullptr) {
        *view = latchedViews_[eye];
    }
    return true;
}

id<MTLTexture> RenderSurface::Acquire() {
    std::unique_lock<std::mutex> lock(mutex_);
    if (!EnsureRingLocked()) {
        return nil;
    }

    // Mode B has already reserved its slot in BeginStereoFrame; all that is left
    // is to hand over the eye the engine is about to draw.
    if (buildingIsStereo_ && building_ >= 0 && ringIsStereo_) {
        Slot& slot = slots_[building_];
        slot.engineBusy[currentEye_] = true;
        ++acquired_;
        return slot.texture[currentEye_];
    }

    for (;;) {
        for (size_t index = 0; index < kRingDepth; ++index) {
            if (!SlotFreeLocked(index)) {
                continue;
            }
            Slot& slot = slots_[index];
            slot.engineBusy[0] = true;
            slot.writtenEyes = 0;
            slot.eyes = 1;
            building_ = static_cast<ptrdiff_t>(index);
            buildingIsStereo_ = false;
            currentEye_ = 0;
            ++acquired_;
            return slot.texture[0];
        }

        // Every buffer is still held by the GPU. -nextDrawable blocks here too;
        // the difference is that this says so if the wait becomes pathological,
        // rather than looking like a hang with no explanation.
        if (free_.wait_for(lock, std::chrono::seconds(1)) ==
            std::cv_status::timeout) {
            os_log_error(SurfaceLog(),
                         "waited a second for a free render surface after %llu "
                         "frames; the GPU is not retiring work",
                         (unsigned long long)acquired_);
        }
    }
}

void RenderSurface::Publish(id<MTLTexture> texture,
                            id<MTLCommandBuffer> commandBuffer) {
    if (texture == nil || commandBuffer == nil) {
        return;
    }

    ptrdiff_t index;
    size_t eye = 0;
    unsigned eyesInFrame = 1;
    uint64_t ring;
    {
        std::lock_guard<std::mutex> lock(mutex_);
        index = IndexOfLocked(texture, /*srgb=*/false, &eye);
        if (index >= 0) {
            eyesInFrame = slots_[index].eyes;
        }
        ring = ringGeneration_;
    }
    if (index < 0) {
        os_log_error(SurfaceLog(), "a texture that is not part of the ring was "
                                   "published");
        return;
    }

    const bool stereo = eyesInFrame > 1;

    // The whole ordering guarantee between the engine's queue and the
    // compositor's is this handler: the frame becomes visible to the compositor
    // only once the GPU says it is finished being written. In Mode B that is
    // once *both* eyes say so, and the two command buffers can complete in
    // either order, so the count rather than the eye index is what decides.
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> _) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (ring != ringGeneration_ || slots_[index].texture[eye] == nil) {
            // The ring was reallocated under this frame. Whatever occupies this
            // slot now was written by someone else, or by nobody.
            free_.notify_all();
            return;
        }
        slots_[index].engineBusy[eye] = false;
        slots_[index].writtenEyes += 1;
        if (!stereo || slots_[index].writtenEyes >= eyesInFrame) {
            published_ = index;
            publishedIsStereo_ = stereo;
            ++generation_;
        }
        free_.notify_all();
    }];
}

float RenderSurface::WorldScale() const {
    return worldScale_.load(std::memory_order_acquire);
}

void RenderSurface::SetWorldScale(float metresPerGameUnit) {
    if (metresPerGameUnit > 0.0f) {
        worldScale_.store(metresPerGameUnit, std::memory_order_release);
    }
}

// The compositor's frame, published once per drawable. Cheap on purpose: it runs
// on the compositor thread with a headset's deadline over it.
void RenderSurface::PublishViews(const SpaghettiPadEyeView views[kEyeCount],
                                 uint32_t width, uint32_t height) {
    std::lock_guard<std::mutex> lock(mutex_);
    memcpy(reportedViews_, views, sizeof(reportedViews_));
    haveReportedViews_ = views[0].valid != 0 && views[kEyeCount - 1].valid != 0;
    if (width > 0 && height > 0) {
        reportedEyeWidth_ = width;
        reportedEyeHeight_ = height;
    }
}

void RenderSurface::SetStereoRequested(bool requested) {
    const bool previous =
        stereoRequested_.exchange(requested, std::memory_order_acq_rel);
    if (previous != requested) {
        // A surface flip with this line beside it is the wearer's toggle; one
        // without it is the mode collapsing on its own. A session was once seen
        // flipping stereo -> flat -> stereo and nothing could say which.
        os_log(SurfaceLog(), "stereo %{public}s by request",
               requested ? "enabled" : "disabled");
    }
}

bool RenderSurface::StereoRequested() const {
    return stereoRequested_.load(std::memory_order_acquire);
}

id<MTLTexture> RenderSurface::LatestFrame(int eye, uint64_t* generation) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (published_ < 0) {
        return nil;
    }
    if (eye < 0 || eye >= static_cast<int>(kEyeCount)) {
        return nil;
    }
    // A caller asking for the second eye of a flat frame is asking whether the
    // latest frame is stereo, and the answer is no.
    if (eye > 0 && !publishedIsStereo_) {
        return nil;
    }
    id<MTLTexture> view = slots_[published_].srgbView[eye];
    if (view == nil) {
        return nil;
    }
    ++slots_[published_].compositorUses;
    if (generation != nullptr) {
        *generation = generation_;
    }
    return view;
}

void RenderSurface::ReleaseFrame(id<MTLTexture> srgbView,
                                 id<MTLCommandBuffer> commandBuffer) {
    if (srgbView == nil) {
        return;
    }

    ptrdiff_t index;
    uint64_t ring;
    {
        std::lock_guard<std::mutex> lock(mutex_);
        index = IndexOfLocked(srgbView, /*srgb=*/true, nullptr);
        ring = ringGeneration_;
    }
    if (index < 0) {
        return;
    }

    // Released when the compositor's own command buffer retires, not when it was
    // encoded: the sample happens on the GPU, long after this returns.
    //
    // The ring check is not belt and braces. A reallocation zeroes every borrow
    // count, so a release arriving afterwards would decrement a count that
    // belongs to somebody else's frame — and a count that reaches zero while the
    // compositor is still reading is the engine drawing over a texture in use.
    auto release = [this, index, ring] {
        std::lock_guard<std::mutex> lock(mutex_);
        if (ring != ringGeneration_) {
            return;
        }
        if (slots_[index].compositorUses > 0) {
            --slots_[index].compositorUses;
        }
        free_.notify_all();
    };
    if (commandBuffer == nil) {
        release();
        return;
    }
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> _) { release(); }];
}

void RenderSurface::SetLive(bool live) {
    live_.store(live, std::memory_order_release);
}

bool RenderSurface::IsLive() const {
    return live_.load(std::memory_order_acquire);
}

void RenderSurface::SetDisplayRate(uint32_t hertz) {
    if (hertz > 0) {
        displayRate_.store(hertz, std::memory_order_release);
    }
}

uint32_t RenderSurface::DisplayRate() const {
    return displayRate_.load(std::memory_order_acquire);
}

} // namespace

// ------------------------------------------------- engine side of the contract
//
// Declared by libultraship in include/fast/backends/gfx_visionos.h and called
// from the engine thread. Deliberately not weak: an engine that could not reach
// its surface must fail to link, not render into nothing.

extern "C" void* SpaghettiPad_RenderMetalDevice(void) {
    return (__bridge void*)RenderSurface::Shared().Device();
}

extern "C" void SpaghettiPad_RenderSurfaceSize(uint32_t* width, uint32_t* height) {
    RenderSurface::Shared().SurfaceSize(width, height);
}

extern "C" void* SpaghettiPad_RenderAcquireTexture(void) {
    return (__bridge void*)RenderSurface::Shared().Acquire();
}

extern "C" void SpaghettiPad_RenderPublishTexture(void* texture,
                                                  void* commandBuffer) {
    RenderSurface::Shared().Publish((__bridge id<MTLTexture>)texture,
                                    (__bridge id<MTLCommandBuffer>)commandBuffer);
}

extern "C" int SpaghettiPad_RenderIsLive(void) {
    return RenderSurface::Shared().IsLive() ? 1 : 0;
}

extern "C" uint32_t SpaghettiPad_RenderDisplayRate(void) {
    return RenderSurface::Shared().DisplayRate();
}

extern "C" int SpaghettiPad_RenderStereoEnabled(void) {
    return RenderSurface::Shared().StereoEnabled() ? 1 : 0;
}

extern "C" int SpaghettiPad_RenderBeginStereoFrame(void) {
    return RenderSurface::Shared().BeginStereoFrame() ? 1 : 0;
}

extern "C" int SpaghettiPad_RenderBeginEye(int eye, SpaghettiPadEyeView* view) {
    return RenderSurface::Shared().BeginEye(eye, view) ? 1 : 0;
}

extern "C" float SpaghettiPad_RenderWorldScale(void) {
    return RenderSurface::Shared().WorldScale();
}

// --------------------------------------------- compositor side of the contract

void* SpaghettiPad_RenderLatestFrame(uint64_t* generation) {
    return (__bridge void*)RenderSurface::Shared().LatestFrame(0, generation);
}

void* SpaghettiPad_RenderLatestStereoFrame(int eye, uint64_t* generation) {
    return (__bridge void*)RenderSurface::Shared().LatestFrame(eye, generation);
}

void SpaghettiPad_RenderReleaseFrame(void* frame, void* commandBuffer) {
    RenderSurface::Shared().ReleaseFrame(
        (__bridge id<MTLTexture>)frame, (__bridge id<MTLCommandBuffer>)commandBuffer);
}

void SpaghettiPad_RenderSetLive(int live) {
    RenderSurface::Shared().SetLive(live != 0);
}

void SpaghettiPad_RenderSetDisplayRate(uint32_t hertz) {
    RenderSurface::Shared().SetDisplayRate(hertz);
}

void SpaghettiPad_RenderSetStereoRequested(int requested) {
    RenderSurface::Shared().SetStereoRequested(requested != 0);
}

int SpaghettiPad_RenderStereoRequested(void) {
    return RenderSurface::Shared().StereoRequested() ? 1 : 0;
}

void SpaghettiPad_RenderSetWorldScale(float metresPerGameUnit) {
    RenderSurface::Shared().SetWorldScale(metresPerGameUnit);
}

void SpaghettiPad_RenderPublishViews(const SpaghettiPadEyeView* views, uint32_t eyeCount,
                                     uint32_t width, uint32_t height) {
    if (views == nullptr || eyeCount < SPAGHETTIPAD_EYE_COUNT) {
        // Fewer views than eyes is the Simulator, which renders one. Reporting
        // it as stereo would let Mode B run against a frustum for an eye that
        // does not exist, and a single-eye "stereo" frame is precisely the
        // result this project refuses to treat as evidence.
        SpaghettiPadEyeView none[SPAGHETTIPAD_EYE_COUNT] = {};
        RenderSurface::Shared().PublishViews(none, width, height);
        return;
    }
    RenderSurface::Shared().PublishViews(views, width, height);
}
