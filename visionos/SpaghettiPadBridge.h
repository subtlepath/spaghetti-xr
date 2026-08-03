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

// How many .z64 ROMs the container holds. Answerable before the engine has
// started, which is when the launch window has to decide whether to offer
// extraction.
int SpaghettiPad_ImportedRomCount(void);

// Non-zero when there is a ROM but no game archive: starting the engine now
// means extracting, which takes minutes.
int SpaghettiPad_ExtractionPending(void);

// Non-zero when the previous launch started extracting and never produced an
// archive. Extraction failures inside the engine end in _Exit(1), so this is the
// only trace they leave. Fixed for the lifetime of the process.
int SpaghettiPad_PreviousExtractionFailed(void);

// Copies a user-selected ROM into the container. Extraction is the engine's and
// happens on its first start; this only puts the file where the engine's
// container scan will find it. Long-running; call off the main thread.
// Returns non-zero on success.
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

// What the engine's textures are costing, for the compositor's memory line.
//
// Five out-parameters rather than a struct because a struct here would have to
// be declared identically in libultraship too, and this header already carries
// one of those. Any may be null. All read atomics the engine publishes once a
// frame, so a caller on the compositor thread gets the last frame's figures
// rather than a torn view of this one's, and all answer 0 before the engine
// starts.
//
// `gpuBytes` is what the rendering backend is holding, by the device's own
// accounting; `cacheBytes` is what the Fast3D texture cache thinks its entries
// are worth. The two disagreeing is the whole reason this exists: on 2026-08-03
// a wearer's session reached 8065 MiB of footprint with 126 MiB of headroom left
// while the cache sat inside its one-gigabyte budget, because evicting an entry
// did not free the texture behind it.
void SpaghettiPad_EngineTextureMemory(uint64_t* gpuBytes, uint64_t* gpuTextures, uint64_t* cacheEntries,
                                      uint64_t* cacheBytes, uint64_t* evictions);

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

// How far the Digital Crown has the world wound open, from 0 (a small portal
// with the wearer's own room around it) to 1 (fully immersive), or a negative
// value under an immersion style that has no amount at all.
//
// Nothing renders from this. The portal's actual shape reaches the renderer as
// a stencil mask on each drawable, which is the only description of it that is
// correct for the frame being drawn. This exists so the log can say what the
// wearer was looking through when they saw whatever they are reporting.
void SpaghettiPad_SetImmersionAmount(double amount);

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
// SpaghettiPad_ARSession() hands it out; the accessory-tracking provider joins
// that same session rather than creating a second one, and does so inside
// WorldTracking::Start() before the session is ever run.
//
// What is left for this entry point is the part that cannot happen that early:
// finding the controllers, which connect and disconnect as a wearer switches
// them on. The `arSession` argument is vestigial — the provider is already in
// the session by the time anything can call this — and is ignored.
void SpaghettiPad_AttachAccessoryTracking(void* arSession);

// PS VR2 Sense 6DoF steering: the two controllers held like a wheel, steering by
// the angle of the line between the hands rather than by either hand alone.
// Needs visionOS 27, where GameController reports the pair as two spatial
// accessories; below that they are only ever the one combined gamepad and these
// are no-ops that say so.
//
// The filter and the deadzone are the physically-tuned constants from the
// retired tilt path. Full lock is **not** — a wrist rolling a phone and a pair
// of arms turning a wheel do not want the same travel — and the number in
// SpaghettiPadAccessorySteering.mm is an untried guess with a slider around it.
void SpaghettiPad_SetMotionSteeringEnabled(int enabled);
void SpaghettiPad_SetMotionSensitivity(float sensitivity);
void SpaghettiPad_RecenterMotionSteering(void);

// The steering axis to apply to port 0's stick X, in the N64's own ±85 units.
//
// Returns 0 — leaving `outStickX` untouched — whenever steering should not be
// applied at all: switched off, unsupported, one of the pair not held or not
// tracked, or the last sample too old to still be true. The engine's control
// deck calls this once per pad read and lets a real thumbstick win, so a wearer
// who lifts a thumb to the stick keeps steering with it.
int SpaghettiPad_MotionSteeringAxis(int* outStickX);

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

// Whether the recentre chord — both shoulders and both triggers — is held right
// now, merged across every controller the GameController framework holds. Read
// by the compositor, which owns the frame clock the hold is timed against and is
// the only thing that can act on it: recentring is moving the room, and the room
// is the compositor's.
//
// This reads the framework's controllers and installs nothing on them. The
// engine's control deck, through SDL's MFi driver, owns their
// valueChangedHandler, and replacing it would take the game's input with it.
int SpaghettiPad_InputRecentreChordHeld(void);

// ------------------------------------------------------------- settings menu
//
// The engine's settings menu, as data, so the shell can draw it as a native
// SwiftUI window instead of the ImGui one — see
// SpaghettiKart:src/port/ui/SpaghettiPadMenuBridge.cpp, which is where all of
// these are defined and where the threading rules are written down.
//
// The short version of those rules: nothing below touches the menu tree, a
// CVar, or a widget's callback on the calling thread. Reads copy the last
// snapshot the engine published; writes are queued and applied at the top of the
// next game frame. So every one of these is safe from the main actor, and none
// of them is synchronous with the change it asks for.

// Whether the engine should keep publishing snapshots. Off by default: a
// snapshot costs a tree walk and a JSON encode per frame, and there is no
// reason to pay it while no window is open.
void SpaghettiPad_MenuSetPolling(int wanted);

// Bumped whenever the menu's *shape* changes, as opposed to its values. The
// shell re-reads the structure when this moves and only the values otherwise.
uint32_t SpaghettiPad_MenuGeneration(void);

// The menu's shape and its current values, as two JSON documents. Both follow
// the snprintf convention: they return the length the document needs, write at
// most `capacity - 1` bytes plus a terminator, and may be called with a null
// buffer to size a buffer first. Both return 0 before the engine has published
// anything, which is every call before the first frame after polling is turned
// on.
int SpaghettiPad_MenuStructureJSON(char* out, int capacity);
int SpaghettiPad_MenuValuesJSON(char* out, int capacity);

// A wearer changed something. `id` is the widget's id from the structure
// document. Queued, not applied: the engine picks these up at the top of its
// next frame and runs the widget's own callback there.
void SpaghettiPad_MenuSetInt(int id, int value);
void SpaghettiPad_MenuSetFloat(int id, float value);
void SpaghettiPad_MenuSetColor(int id, uint32_t rgba);
void SpaghettiPad_MenuActivate(int id);

// Opens or closes the menu from the shell's side, for when a wearer closes the
// native window with its own close button. The engine keeps blocking game input
// for as long as the menu is visible, so failing to say this would leave a kart
// that will not drive and no window to explain why.
void SpaghettiPad_MenuRequestVisible(int visible);

// Whether the engine should skip drawing its ImGui menu because the shell is
// showing a native window instead. Defined by the shell, declared weak in the
// engine's Menu.cpp so every other platform keeps the ImGui menu.
//
// This is the switch between the two front ends, and it is deliberately the only
// one: the menu still becomes *visible* either way, with the same input blocking
// and the same visibility CVar, so turning it off restores the ImGui menu with
// no other state to unwind.
//
// It answers yes only while a native window is actually on screen, which is the
// failsafe: if SwiftUI never presents the window — and on a platform this new,
// "never presents" is a real outcome — the ImGui menu keeps drawing and a wearer
// is never left with settings they cannot reach.
int SpaghettiPad_MenuUsesNativeWindow(void);

// Called by the settings window as it appears and disappears. The only thing
// that makes the answer above yes.
void SpaghettiPad_MenuNativeWindowPresent(int present);

// Posted to the default NSNotificationCenter on the main queue whenever the
// engine's menu visibility changes, carrying an NSNumber `visible` in userInfo.
// This is how the pad's menu button reaches SwiftUI: the engine has no idea a
// window exists, and the shell will not reach into a scene from a game thread.
#define SPAGHETTIPAD_MENU_VISIBILITY_NOTIFICATION "SpaghettiPadMenuVisibilityChanged"

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
