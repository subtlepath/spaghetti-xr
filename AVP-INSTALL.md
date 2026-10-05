# Installing Spaghetti-XR on Apple Vision Pro

Spaghetti-XR, forked from [SpaghettiPad](https://github.com/chrissotraidis/spaghettipad), packages the [SpaghettiKart](https://github.com/HarbourMasters/SpaghettiKart) source port of Mario Kart 64 as a native visionOS app. The engine runs on Compositor Services in an immersive space, draws each frame once per eye, and anchors every frame to an ARKit device pose so the world stays where you left it. The app installs as **SpaghettiPad**.

The launch window offers two ways to see the game:

- **Draw the game in 3D around me** (Mode B): the world has real depth and your head is the camera. A world-scale slider, from about 20 mm to 150 mm per game unit, decides whether the track reads as a race circuit or a tabletop.
- With that switch off (Mode A), the game is drawn flat on a world-locked screen in front of you.

## What you need

- An Apple silicon Mac with an Xcode that ships the visionOS 26 SDK or newer, plus its command-line tools
- [Homebrew](https://brew.sh)
- An Apple ID configured in Xcode, and its 10-character team ID
- Apple Vision Pro on visionOS 26 or later. The optional 6DoF steering needs visionOS 27.
- PS5 or PS VR2 Sense controllers. A pair of PS VR2 Sense controllers has driven a full race on hardware. Power both on and let them connect before you launch the app.
- Your own Mario Kart 64 **US 1.0, big-endian `.z64`** ROM, with SHA-1 `579c48e211ae952530ffc8738709f078d5dd215e`

## Your game files

Neither this repository nor the app contains game data, and the app never downloads it.

1. Launch SpaghettiPad. The window reports what it found in its container.
2. Press **Import ROM…** and pick your `.z64`, or drop it into the app's Files-visible folder.
3. Press **Convert ROM to Game Data** and leave the app in front of you. The engine's extractor and Torch build `mk64.o2r` in place, once; it takes several minutes. Nothing leaves the device.
4. When the window says the game data was found, press **Play**.

If conversion fails, the next launch says so and points at `logs/` inside the app's container. The most likely cause is a ROM that isn't the supported US 1.0 dump. The README records in-app conversion as tested in the Simulator, and not yet on a headset.

Texture packs such as MK64 Reloaded are optional; the README's [Texture packs](README.md#texture-packs) section explains how to import one.

## Build from source

There's no published visionOS build yet. Install the host dependencies, which the macOS build that produces the ROM-free `spaghetti.o2r` needs:

```sh
brew install cmake ninja pkgconf sdl2 glew nlohmann-json libpng libzip \
  tinyxml2 libogg libvorbis opus opusfile sdl2_net ripgrep
```

Then, from a checkout of this repository:

```sh
DEVELOPMENT_TEAM=ABCDE12345 \
BUNDLE_ID=com.yourname.spaghettipad \
scripts/build-visionos.sh --device
```

Use your own team ID and a bundle identifier that belongs to you. Keep the identifier the same for later installs, so visionOS keeps the app's container and your converted game data with it. The script fetches pinned SpaghettiKart, libultraship and Torch revisions into `sources/`, applies the patches in `patches/`, and writes `build-visionos/Release-xros/SpaghettiPad.app`. Without `DEVELOPMENT_TEAM`, the app is built unsigned and won't install on a headset.

## Install on Apple Vision Pro

```sh
xcrun devicectl device install app --device "Your Vision Pro" \
  build-visionos/Release-xros/SpaghettiPad.app
```

If Xcode needs to register the headset or create a provisioning profile first, open `build-visionos/Spaghettify.xcodeproj`, select the `Spaghettify` scheme and your headset, then choose your team under **Signing & Capabilities**.

## Notes

- Opening the immersive space hides the launch window. On a headset the space uses progressive immersion and opens fully immersed. Press the Digital Crown to leave it and bring the window back.
- Hold both shoulders and both triggers for a second to recenter the room where you are. Click both sticks to open and close the settings menu.
- 6DoF steering (**Settings → General → 6DoF Steering**), holding the two Sense controllers like a wheel, is written but hasn't been tried on a headset yet.
- The README notes that a long session may still end in a memory kill; one cause has been fixed and is waiting on a headset measurement.
- Nintendo, Mario and Mario Kart are trademarks of Nintendo. This project is not affiliated with or endorsed by Nintendo, Harbour Masters, or the MK64 Reloaded project.
