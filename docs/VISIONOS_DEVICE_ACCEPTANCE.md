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

- `first drawable: 2 view(s), 2 texture(s), 2 rasterization rate map(s)` with a
  **non-zero eye offset on each view**. One view, or two views at the same
  offset, means there is no stereo and the gate is not met. **One** rate map for
  two views means the layered layout has been selected and every eye after the
  first is rasterizing through another eye's foveation — the compositor logs an
  error saying so, and the picture is visibly warped in the right eye only.
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
0, and it drives the game. Their **6DoF pose does not arrive this way**: that
needs an ARKit accessory-tracking provider added to the session
`SpaghettiPad_ARSession()` hands out, and `SpaghettiPad_AttachAccessoryTracking`
is still an explicit logged refusal. So they work as an ordinary gamepad and not
as tracked spatial controllers.

## Recording the result

Add a dated entry to [`remaining-work.md`](remaining-work.md) with the device
model and visionOS version, the measured separation, the sustained counts, the
captures, and anything that was **not** met. Generated evidence may carry device
and signing identifiers, so keep it out of the repository: `ref/` is ignored.
