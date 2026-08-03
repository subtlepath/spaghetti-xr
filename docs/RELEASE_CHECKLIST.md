# SpaghettiPad release checklist

This is the final gate for a public source snapshot or downloadable package.

The **visionOS lane** is the maintained one; its gates are first. The iPadOS
sections below it belong to the lane retired on 2026-08-01 and are kept because
Preview 3 is published and may still need to be reproduced.

## Every public source update (visionOS)

- [ ] `scripts/check-repo-safety.sh` passes.
- [ ] Both maintained visionOS patches replay on the pinned source revisions and
      the replayed tree is byte-identical to the tree that was built.
- [ ] `scripts/build-visionos.sh --device` produces the arm64 visionOS app and
      its audit passes.
- [ ] `scripts/package-visionos.sh` accepts the unsigned app and refuses signed
      input by default.
- [ ] `REQUIRE_SIGNED=1 scripts/package-visionos.sh` rejects the unsigned app.
- [ ] README claims match the current app, and each is attributed to the
      Simulator, a headset, or the build host.
- [ ] No ROM, `mk64*.o2r`, `.otr`, imported texture, signing material, app, or
      package appears in the current tree or Git history.
- [ ] Simulator and headset claims remain clearly separated. **No Simulator
      result is presented as evidence of stereo, world-locking, or comfort** —
      the Vision Pro Simulator renders the left eye only.

## Before publishing an unsigned visionOS package

- [ ] Build from a clean checkout at the tagged commit.
- [ ] Use a deliberate app version and monotonically increasing build number.
- [ ] Build without `DEVELOPMENT_TEAM`, then run `scripts/package-visionos.sh`.
- [ ] Confirm the package has no `_CodeSignature` or
      `embedded.mobileprovision`.
- [ ] Confirm the only `.o2r` in the app is the content-hash-pinned, ROM-free
      `spaghetti.o2r`.
- [ ] Read `BUILD_PROVENANCE.txt` out of the package and confirm it records a
      clean working tree and the three expected source revisions.
- [ ] **State the Xcode build from that file in the release notes.** This lane's
      active toolchain is a beta Xcode, and no artifact may be published from
      one without saying so.
- [ ] Re-sign and install the exact package on an Apple Vision Pro.
- [ ] State every uncompleted headset gate in the release notes, naming at
      minimum: DualSense, controller port order across reconnects, 6DoF
      accessory tracking, on-device ROM conversion, 4K-pack performance, and
      controller-only settings navigation.
- [ ] Record tag, commit, Xcode/SDK versions, app version, build number, and
      exact unsigned package SHA-256 in the release notes.
- [ ] Publish as a prerelease with known limitations and an explicit statement
      that no game data is included.

## Before claiming visionOS final acceptance

- [ ] Follow [VISIONOS_DEVICE_ACCEPTANCE.md](VISIONOS_DEVICE_ACCEPTANCE.md) end
      to end on an Apple Vision Pro.
- [ ] Convert a ROM in-app on the headset from a clean container, not only in
      the Simulator.
- [ ] Confirm the hosted safety and unsigned visionOS build/package jobs are
      green.

## Every public source update (retired iPadOS lane)

- [ ] `scripts/build-ios.sh --device` produces the arm64 iPhoneOS app.
- [ ] `scripts/package-ios.sh` accepts the unsigned app and refuses signed
      input by default.
- [ ] `REQUIRE_SIGNED=1 scripts/package-ios.sh` rejects the unsigned app.

## Before publishing an unsigned preview IPA

- [ ] Build from a clean checkout at the tagged commit.
- [ ] Use a deliberate app version and monotonically increasing build number.
- [ ] Build without `DEVELOPMENT_TEAM`, then run `scripts/package-ios.sh`.
- [ ] Confirm the IPA has no `_CodeSignature` or
      `embedded.mobileprovision`.
- [ ] Confirm the only `.o2r` in the app is the content-hash-pinned,
      ROM-free `spaghetti.o2r`.
- [ ] Confirm `RIGHTS_AND_LICENSES.md`,
      `ThirdPartyLicenses/SDL_GameControllerDB.LICENSE`, and discovered
      dependency notices are present.
- [ ] Re-sign and install the exact IPA on at least one supported physical
      device.
- [ ] State every uncompleted physical-device gate in the release notes.
- [ ] Record tag, commit, Xcode/SDK versions, app version, build number,
      device/OS matrix, and exact unsigned IPA SHA-256 in release notes.
- [ ] Publish as a prerelease with [INSTALL_IPA.md](INSTALL_IPA.md), known
      limitations, and an explicit statement that no game data is included.

## Before claiming final acceptance

- [ ] Re-sign and update-install the exact IPA on a physical iPhone and iPad.
- [ ] Follow [HARDWARE_ACCEPTANCE.md](HARDWARE_ACCEPTANCE.md), then replay
      touch, ROM import, texture-pack import, controllers, split-screen, tilt,
      lifecycle, audio, and save preservation.
- [ ] Confirm the hosted safety and unsigned-build jobs are green.

## Before publishing a signed build

- [ ] Use a deliberate distribution identity and fresh profile.
- [ ] `REQUIRE_SIGNED=1 scripts/package-ios.sh` passes on the exact app.
- [ ] Install the packaged IPA on clean physical hardware and complete the
      full acceptance matrix.
- [ ] Never publish certificates, profiles, or other signing material.

## Current blockers

### visionOS (maintained)

- **No visionOS artifact has been published.** Packaging, its audit, and the
  hosted workflow exist and pass locally; the workflow itself has never run on a
  hosted runner.
- Mode B has been seen once, on 2026-08-01. Every change since — HUD projection,
  audio session, camera factorisation, texture byte budget, backdrop panel — is
  built and unworn.
- DualSense, controller port order across reconnects, 6DoF accessory tracking,
  on-device ROM conversion, 4K-pack performance on the headset, and
  controller-only settings navigation are all open.
- The active toolchain is a beta Xcode. Any published artifact must say so.

### iPadOS (retired 2026-08-01)

These were the lane's open gates when it was retired. They are **superseded, not
completed**, and must never be described as passed.

- Signed development builds have been update-installed and played on physical
  iPad and iPhone hardware. The promoted customizable controls, A-button hold
  assist, safe-area menu placement, texture-pack rendering, and Grand Prix
  play have been exercised on iPhone. The complete ten-minute Phase 6 evidence
  gate and final update/save-preservation replay remain open.
- Two-controller Bluetooth Grand Prix and physical tilt-steering feel remain
  open.
- MK64 Reloaded HD has been imported and rendered on the physical iPad. Its
  off/on restart-confirmation replay, full hardware Grand Prix, and 4K
  performance attempt remain open; the pack is never bundled or mirrored.
- The initial unsigned preview IPA was built from tagged commit `e0b2da5`,
  audited, temporarily re-signed, update-installed, launched on the physical
  iPad, and published as
  [`v0.1.0-preview.1`](https://github.com/chrissotraidis/spaghettipad/releases/tag/v0.1.0-preview.1).
  The complete hardware replay matrix remains open.
- Preview 2 corrects third-party notices and makes unsigned packaging the safe
  default. Hosted repository safety and unsigned build/package jobs pass; the
  remaining physical-hardware gates are still open.
- Preview 3 promotes the customizable touch controls to the default, retains
  legacy controls as an option, and carries separate physically tuned phone
  and tablet layouts. Its exact artifact was temporarily re-signed,
  update-installed, launched, and verified live on a physical iPhone, then
  published with its checksum as
  [`v0.1.0-preview.3`](https://github.com/chrissotraidis/spaghettipad/releases/tag/v0.1.0-preview.3).

These blockers may be stated as developer-preview limitations, but they must
not be described as passed.
