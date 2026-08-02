// The complete contract between the visionOS shell and the engine.
//
// Successor to ios/SpaghettiPadTouchControls.h. That header bridged a UIKit
// touch overlay into an SDL virtual joystick; this one bridges a SwiftUI app
// lifecycle, a Compositor Services immersive space, and GameController /
// ARKit accessory input into the same engine.
//
// Everything crossing this boundary is C. Swift reaches it through
// SpaghettiPad-Bridging-Header.h; the engine side is Objective-C++.
#pragma once

#include <stdint.h>

// Both eyes of a stereo frame. Defined identically in libultraship's
// include/fast/backends/gfx_visionos.h; an identical macro redefinition is legal
// C, and the two trees must not include each other's headers.
#define SPAGHETTIPAD_EYE_COUNT 2

// One eye's geometry for one frame. The engine's copy of this declaration lives
// in libultraship's gfx_visionos.h, guarded by the same macro: neither tree may
// include the other's headers, so the type is written out on both sides and
// whichever is seen first defines it. Changing one without the other is a silent
// ABI break, which is why both carry this note.
#ifndef SPAGHETTIPAD_EYE_VIEW_DEFINED
#define SPAGHETTIPAD_EYE_VIEW_DEFINED
typedef struct SpaghettiPadEyeView {
    // Tangents of the angles bounding this eye's frustum, measured from the view
    // axis: left, right, up, down. All positive magnitudes, and not symmetric —
    // a Vision Pro cants each eye outwards.
    float tangents[4];

    // Eye-from-recentre, in metres, column-major — which is both simd's memory
    // order and the layout Fast3D's row-vector matrices already use.
    float eyeFromRecentre[16];

    // Non-zero once this came from a real drawable.
    int valid;
} SpaghettiPadEyeView;
#endif

#ifdef __cplusplus
extern "C" {
#endif

// ---------------------------------------------------------------- lifecycle

// Prepares engine paths before any other call. Both arguments are absolute.
// Returns non-zero on success.
int SpaghettiPad_RuntimeInit(const char* documentsPath, const char* bundlePath);

// Non-zero once a usable mk64.o2r exists in the app container.
int SpaghettiPad_GameArchiveReady(void);

// Copies a user-selected ROM into the container and runs Torch extraction.
// Long-running; call off the main thread. Returns non-zero on success.
int SpaghettiPad_ImportRom(const char* sourcePath);

// Copies a user-selected texture pack into the container's mods/ directory.
int SpaghettiPad_ImportModArchive(const char* sourcePath);

// How many .o2r archives the mods/ directory holds. Answerable before the engine
// has started, which is when the app has to decide what to offer.
int SpaghettiPad_InstalledModCount(void);

// The texture-pack switch: SpaghettiKart's gEnhancements.Mods.AlternateAssets.
// Defined in the engine (src/port/Engine.cpp) rather than here, because it is
// the engine's console variable and the engine's per-frame loop is what notices
// it change and reloads every texture. Upstream's only way to reach it is the
// Enhancements menu, which an immersive space has no pointer to click.
//
// Both answer 0 / do nothing until the engine's console variable system exists,
// which it does not until the game loop has started. That is truthful for the
// engine and wrong for a launch window: the pair below is what the app should
// call instead.
void SpaghettiPad_SetAlternateAssets(int enabled);
int SpaghettiPad_AlternateAssetsEnabled(void);

// The same switch, answerable and settable before the engine exists.
//
// While the engine is running these delegate to the pair above, which is the
// only thing that can reload textures in a live session. Before it starts they
// read and write the engine's own saved console variables directly, because
// that file — not the not-yet-existing CVar system — is what the engine will
// load when it does start. Without this the launch window reported "off" for a
// pack that was about to load, and could not turn it off either.
void SpaghettiPad_SetAlternateAssetsPreference(int enabled);
int SpaghettiPad_AlternateAssetsPreference(void);

// SpaghettiKart's main(), renamed at compile time via
// COMPILE_DEFINITIONS main=SpaghettiPad_GameMain so no upstream source
// changes. Blocks until the game loop exits; run it on a dedicated thread
// with a stack of at least 16 MiB.
int SpaghettiPad_GameMain(int argc, char** argv);

// Asks the game loop to exit; SpaghettiPad_GameMain returns shortly after.
void SpaghettiPad_RequestShutdown(void);

// ------------------------------------------------------------------ render

// Hands the Compositor Services layer renderer to the shell and starts the
// compositor thread. The pointer is a cp_layer_renderer_t, which is an
// Objective-C object pointer (CP_OBJECT_cp_layer_renderer *), passed opaquely
// from Swift: CompositorLayer's renderer closure is the only place it exists,
// and it is not a type the Swift side of this app should know anything else
// about. Returns non-zero once the thread owns the renderer.
//
// The compositor thread is permanent. What changes as the port grows is only
// what gets encoded into each drawable: today a per-eye test pattern, later the
// engine's frames. Everything else — frame pacing, the per-view render passes,
// foveation, present — is the same either way.
int SpaghettiPad_StartCompositor(void* layerRenderer);

// Stops the compositor thread and waits for it to finish. Safe to call when no
// compositor is running.
void SpaghettiPad_StopCompositor(void);

// Non-zero while the compositor thread is live. The system can end an immersive
// space on its own — the Digital Crown does exactly that — and when it does,
// the render thread notices its renderer go invalid and exits without any
// SwiftUI code having been asked. This is how the app's own idea of "the space
// is open" gets resynchronised with what actually happened.
int SpaghettiPad_CompositorRunning(void);

// The app's single ar_session_t, as an opaque pointer, or null before the
// compositor has started world tracking. The compositor owns it because it is
// the thing that cannot render a presentable frame without one: every drawable
// carries a device anchor queried from this session, and a headset drops any
// drawable that does not.
//
// It is exposed because ARKit permits exactly one session per app, so
// SpaghettiPad_AttachAccessoryTracking must add its provider to this one.
void* SpaghettiPad_ARSession(void);

// Starts the engine's game thread against the running compositor. Separate
// from the compositor because the two have different lifetimes: the compositor
// runs whenever the immersive space is open, while the game thread runs only
// once game data exists.
int SpaghettiPad_StartEngine(void);

// Non-zero once the engine thread is running.
int SpaghettiPad_EngineRunning(void);

// Called when the immersive space opens or closes.
void SpaghettiPad_SetImmersiveActive(int active);

// ---------------------------------------------------------- render handover
//
// The engine has no window to draw into: SDL_VIDEO is off, so there is no
// CAMetalLayer to take a drawable from. It renders into a small ring of
// textures owned by SpaghettiPadRenderSurface.mm instead, and the compositor
// shows the latest finished one on a screen inside the immersive space.
//
// The engine's half of that contract is declared by libultraship itself, in
// include/fast/backends/gfx_visionos.h, so the engine depends on no header of
// this app's. What follows is the compositor's half, plus the one call both
// sides make.

// The single Metal device the engine and the compositor share. They render and
// sample the same textures, so a second device would not merely be wasteful, it
// would be wrong — which is why the compositor checks this against the layer
// renderer's own device rather than assuming.
void* SpaghettiPad_RenderMetalDevice(void);

// Borrows the most recently finished engine frame, or null if the engine has
// not produced one yet. The returned texture is an sRGB view: the engine writes
// display-encoded pixels, and the compositor's drawable re-encodes on write, so
// this is the decode that makes the round trip exact. Every non-null result
// must be handed back to SpaghettiPad_RenderReleaseFrame.
void* SpaghettiPad_RenderLatestFrame(uint64_t* generation);

// Returns a borrowed frame once `commandBuffer` — the one that sampled it —
// completes. Pass a null command buffer to return it immediately.
void SpaghettiPad_RenderReleaseFrame(void* frame, void* commandBuffer);

// Tells the surface whether anything is consuming frames. While this is zero
// the game loop idles instead of rendering frames nothing would show.
void SpaghettiPad_RenderSetLive(int live);

// Publishes the rate the compositor is actually presenting at. The engine asks
// the surface for this — it has no display of its own to ask — and upstream
// derives its interpolation rate from the answer, so it has to be the headset's
// number rather than anything the engine already chose.
void SpaghettiPad_RenderSetDisplayRate(uint32_t hertz);

// ------------------------------------------------------------------- Mode B
//
// Mode A hangs a flat picture of the game on a screen in the room: everything
// stereoscopic about it belongs to the screen. Mode B draws the game itself in
// stereo — the display list runs once per eye, with the wearer's head standing
// in for the game's camera — so the world has depth rather than being a picture
// of a world that has depth. The engine's half of this contract is in
// libultraship's gfx_visionos.h.

// Borrows one eye of the most recently finished stereo frame, or null when the
// latest frame is not stereo. Released through SpaghettiPad_RenderReleaseFrame
// like any other borrowed frame.
void* SpaghettiPad_RenderLatestStereoFrame(int eye, uint64_t* generation);

// Asks for Mode B. Requesting it is not the same as getting it: the engine draws
// in stereo only once the compositor has also reported real per-eye geometry,
// which a Simulator that renders one view never does.
void SpaghettiPad_RenderSetStereoRequested(int requested);
int SpaghettiPad_RenderStereoRequested(void);

// Metres per game unit — the single control over whether Mario Kart 64's world
// reads as a race track or a tabletop. Nothing in the ROM says what its units
// mean, so this is a comfort setting for a wearer to argue with rather than a
// measurement, and it lives here so changing it is not a rebuild of Fast3D.
void SpaghettiPad_RenderSetWorldScale(float metresPerGameUnit);
float SpaghettiPad_RenderWorldScale(void);

// What the compositor knows and the engine cannot: where each eye is this frame,
// and what shape its frustum is. Called once per drawable from the compositor
// thread. Fewer views than eyes — the Simulator, which renders one — is reported
// as no stereo at all rather than as half of it.
void SpaghettiPad_RenderPublishViews(const SpaghettiPadEyeView* views, uint32_t eyeCount,
                                     uint32_t width, uint32_t height);

// ------------------------------------------------------------------- input

void SpaghettiPad_InputInit(void);
void SpaghettiPad_InputShutdown(void);

// ARKit permits a single ar_session_t. The compositor owns it and
// SpaghettiPad_ARSession() hands it out; the input layer adds its
// accessory-tracking provider to that same session rather than creating a
// second one.
void SpaghettiPad_AttachAccessoryTracking(void* arSession);

// PS VR2 Sense motion steering. Sensitivity and the filter reuse the
// physically-tuned constants from the retired tilt path.
void SpaghettiPad_SetMotionSteeringEnabled(int enabled);
void SpaghettiPad_SetMotionSensitivity(float sensitivity);
void SpaghettiPad_RecenterMotionSteering(void);

// Number of controllers currently routed to N64 ports (0-4).
int SpaghettiPad_ConnectedPortCount(void);

// Called from the engine thread — see the shell contract in libultraship's
// fast/backends/gfx_visionos.h, which is where the engine's copy of this
// declaration lives — whenever the set of game controllers the control deck has
// opened changes. `names` is their comma-separated SDL names, empty when none.
//
// A headset can neither be screenshotted nor watched over someone's shoulder, so
// this log line is the only evidence that a controller reached the engine at all.
void SpaghettiPad_InputDevicesChanged(int count, const char* names);

// Called once per N64 port, from the engine thread, the first time that port
// carries something other than a neutral pad — that is, the first time input
// actually reaches the game rather than merely reaching the app. Declared weak
// in libultraship's control deck so it links without a shell.
void SpaghettiPad_InputFirstActivity(int port, unsigned buttons, int stickX, int stickY);

// --------------------------------------------------- engine -> shell (weak)
//
// Defined by the shell, declared weak in the engine so libultraship links
// without it. Mirrors the existing weak menu bridge.

void SpaghettiPad_SetMenuVisible(int visible);
void SpaghettiPad_SetGameplayActive(int active);

// Replaces SDL_ShowMessageBox, which cannot work with SDL_VIDEO=OFF. Posts to
// SwiftUI. Every upstream message-box call site must route through this or it
// becomes a silent no-op.
void SpaghettiPad_PresentAlert(const char* title, const char* body);

#ifdef __cplusplus
}
#endif
