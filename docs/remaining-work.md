# SpaghettiPad remaining work

This is the chronological execution queue and append-only proof log. Dated
entries preserve what was known at that point and may be superseded by later
evidence. The [README validation table](../README.md#current-validation) is
the canonical public status; this file supplies the underlying detail.

## Goal

Deliver a reproducible, native iPadOS-first SpaghettiKart port with
grip-designed full-analog touch controls, on-device Files import and
extraction, physical-controller support, lifecycle-safe audio, two-player
split-screen, optional tilt steering, user-imported texture packs, and an
audited ROM-free unsigned IPA.

## Invariants

- User-supplied, legally acquired Mario Kart 64 (US) big-endian `.z64` only.
- Never commit or distribute ROMs, `mk64*.o2r`, `.otr`, extracted Nintendo
  assets, or the MK64 Reloaded texture pack.
- `chrissotraidis/spaghettipad` is the sole publication repository.
- SpaghettiKart, libultraship, Torch, and prior-art references are pinned,
  disposable, push-disabled inputs under ignored directories.
- Keep every durable source change as a reviewable maintained patch.
- Keep `ENABLE_SCRIPTING` disabled with an iOS `FATAL_ERROR` guard.
- Treat local, CI, Simulator, physical-device, signing, audio, performance,
  controller, and texture-pack evidence as separate gates.
- Make the smallest maintainable change for the first reproducible failure,
  then replay that gate.

## Repository and source boundary

| Tree | Role | Revision |
|---|---|---|
| `chrissotraidis/spaghettipad` | Sole owned project and publication repository | `59ad133` baseline |
| `HarbourMasters/SpaghettiKart` | Pinned upstream source input | `5b28472d477bab101dee2a0f469fe2aee2c58a01` |
| `Kenix3/libultraship` | SpaghettiKart-pinned upstream source input | `f5c3843fe937320b64ff754fa6bf71b13ff5e7a1` |
| `HarbourMasters/Torch` | SpaghettiKart-pinned upstream source input | `2d474ddb8da8b213fbdbb49d0273ce31fa955f35` |

## Phase queue

On 2026-08-01 the project pivoted to a native visionOS app for Apple Vision
Pro, with stereoscopic rendering in a fully immersive space. The iPadOS lane's
open gates are **superseded, not completed**: no unclaimed iPadOS result below
becomes true by abandonment. Preview 3 remains a released artifact and its
recorded evidence stands.

### visionOS

| Phase | Gate | State | Required evidence |
|---|---|---|---|
| 0 | Toolchain spike and pinned bootstrap | Complete | Mixed Swift/Obj-C++/C++ visionOS bundle builds under the Xcode generator; `platform VISIONOS` confirmed as the audit string |
| 1 | visionOS app configures, links, and launches | Complete | Simulator app bundle links and reaches its SwiftUI launch window |
| 2 | Compositor Services skeleton | **Complete 2026-08-01**, both halves; a wearer confirmed amber/cyan borders, one/two ticks and per-eye reticle disparity on an Apple Vision Pro | Immersive space opens and renders a per-eye test pattern (device proves both eyes differ) |
| 3 | Engine on the compositor | **Complete 2026-08-01**, both halves; the device half ran 6 min 15 s at 89–90 Hz with all 33,601 drawables anchored, which the owner accepted in place of ten minutes | Title screen on a floating screen, sustained — ten minutes as written, **six accepted by the owner on 2026-08-01** |
| 4 | Stereo and immersive environment | **Complete 2026-08-01**: separation measured on device (67.0–70.7 mm across six sessions), world-locking demonstrated, and the wearer drove a comfortable full race and won it. The floor is still misplaced — recorded as a known defect, not as an open gate | Measured on-device stereo separation and a comfortable full race |
| 5 | Input | **PS VR2 Sense half done 2026-08-01** on device — they enumerate as one combined gamepad and drove a race, buttons and sticks only. **6DoF steering written 2026-08-02 and never run**: accessory tracking is no longer a refusal, but the Simulator can exercise none of it. Open: **DualSense** (never connected), port order across reconnects, and every claim about 6DoF | DualSense and PS VR2 Sense races, stable port order across reconnects |
| 6 | Settings UI | **Rebuilt native 2026-08-02; device half never run.** The menu is now a SwiftUI window driven by the engine's own published widget tree rather than ImGui drawn into the game's framebuffer — which is the answer to the legibility question this row used to carry, since the text is now the system's at the system's size. The ImGui menu remains as the fallback and for the Developer windows. Open: the whole thing on a headset | Every settings page operable with a controller alone |
| 7 | ROM and texture-pack import | **Simulator half complete 2026-08-02; device half never run.** In-app extraction now works and was exercised from a clean container: 438 s, peak RSS 1085 MiB, 32,447 entries. The MK64 Reloaded 4K pack (1.18 GiB) imports, loads as `MK64-Reloaded-SK v2026.0.0`, and renders. Open: the whole gate on a headset | Clean-container ROM import, extraction, and a texture-pack switch |
| 8 | Audit, packaging, CI, docs | **Packaging, audit and docs done 2026-08-02; CI written and never run.** `scripts/package-visionos.sh` produces an audited ROM-free unsigned artifact carrying its own build provenance, and refuses a signed app by default. The README and release checklist are rewritten for this lane. Open: the hosted workflow has never executed on a runner | CI green, audited ROM-free unsigned visionOS artifact with its SHA-256 |
| 9 | Mode B, 6DoF (experimental) | **Written 2026-08-01; nothing about it is verified.** The engine renders stereo, the compositor feeds it per-eye geometry, and it builds and replays clean. Every claim about what it *looks* like is unmade: the Simulator reports one view, so Mode B declines there by design and only its fallback has been run | One track drivable in 6DoF with a legible HUD |

Stereo separation, immersion, comfort, and all PS VR2 Sense behaviour are
**device-only** claims: the Vision Pro Simulator renders the left eye only and
cannot emulate Sense controllers. No Simulator result may be written up as
proof of stereo.

### iPadOS (retired 2026-08-01)

| Phase | Gate | State | Required evidence |
|---|---|---|---|
| 0 | Repo scaffolding and pinned bootstrap | Complete | Clean bootstrap, exact revisions, disabled pushes, ignore checks, safety audit, clean-directory replay |
| 1 | Host oracle and clean port archives | Complete | macOS title, archive hashes, clean `spaghetti.o2r` audit |
| 2 | Patched libultraship iOS static library | Complete | arm64 iPhoneOS library, symbol audit, patch replay, macOS regression build |
| 3 | Full unsigned iOS app links | Complete | iPhoneOS app, platform/min-OS/bundle audit |
| 4 | Simulator title screen | Complete | Live Metal frame, logs, screenshot, no desktop dialog symbols |
| 5 | Lifecycle and audio | Complete | Three-cycle continuity, config flush, paused simulation, audible resume |
| 6 | Signed physical-iPad boot | Superseded 2026-08-01 | Signed install, title screen, ten-minute stability run |
| 7 | On-device Files extraction | Superseded 2026-08-01 (hardware replay never closed) | Clean-device extraction, failure recovery, measured time/RSS |
| 8 | Grip-first full-analog touch controls | Superseded 2026-08-01 (layout and A-hold slices passed; full GP never closed) | Full touch-only GP and analog/menu/lifecycle checks on hardware |
| 9 | iPad UX and imported texture pack | Superseded 2026-08-01 (Simulator UX/import slice passed; hardware pack GP never closed) | Touch-complete UX plus Reloaded import/enable/full-GP hardware gate |
| 10 | Controllers and split-screen | Superseded 2026-08-01 (Simulator routing/render slice passed; hardware sessions never closed) | Two-controller 2P session and measured 3P/4P decision |
| 11 | Tilt steering | Superseded 2026-08-01 (Simulator slice passed; hardware GP never closed) | Persisted, drift-free tilt GP on hardware |
| 12 | Package, CI, docs, release | Superseded 2026-08-01 (Preview 3 published; final update/save-preservation gate never closed) | Final physical update/save-preservation acceptance |

## Active gate

**Under review: the owner has questioned the ordering, and the objection is
sound.** On 2026-08-01, after the first hardware run, the owner stated that the
point of an immersive space is *"to allow the game itself to wrap around the
viewer in three dimensions"* rather than to build a synthetic room around a flat
screen — *"otherwise we might as well just use a window with a fixed
aspect-ratio."*

That is Phase 9, Mode B, which the queue below schedules last and marks
experimental. The flat screen of Mode A is now demonstrably real on hardware —
world-locked, stereoscopically placed, 90 Hz, every frame anchored — and it is
also, by the owner's measure, not the product. The queue's ordering is therefore
open rather than settled, and the immersive environment built for Phase 4 (sky
and floor) is scaffolding for a mode that may not be the destination.

What the work so far buys for Mode B, rather than being wasted by it: the device
anchor, the per-eye view and projection matrices, the measured 68 mm separation
and the per-view render passes are all prerequisites for drawing the *game* in
stereo. What Mode B additionally needs is inside the engine, not the shell —
Fast3D would have to run each frame's display list twice against per-eye view
and projection matrices substituted for the game's own, with the HUD's
orthographic passes handled separately so they stay legible.

**That objection has now been acted on rather than only recorded.** Mode B is
written — see the 2026-08-01 Phase 9 entry below — and the queue's ordering was
resolved in its favour rather than left open: the engine renders each frame's
display list once per eye against per-eye view and projection matrices
substituted for the game's own, with the HUD's orthographic passes handled
separately, which is precisely what the paragraph above said it would need.

What that changes about this section is smaller than it sounds. Mode B **builds,
replays clean from the pinned revisions, and passes the audit**, and every claim
about what it looks like is still unmade: a Simulator reports one view, Mode B
declines there by design, and only its Mode A fallback has been run. It needs the
same headset everything else here needs.

**Phase 7, ROM and texture-pack import**, is now closed on the Simulator: as of
2026-08-02 in-app extraction runs — and had to be built to, because it was
blocked by three defects the never-having-run had hidden. Phase 8's packaging,
audit and docs are done; its CI is written and unrun. **Phase 6, the settings
UI**, is closed on the Simulator as of 2026-08-02, and was likewise not merely
unwritten: the menu could not be opened on this platform by any input at all.
See the 2026-08-02 entries below.

**The newest open item is not a phase.** On 2026-08-02 a wearer's Mode B race
was killed at 5 min 50 s by `JETSAM_REASON_MEMORY_PERPROCESSLIMIT` against a
5120 MiB limit, on stock assets — no texture pack was rendering. The compositor
was given a memory report every 600 frames so the next wear would produce a
growth curve instead of only a reason, and on 2026-08-03 it did: 8065.9 MiB of
footprint with 126.1 MiB of headroom left, five minutes into a session with the
4K pack on. **A cause was found in that curve and fixed** — an evicted texture
cache entry left its GPU texture allocated, so the cache's byte budget bounded
the entries and nothing bounded the memory; see the 2026-08-03 entry below. It
is fixed in the build and **unmeasured on a headset**, and the report now carries
the two numbers that disagreed, so the next wear either confirms it or names
something else. Until a sustained wear says so, **every phase whose device half
needs a long session is still time-limited by this** — which is most of them,
including Phase 3's ten-minute stability run and Phase 6's device half.

Everything now open on the visionOS lane besides Phases 6, 7 and 8 is waiting on
an **Apple Vision Pro**, not on work:

- **Phase 2's device half** and **Phase 3's device half** were blocked on the
  missing ARKit device anchor. That blocker is gone — see the 2026-08-01 Phase 4
  entry below — and both are now attemptable the moment a headset is attached.
- **Phase 4's own gate** — measured stereo separation and a comfortable full
  race — is **closed**, both halves, on 2026-08-01. The separation was measured by
  the compositor on hardware at 67.0–70.7 mm; the race was driven by the wearer on
  PS VR2 Sense controllers, comfortably, and won.
- **Phase 5's** PS VR2 Sense half and every comfort claim are device-only for
  the same reasons. Its *binding* half is no longer waiting on anything — see the
  2026-08-01 Phase 5 entry below. The obstacle turned out not to be the headset:
  this lane's own window backend was discarding the SDL event that opens a
  gamepad, so no controller could have worked on hardware either.

A Vision Pro **is** paired with this Mac (`NEW AVP`, visionOS 27.0, Developer
Mode enabled) and as of 2026-08-01 it is **reachable again**: `devicectl` reports
it `connected` over a wired tunnel, and the signed Phase 5 build installs and
launches on it. Earlier entries recording it as `unavailable` with CoreDeviceError
4016 describe that day's state and are left as written.

Reachable is not the same as observable. The headset cannot be screenshotted —
`devicectl device capture screenshot` refuses on an Apple Vision Pro — and this
macOS's `log stream` has no `--device` option at all, so reading the device's log
needs `sudo log collect --device-udid`, which needs a real terminal rather than an
agent session. Every device result therefore still comes from a wearer, or from a
log archive a wearer collects.
[`docs/VISIONOS_DEVICE_ACCEPTANCE.md`](VISIONOS_DEVICE_ACCEPTANCE.md) is the
exact sequence for closing those halves when it is connected and worn.

Boundary:

- **The Vision Pro Simulator renders the left eye only.** No Simulator capture
  may be presented as evidence of stereo, and no Simulator run can demonstrate
  world-locking, under any circumstances. Its head is not quite as fixed as
  earlier entries say — with a Simulator.app window open the camera moves and the
  logged head position moves with it — but that is a window's camera, not a
  wearer, and it settles nothing about world-locking.
- Phase 3 put the engine on a flat screen inside the immersive space and Phase 4
  fixed that screen in the room around it. Neither made the game stereoscopic:
  both eyes see the same flat picture, differing only in where that picture
  sits. That is the intended Mode A, and 6DoF remains Phase 9.
- Import entry points in `visionos/SpaghettiPadBridge.h` remain explicit logged
  refusals. The **input** entry points no longer are — nothing in the shell
  routes the ordinary pad and nothing needs to, because the engine's own control
  deck does, and `SpaghettiPad_AttachAccessoryTracking` and the motion-steering
  entry points are now implemented in
  `visionos/SpaghettiPadAccessorySteering.mm`. **Implemented is not verified**:
  6DoF steering has never run, because the Simulator has neither spatial
  accessories nor accessory tracking. **Audio works** — the
  SDL/CoreAudio path is live and
  a wearer has heard it on device; the earlier "no audio" boundary was an
  untested assumption about `MA_NO_DEVICE_IO`, which disables miniaudio only.
- The active toolchain is Xcode 27.0 beta (`27A5218g`). No release artifact
  may be published from it without saying so in the release notes.

### Superseded iPadOS gate (recorded 2026-07-29, closed unmet)

The iPadOS lane's last open gate was owner hardware replay of Phases 6–11 plus
the final Phase 12 update/save-preservation acceptance. Those were never
closed and are not claimed. The recorded boundary at the time of the pivot:

- Phase 5 proved Simulator lifecycle continuity, durable config flush,
  simulation/audio pause and resume, live rendering continuation, container
  integrity, and human-confirmed audible music/audio.
- Simulator evidence did not prove signing, installation, watchdog behavior,
  or audio on physical hardware. Touch, extraction, performance, controller,
  and texture-pack behavior also remained unclaimed on hardware. Local
  packaging proved artifact contents, not device installation or runtime
  behavior.

## Evidence log

### 2026-08-03 (build + Simulator) — The texture cache's budget was never the process's: an evicted entry kept its GPU texture, and a thousand slots of a 4K pack is eight gigabytes

**What a wearer's log said.** Loading Frappe Snowland, 28,201 frames in — five
and a quarter minutes at 90 Hz:

```
memory: 8065.9 MiB footprint, 126.1 MiB before the limit, 7893.3 MiB consumed since the first of these
```

Everything else in that snapshot was healthy: 28,201 drawables anchored and none
missed, 56,180 eye encodes in Mode B, no command buffer failures. The first
sample of the session had ~8019 MiB of headroom and the last had 126, so the
process took nearly the whole of an eight-gigabyte limit in five minutes and was
about to be killed for it.

**Whether a texture pack was loaded in that session is not recorded anywhere in
it** — the mechanism below is the reason to think so, not evidence of it, and
that inference is exactly what the new `textures:` line exists to stop having to
make. It also means **this does not explain the 2026-08-02 kill**, which a wearer
confirmed happened with no pack rendering: at stock N64 texture sizes the leak
below is worth single-digit megabytes. That one is still open and still
unprofiled.

**The byte budget added on 2026-08-02 was working. It was bounding the wrong
thing.** That budget caps what the Fast3D texture cache's *entries* are worth and
evicts from the LRU end past 1 GiB, and it does evict. What it never touched was
the texture behind the entry:

- `Interpreter::EvictTextureCacheLru` dropped the entry and pushed its texture id
  onto `free_texture_ids` for reuse.
- A texture id is an index into the Metal backend's own `mTextures`, and
  `GfxRenderingAPIMetal::DeleteTexture` was **an empty function body**. Nothing
  called it either; upstream never has.
- So the `MTL::Texture` in that slot stayed allocated until an upload of
  *different dimensions* happened to land in the same slot —
  `GfxRenderingAPIMetal::UploadTexture` releases the old one only when the size
  changes.

Live texture memory was therefore the high-water mark of *the largest texture
ever placed in each slot*, across a pool that grows to `TEXTURE_CACHE_MAX_SIZE`
= 1024. At N64 sizes that is a few megabytes and invisible, which is why it
survived upstream. At MK64 Reloaded's sizes one slot is worth up to 64 MiB, and
1024 slots averaging 7–8 MiB is the 8 GiB in the log. The cache reported itself
inside its budget the entire way, because from where the cache stands it was.

**What changed.**

- `GfxRenderingAPIMetal::DeleteTexture` frees the slot's colour texture, its MSAA
  texture and its sampler, and forgets the framebuffer bind-caches that name them
  by address — those skip a redundant bind by comparing pointers, and the
  allocator is free to hand a released address straight to the next texture. It
  refuses ids that belong to a framebuffer, which are not the cache's to free.
- The interpreter now calls it. Evicted ids go to a new
  `evicted_texture_ids` list and are freed by `ReleaseEvictedTextures` at the top
  of the next frame, not at the point of eviction: eviction runs mid-draw from
  `RecordTextureUpload`, with an encoder still open, and Metal holds its own
  reference to anything a committed command buffer names.
- Every route that drops an entry now does the same three things. `TextureCacheDelete`
  did none of them: it left the bytes booked against the budget (which spends the
  budget evicting entries that are still wanted), left the decoded resource
  loaded, and recycled the id. `TextureCacheClear` released neither resources nor
  textures. Both now match eviction, and `Destroy` releases what it clears —
  which matters because the engine can be stopped and started inside one process.
- `InvalidateBoundTextures` tells the draw path its bindings are stale whenever
  entries go away. The draw path re-imports a tile only when the RDP says that
  tile changed, so a binding could outlive its cache entry; that used to mean
  stale pixels, and with the texture actually freed it would have meant sampling
  an empty slot.
- The compositor's every-600-frames report gains the line that would have named
  this in one wear:

  ```
  textures: N MiB live on the GPU in N, N MiB billed to N cache entries, N evicted so far
  ```

  The GPU figure is `MTL::Resource::allocatedSize` summed over every texture the
  backend holds — the device's own accounting, not an estimate of it — and it is
  precisely the number that disagreed with the cache's. `SpaghettiPad_EngineTextureMemory`
  carries it across the shell boundary; the counters are atomics published once a
  frame, so the compositor thread reads last frame's figures rather than a torn
  view of this one's.

**What the Simulator showed.** visionOS 27 Simulator, the MK64 Reloaded 4K pack
in the container's `mods/` with `gEnhancements.Mods.AlternateAssets` on, Mode A
because the Simulator reports one view. The pack loads, the cache fills, and then
the new line holds still:

```
11:38:38  memory: 1069.2 MiB   textures: 1068.9 MiB live on the GPU in 1005, 1023.8 MiB billed to  993 entries,  270 evicted
11:39:38  memory:  659.3 MiB   textures: 1063.8 MiB live on the GPU in  922, 1023.7 MiB billed to  915 entries, 3458 evicted
11:40:28  memory:  552.6 MiB   textures: 1063.4 MiB live on the GPU in 1001, 1023.3 MiB billed to  994 entries, 4887 evicted
```

**4,617 evictions in under two minutes and the GPU figure moved by −5.5 MiB.**
Before this change every one of those evictions left its texture allocated. The
~40 MiB by which the GPU figure sits above the cache's is the framebuffer, its
depth target and the pattern texture, which the cache does not bill. No command
buffer failed.

Two things that result is *not*. The Simulator's Metal answers 0 for
`allocatedSize`, so the figure above is the geometric fallback rather than the
device's own accounting — the first run of this counter reported 1,005 live
textures worth 0.0 MiB, which is how that was found. And the Simulator's texture
memory is host GPU memory, which is why the footprint sits *below* the texture
tally there; on a headset's unified memory it is the same pool. This run proves
the release path runs, that the tally is bounded, and that eviction under a
saturated budget does not fault. It measures nothing about a headset.

**One thing found while regenerating the patches.** `Spaghettify.entitlements` —
which carries `com.apple.developer.kernel.increased-memory-limit`, and therefore
the whole difference between a 5120 MiB limit and the ~8 GiB one the log above is
measured against — existed only in the working tree and in a stale Xcode index.
It was in no maintained patch, so a clean replay produced no such file. It is now
a new-file hunk in `patches/spaghettikart-visionos.patch`. Note that nothing in
the maintained CMake references it: the `Debug-xros` build that picked it up did
so through a generated project, so **the raised limit is not yet reproducible
from `scripts/build-visionos.sh` alone** and is recorded here as an open thread,
not as a fixed one.

**Boundary.** Built for device and Simulator, audited, patches regenerated and
reverse-checked. **Not worn.** No measurement of the fixed footprint exists, and
none can come from a Simulator: this is a texture-pack-under-load claim, and the
Vision Pro Simulator renders one eye and no headset memory limit. That the leak
above is *the* cause of the 8065 MiB rather than *a* cause is inference — from
the code path and from the arithmetic matching — and the `textures:` line is
exactly what would confirm or refute it on the next wear. If the GPU figure now
tracks the cache figure and both hold flat across a promo loop, the budget is the
process's budget; if the footprint still climbs while both hold, something else
is allocating and this entry names the wrong culprit.

### 2026-08-03 (build + Simulator) — Progressive immersion: the Digital Crown dials the world open, which cost the `dedicated` layout and cannot be run on a Simulator at all

**What changed.** The immersive space opens under
`.progressive(0.35...1.0, initialAmount: 1.0)` on a headset, so the Digital
Crown winds the game between a window in the wearer's room and the fully
immersive space this app was before. At the top of the dial it is the space it
has always been, so a wearer who never touches the Crown loses nothing.

**The layout decision from 2026-08-01 is reversed, and had to be.** Progressive
immersion draws its portal through a `cp_drawable_render_context_t`, and a
render context accepts no layout but `layered` on a drawable with more than one
view. `dedicated` was chosen precisely to avoid `layered`, because under
`layered` the headset returns one rasterization rate map whose per-eye layer is
selected by a `render_target_array_index` these shaders did not emit, and the
wearer saw a clean grid in the left eye and a warped one in the right. That exit
is now closed, so the renderer does what that entry said it declined to do:

- Every vertex program — pattern, screen, eye, sky, floor — takes a
  `view_layer` uniform at buffer index 3 and emits it as
  `[[render_target_array_index]]`. Not vertex amplification: the eye is still a
  separate draw, so Mode B can still bind a different texture per eye.
- `EncodeViews` collapses to one layered pass over the whole texture array,
  with the viewport and layer index set per view inside it. The per-view-pass
  shape is kept for a single-view drawable and any dedicated/shared fallback.
- `PublishViews` now asks the rate map for the layer belonging to the view
  rather than layer 0, which under one map with two layers was the same answer
  only by the coincidence that both eyes are the same size.

**Two defects were found by running rather than by reading, and both were in
this change.**

- **The render context is mandatory, not an optimisation.** It was written as
  the thing that draws the stencil mask and gated, with the mask, on a stencil
  format. The Simulator offers no render-context stencil format, so no context
  was added, and `cp_drawable_encode_present` aborted the process on the first
  frame: `BUG IN CLIENT: cannot present drawable: need to use drawable render
  context when supporting progressive style.` The two are now separate — the
  context is added whenever the layer can give one, and the stencil mask is an
  optimisation layered on top of it that saves shading the pixels outside the
  portal.
- **The layered layout does not imply an array to index.** A pass declared
  `renderTargetArrayLength` from the view count instead of from the texture.
  This turned out not to be the Simulator's problem — its texture is
  `MTLTextureType2DArray` with one slice, logged now as `type 3, 1 slice(s)` —
  but the pass and the shader now both follow the texture, because that is what
  Metal executes against.
- **The render context is claimed on the command buffer, so it must be claimed
  before an encoder is open on it.** Found by a wearer, not here.
  `cp_drawable_add_render_context` takes the command buffer rather than the
  encoder because it encodes on it, and it was being called from inside the
  encoder's own setup. A headset answered:

  ```
  -[IOGPUMetalCommandBuffer encodeWaitForEvent:value:timeout:], line 511:
  error 'encodeWaitForEvent:value: with uncommitted encoder'
  ```

  The order is now Apple's: add the context, open the encoder, draw the mask
  into it, end through the context. **The Simulator never reproduced this and
  cannot**, which is why it survived to a headset: under `.full` the render
  context has no portal to draw and encodes no wait, so the same wrong order ran
  1801 clean frames there. A Simulator run is evidence that this lane still
  works, not that this defect is fixed.
- **The mask draw is a foreign draw on this renderer's encoder, and it leaves
  state behind.** Also found by a wearer. The compositor masks both eyes at once
  through vertex amplification and leaves the encoder amplifying two views; this
  renderer amplifies nothing, because the eye is a separate draw and that is
  what lets Mode B bind a different texture to each. So its pipelines allow a
  count of one, and the first draw after the mask asserted outright:

  ```
  Vertex Amplification Count (2) must be between (inclusive) 1 and the maximum
  vertex amplification count specified in the pipeline state (1)
  ```

  `draw_mask_on_stencil_attachment` documents that it modifies the depth-stencil
  state, the viewports, the vertex amplification count and some texture
  bindings, and says to set them back. Three of the four were already being set
  per view by `EncodeViewContent` and had hidden the omission of the fourth. The
  amplification count is now restored where the mask is drawn, and the cull mode
  is set explicitly beside it — not for a failure that has been seen, but
  because "no cull mode is set anywhere in this file" stopped being true the
  moment a draw this file did not encode ran on its encoder, and the sky is a
  box drawn from the inside.

**All three defects were device-only, and for one reason.** Each lives in the
code that runs only when a portal has a real shape to cut, and the Simulator
offers no render-context stencil format at all — so the entire masked branch is
unreachable there. The Simulator can prove this lane still renders. It cannot
prove anything about progressive immersion, and it did not.

**The Vision Pro Simulator cannot run progressive immersion, and this was
isolated rather than assumed.** A progressive-style frame fails on its GPU with
`MTLCommandBufferErrorDomain error 1`, takes the simulator's Metal service down
with it, and every later Metal call in the process aborts through XPC —
`MTLSimulator_encountered_XPC_error` on the engine thread, allocating its next
frame. Metal API validation is enabled and silent throughout: the encoding is
legal, the execution is not. The identical build under `.full`, with the same
layered layout, the same array index in every vertex program and the same render
context in the loop, presented **1801 frames at 60 Hz with 0 command buffer
failures**. The only difference between the run that dies on frame 1 and the run
that does not is the immersion style. Consistent with the Simulator offering no
render-context stencil format at all, and with CompositorServices' own headers
saying of this API that it "is not available on simulator".

So `SpaghettiPadApp.initialImmersionStyle` is `.full` under
`#if targetEnvironment(simulator)` and progressive only on a headset. The
Simulator lane keeps the fully immersive space every earlier result here was
collected under, and the progressive style joins stereo, world-locking and
comfort as a device claim.

**What was run.** `scripts/build-visionos.sh --device` completed with
`** BUILD SUCCEEDED **` and passed the audit; the Release arm64 xros executable
SHA-256 is
`7fede0793c82b43c2913ad2ad8b71992ad1937d798ed2111e240a97761471033`.
`scripts/build-visionos.sh --simulator` likewise, and the Simulator ran **1801
frames at 60 Hz, 1784 of them showing the engine, 0 command buffer failures,
1801 drawn through a portal** — which exercises the new single-pass layered
encoder and the render context, under `.full`.

**Boundary — everything about the Crown itself is unclaimed.** No headset has
run this. The portal's shape, its edge fade, whether it is identical in both
eyes, whether the foveation warp that `dedicated` was chosen to avoid stays away
now that the array index is emitted, and whether dialling down mid-race is
comfortable are all unmeasured, and none of them can be measured on a Simulator
that renders one view and refuses the style outright. The stencil mask has
**never executed anywhere** — the Simulator offers no format for it, so only a
headset will run that branch. `docs/VISIONOS_DEVICE_ACCEPTANCE.md` gains the
procedure. One design question is left open there rather than answered here:
Mode A draws a synthetic sky and floor so head motion has something to register
against, and at a low immersion amount the wearer's real room is already doing
that job.

### 2026-08-02 (build only) — The settings menu is native: the engine publishes its widget tree and SwiftUI draws it

**What changed.** The 119-widget settings menu is a real visionOS window — `Form`,
`NavigationSplitView`, system controls, system type — instead of ImGui drawn into
the game's own framebuffer and read at two metres.

**Why it is a bridge and not a rewrite.** Upstream already declares the menu:
`PortMenu::AddSettings()` and its siblings build a tree of `WidgetInfo`, each
carrying a label, a CVar, a type, an options struct and a tooltip. Hand-writing
119 SwiftUI controls against that would have produced a second source of truth
that goes stale the first time upstream adds a checkbox — and this project tracks
a pinned upstream it does not control. So the tree is **walked and published as
JSON**, and the Swift side is a renderer for whatever it finds. There is no
switch on a *setting* anywhere in the Swift; only on a widget's kind. A setting
added upstream appears without a line changing.

**Threading, which was the whole of the difficulty.** The tree, the CVars and the
widgets' own callbacks are engine-thread state; SwiftUI is the main actor.
Nothing crosses that line directly. The engine builds a snapshot at the top of a
frame and publishes it under a mutex; the shell copies the last published one and
never blocks on a frame. The shell queues changes; the engine drains them at the
top of the next frame and runs each widget's callback **there**, which is the
thread ImGui would have run it on. Both halves follow `ApplyPendingReset`, which
this project already used for exactly this shape of problem. A consequence worth
stating: a toggle does not change its own value. It asks, and the next poll — 66
ms — shows the answer.

**The failsafe, and why it is shaped this way.** `Menu::Draw` skips its ImGui
body only while `SpaghettiPad_MenuUsesNativeWindow()` says a native window is
*actually on screen* — set by the window's own `onAppear`, not by the request to
open it. If SwiftUI never presents the window, ImGui keeps drawing and a wearer
is never locked out of their settings. The menu still becomes *visible* either
way, with the same input blocking and the same visibility CVar, so the two front
ends are interchangeable with no state to unwind.

**What stays ImGui, deliberately.** The five Developer windows — Gfx debugger,
stats, console, scene visibility, freecam — are ImGui windows that draw their own
contents; the native menu opens them exactly as the ImGui menu did, and the
control shows whether each is open. The resolution editor draws raw ImGui and is
skipped rather than half-rendered. A widget type this build does not know how to
draw is **named on screen** rather than dropped, because a silent omission is how
a settings window quietly loses a feature upstream added.

**Boundary.** Built and never worn. The Simulator builds and links it and the
symbols are in the binary; whether a `NavigationSplitView` presents correctly
alongside a `.full` immersive space, whether the window is reachable and readable
mid-race, and whether closing it actually unblocks game input are all first-run
questions on a headset. The 66 ms poll and the JSON encode per frame are
untested against a running game's frame budget — polling is off unless a window
is open, which bounds the risk but does not measure it.

### 2026-08-02 (build only) — 6DoF steering: the Sense pair's pose finally has somewhere to go, and not one line of it has run

**What changed.** `SpaghettiPad_AttachAccessoryTracking` and the three
motion-steering entry points stop being explicit logged refusals and become
`visionos/SpaghettiPadAccessorySteering.mm`. Holding both Sense controllers where
a steering wheel would be steers the kart.

**The measurement, and why it is that one.** Not the raw height difference
between the hands, which was the obvious reading of the idea and is wrong: the
same 10 cm is a gentle lean with the hands wide and a hard turn with them close.
What is measured is the **angle** above horizontal of the line from the left grip
to the right grip — `asin(Δy / separation)` — which is the same number a wheel's
rim reports and is independent of grip width. It is also independent of which way
the wearer is facing, because `y` is gravity in ARKit's world origin and
chirality names the hands rather than the room. Positive is right-hand-high,
which is a wheel turned anticlockwise, which is a left turn, which is negative on
an N64 stick; the sign lives in one place.

**Two paths, and only one of them was ever the problem.** GameController merges
the pair into one combined gamepad — that is the 2026-08-01 finding and it has
not changed. ARKit's accessory tracking is a separate path that reports each
controller individually with a chirality, through
`GCSpatialAccessory.spatialAccessories`. That API is **visionOS 27**, as is
`ar_accessory_tracking_provider_update_accessories`, so the whole feature is
gated on 27 and says so on 26 rather than half-working.

**Where it joins, and the risk that shaped the design.** ARKit permits one
`ar_session_t`, and the one this app has is the session every drawable's device
anchor comes from — lose it and the headset renders nothing. So the accessory
provider is composed into the provider set **before** `ar_session_run`, rather
than re-running a live session when a wearer flips the setting. It is declined
outright, with a log line, if ARKit reports a required authorization this bundle
declares no usage string for, because a missing usage description is a process
kill rather than a polite failure. The session state-change handler now names
which provider changed, which it did not need to when there was only one.

**Where the axis lands.** `ControlDeck::WriteToOSContPad`, after every controller
has been read, writing port 0's `stick_x` in the N64's own ±85 units — not as a
device, because there is no SDL joystick behind it and nothing for the Input
Editor to bind. A real thumbstick past ±8 takes it straight back.

**Tuning, and what is honestly inherited.** The retired iOS tilt path's filter
and deadzone carry over; its full-lock angle does not, and the header that
promised all three has been corrected. 0.45 rad was tuned for a wrist rolling a
phone, and the same 26° across a two-handed wheel is inside the noise of
unsupported arms. Full lock is 0.70 rad (40°) with a 0.5x–2.0x slider around it.
The filter carries over as its **time constant** rather than its alpha: 0.18 per
sample only means what it meant at the 60 Hz CoreMotion was polled at, and
accessory tracking promises no rate, so alpha is recovered from the measured
interval each update.

**Boundary — and it is the whole of this entry's weight.** **Nothing here has
run.** The Vision Pro Simulator reports no spatial accessories and
`ar_accessory_tracking_provider_is_supported()` is false there, so this is the
first feature in this lane with no Simulator half at all: it compiles for
xros and xrsimulator, it links, the symbols are in the binary, and that is the
entire claim. Unverified and first-run on hardware: that a session carrying two
providers still renders; that the pair arrives as **two** accessories rather than
one, which is the assumption the whole scheme rests on; the sign; the 40°; the
feel; and whether the grip location resolves at all. `docs/VISIONOS_DEVICE_ACCEPTANCE.md`
carries the acceptance steps in the order they should be tried.

### 2026-08-02 (seventh wear) — The HUD panel was exactly where it was told to go, and what was wrong was the pose it was told to go in front of

**The report.** The game's HUD and menu screens show with the **top-right corner
of the HUD at the wearer's visual centre**, so the whole 2D layer sits down and
to the left of where they are looking. Asked whether it follows their head or
stays put in the room, the wearer answered: **it stays put in the room.**

**That answer is the diagnosis, and it clears the projection.** The panel is a
fixed object in the recentre frame, and `BeginStereoEye` finds it each frame by
projecting its centre through that eye's own pose — so a panel that stays put
while the head turns is a panel whose placement is working exactly as written.
The arithmetic was re-derived against `BuildEyeFrustum` and `EyeTangents` and
inverts it exactly: NDC x is `(x/depth − ½(R−L)) / halfWidth`, which is the
frustum read backwards, and the same for y. Nothing in the panel maths is wrong.

**What is wrong is one line in the compositor: `if (!roomPlaced_ && pose.state
== tracked)`.** The room — Mode A's screen, Mode B's recentre frame, the floor
and the sky — was hung off **the first fully tracked pose that arrived**, which
is whatever direction the wearer's head happened to be pointing in the instant
the immersive space finished opening. Half the HUD panel is 21.8 degrees wide
and 16.7 degrees tall (0.88 m and 0.66 m at 2.2 m), so a head that settles about
that far right of, and above, the placement pose puts the panel's top-right
corner precisely at the visual centre. The wearer's description is that geometry
read back to us.

Mode A hangs off the same pose and the same instant, deliberately, so the two
modes agree — which means this has always been a Mode A defect too, and was
simply less visible on a 1.6 m screen with no HUD to be off-centre *within*.

**Changed, first half: the room waits for a still head.** From the first tracked
pose the compositor watches the two quantities a placement actually reads —
where the head is, and which way it faces along the floor — and places the room
once both have held to within 3 cm and 3 degrees for half a second. Pitch and
roll are not watched because `PlaceScreen` and `PlaceRecentre` drop them: a
wearer who settles while looking down at a pair of controllers still gets a
level room facing the way they are facing. If the head never holds still, the
room is placed anyway after four seconds and says so in the log, because Mode B
publishes no views until a room exists and an unplaced room is worse than a
roughly placed one.

**Changed, second half: it can be moved.** Holding **both shoulders and both
triggers together for one second** re-places the whole room from the current
pose. The chord is read in the shell, above SDL, straight off the
GameController framework and merged across every controller it holds — a Sense
pair can arrive as two devices, and this gesture wants a hand on each — and it
installs nothing on them, because SDL's MFi driver owns their
`valueChangedHandler` and taking it would take the game's input with it. It is a
chord rather than a button because every button is something Mario Kart 64 does
and the two stick clicks are already the settings menu; a recentre that fired
mid-race would move the world under someone at speed, which is the one thing in
this app that can make a person ill. The left shoulder is the safety pin: `L` is
unused in Mario Kart 64, so dragging a shell through a drift — left trigger and
right shoulder — cannot reach it. One hold fires once; the chord must be
released before it can fire again.

The engine needed no change at all. It reads `eyeFromRecentre` out of the
published views every eye of every frame, so a room that moves is picked up on
the next frame by construction.

**What the log will now say.** The placement line carries the head's own
position, which is the number a future "the HUD is off to one side" report has
to be read against: the panel is fixed in the frame placed there, so the
difference between that pose and the pose the wearer is in when they complain is
the whole answer. A timed-out settle logs that it timed out; the chord logs its
edges from the shell and its firing from the compositor, so an archive can
separate "the chord was never completed" from "it was, and the room did not
move".

**Boundary.** **Built and unworn.** Both the device and Simulator apps build and
the device app passes the audit (`arm64`, unsigned, archive content
`5ab6f5d8…`). Nothing here has been on a face: the settle has never run against
a real head, no chord has ever been held on real hardware, and whether the
thresholds are right is a wearer's measurement. This also does not touch either
maintained patch — every line is in `visionos/` — so no patch was regenerated.
The wearer's report is **explained** rather than fixed: what has been fixed is
the pose the room is placed from, and only a wear can say whether that puts the
HUD where they are looking.

### 2026-08-02 (sixth wear) — The fill boxes are gone, confirmed on a face. What was left standing behind them is a fade the wide helpers turned into a square, and half a controller

**The report.** The black boxes below are fixed. Two things remain: a square that
appears as the main menu loads and unloads, and a pair of PS VR2 Sense
controllers — powered on after launch — whose buttons drove the game while the
sticks did nothing, so nothing could be steered or selected. A `log collect`
archive was taken.

**The fill-box fix is worn and confirmed.** That is the first wearer-confirmed
Mode B fix since the camera factorisation, and it retires the fifth-wear entry's
open boundary. It says nothing about the four other fixes riding in the same
build; they drew no complaint, which is not the same as being checked.

**The square is the menu's full-screen fade, shrunk by the game's own widescreen
helpers.** `func_8009DAA8` fades the menu with
`draw_box_wide(0, 0, 320, 240, black, alpha)`, and `draw_box_wide` emits its
rectangle through `OTRGetRectDimensionFromLeftEdge` /`...FromRightEdge`. Those
extend 4:3 content out to a wider screen, and both derive their extension from
`OTRGetAspectRatio`, which returns `mCurDimensions.aspect_ratio` — the aspect of
the surface the engine renders into. In Mode B that surface is **one eye's
viewport, 1856×1792, aspect 1.04**, which is *narrower* than 4:3. So the helpers
inset where they mean to extend: `160 − 120 × 1.04 = 35`, and the fade is emitted
as `(35, 0, 285, 240)` — a 250×240 box, square to within four per cent, floating
in the middle of the panel. Not full width, so it lands on the HUD panel rather
than the backdrop, in front of the wearer, exactly as reported. It is a
pre-existing defect that the black boxes were hiding, not a consequence of
removing them.

**Changed, first half.** `OTRGetAspectRatio` answers 4:3 while Mode B is engaged. That is the
truthful answer for this mode rather than a special case: the game's 2D is
composed onto the HUD panel, which `BeginStereoEye` builds at 4:3 by
construction, and its 3D goes through a projection the eye replaces outright,
keeping only near and far, which have no aspect in them. At 4:3 both edge helpers
reduce to the identity, which is what a 4:3 panel wants, and it is the game-side
half of the same decision the interpreter already makes when it skips
`AdjXForAspectRatio` for a rectangle bound for a panel. The other callers are
unaffected or improved: the main race cameras use `gScreenAspect`, not this;
`framebuffer_effects.c` only crops when the ratio exceeds 4:3, which neither
value does; the sky's culling factor widens slightly, which is the direction that
helps a wearer looking off-axis.

**Changed, second half — a fade must fade the world, not a rectangle in front of
it.** The first half only restored the fade to the full 4:3 frame, and the
wearer's verdict on that was that fading a 4:3 box is no good either: it has to
take the whole view or not be drawn. It has to. Every menu transition is the same
primitive — `D_8018E810[4]` is fixed at `SCREEN_WIDTH × SCREEN_HEIGHT` and
`D_8018E7E8[4]` at its centre, so `draw_fade_in`, `func_8009D77C` and
`func_8009DAA8` all emit `draw_box_wide(0, 0, 320, 240)` and animate the *alpha*,
never the size — and at 4:3 that is exactly the framebuffer, ±1 in both axes.

So the placement rule stops naming a cycle and names a purpose: **an untextured
rectangle covering the whole frame is a veil over the view** — a clear, a fade, a
wipe at full extent — and keeps its framebuffer coordinates instead of going to a
panel. Left there it covers the eye: `AdjXForAspectRatio` widens x past both
edges of a viewport narrower than 4:3, and y already spans the frame. Nothing
else changes hands. A veil has no distance to be placed at and no orientation to
disagree between the eyes, which is why the mirrored-frustum asymmetry that
"reversed" the textured backdrop on the fourth wear cannot reach one: flat colour
looks the same through two canted frustums. That is also why the test needs the
untextured half — `GfxDpFillRectangle` passes it, `GfxDpTextureRectangle` does
not — since a *picture* covering the frame is still a picture and still has to
hang somewhere.

The rule now reads: an image goes on a panel; flat colour goes on a panel unless
it covers the frame, in which case it covers the view. That is one sentence where
there were three exclusions, and each of the three had been wrong once.

**The controllers: the app was running on half a pair, and the archive says which
half.** From `avp.logarchive`, one launch, PID 1695:

| Time | Event |
|---|---|
| 17:14:45 | app launches |
| 17:14:57.502 | `no game controller is connected` — both Sense controllers were off |
| 17:15:29.65 | the **right** Sense pairs over Bluetooth |
| 17:15:30.78 | it reaches the app: `Connected devices changed (1 added) -> [3]`, `'Spatial Controller'/'PlayStation VR2 Sense Controller (R)'` |
| 17:15:30.85 | the app reports `1 game controller(s) connected: PlayStation VR2 Sense Controller (R)` |
| 17:15:30.80 | the **left** Sense pairs over Bluetooth |
| 17:15:32.14 | `gamecontrollerd` builds its logical device and names 1695 the active process |
| 17:15:32.15 | `Publish Controllers` to the app |
| 17:15:32.18–32.28 | `situationalawarenessd`, `backboardd`, `matted` and `RealityHUD` all add the left controller, reaching two |
| — | **the app never does.** Its device list stays at the right Sense for the rest of the session |
| 17:15:37.04 | `port 0 first input reached the game: buttons 0x0009, stick (0, 0)` |

The left thumbstick is on the left controller. Mario Kart 64 steers and moves
menu selections with the left stick and accelerates with a face button, and the
face buttons are on the right controller — so the symptom is exactly what half a
pair produces. The engine's own path is fine: `RefreshConnectedSDLGamepads` opens
every gamepad SDL enumerates and marks all of them ignored on ports 1–3, so both
halves of a pair drive port 0 as one controller. It only ever had one to open.

**What is not yet known, and what was added to find out.** Three layers could
have dropped it — the framework never delivering it, SDL's MFi driver refusing it
(`IOS_AddMFIJoystickDevice` frees a device it cannot read and logs nothing, which
a half-pair with no face buttons could well hit), or the
`SDL_CONTROLLERDEVICEADDED` event being lost before
`Ship::SDLAddRemoveDeviceEventHandler` acts on it, which this lane has suffered
once before. The archive cannot separate them: it shows the framework's own
`Connected devices changed` line absent from this process, but an absent debug
line is not proof. **A rescan would not settle it either** — SDL's MFi driver
builds its device list from notifications alone, so `SDL_NumJoysticks` cannot see
what the notification never carried. So the shell now watches
`GCControllerDidConnect`/`Disconnect` itself, above SDL, logs every controller
the framework hands this process, and two seconds later logs an error when the
framework holds more than the game does. That names the layer on the next wear:
if the framework offered the left Sense, the loss is this project's and fixable;
if it never did, it is not, and the answer is to connect the pair before
launching.

**Boundary.** Both changes are **built and unworn** — Simulator and device
libraries and apps compile, and both patches reverse-apply clean against the
built trees. Mode B declines in the Simulator, so neither the aspect answer nor
the controller watcher has run in the mode that needs them. The controller change
diagnoses; it fixes nothing by itself, and no second controller has been seen
reaching this app since.

### 2026-08-02 (fifth wear) — Black boxes hanging in front of the wearer's face in the menus: an exclusion named a whole cycle when it meant the clears inside it

**The report.** Floating black boxes while navigating the game menus, fixed in
front of the face as the wearer looks around, masking a different part of the
view on each screen — which the wearer read, correctly, as coming from the
individual menus.

**What they are.** Mario Kart 64 draws menu furniture in fill cycle, not only its
clears. `menu_items.c`'s `draw_box_fill` sets a fill colour and fills a box;
`func_80098FC8` is that with the colour fixed at opaque black; `draw_box_fill`
under `draw_flash_select_case` is the pulsing highlight beneath a selection; and
`func_80098FC8_wide` is the cinematic borders. `StereoRectOnPanel` excluded the
whole of `G_CYC_FILL` — literally `cycleType != G_CYC_FILL` — on a reason
recorded 2026-08-01 that only ever described the clears: "G_CYC_FILL is how this
game clears; a clear has no distance to be placed at."

So every one of those boxes kept raw framebuffer NDC while the rest of the menu
was placed on the HUD panel. Raw NDC in an eye's render target is that eye's
**entire field of view**, at the near plane, head-locked — so the 63×17-pixel
black box behind a menu readout became a full-size black rectangle pinned to the
face, in front of text that had meanwhile shrunk onto a 4:3 panel 2.2 m out.
Different screens fill different boxes, which is the mask that changes.

**Changed.** A fill-cycle rectangle is excluded only when it covers the frame.
The two things the old exclusion was written to protect are already protected
elsewhere and do not need the cycle test: `GfxDpFillRectangle` widens a fill
matching the native frame so a clear still covers a wider viewport, and it routes
a fill whose colour image is the z-buffer — `init_z_buffer` and its splitscreen
counterpart, full-frame or partial — down `ClearDepthRegion` and returns before
any rectangle is built. What is left is furniture, and it now takes the same
panel rule every other rectangle takes: full-width to the backdrop panel,
anything narrower to the HUD panel with the text it sits behind. The cinematic
borders, being full-width bars, therefore go behind the world rather than
staying as black bands across the wearer's view. `StereoRectOnPanel` takes all
four NDC bounds now, since coverage is what it tests rather than width.

**Boundary.** Built and unworn. libultraship compiles for both
`arm64-apple-xros26.0` and `arm64-apple-xros26.0-simulator` with `__VISIONOS__`
defined, and `interpreter.o` carries
`Fast::Interpreter::StereoRectOnPanel(float, float, float, float, unsigned int) const`
in each; `libultraship-visionos.patch` was regenerated and reverse-applies clean
against the built tree. Nothing was seen: the Simulator reports one view, so
Mode B declines there and no fill rectangle in this change has ever been drawn
onto a panel. **Which build produced the report is not recorded**, so this entry
claims nothing about whether the five fixes before it have now been worn.

If black boxes survive this, two suspects, in order. The settings overlay is a
different draw path from the game's own menus and this change does not touch it.
And the scissor never follows a rectangle onto the panel: `gDPSetScissor` is
applied in framebuffer coordinates against the whole eye, so `menu_items.c:6967`,
which scissors a menu to `(0, 0, 319, 194)`, clips panel-placed 2D by a rectangle
that was never moved with it. A capture of both eyes, not a verbal report, is
what settles either.

### 2026-08-02 (Phase 6, and a wearer's crash) — The settings menu could not be opened at all on this platform; now all thirteen pages are reachable from a pad. Separately, a Mode B race ended in a jetsam kill, and the app had been silenced by the OS four minutes before it

**Phase 6 was not "not started". It was unreachable.** The gate reads "every
settings page operable with a controller alone", and on visionOS the menu could
not be opened by any means whatsoever. Three things, each of which alone was
enough:

1. **No gamepad input reached ImGui, ever.** The visionOS ImGui platform half
   (`VisionOSNewFrame`, added in the Phase 2 work) replaced
   `ImGui_ImplSDL2_NewFrame` because there is no SDL window to wrap. That
   function is also the only caller of `ImGui_ImplSDL2_UpdateGamepads`, so
   every `ImGuiKey_Gamepad*` sat at rest forever. The comment there said
   "controller navigation arrives in Phase 5"; Phase 5 delivered controller
   input to the *game*, through the control deck, and nothing to the menu.
2. **The toggle was behind a switch that lives inside the menu.** Upstream gates
   the pad's Back button on `gControlNav`, which defaults to 0 and whose only
   control is in Settings. F1 and Escape need a keyboard an immersive space does
   not have. So the one way in was locked behind the room it opens.
3. **The shell was never told.** `SpaghettiPad_SetMenuVisible` was called from
   `Gui::DrawMenu`, which is virtual and which SpaghettiKart overrides without
   chaining (`SpaghettiGui`, installed at `Engine.cpp:173`). The notification
   reached the shell in exactly the configurations nobody ships. It now fires
   from `Gui::StartDraw`, which is not virtual.

The gamepad mapping is ImGui's SDL2 table transcribed, sourcing handles from
`ConnectedPhysicalDeviceManager` rather than opening its own — the control deck
already owns those devices. `ImGuiBackendFlags_HasGamepad` is not decoration:
ImGui clears every gamepad key each frame unless a backend claims it. On
visionOS the nav gate is removed rather than defaulted on, because a default can
be switched off and here that is a one-way door; `PortMenu` accordingly stops
offering the switch, joining the two consoles already excluded for the same
reason. `Gui::SupportsViewports()` now answers false: it was returning true
through the `FAST3D_SDL_METAL` arm, enabling multi-viewport against a platform
backend this app had replaced.

**All thirteen pages, opened and walked with nothing but a pad.**
`scripts/run-visionos-sim-menu.sh` does a clean install, launches into the
immersive space, and drives the menu:

```
scripted presses 57
pages reached    13 of 13
  Settings / General, Audio, Graphics, Controls
  Enhancements / General, Cheats, Freecam, Rulesets
  Developer / General, Gfx Debugger, Stats, Console, Scene Visibility
```

The expected list is written into the script rather than discovered, so a page
added upstream makes the run report a shortfall instead of walking twelve of
thirteen and calling it every. The shell log brackets it: `menu opened` on the
Back press, `menu closed` twenty seconds later on the next one.

**The pad is synthetic, and that is the part worth reading carefully.** No
controller can be attached to a Simulator, and SDL's virtual-joystick driver is
unavailable here — SDL declares `SDL_VIRTUAL_JOYSTICK` dependent on
`SDL_HIDAPI`, which this lane forces off because SDL 2.32.10 has no visionOS
HIDAPI branch and fails to compile. So the substitution is made one layer up, at
the button state: a scripted press travels through the same mapping table, the
same cross-pad merge, the same `ImGuiKey` and the same nav machinery a real
pad's would. What stays untested is `SDL_GameControllerGetButton` reporting real
hardware, which is upstream's and shared with every other platform. The
scripted pad is compiled **only for the Simulator** — a device build carries an
inert stub, so no synthetic input path exists in a packaged artifact at all.

**What the walk taught about the menu itself**, none of which is a defect but
all of which a wearer will meet: directions alone go nowhere, because the menu's
contents live in ImGui child windows that are entered with A and left with B;
the first directional press only makes navigation visible; and the first item
inside the menu block is the **close button**, so a wearer's first A press shuts
the menu. An earlier version of this script pressed only the d-pad and reported
one page for twenty seconds, which is what sent this investigation into ImGui's
nav internals before the answer turned out to be "press A".

**Boundary.** Every result above is the Simulator's. "Operable" is claimed only
as *reachable and selectable*: a scripted walk cannot say whether each page's
widgets can be actuated, or whether 13 px ImGui text is legible on a screen two
metres away in a headset. Both are for a wearer, and both are Phase 6's device
half.

---

**The same day, a wearer's session was killed, and this is what the archive
says.** The owner drove a race in Mode B and the app went away at the end of it.
The cause is not ambiguous:

```
16:00:14.003 launchd: UIKitApplication:com.subtlepath.spaghettipad[1610]
  exited with exit reason (namespace: 1 code: 0x7)
  - JETSAM_REASON_MEMORY_PERPROCESSLIMIT, ran for 349766ms
```

RunningBoard had set the limit at launch: `Memory Limits: active 5120 inactive
5120`. The app exceeded **5120 MiB** and was killed after 5 min 50 s. This is
the second session this lane has lost to that exact reason.

**A first reading of this blamed the texture pack, and that was wrong.** The
archive carries two *shell* lines — `enhanced textures on for the next engine
start` and `imported texture pack: 423 MiB ...
mk64-reloaded-v2026.04.03-sk-hd.o2r` — and those say the shell wrote a
preference and copied a file. Neither says the engine loaded a mod. **The owner,
who was wearing it, reports the pack was not rendering**, and the archive cannot
contradict that: it contains no `ModManager` line at all. Every one of the
engine's startup lines is missing from it, because they are `SPDLOG_INFO` →
`OS_LOG_TYPE_INFO`, which lives in the in-memory ring rather than the persistent
store — the exact risk the 2026-08-02 Phases 7/8 entry recorded when that sink
was added, now realised. The first engine line that survives is 1.3 s after the
game loop started.

**That makes the memory result worse, not better.** What is left is: **Mode B**,
which renders every frame's display list twice, once per eye, into 1856×1792
per-eye targets — reaching a 5120 MiB limit in under six minutes on *stock* MK64
assets. "HD art is large" would have been a comfortable explanation and is not
available. `GfxRenderingAPIMetal::DeleteTexture()` is an empty function and
`NewTexture()` only ever grows `mTextures`, and `docs/TECH_DEBT.md` already
recorded that texture lifetime was unprofiled; but nothing here has profiled an
allocation, and the honest position is that **the cause is unknown**.

**The app had been silenced by the operating system four minutes before it
died.**

```
15:57:07.442 SpaghettiPad (libsystem_trace.dylib) QUARANTINED DUE TO HIGH LOGGING VOLUME
```

After that timestamp not one of this app's own log lines appears — no
compositor, no engine, no shell. The last compositor line is 15:57:02.802,
reporting a healthy 1201 frames at 90 Hz, all stereo, zero GPU command-buffer
failures; the next was due at 15:57:09 and the quarantine had landed by then.
So the archive's silence over the final three minutes is the quarantine, not a
freeze, and it means **the run has no diagnostics from the window that matters**.

The volume was not this project's. Of the app's 7,526 messages in the archive,
**6,064 are `com.apple.UIKit:EventDispatch`** — two lines per GameController
event, logged because a fully immersive app has no UIEvent responder for them.
This project's own subsystem contributed 163. Nothing in this repository can
turn Apple's logging off, which makes the quarantine a standing hazard for every
device session with a controller connected, and a reason to keep this lane's own
per-frame diagnostics rare rather than merely capped. The Phase 6 nav
diagnostics written during this work were per-frame while being debugged and are
now a single line per launch, for exactly that reason.

**What has been added is the one thing that was missing: a number.** The app had
no memory instrumentation anywhere, so an archive could name the reason and not
the cause. The compositor's periodic report now carries
`os_proc_available_memory` — the headroom before the limit jetsam actually acts
on — alongside `phys_footprint`, every 600 frames, with the drop since the first
sample. The next wear turns "it died" into a curve.

**Boundary.** No fix for the memory growth is claimed, because none has been
made and nothing has been profiled. What the archive supports: the kill reason,
the limit, the duration, Mode B being the mode, and 1201 consecutive stereo
frames at 90 Hz with no GPU errors before the logging stopped. What it does
**not** support: which allocation grew, whether any mod was loaded, or what the
wearer saw. Two of those three were asserted in a first draft of this entry on
inference from shell-side lines, and are corrected above rather than quietly
removed.

**A second, cheaper defect falls out of this.** A device archive cannot
currently answer "which mods did the engine load", because the engine's whole
startup — version banner, `ModManager`, `ArchiveManager`, banks, sequences — is
`OS_LOG_TYPE_INFO` and does not survive collection. Those few dozen lines are
the ones most worth having and the least costly to keep; promoting startup and
mod-load lines to a persisted type would have answered this question in one
grep instead of needing the wearer to answer it.

### 2026-08-02 (Phases 7 and 8) — The ROM converts inside the app, which needed three defects fixed first; the engine's log finally reaches a device archive; and the lane gets a package, a workflow and a README

**Phase 7's open half was not "written and unexercised". It could not run.**
The plan said extraction was the engine's — `GameExtractor` scans the container,
Torch builds `mk64.o2r` — and the launch window's own comment said so:
"Extraction is the engine's, and it runs on the engine's first launch." Three
things stood between a person importing a ROM and that ever happening, and
each of them was invisible for exactly the same reason: every Simulator result
this lane has ever recorded was produced against an archive Torch had built on
the *host* and copied in, so the first-run path had never executed once.

1. **The shell refused to start the engine without an archive.** The guard was
   right about the empty case — upstream puts up an `SDL_ShowMessageBox` that
   cannot draw with SDL's video subsystem off, then exits — and wrong about
   this one: an imported ROM and no archive is not "nothing to play", it is the
   first run, and refusing it refused the only thing that could ever create an
   archive. It now refuses only when the container holds neither, and says
   which case it is in.
2. **`GameEngine::ShowYesNoBox` decided by coin toss.** Its `int ret;` is
   uninitialised, and `SDL_ShowMessageBox` with no video subsystem fails
   without writing it. So the first-run "No O2R files found. Generate one now?"
   prompt returned whatever was on the stack, and roughly half the time that
   would have been read as No — which is `_Exit(1)`, the app vanishing with no
   message. visionOS now answers yes and logs it, because reaching that line
   means the shell already found a ROM, which is the person asking for exactly
   this. `ShowMessage` joins `__SWITCH__` in logging rather than calling SDL.
3. **`GameExtractor::SelectGameFromUI` would have opened a desktop file
   dialog.** visionOS is not `__IOS__`, so it took the desktop branch and its
   `pfd::open_file` fallback. It now joins the mobile branch. Unreachable while
   the container scan finds a supported ROM, and the trap waiting for the first
   person whose ROM is the wrong dump.

**It runs, from a clean container, and the numbers are the point of running
it.** `scripts/run-visionos-sim-extraction.sh` is the reproducible form:
uninstall (which is what makes the container clean rather than merely empty),
install, verify Documents holds nothing, place the ROM — byte-for-byte what
`SpaghettiPad_ImportRom` does once a person has picked a file — launch, and
wait for the archive.

```
In-app extraction succeeded:
  ROM sha256       d6b8538dd63f0132ecb2856e7d32816ed3c30e3e479aecd23cf83fb6ba17a5da
  elapsed          438s
  peak RSS         1085 MiB
  archive          26664858 bytes, 32447 entries
  archive sha256   de2ef5a9a3057de72edd69b32fc89b5383ed87f9756fbf984f03fd6bb308fb8b
  no ROM image inside the archive
```

Torch identified the game from the container itself — `Game: MARIOKART64`,
`Hash: 579c48e211ae952530ffc8738709f078d5dd215e`, the exact SHA-1 the README
names as supported. **Peak RSS 1085 MiB is the number to carry to the
headset**: this lane has already lost one session to `jetsam reason
per-process-limit`, and extraction is now known to be a gigabyte-class event
before a single frame is drawn. Two runs produced identical byte counts and
entry counts and different file hashes; the archive is a ZIP and its timestamps
move, so a whole-file hash is not a reproducibility claim and is recorded as
identity, not as proof.

**The launch window can now say all of this.** With a ROM and no archive it
offers "Convert ROM to Game Data" with a running elapsed count, rather than the
previous state, which was a label telling people to copy a ROM into a folder
and no way to do anything with it afterwards. Extraction is deliberately not
folded into opening the immersive space: seven minutes of test pattern inside a
headset is not a way to tell someone their ROM is being converted. And because
every extraction failure ends in `_Exit(1)` — upstream's deliberate choice,
since those bail-outs run before the game world exists — the shell drops a
marker before starting and reads it once on the next launch, so a failure that
takes the whole process with it still leaves something behind to report.

**The engine's log now reaches a device archive, which this project has needed
for weeks.** `libultraship` gained an `os_log` sink beside its existing stdout
and rotating-file sinks, under the `engine` category of the app's own
subsystem. Every device diagnostic this lane has chased was previously written
twice — once as SPDLOG for the engine and once as `os_log` for the shell — or
simply went unseen, which is what sent nine build-install-wear cycles after a
black frame. The Simulator run above is the first evidence it works: the
extraction banner, Torch's game identification and its per-resource lines all
appear under `com.subtlepath.spaghettipad:engine`. Errors map to
`OS_LOG_TYPE_ERROR` and are persisted; ordinary lines map to
`OS_LOG_TYPE_INFO`, which lives in the in-memory ring a `log collect` archive
captures rather than in the persistent store. That mapping is deliberate and
its risk is worth stating: extraction alone emits tens of thousands of lines,
and an archive collected *during* one would be mostly Torch.

**Phase 8: the lane can now produce an artifact and say what made it.**
`scripts/package-visionos.sh` audits the bundle, wraps it in the same `Payload/`
container iOS uses, and refuses a signed app unless asked. The unsigned device
app built from this tree passes the audit — arm64, `platform VISIONOS`, minimum
26.0, ARKit/CompositorServices/Metal linked, port archive content
`5ab6f5d8…`, unsigned — with executable SHA-256

```
53120f500da87f47b959f7bd52cbb213081e4f7b3db39bbcf587e7487141b279
```

and packages to `SpaghettiPad-visionOS-0.2.0-preview.1-unsigned.ipa`, SHA-256
`31b1ae2bdf4f1b7030d9622844aa89415b645ee1ccf8534e48d1f5a672dcbf1a`. The
executable hash is the durable identity; the artifact is a ZIP and its hash
moves with its timestamps. `REQUIRE_SIGNED=1` was run against the same app and
rejected it, which is the gate CI exercises. The artifact
carries `RIGHTS_AND_LICENSES.md`, 32 discovered third-party notices, and a
`BUILD_PROVENANCE.txt` naming the Xcode build, the visionOS SDK, all three
source revisions and whether the working tree was clean. That file exists
because of an invariant this log already recorded and had no mechanism for:
the active toolchain is a beta Xcode, and no release may be published from one
without saying so. `SPAGHETTIPAD_EXPECTED_XCODE_BUILD` makes it a hard gate for
anyone who wants one. The archive-allowlist check is an allowlist rather than a
pattern — the only `.o2r` permitted is `spaghetti.o2r` — because a pattern is
what the next kind of ROM-derived archive slips past.

**The repository safety gate was red and is green.** `check-repo-safety.sh`,
which is CI's first job, was failing on seven broken Markdown links: commit
`1d31f06` deleted the iPad screenshots while the README still linked five of
them, and the whole `docs/screenshots/` directory is gone — the visionOS
captures this log names throughout were never committed and are not
recoverable. The README no longer links them and the one Markdown link in this
file has been converted to prose that says what the capture was and that it no
longer exists. **The measured numbers those entries record stand; the pictures
do not exist.** Nothing else was changed in any earlier entry.

**A visionOS CI workflow exists and has never run.**
`.github/workflows/visionos-build.yml` runs the safety gate, selects an Xcode
that ships
a visionOS SDK (failing by name if none does, rather than as a CMake error ten
minutes later), reproduces the unsigned device app from the pinned inputs,
packages it, exercises the `REQUIRE_SIGNED=1` rejection, and publishes the
artifact hash and provenance to the run summary. It targets a `macos-26`
runner, which is **an assumption, not a verified fact** — a hosted image
without the visionOS 26 SDK cannot produce a build this lane's audit accepts,
and nothing here can confirm the label until someone pushes. The retired
iPadOS workflow is kept but no longer triggers on push or pull request: nothing
in this lane can change its result, and a retired lane's failures would sit on
every commit claiming something is broken that nobody is maintaining.

**Docs.** The README is rewritten for visionOS: what the two modes are, what
has been measured and on what — Simulator, headset, or build host, per row —
what is explicitly not claimed, and the iPadOS lane condensed into one section
that says its open gates were superseded rather than passed.
`RELEASE_CHECKLIST.md` gains visionOS gates ahead of the retired ones,
including the requirement to read the Xcode build out of the artifact and state
it.

**Boundary.** Everything above is a build-host or Simulator result. Both
maintained patches were regenerated and replay byte-identically from the pinned
revisions — reversed, replayed through `apply-patches.sh`, and the tree hashed
before and after. **No part of this has been on a headset.** In-app extraction
on an Apple Vision Pro is untested and is the half of Phase 7 that remains, and
the 1085 MiB peak is a reason to expect it to be interesting rather than
routine.

### 2026-08-02 (fourth wear) — "Still reversed": the backdrop diagnosis below was wrong, and the right one was sitting in an exclusion this project wrote itself

**The report.** The menu backdrop is still reversed after the readback gating
below. That verdict retires the capture-path diagnosis as the explanation for
*this* symptom — the gating fixed a real cross-eye mechanism, but not the one
the wearer was looking at, because the menu backdrop never touches the
captured framebuffers at all.

**What the backdrop actually is.** `menu_items.c` draws
`seg2_blue_sky_background_texture` — one prerendered 320×240 image — through
`func_80097A14`, which emits it as **full-width texture-rectangle strips** in
copy cycle. And full-width rectangles were one of `StereoRectOnPanel`'s three
exclusions, on reasoning this log recorded on 2026-08-01: "a background
belongs at infinity, and leaving it alone puts it there." It does not.
Identity coordinates map the image across each eye's *own* NDC, and the eyes'
views are asymmetric mirrored frustums with a rotational cant — the same
coordinates mean visibly different directions in the two eyes, skewed
opposite ways. That is the original three-defect pathology from the first
Mode B sighting, surviving in the one category of draw the panel fix
deliberately left untouched. A wearer reading "the backdrop's orientation is
reversed in the right eye" was describing the mirrored asymmetry itself.

**Changed.** The full-width exclusion is gone. Full-width rectangles are
still recognised — they are backgrounds by construction — but they now land
on the backdrop panel: a real object in the recentre frame, identical for
both eyes, 60 m out and wider than the widest view a headset has reported, so
the unfilled-band worry the old exclusion answered does not arise. Fill-cycle
clears and off-screen-framebuffer draws keep their exclusions. Race wipes and
fades, which are also full-width, ride along to the backdrop, where a fade
over a deep world reads like a cinema fade rather than a card on the nose.

**Boundary.** Built clean, not worn. The readback gating and the byte-budget
below stand on their own evidence and remain in the build. If the backdrop
still misbehaves after this, the next suspect is the strip *interior* — how
`func_80095E10` tiles the image — and a capture of both eyes, not a verbal
report, is the instrument that settles it.

### 2026-08-02 (third wear) — The world reads right; what remains is a backdrop drawn by one eye for the other, and a death by memory that the archive names outright

**The report.** The camera-factorisation build below is better. Two things
remain: the main menu's prerendered backdrop renders with the wrong
orientation in the right eye, and the game died after several minutes of the
promo loop. The wearer collected `log collect` evidence for the second.

**The crash is not a crash: `Process SpaghettiPad [1408] killed by jetsam
reason per-process-limit`,** seconds after a compositor line showing 90 Hz,
every drawable anchored, nothing skipped, nothing failed. The app was healthy;
it was simply too big. The mechanism: the Fast3D texture cache is bounded by
*entry count* — 1024, LRU — which is a byte bound only while every texture is
N64-sized. The MK64 Reloaded pack makes single entries cost tens of megabytes,
the promo loop cycles courses, and nothing in this port has ever unloaded a
resource: both the GPU copies and the decoded CPU copies in the resource cache
grow until the per-process limit ends the session. **Changed:** the cache now
also carries a byte bound (1 GiB — several courses of 4K textures, so eviction
stays off the hot path). Each upload books its bytes against its entry;
eviction past the budget walks the LRU end, returns the texture id, and — for
entries whose pixels came from an archive resource — releases the decoded CPU
copy too, recorded by path at import time. Unloading is safe by construction:
OTR-path textures resolve at interpret time and reload from the archive on
demand, and anything in flight is kept alive by the RDP's own shared_ptr.

**The backdrop, found in the capture path.** The port reads the finished frame
back to the CPU at the end of every rendered pass
(`FB_WriteFramebufferSliceToCPU`, main.c) into `gPortFramebuffers`, and the
game draws those pixels back on screen — the menu backdrop among them. Mode B
interprets the same display list once per eye, so the readback ran twice, and
whichever eye ran last owned the buffer: within a frame, the first eye
composited the *previous* frame's last-eye capture while the second composited
the first's — each eye wearing the other's picture, which is what "the
orientation is wrong in the right eye" looks like from inside. **Changed:**
the readback runs only in the frame's last eye. Both eyes now composite the
same picture, from the same pass, one frame old — mono, like any photograph,
and consistent between the eyes. It also halves a synchronous GPU→CPU readback
that was being paid twice per frame.

**Boundary.** Both changes build clean; neither has been worn. The byte
budget's eviction-under-pressure has not been exercised against a full promo
cycle, and whether 1 GiB is the right number is a device measurement — if the
next session still dies by jetsam, the remaining growth is somewhere the
texture path never touches, and the next archive will say. The backdrop fix
predicts the menu backdrop reads identically in both eyes; a captured image is
now knowingly mono, which is correct for a 2D backdrop and a recorded
limitation for anything that ever composites a capture as scenery.

### 2026-08-02 (later) — The wearer wears the world-locked HUD build: the panel reads right, the world does not, and the cause is one classification reading the wrong matrix

**The report.** The HUD and menus sit at a comfortable distance now — the
exact projection in the entry below did what it claimed. But "the characters
and everything rendering in the background feel too close," and head tracking
does not work: turning the head does not look around. The owner's direction:
forward may always be the game camera's orientation, but the wearer should be
able to look around relative to the camera's position.

**The cause, found by reading the game rather than the interpreter.** Mario
Kart 64 multiplies its camera onto the *projection* stack:
`gSPMatrix(camera->perspectiveMatrix, G_MTX_LOAD | G_MTX_PROJECTION)` followed
by `gSPMatrix(camera->lookAtMatrix, G_MTX_MUL | G_MTX_PROJECTION)`, in every
in-race render path (`render_courses.c`, `code_80057C60.c`,
`skybox_and_splitscreen.c`). Camera-times-perspective does not classify as a
perspective matrix — its w row picks up the camera translation, so
`IsPerspectiveProjection` reads `[3][3] ≠ 0` and says no. The stereo path
classified the *composed* product. So on the LOAD it classified perspective,
built the eye frustum and logged recovered near/far — and a moment later the
camera MUL arrived, the product reclassified as orthographic, and every draw
after it — the entire racing world — silently took the HUD-panel path: a flat
projected photograph of the world, at panel distance, deaf to head rotation.
Both reports are that one defect. The menus classified correctly all along
because they load their lookAt into the *modelview* stack (`menu_items.c`),
which is why the 2D fix below was visible while the world stayed wrong.

**The fix: classify the factors, not the product.** The interpreter now tracks
the game's projection factorised alongside the composed copy: the matrix the
last LOAD carried (`mStereoGameLoaded` — classification, near/far recovery)
and the product of every MUL since (`mStereoGamePre` — the game's camera,
exactly as the game placed it). A perspective replacement is now
`camera · eyeFromRecentre · frustum`: forward follows the race because the
camera does, and the wearer's head pose — always present in
`eyeFromRecentre`, never before reached by the world's draws — looks around
from there. Nothing about the modelview path changed, so the menus render as
they did.

**The skybox moved out of the way of the world it stands behind.** With the
world at real depths, an orthographic skybox on the 2.2 m panel would float
in front of the track it backs. Orthographic passes are now split by when
they run: a pass before the frame's first perspective load, in a frame whose
previous pass over the same display list had one, is scenery and lands on a
backdrop panel — same construction as the HUD's, 60 m out, ±63° wide, wider
than the widest eye tangent a headset has reported. Everything else,
including every 2D pass of a frame with no perspective in it at all, stays at
reading distance. The prediction flag crosses eyes, so a scene change costs
one eye's worth of misclassified backdrop and then corrects.

**Boundary.** Built clean; not yet worn. Two things the next wear should
expect and not mistake for new bugs: the game CPU-culls to its own camera's
frustum, so looking far off-axis will show geometry popping out at the edges
of what the game ever submitted; and the stretched sky is cosmetic on
gradient skies but a texture sky (clouds) will look widened. Both are
recorded here rather than fixed, because neither has been seen yet.

### 2026-08-02 — The wearer reports back twice, and three changes answer: the HUD leaves the face, the audio survives the window, the window gets out of the way

**Report one: the HUD and menus still render "much too close to my face" in
stereo.** So the panel fix in the 2026-08-01 entry was worn and found wanting,
and rereading it against the geometry shows why it could not have been enough.
The panel was still *head-anchored* — centred on each eye's frustum axis every
frame — and its convergence was an approximation: a shift computed from the eye
*translations* alone, as if the two views differed only by where they sit. They
do not. The eye transforms carry rotation — the interpreter's own perspective
path honours that cant, which is why the world fuses — and a convergence shift
that ignores it puts the panel's per-eye images at directions that match no
single distance. A stereo pair that converges wrongly does not read as "a bit
off"; it reads as *near*, because near is where the eyes go when disparity
fights them.

**Changed in the interpreter, and the shift deleted rather than corrected.**
The panel is now a fixed object in the recentre frame — the same 4:3 rectangle,
1.76 m across, 2.2 m ahead of where the wearer was when the world was placed,
at their placement eye height — and `BeginStereoEye` projects its centre
through each eye's *full* pose, rotation included, every frame. Convergence is
no longer a term added on top; it is inside the projection, exact by
construction, cant and all. `mStereoHudShift` is gone from the interpreter, the
orthographic replacement, and the rectangle path alike. This also world-locks
the HUD — the recorded follow-up from the last entry, now done because the
wearer asked in the only way that counts: a cockpit instrument that stays put
when the head turns, and is behind the wearer (drawn nowhere, by a zero scale)
if they turn all the way round.

**Report two: audio plays only while the launch window is open; closing it for
full immersion silences the game.** Nothing in this repository pauses anything
on window close — `Audio::SetPaused` has no caller — and SDL's CoreAudio
backend was measured healthy in the last archives. The mechanism is the
system's: visionOS spatializes an app's audio by default as a head-tracked
sound stage whose Automatic anchoring strategy anchors it to the app's window
scene. Dismiss the window and the sound stage loses its anchor; no
interruption fires, no error surfaces, and SDL has nothing to notice. The
shell now sets the session's intended spatial experience to **Bypassed** —
the engine ships a finished stereo mix, panned camera-relative the way the
game has mixed it since 1996, and re-spatializing that mix against a window
was never right even while it worked — and registers interruption and
media-services-reset observers under the `audio` os_log category, so the next
archive records what fired rather than leaving it to inference. Set in
`SpaghettiPad_RuntimeInit`, before SDL can open a device.

**And the owner's direction: hide the window in immersive mode; the Digital
Crown is the way out.** Opening the space now dismisses the launch window as
its last step — after the engine start request, because the window owns the
task that request runs on — and the caption says so before the button is
pressed. The crown path made one thing newly load-bearing: the system ends the
immersive space without any SwiftUI code being asked, so the app's
`immersiveSpaceOpen` state goes stale. The compositor thread already noticed
its renderer go invalid and exited; a new `SpaghettiPad_CompositorRunning()`
bridge exposes that, and the launch window resynchronises against it when it
reappears — routing through the existing `onChange`, which joins the finished
thread. The Simulator's scripted auto-open keeps the window alive explicitly
(`hideWindow: false`), because its cycle variant runs off a task that window
owns.

**Boundary.** All three changes build clean; none has been worn. The HUD claim
is geometric — an exact projection replacing an approximation measured wrong on
a face — and the audio claim rests on the documented default plus the exact fit
of the symptom (works with window, dies without, returns with it). The next
wear answers both, and the new observers make the audio answer legible in the
archive either way. The device log archive captured for this round could not be
read on the build host ("corrupt or incomplete"), so nothing above leans on it.

### 2026-08-01 — Mode B is seen: the game renders in stereo on a wearer's face, and the sighting bills three regressions

**The depth-write build (`2773f8c5…`) was worn and the wearer can see the
game.** That is the first sighting of Mode B by anyone, and it confirms the
depth-buffer mechanism in the entry below: the only change between black and
visible was writing a finite depth. What the sighting also did was surface
three problems that black had been hiding, reported first-hand:

1. **The 2D interface fills the view, is glued to the face, and loses its
   edges off-screen.** Diagnosed from the geometry, three defects compounding:
   an orthographic pass left alone maps across each eye's *entire* NDC, but
   the eyes are asymmetric mirrored frustums (L1.732/R1.000 against
   L1.000/R1.732), so NDC zero sits ~15 degrees to one side — mirrored — and
   the two eyes were shown the HUD in incompatible directions, a pair no one
   can fuse. The view is also far wider than the headset displays, so the 2D
   passes' edges landed in rendered-but-invisible territory — the same trap
   that once hid the eye-identity ticks. And `AdjXForAspectRatio`, letterboxing
   meant for a desktop window, *stretched* x by ~1.29 at the eye's near-square
   aspect, pushing content further out. **Fixed in the interpreter:** the 2D
   passes (orthographic matrices and qualifying rectangles alike) now land on
   a 4:3 panel `kHudPanelWidthMetres` (1.76 m) across at `kHudDistanceMetres`
   (2.2 m) — the same arc as Mode A's screen, a size a wearer has already read
   menus at — centred on each eye's own forward axis, with the existing
   convergence shift on top and the aspect factor cancelled. The rect
   exclusions (fill-cycle, full-width backgrounds, off-screen framebuffers)
   keep their old behaviour. The panel is still head-anchored; world-locking
   it is the recorded follow-up if a wearer asks for it.
2. **No sound.** Not new to this build: the previous session's archive shows
   the app's audio session created and **never activated** — and the archive
   of the black session says the same, so this predates the depth fix and
   belongs to the Mode B build lineage. The audio code in the working tree is
   byte-identical to the maintained patch that produced audible sessions, so
   the failure is at runtime and currently invisible: SPDLOG never reaches a
   device log. **An `audio` os_log category now reports** the backend chosen
   (SDL / Null-by-fallback / other), device-open failures with SDL's error
   string, and the open-and-unpaused success line. The next archive answers
   this; nothing was changed blind.
3. **PS VR2 Sense partial: only start and accelerate worked.** The previous
   archive shows `no game controller is connected` with no connection ever
   logged and gamecontrollerd seeing no Sense device at the OS level in its
   window — so in the *newest* session something connected that the archive
   does not cover. The standing hypothesis, from which buttons worked: **only
   the right Sense controller joined** — options and cross are both on the
   right one, and the steering stick is on the left one. The `input` category
   already logs the connected set by name; the next archive settles it. No
   code was changed for this.

The build carrying the HUD panel fix and the audio logging is `fa2161cf…`,
audited signed and ROM-free. Its wear is the next evidence.

### 2026-08-01 — The clip fix was worn and refuted; the counters worked; the answer is the depth buffer

**The wear test.** Build `31981a2f…` — eye quad at z = 0.5, depth writes still
off — was installed on `NEW AVP` and worn. **Still black.** That kills the
clipping theory in the entry below as the *whole* answer: a quad strictly
inside the clip volume changed nothing the wearer could see.

**The counters did their job on their first outing.** The wearer collected a
log archive, and the new periodic line reads, across two immersive opens:
`view encodes so far: 1186 eye (Mode B), 0 screen, 0 pattern, 0 skipped; 0
command buffer(s) failed on the GPU` — exactly two eye encodes per presented
frame, nothing skipped, no GPU faults, every drawable anchored, 90 Hz. So the
Mode B branch runs, encodes both views, and presents cleanly every frame, and
the wearer sees black anyway. The app's pipeline is measured healthy end to
end; the loss is after the present, in the system compositor. No system-side
log line complains, because nothing is wrong by the system's lights.

**The mechanism, which explains this run and every run before it.** The eye
pass **wrote no depth** — `eyeDepthState_` was compare-Always, write-off, by a
comment that reasoned writing far depth "would be a worse answer than saying
nothing". But not writing *is* saying far plane: the pass clears depth to 0.0
(reverse-Z far) and nothing in Mode B ever writes over it, so every pixel of
every Mode B frame told the compositor its content was at infinity, and the
compositor's reprojection shows a far-plane pixel as nothing there. That is
why the constant-green shader was black (colour was never the problem), why
the vertex-z fix was black (writes were still off), and why Mode A was always
fine (its sky box writes finite depth over every pixel). It also re-explains
the old sky bug more precisely than the clipping theory did: the far-plane
clip-space sky *drew* — the wearer saw a void where its colour went because
its depth stayed at the far plane, while the depth-writing floor grid beside
it stayed visible, and rewriting its fragment reconstruction changed nothing
because colour was never consulted.

**What was changed.** `eyeDepthState_` now writes depth, and the eye quad's
depth is computed rather than chosen: `kEyeContentDistanceMetres` (2.0 m — the
distance Mode A's screen has been comfortably reprojected at all along) pushed
through each view's own `cp_drawable_compute_projection`, so the value written
is whatever that drawable's reverse-Z mapping says 2 m is. A single plane
stands in for a world of real depths, so distant scenery will swim slightly
under head motion until the engine's own depth buffer is carried across; what
it buys is that the picture exists. The shaders still compile offline against
the xros SDK.

**Boundary.** The mechanism is inferred from the correlation across every
device session — far-plane depth has never been seen, written depth always has
— plus the healthy counters above; no Apple document was consulted that states
it outright. It predicts the next wear shows the game in stereo at last, and
if that is wrong the next suspect is real: something between
`cp_drawable_encode_present` and the display that neither the counters nor the
command-buffer watch can see.

### 2026-08-01 — Mode B's black frame, found by reading rather than wearing: the eye quad was emitted at exactly the far plane

**The bug.** Mode B's present quad — the one draw that puts a finished eye
texture onto the drawable — emitted clip coordinates with **z = 0.0 exactly**,
which under reverse-Z is the far plane. This project already measured, once,
what this headset does with a full-viewport primitive at exactly that depth:
the original clip-space sky rasterized on the Simulator and never on the
device, and two rewrites of its *fragment* reconstruction changed nothing —
which is precisely the signature of vertices that never survive clipping,
because no fragment ever ran. The eye quad was the same construct at the same
depth, and it is the one construct in the lane that has never run anywhere
else: Mode B declines on the Simulator, so unlike the sky there was no
working-in-one-place comparison to notice.

**Why every measurement in the entry below fits.** The constant-green fragment
shader stayed black because the quad was clipped before any fragment ran —
fragment changes cannot rescue a clipped vertex, exactly as they could not
rescue the sky. The magenta-stained eye textures were invisible for the same
reason. The engine's rendering was correct throughout because it was: the
pipeline wrote perfect pictures into textures whose composite draw was then
discarded by the rasterizer. And what the wearer called black was the eye
pass's own clear colour, (0.02, 0.02, 0.03). The correlation across every
device session is exact: every primitive ever seen on hardware — pattern rects
at reticle depth, the sky box, the floor, the screen — emits clip z strictly
greater than 0; the two that were never seen — the old sky and the eye quad —
emitted exactly 0.

**What was changed, all of it in repo-owned `visionos/` files.**

- `eye_vertex` now emits z = 0.5. The eye depth state neither tests nor writes,
  so the value only has to survive clipping; it says nothing about where the
  picture is.
- `eye_fragment` is restored to sampling the eye texture — the constant-green
  diagnostic is gone.
- `EncodePattern`'s fallback depth for an unprojectable reticle was also 0.0 —
  the same bug class, which would have made the whole test pattern invisible on
  device during any frames before tracking converges. It is now 0.5.
- **The branch counters the entry below asked for exist.** `EncodeViews` counts
  eye/screen/pattern encodes and skipped views, logged every 600 frames beside
  the existing counters, so a session's log now states what was encoded all
  session long instead of once on the first stereo frame.
- **Command buffers are checked for GPU errors** from their completion handler
  (first three logged in full, total counted in the periodic line). A faulting
  command buffer has no CPU-side symptom otherwise, and this run of hypotheses
  should have been able to kill that one by measurement instead of inspection.
- **The stereo -> flat -> stereo question is now answerable from a log.**
  `SetStereoRequested` logs on change, so a surface flip with that line beside
  it is the wearer's toggle; the compositor logs transitions of per-eye view
  validity with the pose and room state, so a flip without it names its cause.
- The shell's temporary diagnostics — the per-acquire eye stain with its
  synchronous GPU wait, and the slot/pointer logs — are removed; slot
  bookkeeping is measured clean in the entry below and the stain would have
  dragged on a 90 Hz verification run. The engine-tree diagnostics in
  `interpreter.cpp`, `gfx_metal.cpp` and `Gui.cpp` are untouched and still
  outside the maintained patches.

**What was verified, which does not include the only thing that matters.**
Simulator and device lanes both build (direct `cmake --build`, preserving the
engine-tree diagnostics; the pristine-tree guard still refuses the script, as
it should). The device audit passes with `REQUIRE_SIGNED=1`: arm64, signed,
executable SHA-256
`31981a2fcda0ee05a66a30e18753053330661cb66a15da11787520f07d5e73b2`, archive
content SHA-256 unchanged and still ROM-free. All four embedded Metal shader
sources compile offline against the xros SDK — they are compiled at runtime,
where a syntax slip would otherwise first appear. **No wearer has seen this
build.** The diagnosis is a reading of the project's own device evidence, not
a device result; if it is right, the next wear of Mode B shows the game in
stereo, and if it is wrong, the branch counters now say which encoder actually
ran while the wearer saw whatever they saw.

### 2026-08-01 — Mode B's first hardware run: it engages, it renders, and the wearer sees black

**This entry is mostly negatives.** Nine build-install-wear cycles on `NEW AVP`
(visionOS 26, M2) produced no fix and a great deal of eliminated ground. The
eliminations are the value here: five specific hypotheses were killed by
measurement, and re-deriving any of them would cost another evening.

**What is true and was not before.** Mode B is no longer unseen. It engages on
hardware, and the engine half of it works:

```
surface:    render surface ready: stereo, 1856 x 1792 per eye, 2 eye(s), 3 buffers (76.1 MiB)
surface:    Mode B: first stereo frame, tangents L1.732 R1.000 U1.000 D1.192
                                              / L1.000 R1.732 U1.000 D1.192
compositor: Mode B: drawing the game in stereo, 1856 x 1792 per eye
compositor: 2401 frames presented at 90 Hz, 2359 showing the engine (1458 in stereo);
            2401 drawables anchored, 0 not
```

**Mode A is unaffected throughout.** The flat screen renders correctly and audio
plays for the whole session, in every run below. Whatever this is, it is Mode B's
alone.

**What was eliminated, each by a measurement rather than an argument.**

- **The projection substitution.** Probe points pushed through both the game's
  matrix and the replacement, logged as NDC: `(0,0,-100)` → `(+0.102, +0.016,
  +0.952)` with `w +89.70`; `(200,100,-500)` → `(+0.314, +0.374, +0.992)` with
  `w +502.75`. Positive `w` everywhere, x and y inside ±1. Geometry is projected
  on screen, and the two eyes differ correctly (`+0.102` against `-0.322` on the
  forward probe) by the frustum cant.
- **The near-plane clamp.** It does compress the visible world into NDC z
  `[0.95, 1.0]` — the game asks for near 100 and the clamp gives 2.18 — and that
  will cause z-fighting once a picture exists. It is **not** the black frame:
  disabled for one run, `near 100.000`, still black.
- **The viewport.** `in (0,240 320x240) -> out (0,0 1856x1792)`, with `cur`,
  `window` and `gameWindowViewport` all agreeing at 1856x1792 and `offsetApplied
  0`. `AdjustVIewportOrScissor`'s window-relative offset — a real suspect, since
  visionOS has no window — never fires.
- **The ring's slot and eye bookkeeping.** Each eye texture was stained a
  distinct colour at the moment the engine was handed it, and the pointers
  logged at both ends: `handing the engine slot 0 eye 0 (0x135ed8f00)` against
  `presenting slot 0 eye 0: srgbView 0x135ed9180 over texture 0x135ed8f00`. They
  pair exactly, for both eyes, `stereo yes`.
- **The ImGui size guard.** `gfx_metal.cpp`'s "workaround for detecting when
  transitioning to/from full screen mode" silently returns without drawing when
  the screen texture and ImGui's display size disagree — the only code in the
  pipeline that can draw nothing while every input is correct. It never fires:
  `screen texture 1856x1792 vs drawData 1856x1792 … -> upstream would draw`.

**What else was measured and found correct.** Triangles reach the rendering API
— `4737 triangles, 409 clipped away, 1381 culled, 2947 drawn` per eye, which is
an ordinary scene ordinarily drawn. The ImGui composite that is the only thing
ever putting the game onto the presented surface is issued correctly: `fb
0x1334fea80 pos (0.0,0.0) size 1856.0x1792.0 windowSize 1856.0x1792.0`. The
compositor's `EncodeEye`, its `MTLCompareFunctionAlways` depth state and its eye
shader are correct by inspection, and `eyePipeline_` is non-nil or the compositor
would have refused to start.

**The measurement that breaks the story.** Every framebuffer was cleared to
magenta for one run — the log confirms both `framebuffer 1` (`mGameFb`) and
`framebuffer 0` (the eye texture) cleared at 1856x1792 — and the wearer saw
black, not magenta. Mode A correctly showed no magenta, because the game draws
over the clear. Then the eye shader was reduced to `return float4(0,1,0,1)`,
removing the texture, the sampler and the ring from the question entirely.
**Still black.**

A constant-colour fragment shader that does not reach the wearer means Mode B's
present is not painting, and that every measurement above describes a pipeline
whose output never reached the display. The engine renders correctly into
textures nobody sees.

**What to do next, and what not to.** Do not re-examine the projection, the
viewport, the near plane, the slot bookkeeping or the ImGui guard; they are
measured and clean. The missing thing is observability in the compositor itself:
**count which branch each frame takes** — `EncodeEye`, `EncodeScreen`,
`EncodePattern` — and log it periodically alongside the frame counters. Every
wrong turn in this entry came from trusting `Mode B: drawing the game in stereo`,
which is logged once, on the first stereo frame, and says nothing about the
thousands after it. The surface is also seen flipping `stereo -> flat -> stereo`
within a session; whether that is the wearer using the toggle or the mode
collapsing on its own has never been established, and the branch counters would
settle that too.

**The diagnostics are not in the maintained patches.** They were built directly
with `cmake --build build-visionos --config Release --target Spaghettify`, which
bypasses `apply-patches.sh` and its pristine-tree guard. The working tree
therefore carries temporary instrumentation in `interpreter.cpp`, `Gui.cpp`,
`gfx_metal.cpp`, `SpaghettiPadRenderSurface.mm` and `SpaghettiPadCompositor.mm`
that must be reverted or deliberately kept before either patch is regenerated.

### 2026-08-01 — Mode B: rectangles were never in stereo at all, read out of RT64's classification

**Where this came from.** RT64 was cloned to answer whether it could replace
Fast3D. It cannot — its entry point is
`Application::processDisplayLists(uint8_t *memory, uint32_t dlStart, uint32_t
dlEnd, bool isHLE)` against a raw RDRAM image, and it re-implements the RSP and
RDP including TMEM, while this port's display lists carry host pointers and OTR
resource handles (`G_SETTIMG_OTR_HASH`, and `words.w1` holding a `Texture*` at
`interpreter.cpp:4194`). There is no seam to join them at without rebuilding the
asset pipeline back into N64 physical memory. What RT64 *does* have that Mode B
wanted is its classification of draws, and that reads across for free.

**What it found, which the engine had no name for.** RT64 gives a rectangle a
projection type of its own — `Projection::Type::Rectangle`, listed beside
`Orthographic` rather than inside it (`rt64/src/hle/rt64_projection.h`). Fast3D
behaves the same way without saying so: `GfxDrawRectangle` writes clip
coordinates straight into `loaded_vertices` and calls `GfxSpTri1` with `is_rect`
set, so `P_matrix` is never consulted and `Interpreter::StereoProjection` never
ran for a single rectangle.

Identical coordinates in both eyes are zero disparity, and zero disparity is
converged at infinity. The orthographic half of the HUD was deliberately placed
at 2.2 m for precisely that reason — infinity being the one distance guaranteed
to fight everything else in view — and the rectangle half was still at infinity
the whole time. The game makes 23 live `gSPTextureRectangle` /
`gDPFillRectangle` calls: eight in `menu_items.c`, five each in
`skybox_and_splitscreen.c` and the debug `profiler.c`, four in
`render_objects.c`. The menus are the clearest case, since a menu is read at
length and at leisure.

**What was built.** `Interpreter::StereoRectShift` applies the same
`mStereoHudShift` the orthographic path already uses. A rectangle is in clip
space with `w = 1`, so what `StereoProjection` folds into a matrix as a multiple
of w is here simply added to x, and the two halves of the HUD land at the same
distance rather than at two different ones. It is decided before
`AdjXForAspectRatio` — which scales about zero and would move the very edges
being tested — and applied after it.

Three kinds of rectangle are excluded, each because moving it would be wrong
rather than because moving it is hard:

- **Fill-cycle rectangles.** `G_CYC_FILL` is how this game clears:
  `init_z_buffer` and its splitscreen counterpart point the colour image at the
  z-buffer and fill it. A clear has no distance to be placed at, and shifting one
  leaves a band of the previous frame along the edge it moved away from.
- **Rectangles spanning the full framebuffer width.** A background cannot move
  sideways without opening that same unfilled band, and a background belongs at
  infinity anyway — which is where leaving it alone already puts it.
- **Rectangles drawn into an off-screen framebuffer.** The shift belongs to the
  draw that reaches the eye, which is the later one compositing that target onto
  the screen. Applying it twice would converge a texture that already had
  convergence painted into it.

`IsPerspectiveProjection` also gained RT64's vertical-scale term from
`RSP::getCurrentProjectionType`: a matrix can divide by depth and still be
degenerate, and no frustum can be recovered from one. Misreading such a matrix as
flat costs a frame of the HUD's convergence; misreading it as perspective costs a
frame of geometry smeared across the wearer's field of view.

**What was verified, which does not include how any of it looks.**

- `libultraship-visionos.patch` was regenerated and **replays clean from the
  pinned revisions**; the replayed tree is byte-identical to the tree that was
  built. libultraship compiles for `arm64-apple-xros26.0-simulator` with
  `__VISIONOS__` defined, and `StereoRectShift` is present in `interpreter.o` as
  `__ZNK4Fast11Interpreter15StereoRectShiftEffj`.
- **Nothing was run, and nothing was seen.** The Simulator reports one view, so
  Mode B declines there and no rectangle in this change has ever been drawn with
  a shift applied to it. This is a compile-and-replay result and nothing more.
- **The exclusion rules are reasoned from the display list, not observed.** They
  were derived by reading `skybox_and_splitscreen.c` and the fill-cycle setup
  around it, not by watching a frame. A wearer is what would show whether the
  full-width test catches everything it should — a background that is drawn a
  column short of the edge would slip past it and be shifted.
- **2.2 m is still an unchecked number.** This change converges rectangles at the
  same distance the orthographic HUD uses, so if that distance is wrong it is now
  uniformly wrong instead of wrong in one half. That is an improvement in
  consistency and not evidence about comfort.
- RT64 is MIT-licensed. No RT64 code was copied — what was taken is the
  distinction its types draw, and the comments name where it came from.

### 2026-08-01 — visionOS Phases 9 and 7: Mode B is written and the 4K pack renders, and only one of those two sentences has been seen by anyone

**What was built.** Mode B — the game drawn in stereo, rather than a flat picture
of it hung on a screen — and the texture-pack path the 4K pack needs to get in.

- **The stereo happens at the projection matrix and nowhere else.** A vertex
  reaches the game's projection already in Mario Kart 64's camera space, and that
  space is axis-for-axis what Compositor Services calls right-up-back. So the
  game's camera and the wearer's head are declared the same thing, and the only
  substitution needed is the projection: `Interpreter::StereoProjection` replaces
  each perspective matrix the game loads with that eye's own frustum, composed
  with where that eye is relative to the pose the world was placed from. Nothing
  touches the modelview stack, the vertex transform, lighting, or clipping.
- **The game's near and far planes are kept, not replaced.** They are recovered
  from the matrix the game loaded — F3D projections are OpenGL-convention, so the
  depth row inverts exactly — because they are the game's statement about how far
  it means to draw. The eye's frustum decides the *shape* of the view, which
  belongs to the headset; it has no opinion about draw distance, which does not.
  The near plane is pulled in to 0.12 m so that leaning forward does not open a
  hole in the world, which the game's own value, chosen for a camera bolted behind
  a kart, would.
- **Two conventions had to be honoured and are easy to conflate.** Fast3D expects
  clip z spanning `[-w, w]` and remaps it to Metal's `[0, w]` itself, on the CPU,
  in `GfxSpTri1` — a Metal-convention projection handed straight over would be
  remapped twice and put every polygon in the front half of the depth buffer. And
  `AdjXForAspectRatio` letterboxes a 4:3 game onto a wider window afterwards,
  which is meaningless when the frustum already *is* the shape of the eye, so the
  frustum cancels that factor in advance rather than teaching the vertex path
  about a mode it otherwise ignores.
- **The HUD is handled separately, as the plan said it would have to be.** Its
  orthographic passes keep their own matrices and gain a per-eye sideways shift in
  clip space, which puts it at 2.2 m instead of at infinity — infinity being the
  one distance guaranteed to fight everything else in view.
- **`cp_view_get_tangents` was not used**, though it returns exactly what is
  wanted in one call: it has been deprecated since visionOS 2.0 in favour of
  `cp_drawable_compute_projection`, so the four tangents are read back out of that
  matrix instead. They invert exactly, and nothing about its depth convention
  matters here.
- **A frame is now a slot rather than a texture.** The ring holds one texture per
  eye and publishes a slot only once every eye of it has been written: half a
  stereo frame would put one eye a frame ahead of the other. Both eyes of a frame
  are also rendered from **one latched head pose** — using a fresher pose for the
  second eye sounds like an improvement and is the exact shear that makes a stereo
  pair impossible to fuse.
- **Only the last eye paces the frame.** Two submissions make one frame; pacing
  both would have halved the frame rate in a way that looked like stereo costing
  twice what it does.

**What was verified, which is less than the above might suggest.**

- Both maintained patches were regenerated and **replay clean from the pinned
  revisions**; device and Simulator builds succeed and the visionOS audit passes.
  Unsigned device binary `0713389ba28064ae33c18f1ff3327f658a303ffb38c1a4284e8b88e6c194480b`.
- **The 4K pack renders.** `mk64-reloaded-v2026.04.03-sk-4k.o2r` (1.18 GiB) was
  placed in `Documents/mods/` — by hand, which is byte-for-byte what
  `SpaghettiPad_ImportModArchive` now does — and the engine reported
  `Loaded mod: MK64-Reloaded-SK v2026.0.0` and added the archive. With
  `gEnhancements.Mods.AlternateAssets` on, resident memory went from **265 MiB to
  707 MiB** and the captured frame shows the pack's own art: mowed-stripe grass,
  gravel road detail, a crisp billboard. (The capture was
  `docs/screenshots/visionos-4k-texture-pack.png`. It, and every other
  visionOS capture this log names, was lost on 2026-08-02 — see that day's
  entry. The measured numbers above stand; the pictures do not exist.)
- **Nothing about Mode B's appearance has been seen by anyone.** The Simulator
  reports **one view**, so Mode B declines there by design — the log line reads
  `Mode B is unavailable here: this drawable reports 1 view(s), so there is no
  second eye to render one` — and the surface allocated `flat, 1920 x 1080, 1
  eye(s)`. What that run proves is the **fallback**: Mode A still renders, at
  60 Hz, unchanged by the interpreter surgery above. It is not evidence of stereo
  and is not offered as any.
- **`NEW AVP` is paired but not connected** (`available (paired)`, no tunnel), so
  the device half was not attempted. Phase 9's gate — one track drivable in 6DoF
  with a legible HUD — stays open, and so does every question a wearer answers:
  whether two interpreter passes hold 90 Hz, whether they hold it under the 4K
  pack, whether the HUD is legible at 2.2 m, and whether the world scale is right.
- **The world scale is a guess and is exposed as one.** 55 mm per game unit,
  derived from karts that ought to read as about 1.4 m of go-kart. Nothing in the
  ROM says. It is a slider in the launch window rather than a constant in Fast3D
  precisely so the first wearer can disagree with it without a rebuild.
- **In-app ROM extraction is still unexercised.** `GameExtractor` now scans the
  app container for a `.z64` on visionOS and `SpaghettiPad_ImportRom` puts one
  there, but the Simulator's `mk64.o2r` was built by running Torch on the host.
  The path is written; it has not been run.

### 2026-08-01 — visionOS Phase 5: the reason no controller worked was one line in this lane's own window backend, and with it gone the owner drove a race and won it

- **The device result, which is the one that counts.** With the signed build above
  installed on `NEW AVP`, the owner — wearing it — drove a race, finished **1st**,
  and reports the session as **comfortable**. That is the first race ever driven
  in this lane and the first time any button has reached this game here.
- **The controller was not the one first reported, and the log is why this is
  recorded correctly.** The owner reported a DualSense. The device's own log names
  the connected device
  **`PlayStation VR2 Sense Controllers (L/R)`**, reports `1 game controller(s)`
  for the whole session, and never reports a second device or another name. No
  DualSense was connected in the collected window. The first-hand report and the
  log disagreed, and the log is the record kept here — this is exactly the kind of
  claim the `input` category was added to settle rather than have to remember.
- **PS VR2 Sense controllers therefore enumerate, and they enumerate as one
  gamepad, not two.** GameController presents the pair as a single combined
  device; SDL opened it, the control deck bound it to port 0, and it drove the
  game. This was an open question — the acceptance guide said whether they
  enumerate at all was itself the finding — and the answer is that they do.
  **Their 6DoF pose does not**, and nothing here claims it:
  `SpaghettiPad_AttachAccessoryTracking` is still an explicit logged refusal, so
  what worked is buttons and sticks, with the Sense controllers acting as an
  ordinary gamepad rather than as tracked spatial controllers.
- **Input reached the game, logged at the point of use:**
  `port 0 first input reached the game: buttons 0x0010, stick (0, 0)` — `0x0010`
  is `BTN_R` — 12.9 seconds after the controller connected.
- **The session, in numbers, all from the device.** Two immersive-space opens; the
  second ran to `compositor stopped after 19871 frames` at **89–90 Hz**, with the
  engine finishing 7,207. **Every drawable was anchored and none went without**,
  `com.apple.CompositorNonUI` logged `Presenting a drawable without a device
  anchor` **zero** times, and the app's subsystem logged **no error-level line at
  all**. The first drawable reported `2 view(s), 2 texture(s), 2 rasterization
  rate map(s)` — the dedicated layout, still correct — with distinct non-zero eye
  offsets per view.
- **Stereo separation, two more measurements: 67.0 mm and 67.6 mm**, with the
  screen centre at 0.6384/0.3575 and 0.6430/0.3623 across the two views (disparity
  0.281 of a view width, matching the earlier runs exactly). These sit just below
  the previously recorded 68.4–70.7 mm, so the observed range across six sessions
  is now **67.0–70.7 mm**.
- **The floor rule behaved as the earlier entry predicted and is still wrong.**
  The head was 0.89 m above the world origin and the floor was drawn at that
  origin. Nothing here measures the real floor; it needs plane detection and
  world-sensing authorization.
- **This closes Phase 4.** Its gate is a measured on-device stereo separation and
  a comfortable full race. Both are now on hardware. Phase 4's comfort half had
  been open only because no race could be driven, and that was Phase 5's obstacle
  rather than Phase 4's.
- **It does not close Phase 5.** Its gate asks for DualSense *and* PS VR2 Sense
  races plus stable port order across reconnects. The Sense half is met for
  buttons and sticks. **The DualSense half is now the unmet one** — no DualSense
  has been connected to this app — and no reconnect or multi-controller port
  ordering was exercised at all.

- Toolchain: Xcode 27.0 beta (`27A5218g`), XRSimulator 27.0 SDK, CMake 4.4.2
  under the Xcode generator. arm64, visionOS 26.0 deployment target, Release.
- **The bug, which is entirely this project's own.** `GfxWindowBackendVisionOS::HandleEvents`
  drained SDL's whole event queue every frame with `while (SDL_PollEvent(&event))`,
  discarding everything. Two of the events it discarded were
  `SDL_CONTROLLERDEVICEADDED` and `SDL_CONTROLLERDEVICEREMOVED`, and those are not
  the window backend's to consume: `Ship::SDLAddRemoveDeviceEventHandler` takes
  them out of the queue from inside the GUI update, and it is the **only** caller
  of `ConnectedPhysicalDeviceManager::RefreshConnectedSDLGamepads` — the one
  function that opens an SDL gamepad and makes it visible to a port. The drain ran
  first, so the handler found an empty queue, no gamepad was ever opened, and
  `GetConnectedSDLGamepadsForPort` returned nothing forever.
- **The SDL2 backend does not have this bug, and its shape says why.** It peeps
  two ranges — `SDL_FIRSTEVENT … SDL_CONTROLLERDEVICEADDED - 1` and
  `SDL_CONTROLLERDEVICEREMOVED + 1 … SDL_LASTEVENT` — which skip exactly those two
  adjacent events and leave them for the handler. That is a deliberate gap and it
  was not carried across when this lane's backend was written in Phase 3. The
  visionOS backend now peeps the same two ranges.
- **Everything else was already in place, which is why this was invisible.** SDL's
  MFi driver is compiled into this lane — `SDL_mfijoystick.o` is in the built
  `libSDL2.a` and exports `SDL_IOS_JoystickDriver` — `SDL_JOYSTICK_MFI` is `1` in
  the generated `SDL_config.h`, libultraship calls
  `SDL_Init(SDL_INIT_GAMECONTROLLER)` in `os.cpp`, and `ControlDeck::Init` already
  gives port 0 `PhysicalDeviceType::SDLGamepad` default mappings. Nothing needed
  adding. `SDL_PrivateJoystickShouldIgnoreEvent` was read rather than assumed as
  well: it gates on `SDL_HasWindows()`, which is false with no video subsystem, so
  a windowless app does not need `SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS` and
  none is set.
- **This corrects "No controller works, and none can" in the entry below.** That
  claim was written from the shell's logged refusals — `SpaghettiPad_InputInit`
  and the rest — and those refusals were real but were not the obstacle. Nothing
  in the shell routes input and nothing needs to: the engine's own control deck
  does all of it. The shell's input entry points are no longer refusals, but what
  they now do is report, not route.
- What was added, all of it reporting rather than routing:
  - `SpaghettiPad_InputDevicesChanged(count, names)` — the set of controllers the
    control deck has **opened**, read from `ConnectedPhysicalDeviceManager` rather
    than from SDL's raw device list, because a pad SDL enumerates but has no
    mapping for is never opened and reads as no controller at all. Reported on
    change, and always once at startup: a log with no line about controllers would
    not distinguish "none connected" from a reporting path that never ran.
  - `SpaghettiPad_InputFirstActivity(port, buttons, stickX, stickY)` — logged once
    per port from `LUS::ControlDeck::WriteToOSContPad`, at the point where the pad
    has been read and is about to be acted on. A controller being *connected* and
    a controller being *read* are separate claims and only the second is Phase 5's
    gate. A stick threshold of 20 is required for a stick-only report so that a
    resting analog stick that has drifted is not written up as the game being
    driven; a button needs no such allowance.
  - A new `input` os_log category. On a headset nothing can be screenshotted —
    `devicectl device capture screenshot` refuses on an Apple Vision Pro — so a
    log line is the only witness there is.
- Build: `scripts/build-visionos.sh --simulator` completed with
  `** BUILD SUCCEEDED **`. The only compiler diagnostics anywhere in the lane are
  the pre-existing `#pragma once in main file` on the bridging header and a
  pre-existing upstream `-Wdelete-non-abstract-non-virtual-dtor` on
  `LUS::ControllerDefaultMappings`, which surfaced only because this is the first
  change that recompiles `ControlDeck.cpp`. The diff to that file is 45 insertions
  and no deletions, and the warned construction is untouched context.
- Device build: `scripts/build-visionos.sh --device` completed with
  `** BUILD SUCCEEDED **` and passed `scripts/audit-visionos-app.sh` with
  `REQUIRE_SIGNED=1`: arm64, signed, executable SHA-256
  `693db554a08d4f930643a331ff27da5b8793e2b746ea046ff08bef5fea280671`, archive
  content SHA-256 `5ab6f5d8898cfdc3e8806b985bf84ec34b2d2968f158ac2e84359e45ff8564a0`
  (unchanged, and still ROM-free), controller database
  `eb002773dc8a16aa96f9ee2609798e231a9deb60c45e21fbdd4e221c9e8b7d77`.
- **Run, and the finding nobody expected: the Vision Pro Simulator has a
  gamepad.** Installed and launched on the Apple Vision Pro Simulator running
  visionOS 26.0 (`23M336`) with game data staged. The `input` category logged
  `no game controller is connected` and then, 0.15 s later,
  `1 game controller(s) connected: Gamepad` — reproduced across two separate
  launches. So a device the Simulator itself provides was enumerated, recognised
  as a game controller, opened by the control deck, and assigned to port 0. Before
  this change that could not have happened at all. What the device *is* was not
  established; SDL names it `Gamepad`, and the Simulator's own
  `I/O › Input › Send Game Controller to Device` is **off**, so it is not a
  forwarded Mac controller — there is none attached to this Mac.
- **The Simulator cannot press it, and no first-input line was produced.**
  `Send Keyboard Input to Device` was enabled and Return, Space and arrow keys
  were sent to the Simulator window; `port … first input reached the game` never
  appeared, and it should not have — the engine's keyboard path needs SDL video
  events that do not exist here, and nothing maps those keys to that gamepad. So
  this closes **the binding half only**. Whether input reaches the game is a
  device claim and is not made here.
- Sustained, as a regression check on a change that is in the per-frame event
  path: 201 seconds in one process, 12,001 frames presented at 60 Hz, 11,986 of
  them showing the engine, which finished 5,998; **all 12,001 drawables anchored
  and none went without**, and **no error-level line** was logged by the app's
  subsystem in the window.
- **Two Simulator boundaries recorded below are now stale, and both were
  environmental rather than technical.** Simulator.app **can** be opened on this
  Mac — the Phase 4 entry says no window could be — and once it had a window the
  Simulator's head **did** move, logging
  `the wearer's head is at (-0.08, 0.00, 0.00) m` where every previous run
  reported `(0.00, 0.00, 0.00)` unchanged. The head still only shifts with the
  window's camera and this is **not** world-locking evidence; the substantive
  boundary is unchanged, in that the first drawable still reports
  `1 view(s), 1 texture(s), 0 rasterization rate map(s)` with a zero eye offset,
  so **no Simulator result here is evidence of stereo**.
- Maintained patches: `patches/libultraship-visionos.patch` is now 1,200 lines /
  46,720 bytes, SHA-256
  `b44a991b4f752b70093bafeab2c6ebf8a1cb443b792e2659702e41b70c4dcd1a`, having grown
  by the two window-backend files and
  `src/libultraship/controller/controldeck/ControlDeck.cpp`.
  `patches/spaghettikart-visionos.patch` is **unchanged** at 437 lines / 18,428
  bytes, SHA-256
  `66154517ac8d6aebb6d4398b7dd22baad41398222825734af150be9cc0d1e39f` — nothing in
  this phase needed a change to SpaghettiKart.
- Replay: fresh clones at the exact pins
  `5b28472d477bab101dee2a0f469fe2aee2c58a01` and
  `f5c3843fe937320b64ff754fa6bf71b13ff5e7a1` accepted both patches in lane order,
  passed reverse application and `git diff --check`, and produced all 30 patched
  files — 22 libultraship and 8 SpaghettiKart — byte-identical to the working
  trees. `scripts/check-repo-safety.sh` passes.
- Boundary: this closes the **PS VR2 Sense half** of Phase 5's written gate and
  **not** the rest of it. Unclaimed and untried: a **DualSense**, which has never
  been connected to this app at all; port order across reconnects; multiplayer
  port assignment; and rumble. Accessory tracking — the 6DoF pose a Sense
  controller needs, and the only thing that would make them spatial controllers
  rather than a gamepad — is still an explicit logged refusal, and remains the one
  part of Phase 5 that needs code rather than a headset. ROM and texture-pack
  import remain logged refusals. The toolchain is an Xcode beta.

### 2026-08-01 — Apple Vision Pro, first hardware run: Phase 2's device half closes, Phase 3's runs six minutes, and the headset finds three bugs no Simulator could

- Hardware: `NEW AVP`, Apple Vision Pro (`RealityDevice14,1`), visionOS 27.0
  (`24M5326g`), Developer Mode enabled, connected to this Mac. Signed with team
  `8653K5YW36` as `com.subtlepath.spaghettipad`; the audit passed with
  `REQUIRE_SIGNED=1`, including the new ARKit/CompositorServices/Metal link
  check. The owner wore the headset throughout and every observation below that
  is not a log line is theirs.
- **The headset's own topology, which is not what the Simulator reports.**
  `compositor ready on Apple M2 GPU … foveation on`, and the first drawable gave
  **2 views** with distinct eye offsets — the Simulator has never given more than
  one view at the origin. Per-view viewports are 4493×3604.
- **Phase 2's device half is closed.** With no game data in the container the
  immersive space opened and drew the per-eye test pattern, and the wearer
  confirmed what only a wearer can: the border is **amber in the left eye and
  cyan in the right**, the identity ticks read **one square left, two right**,
  and the white reticle sits at a **different horizontal position in each eye**.
  Both eyes differ, which is the gate.
- **Measured stereo separation: 68.4, 68.7, 68.8 and 70.7 mm** across four
  sessions, from the two views' own transforms. The screen's centre lands at
  0.642 and 0.361 across the two views — a disparity of 0.281 of a view width.
  This is Phase 4's measurement, taken on hardware.
- **World-locking is demonstrated, which no Simulator run can do.** Over one
  374-second run the wearer's head moved and the screen's offset from it moved
  with it: `(0.00, 0.06, -2.00)` → `(0.19, 0.24, -1.97)` → `(-0.08, 0.26, -1.96)`
  → `(1.89, 0.21, -0.73)` metres. A head-locked screen reports the same triple
  forever. The Simulator reported exactly that for eighteen minutes because its
  head never moves.
- **Phase 3's device half is closed at 6 minutes 15 seconds.** From `engine
  thread entering the game loop` at 14:26:51.3 to the last sample at 14:33:06.0,
  the compositor presented **33,601 frames at 89–90 Hz, 33,562 of them showing
  the engine, which finished 11,192** (≈30 Hz). **All 33,601 drawables were
  anchored and none went without.** No error-level line was logged by the app's
  subsystem in the whole session. The run ended because this session terminated
  the process to install another build, not because anything failed.

  The gate as written asks for ten minutes. It ran six and a quarter, and the
  owner accepted that as sufficient on 2026-08-01 after reviewing these numbers.
  Recorded here rather than rounded up: nothing observed the remaining
  three and three-quarter minutes, and the phase queue's requirement column
  carries the same note.
- **The warning that blocked everything is gone on hardware.** Across the
  sessions above, `com.apple.CompositorNonUI` logged
  `Presenting a drawable without a device anchor` **once**, in the milliseconds
  between the wearer closing the immersive space and `layer renderer
  invalidated` — ARKit pauses world tracking on close, the compositor then
  refuses to anchor from a pose nothing vouches for, and the drawable is
  correctly dropped. Every drawable of every live frame carried an anchor.
- Three bugs came from the headset, and all three were invisible to eighteen
  minutes of Simulator running:
  - **The right eye was rasterized through the left eye's foveation.** The
    device offered layouts `[0, 2]` and the app chose `layered`, which returned
    `2 view(s), 1 texture(s), 1 rasterization rate map(s)`. Under that layout the
    single map carries a layer per eye and the layer is chosen by a
    `render_target_array_index` these shaders do not emit, so both passes used
    layer 0. The wearer saw a uniform grid in the left eye and a warped one in
    the right. The configuration now asks for `dedicated`, which returns
    **2 views, 2 textures, 2 rate maps**, and the wearer confirms both eyes are
    uniform. `EncodeViews` now logs an error if views ever outnumber rate maps
    again. Fixing this inside `layered` needs vertex amplification in all four
    shader programs, which buys nothing for a scene of one quad, a grid and a
    gradient.
  - **The eye-identity ticks were invisible because they were in a corner.** A
    Vision Pro renders considerably more than it shows; at 8% across and 86% down
    they fell outside the wearer's view entirely. Moved to 44%/68%, they are
    visible. The Simulator shows the whole rendered view, so nothing about this
    was observable there.
  - **The sky did not render at all.** The wearer saw grid lines on a void. The
    sky was a full-viewport triangle emitting clip coordinates directly, with its
    ray reconstructed by unprojection; the floor, which is world geometry through
    the same view projection, rendered perfectly throughout. Unprojecting at
    mid-depth instead of at the far plane — an infinite far plane makes `w = 0`
    there — changed nothing, so that theory was wrong or incomplete. The sky is
    now a large box of ordinary world geometry, the same kind of object as the
    floor, and the wearer confirms **the sky is visible**. The room's brightness
    was raised roughly threefold at the same time: the values before it had been
    judged from a Simulator screenshot, which is a poor instrument for what a
    headset shows, and the wearer's first report of that room was that there was
    no sky at all.
- **The floor is in the wrong place and the rule that puts it there is still a
  guess.** The headset reports the wearer's head **0.93 m above the ARKit world
  origin**; the Simulator reports 0.00. The rule became "treat an origin well
  below the head as the ground", which the log states explicitly along with the
  measurement. The wearer — seated — reports that the rendered floor is
  **higher than the real floor of the room they are sitting in**, so that origin
  is not the ground either. Nothing in this lane measures the real floor; doing
  so needs ARKit plane detection, which requires world-sensing authorization and
  returns nothing on the Simulator.
- **Comfort: the wearer reports the session was comfortable.** That covers six
  minutes of the game's attract loop on a world-locked screen, not a race —
  no race can be driven, because there is no input. Phase 4's gate asks for a
  comfortable *full race*, so that element remains open on Phase 5 rather than
  on anything in this phase.
- **Audio works, and the ledger was wrong to say otherwise.** The wearer reports
  hearing the game's audio on device and describes it as perfect. Earlier
  entries state "there is no audio" on the strength of `MA_NO_DEVICE_IO` being
  defined; that flag disables **miniaudio's** device I/O only, and SDL's
  CoreAudio driver is compiled into this lane — the generated `SDL_config.h`
  carries `SDL_AUDIO_DRIVER_COREAUDIO 1`, and the maintained libultraship patch
  touches `SDLAudioPlayer` precisely because that is the path in use. What was
  true is that **nobody had ever listened**; the claim was an untested assumption
  carried forward, and it is corrected here rather than in the dated entries
  below, which preserve what was known when they were written.
- **No controller works, and none can.** The wearer's PS VR2 Sense controller
  does nothing: `SpaghettiPad_InputInit`, `SpaghettiPad_AttachAccessoryTracking`
  and the motion-steering entry points are all explicit logged refusals. What
  ran for six minutes was the game's own attract loop. The ARKit session that
  accessory tracking must join is now live and reachable through
  `SpaghettiPad_ARSession()`, which is the part Phase 5 needed from this phase.
- Builds used: signed device executables `2565234c…` (first install),
  `7ad3ba8d…` (dedicated layout, ticks moved, floor rule), `e75d4acd…`
  (mid-depth sky unprojection, ineffective) and `0bce283a…` (sky as world
  geometry, the build the wearer confirmed). The maintained patches are
  **unchanged** by all of this — every file edited is repo-owned under
  `visionos/` — and the Simulator lane still builds from the same source, with
  Release arm64 xrsimulator executable SHA-256
  `102f2c2b54560a576a652122ad39d9b0b2c6d43383d8585ac804a1fdaf9d12fc`.
- Not re-run after these fixes: the Simulator evidence in the entry below was
  captured before the dedicated-layout, tick, floor and sky changes, so its
  captures show the older room. The Simulator cannot exercise any of the four.

### 2026-08-01 — visionOS Phase 4, first half: every drawable carries an ARKit device anchor, and the picture it shows is fixed in a room

- Toolchain: Xcode 27.0 beta (`27A5218g`), XRSimulator 27.0 SDK, CMake 4.4.2
  under the Xcode generator. arm64, visionOS 26.0 deployment target, Release.
- The shape of the problem: Phase 3 recorded that `com.apple.CompositorNonUI`
  logged `Presenting a drawable without a device anchor. On device this drawable
  won't be presented.` on every frame. That is the whole of what blocked the
  device halves of Phases 2 and 3, and it is now fixed and measured, not
  reasoned about — see the count below.
- What was added:
  - `visionos/SpaghettiPadWorldTracking.h` and `…mm` are new and repo-owned: the
    app's single `ar_session_t`, one `ar_world_tracking_provider_t`, and the
    per-frame pose query. The session is deliberately never stopped — stopping
    it when the wearer closes the immersive space would reset the world origin
    under a game they left running — and `SpaghettiPad_ARSession()` hands it to
    Phase 5, because ARKit permits exactly one session per app.
  - `visionos/SpaghettiPadCompositor.mm` queries that pose for each drawable and
    calls `cp_drawable_set_device_anchor` before encoding a single view.
  - The screen became an object in a room rather than a fixed distance ahead of
    the eyes: its place is computed once, from the first fully tracked pose, as
    2.00 m along the wearer's own horizontal gaze at their own height, upright.
    Pitch and roll are dropped, so a screen placed while glancing at the floor
    is still level.
  - An immersive environment, which is the other half of what Phase 4 is for: a
    graded sky and a floor grid, both world-locked and both dim enough that the
    game stays the brightest thing in the space. A fully immersive space with
    nothing in it but a screen gives head motion nothing to register against,
    and that is a comfort problem rather than a decoration one.
  - `ARKit` on the link line in the maintained SpaghettiKart patch, and a new
    check in `scripts/audit-visionos-app.sh` that the built app links ARKit,
    CompositorServices and Metal. Losing ARKit is the one regression a Simulator
    run cannot catch: the app would still build and still render here, and a
    headset would drop every frame it presented.
- Five findings came from the SDK and from running, not from the plan:
  - **The plan named the wrong clock.** The active gate recorded here said to
    query at `cp_frame_timing_get_trackable_anchor_time`. The header for that
    function says otherwise in its own note — *"For predicting ARKit device
    anchor use presentation time"* — and trackable anchor time is for
    registering content against real-world objects. The compositor queries
    `cp_frame_timing_get_presentation_time` of the drawable's own timing.
  - **`cp_view_get_transform` is device-from-view, not world-from-view.** Its
    documentation is explicit: it is where an eye sits relative to the head.
    Composing it with the anchor's `origin_from_anchor` transform is what makes
    a world-locked screen possible, and until an anchor existed the omission was
    invisible, because device space *was* the world.
  - **World tracking needs no authorization here, so no usage-description string
    was added.** `ar_world_tracking_provider_get_required_authorization_type()`
    was called rather than guessed at, and logs `required authorization none`.
  - **The world origin is not the floor.** The first version drew the floor at
    the origin's height, assuming visionOS puts that origin on the ground. The
    check written alongside it reported `the head is 0.00 m above the world
    origin`, so the origin is where the head was when tracking started and that
    floor would have been at eye level. The floor is now a nominal 1.50 m below
    the head, and the log says in the same line that this is not a floor
    measurement. Measuring the real floor needs plane detection, which requires
    world-sensing authorization and returns nothing on the Simulator.
  - **The room's colours are linear values, not display values.** The drawable
    is `bgra8Unorm_srgb` and encodes on write, so the first version's sky and
    grid — numbers chosen to look like dim greys — arrived about three times too
    bright. This was visible in a capture and invisible in the code.
  - A sixth, smaller one: the compositor creates a **fresh `ar_device_anchor_t`
    per query** rather than reusing one, which is what Apple's C example does.
    The compositor reads the anchor it was handed when it presents, which is
    after the next frame has been drawn, so a single reused object would have
    the following frame's prediction in it by then.
- Build: `scripts/build-visionos.sh --simulator` completed with
  `** BUILD SUCCEEDED **`; the Release arm64 xrsimulator executable SHA-256 is
  `f8d225bb9fd90f79e22982469e459034e29e80101ab08a69a8fb1e4e0cec169d`. When every
  shell source was recompiled, the only compiler diagnostic for any file under
  `visionos/` was the pre-existing `#pragma once in main file` warning on the
  bridging header; the two new files add none.
- Device build: `scripts/build-visionos.sh --device` completed with
  `** BUILD SUCCEEDED **` and passes the audit, which now includes the framework
  check: arm64, unsigned, executable SHA-256
  `41d82ababe6c81d61f15038eb01defd1959c1eb2d0a3532693b70f8e9c638453`, archive
  content SHA-256
  `5ab6f5d8898cfdc3e8806b985bf84ec34b2d2968f158ac2e84359e45ff8564a0`, controller
  database `eb002773dc8a16aa96f9ee2609798e231a9deb60c45e21fbdd4e221c9e8b7d77`.
  `xcrun vtool -show-build` reports `platform VISIONOS`, `minos 26.0`; `otool -L`
  shows `ARKit`, `CompositorServices`, `Metal` and `_CompositorServices_SwiftUI`.
  **It has not been run** — see the hardware note below. `strings` finds
  `SPAGHETTIPAD_AUTO_OPEN_IMMERSIVE_SPACE` once in the xrsimulator executable and
  not at all in the xros one.
- **The measurement that matters, as a before and after on the same Simulator.**
  In a ten-minute window of the previous build, `com.apple.CompositorNonUI`
  logged `Presenting a drawable without a device anchor` **17,363 times**. In the
  whole of this build's 18-minute run it logged **nothing at all** — not that
  message, not any message.
- Run: installed and launched on the Apple Vision Pro Simulator running visionOS
  26.0 (`23M336`). `world tracking running: required authorization none, provider
  running`, then `device anchor tracked at compositor frame 1`, then `room
  placed: a 1.60 m screen centred (0.00, 0.00, -2.00) m, 2.00 m ahead of the
  wearer` — all before the first frame was presented.
- **Sustained: 1,100 seconds — eighteen minutes — in one process, no restart.**
  The compositor presented 66,001 frames (59.998 Hz), 65,986 of them showing the
  engine, which finished 32,969 (29.97 Hz). **Every one of those 66,001 drawables
  carried a device anchor and none went without**, which the compositor counts
  separately for exactly this reason. Not one error-level line was logged by the
  app's subsystem in the whole window — the categories that spoke were `shell`,
  `compositor`, `surface` and the new `tracking` — and the ring never reported
  waiting for a free surface.
  The two evidence captures are 3,840×2,160 stills taken three seconds apart:
  `docs/screenshots/visionos-immersive-room.png` (SHA-256
  `353f5b514c259b5bd2cab074e45822002125b78d6209071c950238d7034bb4a5`) and
  `…-advanced.png` (SHA-256
  `6267671e1a30cd2ed25099190f416f27ccfd32abff28c7925b1b198774ae8d80`) show the
  Kalimari Desert attract demo at two different moments on a screen that has not
  moved, inside the graded room.
- The close-and-reopen path was exercised with the engine running, and it tests
  something new now. One `cycle` run logged the engine thread starting **once**
  and `world tracking running` **once**; the first compositor reported `layer
  renderer invalidated after 120 frames`; a second compositor came up on a
  different thread, immediately logged `engine frame 55`, anchored its own frame
  1, and placed the room again. So the ARKit session outlived the immersive
  space while the room did not — which is the intended split: reopening puts the
  screen back in front of the wearer wherever they have gone, without restarting
  the game or the session.
- Maintained patches: `patches/spaghettikart-visionos.patch` is now 437 lines /
  18,428 bytes, SHA-256
  `66154517ac8d6aebb6d4398b7dd22baad41398222825734af150be9cc0d1e39f`;
  `patches/libultraship-visionos.patch` is **unchanged** at 1,056 lines / 39,826
  bytes, SHA-256
  `da4950549fb5d05bac8b1185f85f646f62d26b70d0b87ee19093037670f2d60a`. Nothing in
  this phase needed a change to the engine.
- Replay: fresh clones at the exact pins
  `5b28472d477bab101dee2a0f469fe2aee2c58a01` and
  `f5c3843fe937320b64ff754fa6bf71b13ff5e7a1` accepted both patches in lane order,
  passed reverse application and `git diff --check`, and produced all 29 patched
  files — 21 libultraship and 8 SpaghettiKart — byte-identical to the working
  trees. `scripts/apply-patches.sh --lane visionos` recognises the applied stack,
  and `scripts/check-repo-safety.sh` passes.
- **Hardware, corrected.** Earlier entries said no Apple Vision Pro is attached
  to this Mac. More precisely: one **is paired** — `NEW AVP`, visionOS 27.0,
  Developer Mode enabled, last connected 2026-07-25 — but it is not reachable.
  `devicectl` reports its tunnel `unavailable`, and a live query fails with
  `com.apple.dt.CoreDeviceError error 4016`. Nothing was run on it, and no device
  claim is made anywhere in this entry.
- Boundary: this closes **none** of Phase 4's own gate, which is a measured
  on-device stereo separation and a comfortable full race. What it does is
  remove the reason the device halves of Phases 2 and 3 could not be attempted,
  and take the measurement Phase 4 needs so that closing it becomes a matter of
  reading a log on hardware. In particular:
  - **World-locking is not demonstrated here and cannot be.** The Simulator's
    head never moves: it logged `the wearer's head is at (0.00, 0.00, 0.00) m and
    the screen is (0.00, 0.00, -2.00) m from it` unchanged for eighteen minutes,
    and a head-locked screen would log exactly the same thing. The Simulator was
    also driven headless, and no Simulator.app window could be opened on this Mac
    to move its camera. That periodic line is the check a headset settles in
    seconds.
  - **Stereo remains unmeasured.** The Simulator's first drawable still reports
    `1 view(s), 1 texture(s), 0 rasterization rate map(s)` with `eye offset
    (0.0000, 0.0000, 0.0000) m`, and the compositor refuses to report a
    separation rather than reporting zero: `stereo separation is not measurable
    here: this drawable reports 1 view(s)`.
  - Comfort, foveation and the layered layout are untouched and untested. There
    is still **no audio** and **no input**: the game ran its own attract loop for
    the whole eighteen minutes and no button has ever been pressed. ROM import,
    texture-pack import and every input entry point remain logged refusals. The
    toolchain is an Xcode beta.

### 2026-08-01 — visionOS Phase 3, Simulator half: the engine runs on the compositor and its title screen holds a floating screen for twelve minutes

- Toolchain: Xcode 27.0 beta (`27A5218g`), XRSimulator 27.0 SDK, CMake 4.4.2
  under the Xcode generator. arm64, visionOS 26.0 deployment target, Release.
- The shape of the problem: `SDL_VIDEO` is off on visionOS, so libultraship's
  Fast3D Metal backend has no `SDL_Renderer`, no `CAMetalLayer`, and therefore
  no `-nextDrawable` to render into. Everything below follows from replacing
  that one call, and only that one call, with a surface the shell owns.
- What was added:
  - `include/fast/backends/gfx_visionos.h` and
    `src/fast/backends/gfx_visionos.cpp` are new in libultraship:
    `GfxWindowBackendVisionOS`, which answers the questions the SDL2 backend
    still owed the engine once the window was gone — dimensions, frame pacing,
    running state — and answers the desktop-only ones (fullscreen, cursor,
    mouse capture) honestly rather than by faking a window. The header also
    declares the C contract the shell implements. It is deliberately **not**
    weak: an engine that cannot reach its surface must fail to link, not render
    into nothing.
  - `visionos/SpaghettiPadRenderSurface.mm` is new and repo-owned: a ring of
    three 1920×1080 textures, one acquired per engine frame, published to the
    compositor when the GPU is finished with it.
  - `visionos/SpaghettiPadCompositor.mm` draws the latest published frame on a
    flat screen 1.6 m wide, 2 m ahead. The frame lifecycle, per-view render
    passes, layout handling and present around it are unchanged from Phase 2;
    what the engine added is one branch inside the encoder.
  - `SpaghettiPad_StartEngine` is live: a detached pthread with a 16 MiB stack
    calling upstream's renamed `main`.
- Correctness decisions that are not obvious from the code:
  - **Ordering between the two Metal queues is by completion, not by hope.** A
    texture is published only from its command buffer's `addCompletedHandler`,
    and returned to the ring only from the compositor's. Nothing samples a
    texture that is still being written, without an `MTLEvent` anywhere.
  - **The ring textures are `BGRA8Unorm` with an `_sRGB` texture view.** The
    engine's shaders write display-encoded values, exactly as they do into the
    `BGRA8Unorm` `CAMetalLayer` on every other platform; the compositor's
    drawable is `bgra8Unorm_srgb` and re-encodes on write. Sampling through the
    view is the decode that makes the round trip exact. Sampling the raw
    texture would have brightened every frame.
  - **Three buffers, not two.** With one published and one possibly in flight
    on the compositor, two would make the engine wait on the compositor every
    frame.
- Three findings came from building and running rather than from inspection:
  - **`SDL_main.h` renames `main` on visionOS.** `TARGET_OS_IPHONE` holds
    there, so SDL defines `SDL_MAIN_NEEDED` and then `#define main SDL_main` —
    which won over the maintained `main=SpaghettiPad_GameMain` and produced an
    `SDL_main` nothing called. `nm` on `Game.o` showed `_SDL_main` and no
    `_SpaghettiPad_GameMain`. The app now defines `SDL_MAIN_HANDLED`, which is
    exactly what it means, and the engine thread calls `SDL_SetMainReady()`
    before the game loop because SDL then refuses to initialise any subsystem
    until it is told the entry point has run.
  - **SDL 2.32.10 has no visionOS branch for HIDAPI.**
    `cmake/sdlchecks.cmake` picks a platform backend under `if(IOS OR TVOS)`,
    so visionOS compiled `SDL_hidapi.c` with nothing behind it and the app
    failed to link on seventeen `PLATFORM_hid_*` symbols. `SDL_HIDAPI` is now
    off for this lane. The generated `SDL_config.h` was read back rather than
    assumed: `SDL_HIDAPI_DISABLED` and `SDL_JOYSTICK_HIDAPI` off,
    `SDL_JOYSTICK_MFI` **on**, `SDL_AUDIO_DRIVER_COREAUDIO` on. SDL declares
    `SDL_VIRTUAL_JOYSTICK` dependent on `SDL_HIDAPI`, so
    `SDL_JOYSTICK_VIRTUAL` went off with it; the stale claim that this lane
    kept it has been corrected in the maintained patch. Nothing needs it yet.
  - **Reporting the engine's own pace as the display's rate is a feedback
    loop.** Upstream derives its interpolation target from
    `GetCurrentRefreshRate()` and then calls `SetTargetFps` with the result, so
    a backend answering with `mTargetFps` answers with its own previous answer
    — harmless while the two agree, and permanently stuck at the lower of them
    the moment a user raises the interpolation setting. The compositor now
    measures its own presentation rate over each 600-frame window and the
    backend reports that.
- Build: `scripts/build-visionos.sh --simulator` completed with
  `** BUILD SUCCEEDED **`. The Release arm64 xrsimulator executable SHA-256 is
  `078519c009776ba3256a6971307cc47715cfea89a61c5d8b0891a2989d27ca7e`;
  `xcrun vtool -show-build` reports `platform VISIONOSSIMULATOR`, `minos 26.0`.
  The only compiler diagnostic for any file under `visionos/` or for the two
  new libultraship files is the pre-existing `#pragma once in main file`
  warning on the bridging header.
- Device build: `scripts/build-visionos.sh --device` completed with
  `** BUILD SUCCEEDED **` and the app passes `scripts/audit-visionos-app.sh`:
  arm64, unsigned, executable SHA-256
  `75d2ab5db9a978eb45ec009507cf5c04b191132722103199d06b457c10a5be4b`, archive
  content SHA-256
  `5ab6f5d8898cfdc3e8806b985bf84ec34b2d2968f158ac2e84359e45ff8564a0`,
  controller database
  `eb002773dc8a16aa96f9ee2609798e231a9deb60c45e21fbdd4e221c9e8b7d77`.
  `xcrun vtool -show-build` reports `platform VISIONOS`, `minos 26.0`, and
  `otool -L` shows `CompositorServices`, `Metal` and
  `_CompositorServices_SwiftUI`. **It has not been run:** no Apple Vision Pro
  is attached to this Mac. `strings` finds
  `SPAGHETTIPAD_AUTO_OPEN_IMMERSIVE_SPACE` once in the xrsimulator executable
  and not at all in the xros one.
- Game data: a local `mk64.o2r` was generated with the pinned Torch from the
  owner's own Mario Kart 64 (US) ROM, SHA-1
  `579c48e211ae952530ffc8738709f078d5dd215e`, in a disposable copy of the
  source tree so no generated header or asset touched the working checkout. It
  was staged into the Simulator container. **It is not in this repository and
  never will be**, and neither is the ROM.
- Run: installed and launched on the Apple Vision Pro Simulator running
  visionOS 26.0 (`23M336`). The engine thread logged `entering the game loop`,
  the surface logged `render surface ready … 1920 x 1080, 3 buffers`, and the
  compositor logged `showing the engine on a 1.60 m screen 2.00 m ahead, from a
  1920 x 1080 frame (engine frame 1, compositor frame 17)` 0.33 seconds after
  the engine thread entered the game loop — the whole of `GameEngine::Create`,
  the 26 MB game archive, and the first rendered frame.
- **Sustained: 730.0 seconds — twelve minutes — in one process, no restart.**
  The compositor presented 43,801 frames (59.998 Hz, and it measured itself at
  60 Hz), 43,785 of them showing the engine, which finished 21,894 frames
  (29.99 Hz). No error was logged by any of the app's four log categories, and
  the ring never once reported waiting for a free surface. The two evidence
  captures are 3,840×2,160 stills taken three seconds apart **twelve minutes
  into that run**: `docs/screenshots/visionos-immersive-title-screen.png`
  (SHA-256
  `0bcf4cba04d10fa317718ccfccd36a47edf5964de27dd398ac8e82bfc9bf5364`) shows
  the Mario Kart 64 title mid-fade with `PUSH START BUTTON` legible, and
  `…-advanced.png` (SHA-256
  `f44969dac2594669d17c6fa250486b7c08a583457b16c24201c1bf4de0ff5d22`) shows it
  fully faded in three seconds later. Two stills that disagree are what
  separates a running engine from one stalled frame left on a screen.
- The engine runs at 30 Hz **because upstream asks it to**, not because the
  path cannot do more: `gInterpolationFPS` defaults to 30 and
  `GetInterpolationFPS()` takes the smaller of that and the display rate. This
  was measured rather than reasoned about — with the console variable set to
  60 the engine finished 600 frames per ten-second interval against the
  compositor's 600, a 1:1 match at 60 Hz. The variable was returned to its
  default afterwards. Whether 30 or 60 is the right default in a headset is a
  comfort question, and comfort is a device measurement.
- The close-and-reopen path was exercised with the engine running, which is a
  different test from Phase 2's. One `cycle` run logged the engine thread
  starting **once**; the first compositor thread reported `layer renderer
  invalidated after 122 frames`; a second compositor came up **on a different
  thread** and immediately logged `engine frame 55`, not frame 1. The engine
  kept its place rather than restarting the game, and its counter did not run
  on through the closed second — the surface reports itself live only while a
  compositor is consuming, and the game loop idles otherwise.
- Runtime side effects, not just return values: the container gained
  `spaghettify.cfg.json`, `imgui.ini`, `default.sav`,
  `controllerPak_header.sav` and `logs/`, so the engine reached and used its
  own storage rather than merely rendering.
- Maintained patches: `patches/libultraship-visionos.patch` is now 1,056 lines
  / 39,826 bytes, SHA-256
  `da4950549fb5d05bac8b1185f85f646f62d26b70d0b87ee19093037670f2d60a`;
  `patches/spaghettikart-visionos.patch` is 433 lines / 18,168 bytes, SHA-256
  `34dc7e0d304d452f0e4eba7892104d044ed7546a58a977cb0185c24a7bf8d9dc`.
- Replay: fresh clones at the exact pins
  `5b28472d477bab101dee2a0f469fe2aee2c58a01` and
  `f5c3843fe937320b64ff754fa6bf71b13ff5e7a1` accepted both patches in lane
  order, passed reverse application and `git diff --check`, and produced all 29
  patched files — 21 libultraship and 8 SpaghettiKart, including the two new
  files — byte-identical to the working trees.
  `scripts/apply-patches.sh --lane visionos` recognises the applied stack, and
  `scripts/check-repo-safety.sh` passes.
- **The finding that changes the plan: every drawable so far has been presented
  without a device anchor.** `com.apple.CompositorNonUI` logs `Presenting a
  drawable without a device anchor. On device this drawable won't be presented.`
  on every frame. The compositor has never called
  `cp_drawable_set_device_anchor`, because ARKit world tracking was scheduled
  for Phase 4 — but the consequence is stronger than "head-locked": on real
  hardware the frame is **dropped**, not misplaced. So the device halves of
  Phase 2 and Phase 3 are both blocked on Phase 4's first task, and the Phase 2
  expectation that attaching a headset would show the amber and cyan borders
  was wrong. This is recorded rather than fixed: an ARKit path written here
  could not be verified here, and an unverified fix is not evidence.
- Boundary: this closes the Simulator half of Phase 3 and **nothing about
  stereo, immersion, comfort, foveation, or the layered layout**. The
  Simulator's first-drawable log still reads `1 view(s), 1 texture(s), 0
  rasterization rate map(s)` with `eye offset (0.0000, 0.0000, 0.0000) m`, so
  there was one eye at the origin; both eyes would in any case receive the same
  flat picture, since a screen is not a stereoscopic scene. There is **no
  audio**: `MA_NO_DEVICE_IO` is defined and the SDL audio path is unexercised
  on visionOS. There is **no input**: nothing is wired to a controller, the
  game ran its own attract loop for the whole twelve minutes, and no button has
  ever been pressed. ROM import, texture-pack import and every input entry
  point remain logged refusals. The toolchain is an Xcode beta.

### 2026-08-01 — visionOS Phase 2, Simulator half: an immersive space opens and renders a test pattern

- Toolchain: Xcode 27.0 beta (`27A5218g`), XRSimulator 27.0 SDK, CMake 4.4.2
  under the Xcode generator. arm64, visionOS 26.0 deployment target, Release.
- What was added:
  - `visionos/SpaghettiPadApp.swift` gains an `ImmersiveSpace` whose only
    content is a `CompositorLayer`, an `.immersionStyle` of `.full`, and a
    launch-window button that opens and dismisses it. Its configuration
    provider reads capabilities rather than assuming them.
  - `visionos/SpaghettiPadCompositor.mm` is new: the compositor thread, the
    frame lifecycle, the Metal pipeline, and the test pattern.
  - `visionos/SpaghettiPadBridge.h` gains `SpaghettiPad_StartCompositor` and
    `SpaghettiPad_StopCompositor`. `SpaghettiPad_StartEngine` lost its layer
    renderer argument: the compositor and the game thread have different
    lifetimes, since the compositor runs whenever the space is open while the
    engine can only run once game data exists. It remains a logged refusal.
  - The maintained SpaghettiKart patch compiles the new file and names
    `CompositorServices` and `Metal` on the link line rather than inheriting
    Metal from libultraship by luck.
- Deprecated API avoided rather than inherited: `cp_frame_query_drawable` is
  deprecated as of visionOS 26.0, so the loop uses `cp_frame_query_drawables`
  and walks the returned array; `cp_view_get_tangents` has been deprecated
  since visionOS 2.0, so the reticle is placed with
  `cp_drawable_compute_projection`.
- The test pattern is not a hardcoded left/right image. Its reticle is one
  world point 0.6 m ahead, projected through each view's own projection and
  transform, so the eyes differ because the compositor's geometry says they
  differ; a pattern that faked the difference could not tell a working stereo
  path from a broken one. The border colour (amber/cyan) and a tick run one
  longer per view identify which eye a capture came from even without colour.
  A sweep bar advances with the frame index, so two stills taken moments apart
  disagree about where it is.
- Two findings came from building and running rather than from inspection:
  - **The Vision Pro Simulator does not offer the layered layout.** The active
    gate expected `.layered`. With foveation unsupported there,
    `supportedLayouts(options: [])` returned `[0, 1]` — dedicated and shared —
    so the configuration fell back to `.dedicated`. The renderer walks whatever
    texture index, slice and viewport each view reports and clears a
    destination only on its first pass, so all three layouts are handled by
    construction — but only `.dedicated` has been run. The layered path is
    **unexercised** and remains a device claim. What was offered and what was
    chosen are both logged rather than assumed.
  - **Coplanar geometry needs `GreaterEqual`, not `Greater`.** visionOS is
    reverse-Z, and a strict depth comparison rejected every pattern rectangle
    after the first at the same depth, so the earliest draw won instead of the
    latest and the sweep bar punched a hole through the reticle. This was
    visible in a capture and invisible in the code.
- Build: `scripts/build-visionos.sh --simulator` completed with
  `** BUILD SUCCEEDED **`. The Release arm64 xrsimulator executable SHA-256 is
  `ce145a5f41589f89331b75b9f5f2dd91b9304a5f85c2b41692de695e2d319d1c`;
  `xcrun vtool -show-build` reports `platform VISIONOSSIMULATOR`, `minos 26.0`.
  The only compiler diagnostic for any file under `visionos/` is the
  pre-existing `#pragma once in main file` warning on the bridging header; the
  new sources add none.
- A device build now exists. Phase 1 produced none and left
  `scripts/audit-visionos-app.sh` unexercised; `scripts/build-visionos.sh
  --device` now completes with `** BUILD SUCCEEDED **` and the app **passes
  that audit**: arm64, unsigned, archive content SHA-256
  `5ab6f5d8898cfdc3e8806b985bf84ec34b2d2968f158ac2e84359e45ff8564a0`, and
  controller database
  `eb002773dc8a16aa96f9ee2609798e231a9deb60c45e21fbdd4e221c9e8b7d77`.
  `xcrun vtool -show-build` reports `platform VISIONOS`, `minos 26.0`; the
  executable SHA-256 is
  `53858c578a5c585b9b1461be273a14c181b4ae6d13555bf1e2bf2577c635cec2`, and
  `otool -L` shows `CompositorServices`, `Metal` and
  `_CompositorServices_SwiftUI` linked. This proves the compositor compiles and
  links against the real `xros` SDK. **It has not been run:** no Apple Vision
  Pro is attached to this Mac.
- The Simulator hook's exclusion from device builds was checked rather than
  assumed: `strings` finds `SPAGHETTIPAD_AUTO_OPEN_IMMERSIVE_SPACE` in the
  xrsimulator executable and finds no occurrence of it in the xros one.
- Run: installed and launched on the Apple Vision Pro Simulator running
  visionOS 26.0 (`23M336`). The app logged `openImmersiveSpace returned
  opened`, then `compositor ready on Apple xrOS simulator GPU: layout 0,
  colour format 81, depth format 252, foveation off` — that is
  `BGRA8Unorm_sRGB` and `Depth32Float`, the two formats the configuration
  asked for.
- Live rather than a single frame: the loop reported `compositor is live` every
  600 frames at ten-second intervals, so a sustained 60 Hz, and ran past 7,200
  frames in one sitting. `docs/screenshots/visionos-immersive-test-pattern.png`
  and `…-advanced.png` are 3840×2160 captures two seconds apart in which the
  sweep bar has visibly moved, with SHA-256
  `196badccdbaf7da172319ceecd3671b93ae2312c85f767aa6f5e3e506b0e243a` and
  `52f2800e9508f6d60c2090e0445531aa5cebe42df980ed3055ffdeec04bc6b85`.
- The close and reopen path was exercised, not merely reasoned about. A cycling
  run logged `layer renderer invalidated after 120 frames`, then `immersive
  space dismissed`, then a second `openImmersiveSpace returned opened` and a
  second `compositor ready` **on a different thread**, which is what proves the
  first render thread noticed its renderer go invalid, was joined, and did not
  block or leak into the next open. The evidence captures above come from that
  third open.
- Driving a headless device: the Simulator here runs with no Simulator.app
  window, so there is no button to press.
  `SPAGHETTIPAD_AUTO_OPEN_IMMERSIVE_SPACE` opens the space at launch (`1`) or
  opens, closes and reopens it (`cycle`), and then dismisses the launch window
  so a capture shows what the compositor drew rather than a window and a
  container path. It is inside `#if targetEnvironment(simulator)`, so it is
  compiled out of every device build, and it is inert unless set. No release
  behaviour is attached to it.
- Maintained patches: `patches/libultraship-visionos.patch` is unchanged at 472
  lines / 16,811 bytes, SHA-256
  `6f048b7662def878da776a60c15ffea6bd186f5a7e3008334d38d414d6a503e3`;
  `patches/spaghettikart-visionos.patch` is now 413 lines / 16,770 bytes,
  SHA-256
  `2a4d0b47180ca8da47a0bf15db2b93d5ed800dba86d16de3bea0eea2c9520566`.
- Replay: fresh clones at the exact pins
  `5b28472d477bab101dee2a0f469fe2aee2c58a01` and
  `f5c3843fe937320b64ff754fa6bf71b13ff5e7a1` accepted both patches in lane
  order, passed reverse application and `git diff --check`, and produced all 8
  SpaghettiKart and 17 libultraship patched files byte-identical to the working
  trees, so the patches still capture the whole change.
- `scripts/check-repo-safety.sh` passes. It was failing before this work: the
  Phase 1 entry below recorded the Simulator's device UUID, which the script
  rejects in public documentation. That line has been corrected.
- Boundary: this closes items 1 and 2 of Phase 2 and **nothing about stereo**.
  The Simulator's first-drawable log reads `1 view(s), 1 texture(s), 0
  rasterization rate map(s)` with `eye offset (0.0000, 0.0000, 0.0000) m`, so
  there was one eye, at the origin, and the reticle's per-eye disparity was
  exercised only in its degenerate single-view case. Foveation was off and no
  rasterization rate map existed, so that path is unexercised too. No ARKit
  device anchor is set, so the pattern is head-locked and nothing here speaks
  to reprojection, immersion or comfort. This renders a test pattern, not game
  content: `SpaghettiPad_GameMain` is still never called, and the engine,
  import and input entry points remain logged refusals. The toolchain is an
  Xcode beta.

### 2026-08-01 — visionOS Phase 1 closed: the app configures, links, and launches

- Toolchain: Xcode 27.0 beta (`27A5218g`), XRSimulator 27.0 SDK, CMake 4.4.2
  under the Xcode generator. The target is arm64 with a visionOS 26.0
  deployment target, built Release.
- Two real blockers were found by building rather than by inspection, and both
  are now carried in the maintained visionOS patch:
  - **SDL misc subsystem.** SDL2's iOS `SDL_OpenURL` backend calls
    `-[UIApplication openURL:]`, which is `API_UNAVAILABLE(visionos)`, so
    `src/misc/ios/SDL_sysurl.m` could not compile. Setting `SDL_MISC OFF`
    selects SDL's own dummy backend (`if(NOT HAVE_SDL_MISC)` in SDL2's
    `CMakeLists.txt`), so `SDL_OpenURL` still links and returns
    `SDL_Unsupported()` rather than disappearing. Its single caller is
    upstream's desktop "Open App Files Folder" button in
    `src/port/ui/PortMenu.cpp`, which has no folder to open on visionOS.
  - **C-family flags reaching swiftc.** `cmake/SetFlags.cmake` set
    `-Wall -Wextra -Wno-error -Wno-missing-field-initializers -Wno-parentheses
    -Wno-missing-braces -ffast-math -pipe` and `-pthread` through a
    language-agnostic `target_compile_options()`. In a mixed Swift/C/C++/
    Objective-C++ target CMake copied them into `OTHER_SWIFT_FLAGS`, and the
    Swift driver hard-errors on the first flag it does not recognise
    (`Driver threw unknown argument: '-Wall'`). Each C-family option is now
    scoped with `$<COMPILE_LANGUAGE:C,CXX,OBJCXX>`. The generated project was
    re-read to confirm the fix rather than assumed: `OTHER_CFLAGS` and
    `OTHER_CPLUSPLUSFLAGS` still carry the complete warning set, while
    `OTHER_SWIFT_FLAGS` retains only Swift's own `-Osize`/`-Onone`, which CMake
    maps per language. The `-fno-lto` Debug option was scoped the same way.
- Build: `scripts/build-visionos.sh --simulator` completed with
  `** BUILD SUCCEEDED **`. The Release arm64 xrsimulator executable SHA-256 is
  `6c9f0b4251839498d7e51bb5e3c73201f28b50b452ce858091cf2891d87186ad`.
- Bundle: `xcrun vtool -show-build` reports `platform VISIONOSSIMULATOR`,
  `minos 26.0`; `lipo -archs` reports `arm64`; the built `Info.plist` carries
  `UIDeviceFamily` `[7]` from `TARGETED_DEVICE_FAMILY`. The bundle contains the
  ROM-free `spaghetti.o2r`, `gamecontrollerdb.txt`, `config.yml`, `meta/`, and
  `yamls/`.
- Launch: the app installed and launched on the Apple Vision Pro Simulator
  running visionOS 26.0 (`23M336`) and was observed live as PID `13642`. The
  Simulator's device identifier is deliberately not recorded here: it is a local
  identifier, and `scripts/check-repo-safety.sh` rejects one in public
  documentation. The SwiftUI launch window rendered its
  `status.ready` branch, so `SpaghettiPad_RuntimeInit` returned non-zero across
  the Swift/Objective-C++ bridge; the failure branch would have read "The engine
  could not prepare its storage."
- Runtime side effects, not just return values: `RuntimeInit` created
  `Documents/mods` in the app container, and `Documents` held nothing else, so
  `SpaghettiPad_GameArchiveReady` correctly reported no game archive and the
  window showed the "No game data yet" guidance. Evidence image
  `docs/screenshots/visionos-launch-window.png` is 1920×1080 with SHA-256
  `32f878fb1b22cd3c7cfc9db63ec89e39b9112de58dcc17c7b4d4bfa1d34fdb9f`.
- Maintained patches: `patches/libultraship-visionos.patch` is 472 lines /
  16,811 bytes, SHA-256
  `6f048b7662def878da776a60c15ffea6bd186f5a7e3008334d38d414d6a503e3`;
  `patches/spaghettikart-visionos.patch` is 405 lines / 16,333 bytes, SHA-256
  `2459d66e7891af8e0b55e70b38421746a33c58159083f9ee62c990f36c7828f1`.
- Replay: fresh clones checked out at the exact pins
  `5b28472d477bab101dee2a0f469fe2aee2c58a01` and
  `f5c3843fe937320b64ff754fa6bf71b13ff5e7a1` accepted both patches in lane
  order, passed reverse application and `git diff --check`, and produced files
  byte-identical to the working trees, so the patches capture the whole change.
  `scripts/check-repo-safety.sh` passed.
- Boundary: this closes Phase 1 only — that the visionOS app configures, links,
  launches, and reaches its SwiftUI launch window. **It renders no game
  content.** `SpaghettiPad_GameMain` is compiled and linked but never called,
  and every compositor, engine-thread, import, and input entry point in
  `visionos/SpaghettiPadBridge.h` remains an explicit logged refusal. This is a
  Simulator result on an `xrsimulator` bundle: `scripts/audit-visionos-app.sh`
  requires `platform VISIONOS` and deliberately rejects it, so the device audit
  is unexercised, no `xros` device build was produced, and nothing here speaks
  to stereo, immersion, comfort, or signing. The toolchain is an Xcode beta.

### 2026-07-29 — customizable iPad and iPhone controls physically accepted

- The customizable controller is now the default, with the prior fixed
  controller available through **Legacy Touch Controls**.
- On a physical 12.9-inch iPad Pro, layout movement, resizing A and Z, hiding
  controls, returning to a live race, engaging A hold assist, and tapping A to
  release it were exercised successfully. The accepted saved layout became
  the normalized tablet default.
- On a physical iPhone 14, the saved racing layout became the normalized phone
  default. Grand Prix play, A hold assist, texture-pack rendering, the
  safe-area-inset menu, and Start alignment were exercised and accepted.
- Fresh phone and tablet defaults were also rendered in Simulator layout-edit
  mode so visible control spacing and full touch hit frames could be inspected.
  In particular, R and the lower C control remain separated.
- The final signed arm64 development build was installed in place on the
  iPhone, preserving app data, and remained live after launch. The exact
  accepted touch-code commit is `6dcf4a1`; its executable SHA-256 is
  `bd97648f0dc2bb0475047dc7ae642602cf8ba965de252f4d0895bba52f9d22e3`.
- Boundary: these sessions accept the new layouts and native touch behavior;
  a complete touch-only Grand Prix remains the Phase 8 endurance gate.

### 2026-07-29 — Phase 6 runner control-flow replay passed; hardware still pending

- A complete temporary CoreDevice-command replay exercised the signed-audit,
  device-detail, install, cold-launch, process-sampling, evidence-summary, and
  SHA-256-manifest paths without representing the mock as device evidence.
- The first replay exposed that this macOS `plutil -lint` mode rejects
  CoreDevice JSON even though `plutil -p` parses it. The runner now uses the
  latter supported parser check before inspecting each process sample.
- Positive diagnostic replay: a one-second mock session emitted distinct
  process samples at zero and one seconds, generated the full evidence bundle,
  labeled itself diagnostic because it was below 600 seconds, kept visible
  title confirmation pending, and passed `shasum -a 256 -c SHA256SUMS` for
  every captured file.
- Negative replay: an empty running-process result stopped immediately with
  `SpaghettiPad was no longer running after 0 seconds` and wrote the same
  reason to `FAILURE.txt`.
- Boundary: this verifies the local runner control flow only. No physical
  device is attached to this Mac, so Phase 6 still requires the real signed
  install, visible title/demo, and ten-minute run on the owner's other Mac.

### 2026-07-28 — Phase 6 hardware evidence harness ready; physical run pending

- Remote boundary recheck: `xcrun devicectl list devices --timeout 5` on this
  build Mac reports `No devices found`. The owner's physical iPad remains
  attached to a different local Mac, so no install, launch, rendering, or
  stability result is claimed here.
- Reproducible device gate: `scripts/run-phase6-hardware-smoke.sh` now accepts
  an explicit CoreDevice selector, refuses an unsigned build, records the
  repository/app/Xcode/macOS identity, captures before/after device details,
  installs without deleting the existing container, cold-launches the app,
  and samples the SpaghettiPad process every 30 seconds for a default 600
  seconds. It labels shorter runs diagnostic.
- Evidence boundary: the runner writes CoreDevice JSON/logs, code-signing
  metadata, executable SHA-256, operator title/demo confirmation, and a
  manifest to ignored `ref/evidence/`. Process survival alone is explicitly
  insufficient: Phase 6 still requires the owner to confirm the visible
  title/demo, attach a device screenshot or recording, and enter the reviewed
  device model/OS evidence in this log.
- Signing hardening: `scripts/audit-ios-app.sh` now decodes the embedded
  provisioning profile and signed-app entitlements, rejects an expired
  profile, requires matching team identifiers, requires the code application
  identifier to match the profile prefix plus bundle identifier, and verifies
  that the profile authorizes it. The established unsigned app still passes
  `REQUIRE_UNSIGNED=1`; `REQUIRE_SIGNED=1` rejects it, and an ad-hoc-signed
  test copy with a dummy profile is rejected because the profile cannot be
  decoded.
- Operator handoff: `docs/HARDWARE_ACCEPTANCE.md` provides the exact signed
  build, first-install/Files setup, ten-minute gate, and later Phase 7–11
  sequence. It warns that generated evidence may contain device/signing
  identifiers and must remain ignored.
- CI recheck: run
  [30406005730](https://github.com/chrissotraidis/spaghettipad/actions/runs/30406005730)
  remains an external pre-start failure with zero steps and the unchanged
  GitHub billing/spending-limit annotation.

### 2026-07-29 — Preview 3 customizable-controls release published

- Release: annotated tag
  [`v0.1.0-preview.3`](https://github.com/chrissotraidis/spaghettipad/releases/tag/v0.1.0-preview.3)
  resolves to merged `main` commit
  `5786e6faa74487a8be7bdfe30d8b2bb2a7a54541`.
- Controls: Preview 3 is the first downloadable IPA with customizable touch
  controls as the default, separate phone/tablet profiles, move, resize, hide,
  show, and reset tools, A-button hold assist, and an optional legacy mode.
- Clean build: hosted repository safety and unsigned arm64 iPhoneOS
  build/package jobs passed in
  [run 30481595201](https://github.com/chrissotraidis/spaghettipad/actions/runs/30481595201).
  The artifact is version `0.1.0`, build `3`, minimum iOS/iPadOS 15.0, built
  with Xcode 16.4 and the iPhoneOS 18.5 SDK.
- IPA audit: `SpaghettiPad-0.1.0-preview.3-unsigned.ipa` is 11,228,922 bytes
  with 293 ZIP entries and SHA-256
  `4b74433290c1dba54f5b4a31820c835fd826359ebd172fe0351c4115182c388b`.
  It is unsigned and contains no ROM, extracted game archive, imported texture
  pack, provisioning profile, certificate, or signing identity. The only
  `.o2r` is the pinned, ROM-free `spaghetti.o2r`.
- Exact-artifact device check: a temporary extracted copy of the exact IPA was
  signed with the established development profile, passed strict signature
  verification and the signed-app audit, update-installed without uninstalling,
  launched, and observed as a live process on a physical iPhone 14 running iOS
  26.5.2. The public IPA remained unchanged and unsigned.
- Live publication check: both release assets were downloaded back from
  GitHub; `SHA256SUMS` passed and the downloaded IPA's compressed-data audit
  reported no errors.
- Boundary: this evidence proves build, package integrity, install, launch,
  and live process state. The extended gameplay, controller, tilt,
  performance, long-session, and final cross-release update/save-preservation
  gates remain open.

### 2026-07-29 — Preview 2 release hardening completed

- Packaging contract: `scripts/package-ios.sh` now requires an unsigned app by
  default and refuses valid signed input unless the maintainer explicitly sets
  `REQUIRE_SIGNED=1`. Both paths were exercised against valid build products.
- Third-party notices: the tracked Zlib notice for SDL_GameControllerDB is
  required by the packager and appears at
  `ThirdPartyLicenses/SDL_GameControllerDB.LICENSE`. Preview 2 carries 33
  third-party notice files.
- Licensing boundary: the pinned SpaghettiKart revision has no top-level
  license, and the repository now states that its redistribution terms are not
  settled. Upstream clarification is tracked in
  [SpaghettiKart issue #731](https://github.com/HarbourMasters/SpaghettiKart/issues/731).
- Build: the unsigned arm64 iPhoneOS Release app is version `0.1.0`, build
  number `2`, minimum iOS/iPadOS 15.0, with executable SHA-256
  `13a0123bf384c89d96485a7cc783be69081b41c1cc1697b61b725f428db80b6c`.
- IPA audit: `SpaghettiPad-0.1.0-preview.2-unsigned.ipa` is 11,220,542 bytes
  with 293 ZIP entries and SHA-256
  `51717d5645e2b8d126a952e6ef8f8b9c7033b918d1c1a6f22e815320025c6de7`.
  It contains no ROM, `mk64*.o2r`, `.otr`, imported texture pack,
  `_CodeSignature`, provisioning profile, certificate, or signing identity.
- Exact-artifact device check: a temporary extracted copy of the unsigned IPA
  was signed with the established development profile, re-audited as signed,
  update-installed without uninstalling, launched, and observed as a live
  process on the connected 12.9-inch sixth-generation iPad Pro. The release
  IPA remained unchanged and unsigned.
- Publication: Preview 2 supersedes Preview 1 for new downloads. Preview 1
  remains available with its original checksum as an immutable historical
  prerelease.
- Boundary: the device check proves installation and process launch, not
  visible title/demo responsiveness or the remaining physical gameplay gates.
- Hosted CI: repository safety plus the ROM-free unsigned iPhoneOS
  build/package workflow passed at the release head in
  [run 30453167211](https://github.com/chrissotraidis/spaghettipad/actions/runs/30453167211).
  The subsequently combined `main` branch, including the separately reviewed
  iPhone touch refinement, passed the same workflow in
  [run 30455493658](https://github.com/chrissotraidis/spaghettipad/actions/runs/30455493658).

### 2026-07-29 — Initial unsigned preview IPA published

- Release boundary: annotated tag
  [`v0.1.0-preview.1`](https://github.com/chrissotraidis/spaghettipad/releases/tag/v0.1.0-preview.1)
  points to release commit
  `e0b2da5883faa5852b54847bbc8adb6fb46dc9c4`. The build used Xcode 26.6
  (17F113), the iPhoneOS 26.5 SDK, app version `0.1.0`, build number `1`,
  and bundle identifier `com.chrissotraidis.spaghettipad`.
- Clean build: a no-local clone checked out the exact tag, fetched the pinned
  SpaghettiKart, libultraship, and Torch revisions with push URLs disabled,
  generated the host oracle, applied all nine maintained patches, and
  completed the unsigned arm64 iPhoneOS Release build with
  `** BUILD SUCCEEDED **`.
- App audit: the clean app passed `REQUIRE_UNSIGNED=1` with executable
  SHA-256
  `103580431ea1d2410f78279aed59c3a9d4b3f7df48db53258261863e09b8af53`,
  port-archive content SHA-256
  `5ab6f5d8898cfdc3e8806b985bf84ec34b2d2968f158ac2e84359e45ff8564a0`,
  and controller-database SHA-256
  `eb002773dc8a16aa96f9ee2609798e231a9deb60c45e21fbdd4e221c9e8b7d77`.
  The signed-package requirement correctly rejected the unsigned app.
- IPA audit: `SpaghettiPad-0.1.0-preview.1-unsigned.ipa` is 11,219,634 bytes
  with 292 ZIP entries and SHA-256
  `095ac4942d5b6fb103152c45ef88265930532e5e961cb6659772480d2098a1c0`.
  Decompression and extracted-app audits passed. It contains the project
  rights notice, 32 third-party notices, and the ROM-free `spaghetti.o2r`;
  it contains no ROM, `mk64*.o2r`, `.otr`, imported texture pack,
  `_CodeSignature`, provisioning profile, certificate, or signing identity.
- Exact-artifact device check: a temporary extracted copy of that unsigned
  IPA was re-signed locally with the established development profile,
  re-audited as signed, update-installed without uninstalling, and launched
  successfully on a 12.9-inch sixth-generation iPad Pro running iPadOS
  26.5.2. The published IPA remained unchanged and unsigned.
- Publication: GitHub exposes the unsigned IPA and `SHA256SUMS` as prerelease
  assets, and its independently displayed IPA digest matches the recorded
  SHA-256 above.
- Boundary: this proves the initial ROM-free preview build, packaging,
  publication, and exact-artifact iPad install/launch path. It does not close
  the physical iPhone matrix, ten-minute and gameplay acceptance gates,
  sustained controller/reconnect sessions, tilt Grand Prix, 4K texture-pack
  performance, final save-preservation replay, or externally blocked hosted
  CI.

### 2026-07-28 — Phase 12 clean-machine replay passed; clean CI still externally blocked

- Checkout boundary: a `git clone --no-local` into
  `/tmp/spaghettipad-clean-replay-eb0e026` checked out publication commit
  `eb0e0264b9ad6a7c8977d900ab0ad663cfab1327`. The bootstrap fetched
  SpaghettiKart `5b28472d477bab101dee2a0f469fe2aee2c58a01`,
  libultraship `f5c3843fe937320b64ff754fa6bf71b13ff5e7a1`, and Torch
  `2d474ddb8da8b213fbdbb49d0273ce31fa955f35`, then disabled every upstream
  push URL.
- Reproduction: the fresh tree built the host oracle and ROM-free port archive
  from zero, cleanly applied all eight maintained patch layers, configured
  the iPhoneOS project in 869 seconds, and completed the unsigned arm64
  Release target with `** BUILD SUCCEEDED **`. The fresh executable SHA-256 is
  `70413176cc8e8e427d4b25bbb665c549a109d1ff48e648dd69bc7c0e64788e4d`.
- Reproducibility correction: the first post-build audit correctly exposed
  that Torch writes current timestamps into every ZIP entry, so byte-for-byte
  `spaghetti.o2r` hashes differ across clean builds even when every path and
  payload byte is identical. The established and fresh archives are both
  2,706,468 bytes with 369 entries and 19,658,261 uncompressed bytes; their
  sorted path-plus-uncompressed-content SHA-256 is identically
  `5ab6f5d8898cfdc3e8806b985bf84ec34b2d2968f158ac2e84359e45ff8564a0`.
  `scripts/hash-port-archive.sh` now makes that content digest the maintained
  audit contract while ignoring only build-time ZIP metadata.
- Fresh artifact: the corrected audit passed the clean app as unsigned,
  iPhoneOS 15.0, arm64, ROM-free, and controller-database-pinned.
  `scripts/package-ios.sh` produced an 11,217,754-byte / 292-entry unsigned
  IPA with SHA-256
  `752f8a813d277b7658585803a7dce0383b894b2c6ba24ba14bcbc3c205088533`.
  `unzip -tq` passed; the archive contains the project rights notice and 32
  third-party notices, with no ROM, `mk64*.o2r`, `.otr`, signature, or
  provisioning profile.
- Negative and cleanliness gates: `REQUIRE_SIGNED=1` rejected the fresh
  unsigned app before creating an output. Repository safety passed in both
  the publication checkout and fresh checkout, and the fresh checkout
  remained clean after the complete ignored build/package replay.
- Boundary: the local clean-machine half of Phase 12 is now closed. GitHub's
  hosted runner still must execute the same workflow after the account
  billing/spending-limit block is resolved; physical-device gates remain
  separate.

### 2026-07-28 — Phase 12 local package and documentation gates passed; clean CI pending

- Public build path: `scripts/build-ios.sh --device` replayed the pinned
  sources, ROM-free port archive, maintained patches, generic iPhoneOS
  configuration, unsigned Release build, and bundle audit in one command.
  Xcode 26.6 completed with `** BUILD SUCCEEDED **`; the final arm64 executable
  SHA-256 is
  `e9c4d6e57fbac57f27870a575eb74a493432e3b9da74af72d461efea31bf353c`.
- Bundle audit: the app targets iPhoneOS with a 15.0 minimum, contains both
  iPhone and iPad device families, enables Files sharing, and has no valid or
  stale signing material. The only bundled `.o2r` is the hash-pinned ROM-free
  `spaghetti.o2r`
  `4301e00ac0b2363ea2e0e78f97105f82f4c3da1f85f0f9fb42cb2a63918f2b79`;
  the controller database remains
  `eb002773dc8a16aa96f9ee2609798e231a9deb60c45e21fbdd4e221c9e8b7d77`.
- IPA proof: `scripts/package-ios.sh` produced
  `SpaghettiPad-0.1.0-preview.1-unsigned.ipa`, 11,234,757 bytes / 292 ZIP
  entries, SHA-256
  `3c5048d0ee5bdf5c19012ebe253cffa64b12378f6570c343655678e8d4ef02f9`.
  `unzip -t` passed. The payload has no `_CodeSignature`, provisioning profile,
  ROM, `mk64*.o2r`, or `.otr`; it includes the project rights notice and 32
  discovered third-party license files.
- Negative gates: the audit rejected an iPhoneSimulator bundle by exact
  platform, a changed `spaghetti.o2r`, a rogue `mk64.o2r`, stale signing
  material, contradictory signed/unsigned requirements, and an unsigned app
  submitted with `REQUIRE_SIGNED=1`.
- Public documentation: the README now leads with the live iPad/iPhone product,
  screenshots, tailored controls, widescreen, split-screen, tilt, and
  bring-your-own-assets boundaries. `docs/BUILDING.md`,
  `docs/INSTALL_IPA.md`, `docs/RELEASE_CHECKLIST.md`, and
  `RIGHTS_AND_LICENSES.md` define reproducible build, sideload, release, and
  rights boundaries without claiming a public download.
- Clean-runner attempt: GitHub Actions run
  [30403472162](https://github.com/chrissotraidis/spaghettipad/actions/runs/30403472162)
  was created for commit `738805932ce9102e9a6681bda5d4b34247d9205c`
  but GitHub assigned no runner and executed no steps. Its sole annotation
  reports failed recent account payments or an insufficient spending limit
  and directs the account owner to Billing & plans. This is an external
  pre-start block, not a repository-safety or build failure.
- Boundary: this closes the local Phase 12 build/package slice, not Phase 12
  itself. After GitHub billing/run availability is restored, the workflow must
  reproduce the unsigned artifact on a clean macOS runner. Physical signing,
  installation, runtime, update, and gameplay gates remain open regardless of
  CI.

### 2026-07-28 — Phase 11 tilt-steering Simulator slice passed; hardware GP pending

- Motion path: the iOS shell now samples `CMDeviceMotion.attitude.roll` at
  60 Hz using `CMAttitudeReferenceFrameXArbitraryZVertical`, applies a small
  dead zone and low-pass filter, and maps the calibrated delta to the virtual
  controller's analog left-stick X axis. Tilt is off by default.
- Controls UI: Settings › Controls exposes a persisted Tilt Steering checkbox,
  0.5×–2.0× sensitivity slider, and one-tap Recenter Tilt Steering button.
  `docs/screenshots/ipad-tilt-controls.png` records the default 1.0×/off state,
  SHA-256
  `1827654f7bc8967208ce30fef4d31121fcddb06389ecf7cc8e834cfbdfb01bcd`.
- Input ownership: the on-screen stick wins while held, menu visibility blocks
  motion input, and controller parking leaves tilt unable to write into a
  detached touch controller. Releasing the stick lets the next motion sample
  resume tilt steering.
- Deterministic Simulator proof: launching with the Simulator-only
  `SPAGHETTIPAD_SIMULATED_TILT_DEGREES=15` hook, enabling Tilt Steering, and
  closing the menu produced filtered X values `6245`, `10444`, then `15166`.
  Raising sensitivity from 1.0× to 2.0× through the visible Controls slider
  produced `32767`; the setting was returned to 1.0× afterward.
- Recenter/lifecycle proof: the visible recenter button emitted X `0`; closing
  the menu then calibrated the held angle as center with no subsequent
  non-zero value. Sending the app Home and foregrounding it restarted motion,
  centered at the still-held 15-degree input, and again produced no drift.
- Persistence proof: after terminating and relaunching the process without
  touching Settings, the shell immediately logged simulated tilt enabled,
  centered once, and reproduced the analog ramp. Tilt was returned to its
  default off state after the replay.
- Build and patch proof: the Release arm64 iPhoneSimulator executable SHA-256
  is `bcbd3a2de859794974e336f29a3dff99bfd5d090583d042d2ea82f0e879a1ef5`.
  `patches/spaghettikart-ios-tilt.patch` is 67 lines / 3,281 bytes with
  SHA-256
  `0a61bc4ce654abb600989fed90b1403d7163e640d46eb76d37662f32ec852e99`.
  A fresh local clone passed base → first-run → touch → UX → tilt
  application, `git diff --check`, and reverse-check of the tilt patch.
- Boundary: Phase 11 remains in progress. CoreSimulator cannot prove physical
  sensor orientation, grip comfort, long-session drift, or completion of a GP
  using tilt plus on-screen A/B/R/Z; those remain physical-iPad gates.

### 2026-07-28 — Phase 10 controller routing and split-screen Simulator slice passed; hardware sessions pending

- Controller ownership: on iOS, libultraship now creates default SDL mappings
  for all four N64 ports and assigns recognized controllers in stable SDL
  connection order: first controller to port/player 1, second to port/player
  2, then players 3 and 4. Extra controllers remain ignored. This matches
  SpaghettiKart's fixed `gControllers[i]` to human-player `i` relationship.
- Touch/physical handoff: `ios/SpaghettiPadShell.mm` releases every held input,
  closes and detaches the virtual touch controller, and removes the gameplay
  overlay when a physical controller appears. When no physical controller is
  present, it reattaches the virtual controller and restores touch. The
  persistent `•••` menu control remains available in both modes.
- Simulator realism: CoreSimulator exposes a permanent generic controller
  named `Gamepad`. The iOS controller manager ignores only that exact
  Simulator placeholder, while named pass-through controllers remain
  eligible. A Simulator-only, inert-unless-requested
  `SPAGHETTIPAD_SIMULATED_CONTROLLERS` hook creates up to four virtual test
  controllers; no device-build behavior or release setting is attached to
  that hook.
- Live handoff proof: a second replay started in normal touch mode, logged the
  touch controller on port 1, then attached the same two test controllers
  after a two-second Simulator-only delay. The shell logged the touch
  controller being parked, and the next refresh assigned the new controllers
  to ports 1 and 2. This exercises the actual add-event handoff rather than
  only the two possible startup states.
- Two-controller proof: launching the Phase 10 iPad Pro 11-inch (M4),
  iOS 18.5 Simulator with
  `SPAGHETTIPAD_SIMULATED_CONTROLLERS=2` logged controller 1 on port 1 and
  controller 2 on port 2 on every refresh. The Files-visible config recorded
  `HasConfig: 1` for ports 1 through 4; port 2 contained 14 N64 button mapping
  groups plus all four left-stick directions. No touch controller appeared in
  the active assignment, and the gameplay overlay was visibly parked.
- Split-screen render proof: the same process entered
  `mk:versus_2p`, selected the `mk:versus_2p` human item table, rendered two
  horizontal viewports, and continued for about 51 seconds before the
  configured automated course cycle advanced. The 2420×1668 evidence image is
  `docs/screenshots/ipad-2p-split-screen.png`, SHA-256
  `a157afb649400b688c2347150a097b836eab8367bee582ac97c71e1f36f6611e`.
  The open settings sheet makes both viewports and the parked touch overlay
  boundary visible; this is routing/render evidence, not a claim that two
  simulated idle controllers completed a race.
- Touch regression: after clearing the test environment and relaunching, the
  placeholder `Gamepad` remained ignored, `SpaghettiPad Touch Controller`
  alone returned to port 1, and the normal touch-mode app remained live.
- Maintained patch: `patches/libultraship-ios-controller-ports.patch` is 108
  lines / 4,289 bytes with SHA-256
  `a213fcae5d77bb529356846cce9339687380bb40e675162acedca576334b658c`.
  A pristine libultraship clone at
  `f5c3843fe937320b64ff754fa6bf71b13ff5e7a1` passed base -> touch ->
  controller-port application, `git diff --check`, and top-patch reverse
  application. `scripts/apply-patches.sh` also recognizes the complete
  already-applied stack.
- Build proof: the final Release arm64 iPhoneSimulator executable SHA-256 is
  `3df1c62174a9c921baf69cea18e0d44caf39b3f0c9d42140c52f4630cefbcfc2`.
  The unsigned Release iPhoneOS build completed with `** BUILD SUCCEEDED **`;
  its ROM-free arm64 audit passed with executable SHA-256
  `b40cc5aad176172ded7af7c02fa751afb77d994c26e4478cb002221c2b9a7f20`,
  clean bundled `spaghetti.o2r`
  `4301e00ac0b2363ea2e0e78f97105f82f4c3da1f85f0f9fb42cb2a63918f2b79`,
  and controller database
  `eb002773dc8a16aa96f9ee2609798e231a9deb60c45e21fbdd4e221c9e8b7d77`.
- Boundary: Phase 10 remains in progress. Only a physical iPad with two
  Bluetooth controllers can close the 2P GP/VS/battle input, reconnect,
  frame-time, and sustained-session gates. Three- and four-player modes must
  then be attempted with measured results to decide whether they ship or are
  explicitly deferred.

### 2026-07-28 — Phase 9 device UX and imported-pack Simulator slice passed; hardware GP pending

- Device-specific menu fit: SpaghettiPad now selects a 2× menu scale for
  iPad and 0.75× for iPhone. The iOS General page puts the optional texture
  workflow first, so `Use Alternate Assets`, `Check Imported Texture Pack`,
  `Texture Pack Files Steps`, and `Get MK64 Reloaded` remain visible on the
  phone's short landscape viewport without relying on scrolling. iPad and
  iPhone screenshots are recorded as `docs/screenshots/ipad-settings.png`
  (2420×1668, SHA-256
  `830b8369d76635786e86f8c48386ef717ec5b4be4d2ae926da33cf25e5df8854`)
  and `docs/screenshots/iphone-settings.png` (2622×1206, SHA-256
  `4da6688d5842031b43944baa384f38ebe23474f4c78312f262651cbb922dbc87`).
- iOS settings cleanup: desktop-only fullscreen, cursor-visibility, Alt-Tab
  assets, file-picker, renderer-backend, match-refresh, jitter-fix,
  windowed-fullscreen, and multi-viewport controls are hidden. Graphics keeps
  the relevant resolution, MSAA, VSync, and texture-filter options and adds
  explicit 30, 60, and 120 FPS (ProMotion) presets.
- Import workflow: the app scans the Files-visible `Documents/mods` directory
  for case-insensitive `.o2r` files, accepts only consistent ZIP archives with
  a root `mods.toml`, and prompts once to enable Alternate Assets. The General
  page also reports a precise no-pack result, explains the Files path and
  HD-first/4K-on-M-series guidance, and opens only the official MK64 Reloaded
  project page.
- Positive/negative proof: the negative detector returned `No texture pack
  found`. A generated ROM-free 232-byte manifest-only `.o2r` with SHA-256
  `036dbc8814ba10f887dfda7c4ba73ea32cae82219469e306b7f77f372693312a`
  triggered `Texture pack found`; choosing Yes persisted
  `gEnhancements.Mods.AlternateAssets: 1`. The setting was restored to off,
  both exact test archives were removed, and relaunch returned to the
  no-pack state. No real texture pack was downloaded, bundled, mirrored, or
  exercised.
- Maintained patch: `patches/spaghettikart-ios-ux.patch` is 254 lines /
  11,441 bytes with SHA-256
  `cfea42612663c80249eab571623905424069d56d531e67a68d4255a4261b2962`.
  `scripts/apply-patches.sh` applies it at the top of the SpaghettiKart stack,
  recognizes an already-patched tree, and requires every earlier patch in
  order. A fresh clone at the exact pin passed base -> first-run -> touch ->
  UX application, reverse-check, idempotent second replay, and
  `git diff --check`.
- Build proof: the final Release arm64 iPhoneSimulator build completed with
  `** BUILD SUCCEEDED **`; its executable SHA-256 is
  `4d57b823388efb8fec0cdbf1fa88dfc88f80c3f06c29455b22059c0f596a4c7e`.
  The same bundle was installed and visually exercised on the disposable
  iPad Pro 11-inch (M4) and compact iPhone Simulators. The iPhone retained its
  native 874×402 widescreen rendering while the adjusted UI exposed the
  complete import workflow. The full unsigned iPhoneOS wrapper also completed
  with `** BUILD SUCCEEDED **` and passed its arm64/ROM-free audit; its
  executable SHA-256 is
  `d5baf2a0be23738b8e713f9fc826583503a01965faadfbafa179aeba3c3bc871`,
  while bundled clean `spaghetti.o2r` remains
  `4301e00ac0b2363ea2e0e78f97105f82f4c3da1f85f0f9fb42cb2a63918f2b79`.
  The shared macOS target rebuilt successfully as an arm64 Mach-O with
  SHA-256
  `166170d41a841a92c1313529a2e49b30a5a13679c210aabd5350899261111275`.
- Public surface: the README now shows the shared app icon, real touch
  gameplay, side-by-side iPad/iPhone settings, current proof boundaries, and
  an accurate user-directed MK64 Reloaded import path.
- Boundary: this closes only the ROM-free Simulator UX and import mechanics.
  Phase 9 remains in progress until the owner imports the real HD pack on a
  physical iPad, confirms one cold relaunch plus a complete Grand Prix, and
  records frame-time/RSS evidence. The 4K pack remains optional and may be
  evaluated only on an M-series iPad after the HD gate.

### 2026-07-28 — Phase 8 Simulator touch and iPhone widescreen slice passed; hardware GP pending

- Implementation: `ios/SpaghettiPadShell.mm` now carries the current
  HarkinianPad-derived, device-specific overlay rather than the discarded
  proportional prototype. iPad uses the low grip rails and scaled 150-point
  fixed-center stick; iPhone uses a dedicated compact layout with a 116-point
  stick, 44-point upper controls, and safe-area-aware top/bottom menu
  placement. Both expose A, B, L, R, duplicate Z, Start, all four D-pad
  directions, and the full four-button C diamond.
- Input path: the overlay attaches one SDL virtual game controller and writes
  true analog axes plus SpaghettiKart's native button mappings. The menu
  button alone retains the Harkinian keyboard event path; a compile-time
  keyboard fallback remains. Quick taps receive only the remainder of a
  50-millisecond minimum hold, while hiding, disabling, or backgrounding the
  overlay releases immediately.
- Maintained patches: `patches/libultraship-ios-touch.patch` is 49 lines /
  1,603 bytes with SHA-256
  `74b849e5daf1cb88096619ce30240937135c7e9ae64ff8e0d50fed32656aa978`.
  It filters touch-generated mouse clicks and reports menu visibility after
  the port's virtual `DrawMenu` override. `patches/spaghettikart-ios-touch.patch`
  is 134 lines / 4,997 bytes with SHA-256
  `ff6f85c9d29704e0d5d9c589115d6064b70ceb18f5812f92c85076e476aa0019`.
  It compiles the Objective-C++ shell, enables controller navigation,
  persists the Touch Controls setting, records Simulator-only input
  telemetry, and selects the shared app icon. `scripts/apply-patches.sh`
  recognizes and replays the complete patch stacks in dependency order.
- Game-level telemetry: direct touches produced Start held/pressed
  `0x1000`, A `0x8000`, B `0x4000`, and C-Right `0x0001`, followed by zero
  held state on release. Held-pointer Simulator input produced raw stick X
  values of 80 and 22 before returning to zero, proving intermediate analog
  values rather than digital extrema.
- Lifecycle proof: A was held at game level (`0x8000`) before the app was
  backgrounded. The resign-active observer emitted its release, and the game
  returned with held/pressed state `0x0000`. Opening the in-game settings
  menu hid and released every gameplay control; closing restored them.
  Settings › Controls exposed the persisted Touch Controls checkbox while the
  always-available `•••` control prevented a disabled overlay from stranding
  the user.
- Device layout proof: the Phase 8 iPad Pro 11-inch (M4), iOS 18.5
  Simulator rendered the full, non-overlapping grip layout. The disposable
  compact iPhone Simulator rendered its separate layout without
  control overlap or Dynamic Island intrusion, including all four C buttons.
- Native iPhone widescreen: the live Graphics panel reported both viewport
  and internal dimensions as 874×402 (about 2.17:1), with advanced aspect
  forcing disabled. libultraship derives the game viewport from the window
  size and SpaghettiKart's aspect adjustment expands horizontal geometry;
  the live race filled the wide display without scaling a 4:3 framebuffer.
  Enabling a forced ratio retains the renderer's aspect correction rather
  than stretching unless the separate `IgnoreAspectCorrection` option is
  deliberately selected.
- Shared app icon: the original, Nintendo-asset-free spaghetti-track/D-pad
  mark is one opaque universal 1024×1024 source (SHA-256
  `ff669cbfe2d2b11f9f0cc9207d8803d74157cc1cb9fe07c8d25569fe5f2f1a1d`)
  for iPhone and iPad. Xcode emitted `AppIcon60x60@2x.png`,
  `AppIcon76x76@2x~ipad.png`, a 3.8 MiB `Assets.car` (SHA-256
  `dc07c8790b13ea23b47f812c002af88e8c329a8f80e67171f517fa7976f4f968`),
  and matching `CFBundleIcons` / `CFBundleIcons~ipad` metadata. Bundle
  validation passed without asset-catalog warnings.
- Build and replay proof: the Release arm64 Simulator build succeeded; its
  executable SHA-256 is
  `9d6b830057c65f5a2a3779606a6110968938134d92066c57de3a7b097c85ce18`.
  The unsigned Release iPhoneOS wrapper then completed with
  `** BUILD SUCCEEDED **` and its audit accepted an arm64, iOS 15.0,
  iPhone+iPad-family application. The device executable SHA-256 is
  `81fa6a9dc04d7cbe604f7febe44535bc3cdee9f176d70614c139a18cde6c5662`;
  bundled ROM-free `spaghetti.o2r` is
  `4301e00ac0b2363ea2e0e78f97105f82f4c3da1f85f0f9fb42cb2a63918f2b79`;
  and the controller database is
  `eb002773dc8a16aa96f9ee2609798e231a9deb60c45e21fbdd4e221c9e8b7d77`.
  The existing macOS oracle Release target also rebuilt successfully after
  the iOS patch stack, guarding the host path against regression.
  Both differential patches apply and reverse-check after the earlier patches
  in fresh local clones at the exact upstream pins. Root/nested
  `git diff --check`, shell syntax, and the ROM/asset bundle scan pass; no
  ROM, `mk64*.o2r`, `.otr`, or imported texture content exists in the app.
- Boundary: this closes only the reproducible Simulator slice. Phase 8 remains
  in progress until the owner completes a touch-only Grand Prix on physical
  iPad, including rocket start, hop-drift, directed item throw, pause/resume,
  settings cycles, background release, sustained ergonomics, and recorded
  behavior alongside the still-open Phase 6/7 hardware gates.

### 2026-07-28 — Phase 9 texture-pack research narrowed the supported path

- The current realistic visual upgrade is
  [MK64 Reloaded](https://github.com/GhostlyDark/MK64-Reloaded), whose official
  SpaghettiKart release offers an HD `.o2r` around 424 MiB and a 4K `.o2r`
  around 1.15 GiB. The Phase 9 UI will guide a Files copy into `Documents/mods/`,
  detect the archive, and expose SpaghettiKart's Alternate Assets setting.
- Neither the repository nor its release payload carries a redistribution
  license, and the textures derive from Nintendo art. SpaghettiPad must never
  bundle, mirror, or fetch the pack itself; it will link to the
  [official project page](https://evilgames.eu/texture-packs/mk64-reloaded.htm)
  and keep import user-directed. The
  [SpaghettiKart texture-pack guide](https://harbourmasters.github.io/SpaghettiKart/md_docs_2textures-pack.html)
  remains the format reference.
- No complete, maintained, genuinely open-licensed Mario Kart 64 texture pack
  was found. Older Rice-format packs are inactive/unlicensed and require
  conversion, so v1 will support Reloaded HD first, attempt 4K only on an
  M-series physical iPad, and record memory/frame-time measurements before
  adopting any optional texture-memory patch.

### 2026-07-28 — Phase 7 Simulator first-run slice passed; hardware pending

- Implementation: maintained patch
  `patches/spaghettikart-ios-firstrun.patch` (228 lines, 8,534 bytes,
  SHA-256
  `6f6701005cf64dbc3cda22b2105bf4d046932c1b8327e0021d173b2d4674103b`)
  makes the iOS first-run flow recoverable. It scans Files-visible Documents
  for any case-insensitive `.z64`, accepts only the exact US 1.0 big-endian
  SHA-1, rejects corrupt/partial O2R archives, removes stale extraction output
  and cache state, and always returns to a one-button Rescan loop instead of
  exiting. `scripts/apply-patches.sh` now applies and reverse-checks this patch.
- Build proof: Release arm64 Simulator build succeeded. Its executable SHA-256
  is
  `916d8e963fb89b2349361522b0ef69d887de869bbe8d459a1221ebb8e01ea032`.
  The shared-source desktop regression build also succeeded; its arm64
  executable SHA-256 is
  `1d9a87c162dabaa489aa7511a6c60b69a000107e67bec3f1294a777620b08b75`.
- Isolation: all runtime testing used the disposable iPad Pro 11-inch (M4),
  iOS 18.5 Simulator `SpaghettiPad Phase 7`. The supplied ROM was copied only
  into that app sandbox. It remains ignored and untracked.
- Recovery proof: an empty container showed the single Rescan prompt and
  remained in-app after rescanning. A deliberately wrong 1 KiB
  `Wrong Region.z64` produced the precise US 1.0/big-endian guidance and
  returned to the loop. A valid US 1.0 ROM was then found without requiring
  the hard-coded `baserom.us.z64` filename.
- Stale-state proof: before the valid run, the sandbox contained a deliberately
  invalid 2 KiB `mk64.o2r` and 1 KiB `torch.hash.yml`. Both were replaced.
  The generated `mk64.o2r` is a valid 26,664,858-byte ZIP with SHA-256
  `dc20466705d5dfcad843847aad4fa10dba60317fa72580e03dcfbcb5ffeb3ebb`;
  `unzip -tq` reports no errors. The new `torch.hash.yml` is 24,209 bytes.
- Measured Simulator extraction: the external monitor observed a valid archive
  after 2,893 seconds (48m13s) with peak process RSS 201,088 KiB. Torch logged
  `Done! Took 2882828ms` (48m02.828s). These are Simulator measurements, not
  physical-iPad performance claims.
- Relaunch proof: the final rebuilt app relaunched as PID `44236`, skipped all
  first-run prompts, and reached a live race. The archive hash, size, and
  `2026-07-28T10:19:29-0500` modification time were unchanged, and all rotated
  logs still contain exactly one `Done! Took` extraction completion.
- Maintenance and safety: the patch passes current reverse application, a
  pristine temporary base-patch -> first-run-patch replay, nested/root
  `git diff --check`, `bash -n scripts/apply-patches.sh`, and
  `scripts/check-repo-safety.sh`.
- Boundary: this closes the remote Simulator slice only. Phase 7 remains in
  progress until the owner repeats the Files workflow on the locally attached
  physical iPad and records hardware extraction time, peak RSS, failure
  recovery, cold relaunch, and archive validation. Phase 6 hardware signing
  and stability likewise remain open. The next unblocked remote gate is Phase
  8 touch controls using the refreshed HarkinianPad reference.

### 2026-07-28 — Remote device boundary and latest HarkinianPad controls fixed

- Device boundary: the maintainer clarified that the physical iPad is attached
  to the local MacBook in hand, while this agent runs on a remote Mac. The
  remote USB inventory contains no iPad, `security find-identity -p
  codesigning` reports `0 valid identities found`, and no provisioning
  profiles are installed. Phase 6 therefore remains in progress and no
  physical-device result is inferred from Simulator work.
- Owner replay required for Phase 6: configure the same source revision with
  the maintainer's development team and unique bundle identifier, build with
  provisioning updates enabled, install on the locally attached iPad, copy
  the recorded `mk64.o2r` only through its Files-visible Documents container,
  then record the device model, OS, executable hash, cold title boot, and a
  continuous ten-minute attract/demo run.
- Reference refresh: ignored `ref/harkinianpad` now exactly overlays every
  tracked file from the authoritative clean HarkinianPad `main` revision
  `01523225a3e9d32348e25d608dcb2d391dab5310`; an all-tracked-file comparison
  reported zero mismatches. This advances the touch reference from
  `88cefb7` through the compact-display fixes in `e22b3fa` and `0152322`.
- Touch baselines: the refreshed `docs/touch-controls-design.md`,
  `patches/shipwright-ios-touch-controls.patch`, and
  `patches/libultraship-ios.patch` hash respectively to
  `2eb23d57f8b042eb1ca0c74b1841e315ab81e0ead5bdb50184354055a3928b5b`,
  `63a5e3ae69930027c9aafe46a8b3688c957c8f447ec6a562f20c436b7f90ee1f`,
  and
  `172429323474038338b8d172c6b5bcc88506b7519313d1b0cd7897ada4d7b9db`.
  SpaghettiPad will reuse the latest grip-first layout, pass-through overlay,
  persistent menu control, compact-display rules, input-release semantics,
  and touch-mouse filtering while retaining its plan-mandated virtual SDL
  controller for full analog steering.
- Boundary: the ignored reference refresh changes no distributed source or
  artifact. This entry proves reference provenance and the remote/local
  device split only; it does not close Phase 6, Phase 7, or Phase 8.

### 2026-07-28 — Phase 5 audible resume accepted and gate closed

- The maintainer confirmed that Mario Kart music and game audio were audible
  through the active Jump Desktop output and that audio behavior was fine
  after the lifecycle replay.
- This human listening result closes the remaining subjective acceptance item
  on top of the same-PID three-cycle, config-flush, paused-log, live-render,
  integrity, and direct SDL pause/clear/resume/refill evidence recorded below.
- Boundary: this closes Simulator lifecycle and audible-output behavior only.
  It does not prove physical-iPad signing, install, watchdog survival, audio,
  extraction, touch, performance, controllers, texture packs, or packaging.

### 2026-07-28 — Phase 5 lifecycle slice passed; audible resume pending

- Implementation: the iOS-only `src/port/Game.cpp` loop now checks
  `WindowIsFrameReady()` before `push_frame()`. The existing bridge pumps SDL
  events and sleeps for 16 ms when the window is backgrounded, so lifecycle
  events still dispatch without advancing the game, renderer, or audio tick.
  The maintained `patches/spaghettikart-ios.patch` is now 313 lines across
  eight source files (142 insertions, 48 deletions), SHA-256
  `3a5f5b7c516a570d8525ec110d0611cafce6a44099a3f3cd32ad2b456782514c`,
  and passes reverse-apply and whitespace checks.
- Audio-timing question: `func_800CB2C4()` updates camera-relative sound
  state, sequence commands/fades, sound requests, and the audio task at the
  start of `thread5_iteration()`. It has no separate wall-clock owner relevant
  to suspension. Because the new readiness gate runs before `push_frame()`,
  neither that function nor `calculate_delta_time()` runs while backgrounded.
- Build proof: the final arm64 Simulator rebuild ended in
  `** BUILD SUCCEEDED **`; executable SHA-256 is
  `839267f64fa6e71b2560f6996a2de31297aefeb6a9d298c0f11f67898e3c59bb`.
  The native arm64 macOS regression target also rebuilt successfully and
  retained SHA-256
  `236e8cddd0dd54963980d0a3bf6bb9b7909aaa75fa5aa71db8c98f547219c39b`.
- Runtime: on the iPad Pro 11-inch (M4), iOS 18.5 Simulator, PID `86185`
  reached the live title screen and survived three consecutive 20-second
  Home/foreground cycles. Foregrounding after every cycle returned the same
  PID and live Metal animation.
- Pause/config proof: the baseline game log was 659 lines and 53,660 bytes
  with mtime `08:43:21-0500`. It retained exactly those three values through
  all three background dwells. Synchronous config saves advanced
  `spaghettify.cfg.json` from `08:43:19-0500` to `08:44:27-0500`,
  `08:45:38-0500`, and `08:46:32-0500`.
- Integrity: after the cycles, `Documents/mk64.o2r` retained SHA-256
  `26a8d0cf64a9e70276856b8876d41037195ea72cbbe78915257e6efd50179064`
  and `Documents/default.sav` retained SHA-256
  `6421a1adf0c5cc7a3eb1c720f21ccaa3ea528bc6ed12dfae5d46a16cbaab0416`.
  The synchronously saved config hashes to
  `39b423a5ddaec718dd592ef866389b7a26bdc96e266e0bf62b859189a9fa5c66`.
  No new SpaghettiPad crash report appeared.
- Audio boundary: the game log recorded `Audio thread started` at
  `08:43:19.364`. The lifecycle handler pauses SDL output, clears queued
  samples, and resumes the device on foreground; the live process resumed
  after every cycle. A non-invasive LLDB trace against that same Release
  process then proved the runtime path directly: background called
  `SDLAudioPlayer::SetPaused(true)` on SDL device 2, changed its paused byte
  from 0 to 1, and left `Buffered()` at zero. Foreground called
  `SetPaused(false)` on the same object, changed 1 to 0, and the audio worker
  immediately called `DoPlay` with 3,584 bytes, refilling the queue to 896
  stereo sample frames. LLDB detached cleanly; PID `86185` remained alive and
  live rendering continued. However, macOS reported `Jump Desktop Audio` as
  `Default Output Device` and `MacBook Air Speakers` only as
  `Default System Output Device`. No human audible-output result is claimed;
  that listening check remains the Phase 5b gate.

### 2026-07-28 — Phase 4 Simulator title-screen gate passed

- Build: `scripts/configure-ios.sh --simulator` generated the Xcode project
  for `arm64-apple-ios15.0-simulator` with the iPhoneSimulator 26.5 SDK. The
  final `SpaghettiPad.app` build ended in `** BUILD SUCCEEDED **`; its arm64
  executable reports `LC_BUILD_VERSION` platform `IOSSIMULATOR`, minimum
  15.0, SDK 26.5, and SHA-256
  `8e18588cf5de24927e8b2a51251c76068ecc24a23d2d98d77d88f9fbd45a4ef2`.
- Data boundary: ignored `ref/mk64.o2r` was staged only into the app's
  Files-visible Simulator Documents container. Source and staged copies both
  retained SHA-256
  `26a8d0cf64a9e70276856b8876d41037195ea72cbbe78915257e6efd50179064`;
  no ROM was copied into the app or repository.
- Runtime: a clean launch on the booted iPad Pro 11-inch (M4), iOS 18.5
  Simulator loaded bundled `spaghetti.o2r`, then
  `Documents/mk64.o2r`, registered the MK64 and extended-asset mods, loaded
  the title-screen audio sequence, and rendered live Metal frames through
  title and attract-mode races.
- Relaunch: a second clean launch at 08:03:04 loaded the persisted
  `Documents/mk64.o2r` by 08:03:05 and reached game rendering without an
  import or portable-file dialog. The final title-screen evidence is the
  ignored `ref/evidence/phase4-simulator-title-landscape.jpeg` (SHA-256
  `31d867e86f124013a39fb1259722b348e75276702cb416c1a480c3eedfbb06ca`).
- Landscape correction: the initial Simulator launch exposed an actual
  portrait scene despite landscape-only plist declarations. The narrow fix
  keeps SDL's landscape hint and wires its created window to the native shell,
  which requests a landscape `UIWindowScene` geometry update. UIKit logs then
  recorded the scene orientation preferences as landscape-left/right, and
  the visually inspected Simulator window and title screen were upright in
  landscape. Xcode 26.6's `simctl io screenshot` retained the raw portrait
  buffer orientation, so the settled Simulator-window capture is the visual
  acceptance source.
- Dialog audit: the Simulator executable's undefined-symbol table contains no
  `pfd`, portable-file-dialog, or file-dialog symbol.
- Patch replay: `patches/libultraship-ios.patch` now contains the two guarded
  landscape integration additions and exactly matches the 17-file upstream
  diff (520 lines, 184 insertions, 23 deletions; SHA-256
  `db284e75edc058f78ff81dca1dd3b6b64e27f0db67f22cc8d69274b25ff011ea`).
  Both maintained patches reverse-applied to pristine pinned inputs, reapplied
  through `scripts/apply-patches.sh`, and passed reverse-check and
  `git diff --check`.
- Desktop regression: the complete patched native arm64 macOS target rebuilt
  and linked successfully after the orientation addition; final executable
  SHA-256 is
  `236e8cddd0dd54963980d0a3bf6bb9b7909aaa75fa5aa71db8c98f547219c39b`.
  `scripts/check-repo-safety.sh` also passed.
- Boundary: this phase does not claim lifecycle continuity, subjective audible
  audio, physical-device runtime, touch, extraction, performance, controller,
  texture-pack, or package behavior.

### 2026-07-28 — Phase 3 unsigned iPhoneOS application gate passed

- Maintained patch: `patches/spaghettikart-ios.patch` (297 lines, seven source
  files, 137 insertions, 48 deletions; SHA-256
  `7cfe87dc5f386001aad61cb6a42f522bc30904494f4a7fccddfbdc62c9a9c5db`)
  backports the shell/resource bundle, iOS CMake guards, pinned Ogg/Vorbis
  fallback, mobile include correction, and iOS-15-safe controller-pak
  filename construction.
- Patch replay: both maintained patches reverse-applied to pristine
  SpaghettiKart `5b28472d477bab101dee2a0f469fe2aee2c58a01` and libultraship
  `f5c3843fe937320b64ff754fa6bf71b13ff5e7a1`, leaving both inputs clean.
  `scripts/apply-patches.sh` then restored both patches and both passed
  reverse-check and `git diff --check`.
- Build: `scripts/build-ios.sh` configured Xcode 26.6 with the iPhoneOS 26.5
  SDK, `arm64-apple-ios15.0`, scripting disabled, and unsigned code signing,
  then linked `build-ios/Release-iphoneos/SpaghettiPad.app`. The clean wrapper
  replay ended in `** BUILD SUCCEEDED **`.
- Narrow build fixes: Vorbis 1.3.7 required
  `CMAKE_POLICY_VERSION_MINIMUM=3.5` under CMake 4.4, and the upstream
  `std::format` fallback was replaced with simple string concatenation because
  the iOS SDK marks its floating formatter unavailable before iOS 16.3. The
  first resource audit also found upstream's escaped Xcode platform variable;
  iOS runtime directories are now native bundle resources rather than a
  post-build copy.
- Binary audit: the final executable is an arm64 Mach-O with `LC_BUILD_VERSION`
  platform `IOS`, minimum OS 15.0, SDK 26.5, and SHA-256
  `6de1e0ea7bffa7037951911389840873332fe7f431e3fc4a6b8491cf2be4e2f0`.
  `codesign -dv` reports `code object is not signed at all`.
- Bundle audit: `Info.plist` names `SpaghettiPad`, reports `iPhoneOS`,
  minimum 15.0, and device families `1,2`; Files sharing, landscape
  orientations, arm64+Metal capability, extended-controller support, indirect
  input, and ProMotion keys are present. `config.yml`, `yamls/`, `meta/`,
  `gamecontrollerdb.txt`, and `spaghetti.o2r` are inside the bundle.
- Safety audit: the bundled clean archive retains SHA-256
  `4301e00ac0b2363ea2e0e78f97105f82f4c3da1f85f0f9fb42cb2a63918f2b79`;
  the pinned controller database retains SHA-256
  `eb002773dc8a16aa96f9ee2609798e231a9deb60c45e21fbdd4e221c9e8b7d77`.
  `scripts/audit-ios-app.sh` found no ROM, `mk64*.o2r`, `.otr`, signature, or
  provisioning material, and `scripts/check-repo-safety.sh` passed.
- Desktop regression: the full patched native arm64 macOS target relinked
  successfully with final executable SHA-256
  `eba1ae77c1602a14acbc6a6e967ec91e84e0a686854a6a6494063a875aad1187`.
  This replay exposed zero-byte results from upstream's unchecked
  `sse2neon.h` and `semver.hpp` downloads; both are now commit-pinned and
  hash-verified in the maintained patch, and `scripts/build-oracle.sh`
  validates those headers plus `stb_image.h`.
- Boundary: this phase does not claim Simulator or physical-device runtime,
  lifecycle continuity, audible audio, touch, extraction, performance,
  controller, texture-pack, or packaging behavior.

### 2026-07-28 — Phase 2 libultraship iPhoneOS library gate passed

- Patch replay: `patches/libultraship-ios.patch` (505 lines, 17 source files,
  176 insertions, 22 deletions; SHA-256
  `af687f13734f9c3c3d8292003c1695a769a7e54b22fd6cb3a38b122202af29fe`)
  reverse-applied to pristine libultraship
  `f5c3843fe937320b64ff754fa6bf71b13ff5e7a1`, passed `git apply --check`,
  reapplied through `scripts/apply-patches.sh`, and passed reverse-check and
  `git diff --check`.
- iPhoneOS build: `scripts/build-ios-lus.sh` configured Xcode 26.6 with the
  iPhoneOS 26.5 SDK, `arm64-apple-ios15.0`, and scripting disabled, then built
  `build-ios-lus/src/Release-iphoneos/libultraship.a`. The final archive is
  arm64, reports `LC_BUILD_VERSION` platform 2 and minimum OS 15.0, and has
  SHA-256
  `f8185a4de2681bb5a63fd9fa62d1501ec35d301e8cdb1e0570f8337f0271c1f5`.
- Symbol audit: the archive has no undefined
  `toggleNativeMacOSFullscreen` or `CoreAudioAudioPlayer` reference.
  `WindowIsFrameReady` and the weak
  `SpaghettiPad_SetTouchControlsMenuVisible` integration hook are present.
- Scripting guard: an iPhoneOS configure with `ENABLE_SCRIPTING=ON` stopped
  at CMake with the required `ENABLE_SCRIPTING is unsupported on iOS` fatal
  error.
- Desktop regression: the patched dependency rebuilt and linked the complete
  native arm64 `build-oracle/Spaghettify` target on macOS (340 Ninja steps;
  final executable SHA-256
  `0c53480ea6be03a900a5faf2b51ae10e622f6a7321bd72e6da6d630894a3e69a`).
  The compiler emitted existing upstream warnings but no errors.
- Boundary: this phase does not claim a linked iOS app, Simulator or physical
  device runtime, lifecycle continuity, audible audio, touch, extraction,
  performance, controller, texture-pack, or packaging behavior.

### 2026-07-28 — Phase 1 macOS oracle and archive gate passed

- Input: ignored `ref/Mario Kart 64.z64` was identified as big-endian
  `MARIOKART64`, region/revision `NKTE Rev.00`, with the required SHA-1
  `579c48e211ae952530ffc8738709f078d5dd215e`. Torch independently reported
  the same game, country `us`, version `0`, and hash during extraction.
- Build: `scripts/generate-port-archive.sh` configured the pinned unmodified
  SpaghettiKart tree as a Release Ninja build with scripting disabled, built
  the native arm64 Mach-O `build-oracle/Spaghettify`, generated the clean port
  archive, and generated the desktop game archive. The final bounded replay
  passed with `ORACLE_BUILD_JOBS=4`.
- Dependency failure and recovery: a restricted-network configure left
  CMake's pinned `stb_image.h` download at zero bytes, producing the exact
  `GuiTexture.cpp:9:9: error: use of undeclared identifier
  'stbi_image_free'`. The script now fails fast unless that pinned header is
  nonempty; the authorized network replay fetched the 282,848-byte file and
  completed without source changes.
- Archive evidence: final SHA-256
  `4301e00ac0b2363ea2e0e78f97105f82f4c3da1f85f0f9fb42cb2a63918f2b79`
  for `build-oracle/spaghetti.o2r` (369 entries, 2.6 MiB), and
  `26a8d0cf64a9e70276856b8876d41037195ea72cbbe78915257e6efd50179064`
  for both `build-oracle/mk64.o2r` and ignored `ref/mk64.o2r` (25 MiB).
  The clean archive was packed from the pinned source `assets/` input and its
  entry-list audit found no `.z64`, `.n64`, `.v64`, `.rom`, `.otr`, or nested
  `mk64*.o2r`.
- Source-boundary replay: the extractor's ten regenerated tracked asset
  headers were restored by the script's exit trap. Both
  `sources/spaghettikart/baserom.us.z64` and
  `sources/spaghettikart/mk64.o2r` were removed, the pinned checkout returned
  to detached clean `HEAD`, and `scripts/check-repo-safety.sh` passed.
- Runtime: a fresh launch from `build-oracle/` loaded `spaghetti.o2r`,
  `mk64.o2r`, all 21 audio banks, and the title-screen sequence. Continuous
  startup capture visually proved the libultraship splash, Nintendo boot
  logo, and live Mario Kart 64 title screen with `PUSH START BUTTON`; the
  local ignored evidence frame is
  `ref/evidence/phase1-title-screen.png` (SHA-256
  `a7a1aec2b2ccf764a5e7887f3ab89c1e9a9c70796c8ed74b70a09a27e2d69f93`).
- Boundary: the desktop attract-mode races rendered and advanced, but this
  phase does not claim gameplay correctness, controller input, subjective
  audio quality, or any iOS behavior.

### 2026-07-28 — Phase 0 pinned bootstrap and clean-directory replay passed

- Expected: a clean checkout resolves SpaghettiKart, libultraship, and Torch
  at the plan's exact revisions, makes every upstream input fetch-only, keeps
  all local/build material ignored, and passes the ROM/history/credential
  safety gate.
- Workspace replay: `scripts/clone-sources.sh` resolved SpaghettiKart
  `5b28472d477bab101dee2a0f469fe2aee2c58a01`, libultraship
  `f5c3843fe937320b64ff754fa6bf71b13ff5e7a1`, and Torch
  `2d474ddb8da8b213fbdbb49d0273ce31fa955f35`. Each `origin` push URL reports
  `disabled://spaghettipad-upstream-input`.
- Safety replay: `scripts/check-repo-safety.sh` passed after validating the
  current file set, Git history, likely credentials, shell syntax and
  executability, Markdown links, ignore rules, and `git fsck --strict`.
  `git check-ignore -v ref/rom.z64 sources` resolves both paths to
  `.gitignore`.
- Clean-directory proof: a repository containing only the current intended
  tracked files was initialized at
  `/tmp/spaghettipad-phase0.Mm1Yzq`. It was clean before bootstrap, fetched all
  three inputs afresh, reproduced the exact revisions and disabled push URLs,
  passed the safety audit after bootstrap, and remained clean (`## master`).
- Concurrent plan update: remote `main` advanced to `230d536` during the
  Phase 0 push. That commit adds Decision D14 and the hardware-gated Phase 9
  MK64 Reloaded workflow named by the goal. It was inspected and integrated
  before publication; the earlier goal/plan discrepancy is resolved.
- Boundary: no source patches, host/iOS build, runtime, ROM extraction, touch,
  audio, device, texture-pack, multiplayer, or packaging claim is made by
  this phase.

### 2026-07-28 — Phase 0 setup started

- Expected: establish the exact source pins, prevent accidental upstream
  publication, and add a ROM/history/credential safety gate before any build
  work.
- Starting repository: clean `main` at
  `59ad133d7f1df88b0783859bbcda03d0c6d292c92`, equal to `origin/main`.
- Input boundary: `ref/Mario Kart 64 (U) [!].v64` is ignored. No required
  `.z64` input is present, so no extraction or oracle gate is attempted.
