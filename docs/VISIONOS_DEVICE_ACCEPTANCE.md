# Apple Vision Pro acceptance

Simulator results never close SpaghettiPad's hardware gates, and on visionOS
they close less than usual: **the Vision Pro Simulator renders the left eye
only**, its head never moves, and it has no Sense controllers. Stereo,
world-locking, immersion and comfort are device claims and nothing else.

Run this from the Mac the headset is paired with.

## What is already true, and what this is for

Phases 2 and 3 are complete, both halves. Phase 4's separation is measured; its
comfort half is not, and cannot be until there is input. This is the procedure
that produced those results and the one that will close what remains.

## Prerequisites

- The Apple Vision Pro is paired with this Mac, awake, **being worn**, and has
  Developer Mode enabled. This is not advice: with the headset off a head,
  `devicectl device process launch` times out at 90 and 120 seconds and the app
  never appears. Put it on first.
- `xcrun devicectl list devices` shows it as `connected`, not `unavailable`.
- For a run with game content, the app's container already holds your own
  locally generated `mk64.o2r`. Without it the app still opens the immersive
  space and draws the per-eye test pattern, which is exactly what Phase 2 needs.
  To place it there without the import path, which is still a logged refusal:

  ```sh
  xcrun devicectl device copy to --device "Your Vision Pro" \
    --source /path/to/your/mk64.o2r --destination Documents/mk64.o2r \
    --domain-type appDataContainer --domain-identifier com.yourname.spaghettipad
  ```

## Getting the log, which is harder than it should be

Two routes that look right do not work, so try neither: `log stream --device`
is not supported by this macOS, and `devicectl device process launch --console`
bridges only the app's stdout, which the compositor never writes to. Screenshots
are also unavailable — `devicectl device capture screenshot` reports that an
Apple Vision Pro does not support the capability — so every visual result below
is the wearer's own report.

What works is collecting the device's unified log, which needs root and
therefore a real terminal, not an agent session:

```sh
sudo /usr/bin/log collect --device-udid <device-udid> --last 20m \
  --output /tmp/avp.logarchive
/usr/bin/log show /tmp/avp.logarchive --style compact \
  --predicate 'subsystem == "com.subtlepath.spaghettipad"'
```

The app's Swift-side `app` category logs at info level and is not retained in a
collected archive; everything from `shell`, `compositor`, `surface`, `tracking`
and `input` is.

## Build and install

```sh
DEVELOPMENT_TEAM=ABCDE12345 \
BUNDLE_ID=com.yourname.spaghettipad \
scripts/build-visionos.sh --device
```

The build audits the bundle on the way out: arm64, `platform VISIONOS`, minimum
26.0, ROM-free, and linked against ARKit, CompositorServices and Metal. Then:

```sh
xcrun devicectl device install app --device "Your Vision Pro" \
  build-visionos/Release-xros/SpaghettiPad.app
xcrun devicectl device process launch --device "Your Vision Pro" \
  --console com.yourname.spaghettipad
```

Watch the app's own log in another terminal:

```sh
log stream --device --level info \
  --predicate 'subsystem == "com.subtlepath.spaghettipad"'
```

## Phase 2's device half: both eyes differ

Open the immersive space from the launch window with no game data present, so
the compositor draws the test pattern.

What must appear in the log, and what each line settles:

- `first drawable: 2 view(s), 1 texture(s), 1 rasterization rate map(s)` with a
  **non-zero eye offset on each view**. One view, or two views at the same
  offset, means there is no stereo and the gate is not met.

  One texture and one rate map for two views is the layered layout, which is now
  what the app asks for and no longer a fault. It was one once: under that layout
  the single map carries a layer per eye, chosen by the
  `render_target_array_index` a vertex program emits, and a renderer that emitted
  none put both eyes through layer 0 — a uniform grid in the left eye, a warped
  one in the right. Every vertex program now emits its view's index, so **the
  test for this is the wearer's, not the log's**: both eyes must show the same
  uniform grid. A warped right eye means the index is not arriving, and no line
  in the log will say so.

  The layout is not a free choice. Progressive immersion draws its portal
  through a drawable render context, and a render context accepts no other
  layout on a two-view drawable.
- `drawing through a portal: 2 view(s), stencil format 253, mask value 200`,
  once, on the first frame that has one. Its absence, or a
  `no portal is available …` error beside it, means the Digital Crown will still
  dial the immersion but nothing will be masked to the portal it opens.
- `compositor ready on … portal available`. `portal unavailable (no progressive
  immersion)` means the layer offered no stencil format and the space is
  effectively fully immersive whatever the Crown is set to.
- `measured stereo: eyes NN.N mm apart, …` — Phase 4's measurement. Record the
  number. Observed range so far: 68.4–70.7 mm.
- `device anchor tracked at compositor frame 1: …`.
- **No** `Presenting a drawable without a device anchor` from
  `com.apple.CompositorNonUI` while the space is open. One or two of these in
  the milliseconds *after* it closes is expected and harmless: ARKit pauses
  world tracking on close and the compositor then refuses to anchor from a pose
  nothing vouches for.

What the wearer must confirm, because no capture can: the border is **amber in
the left eye and cyan in the right**, and the white reticle sits at a
**different horizontal position** in each. The identity ticks near the middle of
the view — one small square for the left eye, two for the right — are a second,
colour-blind way to tell them apart. They live at 44% across and 68% down
because a Vision Pro renders considerably more than it shows and anything near a
corner of the drawable never reaches the wearer's eye.

## Phase 3's device half: the title screen, sustained

**Closed on 2026-08-01** at 6 min 15 s — 33,601 frames, all anchored — which the
owner accepted in place of the ten minutes originally written. The procedure
below is kept for re-running it.

With `mk64.o2r` in the container, press **Play** and leave it alone. The gate is
the log line every ten seconds:

```
compositor is live: N frames presented at NN Hz, N of them showing the engine,
which has finished N; N drawables anchored, 0 not
```

All three counts must keep climbing and the unanchored count must stay at zero.
A headset presents at 90 Hz where the Simulator presents at 60, so the engine's
own rate is expected to differ from every Simulator number recorded so far.

## Phase 4's own gate: stereo separation and a comfortable full race

Neither half can be taken from a log alone.

- **Separation** is the `measured stereo` line above, cross-checked against what
  the wearer sees: the screen must sit at a single distance, not as two images
  the eyes fail to fuse.
- **World-locking** is the other periodic line:

  ```
  the wearer's head is at (x, y, z) m and the screen is (a, b, c) m from it
  ```

  Turn your head and walk. The first triple must change, and the second must
  change with it — the screen stays in the room while the head moves. A second
  triple that never leaves `(0.00, 0.00, -2.00)` is a head-locked screen, which
  is the bug this phase exists to remove. This is the one check the Simulator
  cannot perform at all, because its head never moves.
- **Comfort** is a full race, reported by the person wearing it. **Closed on
  2026-08-01**: the owner drove a race on PS VR2 Sense controllers, won it, and
  reported the session comfortable. Phase 4 is complete.
- **The floor is known to be wrong.** It is drawn at the ARKit world origin when
  the head is well above it, which on the one headset tested put it 0.93 m below
  a seated wearer's eyes and **above the real floor of the room they sat in**.
  Nothing in this lane measures the real floor. Note where it lands for you; the
  fix is plane detection, which needs world-sensing authorization.

## Progressive immersion: the Digital Crown, worn

Untested on hardware, and untestable off it. The Simulator does not merely fail
to show this: a progressive-style frame **fails on its GPU and takes the
simulator's Metal service down with it**, so the Simulator lane runs `.full`
under `#if targetEnvironment(simulator)` and only a headset ever selects the
progressive style. Every claim below is therefore a prediction, including the
ones that would normally be cheap.

The space opens under `.progressive(0.35...1.0, initialAmount: 1.0)`, which is
why the Crown means something. At the top of the dial the result should be
indistinguishable from the fully immersive space that came before it.

- **No Metal assertion on the first frame.** Two separate ones were hit on the
  first two headset runs of progressive immersion, and both are invisible to a
  Simulator that has no stencil format and therefore never draws the mask at
  all:
  - `encodeWaitForEvent:value: with uncommitted encoder` from
    `IOGPUMetalCommandBuffer` — the render context is claimed on the *command
    buffer*, so claiming it while a render encoder was already open on that
    buffer is what Metal objected to. It is now claimed first.
  - `Vertex Amplification Count (2) must be between (inclusive) 1 and the
    maximum vertex amplification count specified in the pipeline state (1)` —
    the compositor masks both eyes at once by amplifying, and left the encoder
    amplifying two views for draws whose pipelines allow one. The count is now
    restored after the mask.
- **The topology line should read `2 view(s), 1 texture(s), 1 rasterization rate
  map(s)` with `type 3, 2 slice(s)`,** and `portal stencil formats offered
  [253, 260], chose 253`. That is the layered layout with one slice per eye and
  a real stencil to mask into — all three are what the masked path needs, and
  all three were confirmed on an Apple M2 headset with `foveation on`.
- **`per-eye views went invalid at compositor frame 1 (pose valid, room not
  placed)` is not a fault.** The room waits for the head to be still before it
  commits — half a second of stillness, four seconds at the outside — and until
  it does there is no frame for Mode B to publish eyes in. What matters is the
  line that should follow within about a second: `per-eye views are valid again
  at compositor frame N; Mode B may resume`. If that line never arrives, the
  room never settled, or the run ended first.
- **Turn the Crown down.** The world should close to an oval window with the real
  room around it, and the edge should be a soft fade rather than a hard cut. A
  hard edge, or a rectangular one, means the render context's fade did not run —
  check for `drawing through a portal` in the log.
- **`drawing through a portal: 2 view(s), masked`.** The word to read is
  `masked`. **This branch has never executed anywhere**: the Simulator offers no
  render-context stencil format, so it logs `unmasked` and a headset is the first
  machine to run the stencil path at all. `unmasked` on a headset means the
  pixels outside the portal are being shaded and then covered — the picture is
  right and the cost is wrong.
- **Both eyes, at every setting.** The portal must be the same size and in the
  same place in each eye. A portal that differs between the eyes is the layered
  layout's array index going astray, and it will be accompanied by the foveation
  warp described under Phase 2.
- **Turn it back up.** Full immersion must return, and the room, screen and
  Mode B world must not have moved: nothing about placement is derived from the
  immersion amount. A world that shifts as the dial turns is a real bug.
- **Mid-race.** Dial it down while driving. The game must not pause, stutter or
  lose the controller. `immersion dialled to N.NN` in the `shell` category
  records where it was put.
- **Mode A's room, at low immersion.** Unresolved by design rather than by
  oversight: Mode A draws a synthetic sky and floor because a fully immersive
  space needs something for head motion to register against. At a low immersion
  amount the wearer's own room is already providing that, and the synthetic one
  is competing with it inside the portal. Report whether it reads as wrong. The
  fix, if it is wrong, is to fade the environment out as the amount drops, which
  is not attempted here.

## Phase 5's gate: input

Until 2026-08-01 no controller could reach this app at all, for a reason that had
nothing to do with pairing: the visionOS window backend drained SDL's event queue
every frame with `SDL_PollEvent`, and that threw away the
`SDL_CONTROLLERDEVICEADDED` event which is the *only* thing that causes
libultraship to open a gamepad. Everything else was already in place. The backend
now leaves those events for the handler that acts on them, and a controller binds
to port 0 on its own. Nothing in the app routes input — the engine's own control
deck does all of it.

Pair the controller to the **headset**, in Settings › Bluetooth, not to the Mac.
A DualSense pairs by holding **Create + PS** until the light bar flashes.

Two log lines settle this, and they say different things:

```
[input] 1 game controller(s) connected: PlayStation VR2 Sense Controllers (L/R)
[input] port 0 first input reached the game: buttons 0x0010, stick (0, 0)
```

The first means the control deck **opened** the pad. If it never appears, or says
`no game controller is connected` and nothing follows, the headset has not paired
it or SDL has no mapping for it — the engine's own log in `Documents/logs/` says
which, with a `not recognized as gamepad` warning naming the GUID.

The second means input **reached the game**, which is the actual gate: it is
logged from the point where the pad has been read and is about to be acted on.
It fires once per port, on the first press. A first line without a second is a
controller the app can see and the game cannot feel.

Then, in order:

- **Drive a race.** **Done 2026-08-01** on PS VR2 Sense controllers: driven, won,
  and reported comfortable, which also closed Phase 4. **A DualSense has still
  never been connected to this app**, so that half of the gate is the open one.
  Report comfort as the wearer, not from the log.
- **Reconnect.** Turn the controller off mid-session and on again. The `input`
  category must report it leaving and returning, and it must come back on **port
  0**, not a new one. Stable port order across reconnects is written into the
  gate because SDL instance ids change on every reconnect and a naive mapping
  drifts a player to a different port.
- **Two controllers**, if you have them, for the port-order half.

**PS VR2 Sense controllers: answered on 2026-08-01.** They enumerate through
GameController as a **single combined gamepad**, not as two devices — the log
names it `PlayStation VR2 Sense Controllers (L/R)` and reports
`1 game controller(s) connected`. SDL opens it, the control deck binds it to port
0, and it drives the game. Their **6DoF pose does not arrive this way**: that is
a second, unrelated path, and it is what the section below is for.

## Phase 5's 6DoF half: steering with two hands, never worn

**Written 2026-08-02. Nothing about it has run.** The Simulator reports no
spatial accessories and `ar_accessory_tracking_provider_is_supported()` is false
there, so unlike every other Simulator-first feature in this project, not one
line of this has executed anywhere. Everything below is a first run.

The shape of it: ARKit's accessory tracking reports each Sense controller
separately — `GCSpatialAccessory.spatialAccessories`, visionOS 27 and up — with
a world transform and a chirality. The angle above horizontal of the line from
the left grip to the right grip is the wheel angle, and it drives port 0's
`stick_x`. Divided by the hand separation before the arcsine, so it is an angle
rather than a height and does not care how wide the grip is; taken from
gravity-aligned `y`, so it does not care which way the wearer is facing.

Before anything else, **check the room still renders.** The accessory provider
joins the same `ar_session_t` world tracking runs in — the one every drawable's
device anchor comes from. It is added before the session is ever run, and it is
declined outright if ARKit asks for an authorization this bundle has not
declared, but a session with two providers in it has never been run on hardware.
If the picture is black or frozen where it was not before, that is this change,
and the `tracking` category now names which provider changed state.

Then, in order:

- **Reach the setting.** Settings → General → **6DoF Steering**, off by default.
  The `steering` category must say `6DoF steering enabled; watching for anchor
  updates`. If it instead says the provider does not exist, read the line above
  it: unsupported, too old a visionOS, or an undeclared authorization, and the
  log says which.
- **Be seen.** With both controllers on and held, `steering` must report
  `spatial accessory loaded for tracking` **twice** — once `left`, once `right`
  — then `tracking 2 spatial accessories`. One is the interesting failure: it
  means the pair reaches ARKit the way it reaches GameController, as one device,
  and the two-hand scheme cannot work as written.
- **Centre it.** Hold the controllers as a wheel and expect `steering centred at
  N degrees of hand tilt`. The N is a wearer's natural grip and should be small.
  **Recenter 6DoF Steering** in the menu takes the current pose as straight.
- **Turn.** `first steering sample` reports the hand separation in millimetres,
  the tilt in degrees, and the resulting stick value. Check the **sign** before
  anything else: raising the **right** hand must turn **left**, and a wrong sign
  here is a one-character fix in `SpaghettiPadAccessorySteering.mm`.
- **Say what full lock should be.** The one number in this feature that nobody
  has ever felt is how far the wheel turns for full lock: 0.70 rad — 40° — at
  1.0x sensitivity. It is a considered guess. Drive with the slider and report
  the multiplier that feels right; 0.5x is 80° and 2.0x is 20°. Whatever a wearer
  lands on should become the constant, with the slider recentred around it.
- **Put one down.** Steering must stop within about two frames — a controller
  that is not held, not tracked, or not reporting must not leave the kart
  holding its last turn.
- **Push the stick.** The left stick must win while it is pushed, and steering
  must come back when it is released.

## Phase 6's device half: the settings menu, worn

**The menu is native now, and none of it has been worn.** It is a SwiftUI window
— `NavigationSplitView`, `Form`, system controls at the system's own size — built
from the widget tree the engine publishes. The legibility question this section
used to be mostly about is answered in principle and unmeasured in fact.

- **Open it.** Press **Back/Select** on the pad (Create on a DualSense). If your
  pad reports no Back button, **click both thumbsticks together** — that fallback
  exists because what SDL maps onto `SDL_CONTROLLER_BUTTON_BACK` for the combined
  PS VR2 Sense gamepad has never been checked, and MK64 binds neither stick
  click. The `shell` category must say `menu opened` and then
  `native settings window presented; the ImGui menu stands down`.
- **Which menu appeared?** This is the first real question. If the **ImGui** menu
  appeared instead, the SwiftUI window never presented — the failsafe worked, and
  the log will lack the `presented` line. That is a bug but not a lockout, and
  everything below is moot until it is fixed.
- **Is it there at all?** A `.full` immersive space and an ordinary window have
  never been on screen together in this app. Say where the window appeared
  relative to the game screen, whether it is reachable, and whether looking at it
  is comfortable.
- **Read it.** The point of the whole exercise. This is system type at system
  size, not 13 px ImGui on a 1.6 m screen two metres away. Say plainly whether it
  is legible, and if the answer is still no then the problem was never the
  renderer.
- **Operate it.** Change a checkbox, drag a slider, pick from a picker. Every one
  of those is a round trip through the engine's next frame — the control does not
  move itself, it asks and waits ~66 ms. Say whether that feels like lag.
- **Does the game know?** Change **Settings → General → 6DoF Steering** and
  confirm the `steering` category reacts. That is the proof that the widget's own
  C++ callback ran, not just that a CVar moved — a bridge that sets CVars and
  skips callbacks looks identical until something depends on one.
- **Close it with the window's own close button**, not the pad. The kart must
  drive again. If it does not, `SpaghettiPad_MenuRequestVisible` did not land and
  the engine still believes a menu is up.
- **The Developer pages still open ImGui windows**, which is what those widgets
  have always done. Their controls should show as *on* while the window is up.

## The memory kill: one cause fixed, none of it measured

A Mode B session on **stock assets** was killed at **5 min 50 s** by
`JETSAM_REASON_MEMORY_PERPROCESSLIMIT` against a 5120 MiB limit, and a later one
with the 4K pack reached **8065 MiB of footprint with 126 MiB left**. A cause of
the second was found and fixed on 2026-08-03 — evicting a texture cache entry
never freed the texture behind it — so this section is now a **measurement to
take**, not only a crash to survive. Still expect a kill until a wear says
otherwise.

- The compositor prints a `memory:` line every 600 frames with the footprint and
  the headroom left before the limit. **Collect the archive from a session that
  died** and read that series — the slope is the point. A flat line that steps
  at track load means something different from a line that climbs every frame.
- Beside it is a `textures:` line: live GPU texture memory and how many textures
  that is, then what the Fast3D cache bills its own entries at, then a running
  eviction count. **This is the pair that disagreed.** What to read:
  - Both roughly flat with evictions climbing — the cache's 1 GiB budget is
    holding, and any remaining growth is not textures.
  - GPU figure climbing while the billed figure holds — something is allocating
    textures the cache does not know about, and the fix names the wrong culprit.
  - The GPU figure sitting tens of MiB above the billed one is **expected**: the
    framebuffer, its MSAA and depth targets are counted in the first and not the
    second.
  - Evictions climbing by thousands a minute means the budget is thrashing
    rather than merely bounding — worth a look at whether 1 GiB is the right
    number, which is still an unmeasured question.
- Run the same track in **Mode A** for comparison. Mode B renders the display
  list twice per frame; if Mode A survives twice as long, the growth is
  per-draw, and if it dies at the same wall-clock the mode is not the variable.
- Do **not** assume the texture pack is involved. The first reading of this
  crash blamed it on shell-side lines saying a pack had been imported and a
  preference set; the wearer confirmed no pack was rendering. A device archive
  cannot currently answer which mods loaded — the engine's startup logging is
  `OS_LOG_TYPE_INFO` and does not survive collection.
- Note that a device session with a controller connected gets its logging
  **quarantined by the OS after a few minutes** — UIKit logs two lines per
  controller event and there is nothing in this app that can stop it. Collect
  the archive knowing the app's own lines may stop well before the app does.

## Recording the result

Add a dated entry to [`remaining-work.md`](remaining-work.md) with the device
model and visionOS version, the measured separation, the sustained counts, the
captures, and anything that was **not** met. Generated evidence may carry device
and signing identifiers, so keep it out of the repository: `ref/` is ignored.
