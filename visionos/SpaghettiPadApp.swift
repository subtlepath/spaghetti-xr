// SwiftUI owns the process on visionOS.
//
// An ImmersiveSpace can only be opened from a SwiftUI scene, so the engine's
// entry point is no longer main(): the maintained SpaghettiKart patch renames
// it to SpaghettiPad_GameMain and the shell calls it on its own thread. This
// file is the whole app lifecycle; everything below it crosses into
// Objective-C++ through SpaghettiPadBridge.h.
//
// Two scenes: a launch window that reports what the engine found on disk and
// opens the immersive space, and the immersive space itself, whose only content
// is a CompositorLayer. Nothing here draws — the layer's renderer closure hands
// the compositor straight to SpaghettiPadCompositor.mm and returns.

import CompositorServices
import OSLog
import SwiftUI
import UniformTypeIdentifiers

private let log = Logger(subsystem: "com.subtlepath.spaghettipad", category: "app")

/// Where the engine reads and writes, resolved once at launch.
private struct RuntimeStatus {
    var ready = false
    var hasGameArchive = false
    var documentsPath = ""

    static func prepare() -> RuntimeStatus {
        let documents = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0].path
        let ready = SpaghettiPad_RuntimeInit(documents, Bundle.main.bundlePath) != 0
        return RuntimeStatus(
            ready: ready,
            hasGameArchive: ready && SpaghettiPad_GameArchiveReady() != 0,
            documentsPath: documents
        )
    }
}

/// Neither `.z64` nor `.o2r` is a registered type, so both are named by their
/// extension. `nil` would let the picker offer everything; falling back to
/// `.data` keeps it to files rather than folders.
private func fileType(_ fileExtension: String) -> UTType {
    UTType(filenameExtension: fileExtension) ?? .data
}

/// Brings a user-picked file into the app's container.
///
/// The file this exists for is the MK64 Reloaded 4K pack, which is around
/// 1.2 GiB — so it runs off the main actor, and it takes the security-scoped
/// access the picker grants for the duration of the copy. Without that scope the
/// read fails partway through with a permission error, which looks exactly like
/// a corrupt archive.
private func importPickedFile(
    _ result: Result<URL, Error>,
    using copy: @escaping (UnsafePointer<CChar>?) -> Int32,
    what: String
) async -> Bool {
    guard case .success(let url) = result else {
        if case .failure(let error) = result {
            log.error("\(what, privacy: .public) import cancelled: \(error.localizedDescription, privacy: .public)")
        }
        return false
    }

    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }

    let path = url.path
    let imported = await Task.detached(priority: .userInitiated) {
        path.withCString { copy($0) != 0 }
    }.value
    log.info("\(what, privacy: .public) import \(imported ? "succeeded" : "failed", privacy: .public)")
    return imported
}

/// How the compositor is set up before it produces its first frame.
///
/// The system calls this once, off any scene, and the choices are not
/// negotiable afterwards — so each one is taken from what the hardware reports
/// rather than assumed. In particular the Vision Pro Simulator supports neither
/// foveation nor the layouts that depend on it.
private struct SpaghettiPadLayerConfiguration: CompositorLayerConfiguration {
    func makeConfiguration(
        capabilities: LayerRenderer.Capabilities,
        configuration: inout LayerRenderer.Configuration
    ) {
        let foveation = capabilities.supportsFoveation
        configuration.isFoveationEnabled = foveation

        // One texture per eye, not one texture array with a slice per eye.
        //
        // `layered` is the efficient choice and was chosen here until a real
        // headset ran it. An Apple Vision Pro hands back **two views, one
        // texture and one rasterization rate map**, because under that layout
        // the single map carries a layer per eye and the layer is selected by
        // the `render_target_array_index` a vertex shader emits. This renderer
        // draws one pass per view and selects the eye by the attachment's
        // slice, so both eyes rasterized through layer 0 — the left eye's
        // foveation pattern — and the wearer saw a uniform grid in the left eye
        // and a warped one in the right.
        //
        // Fixing that inside `layered` means vertex amplification in all four
        // shader programs. This app draws a textured quad, a grid and a
        // gradient per eye; the second pass costs less than that rewrite, and
        // `dedicated` gives each view its own texture and its own rate map, so
        // foveation stays on and lands on the right eye.
        let options: LayerRenderer.Capabilities.SupportedLayoutsOptions =
            foveation ? [.foveationEnabled] : []
        let layouts = capabilities.supportedLayouts(options: options)
        configuration.layout = layouts.contains(.dedicated) ? .dedicated : .shared

        // Depth is not optional on visionOS: the compositor reprojects each
        // presented frame against it to hold the image still as the wearer
        // moves.
        configuration.depthFormat = .depth32Float
        if capabilities.supportedColorFormats(options: []).contains(.bgra8Unorm_srgb) {
            configuration.colorFormat = .bgra8Unorm_srgb
        }

        // What was on offer, not only what was taken: the Simulator and a real
        // headset differ here, and a build that quietly settled for less should
        // say so in its own log rather than leave it to be inferred.
        let offered = layouts.map { String($0.rawValue) }.joined(separator: ", ")
        // Copied out first: os.Logger interpolation is an autoclosure, and an
        // autoclosure cannot capture an inout parameter.
        let chosen = configuration.layout.rawValue
        log.info(
            """
            compositor capabilities: foveation \(foveation ? "supported" : "unsupported", privacy: .public), \
            layouts offered [\(offered, privacy: .public)], \
            chose layout \(chosen, privacy: .public)
            """)
    }
}

private struct LaunchView: View {
    @State var status: RuntimeStatus
    @Binding var immersiveSpaceOpen: Bool

    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var importingRom = false
    @State private var importingPack = false
    @State private var importInProgress: String?
    @State private var installedPacks = 0
    @State private var enhancedTextures = SpaghettiPad_AlternateAssetsPreference() != 0
    @State private var stereoRequested = SpaghettiPad_RenderStereoRequested() != 0
    @State private var worldScale = Double(SpaghettiPad_RenderWorldScale())

    private var buttonTitle: String {
        if immersiveSpaceOpen {
            return "Close Immersive Space"
        }
        return status.hasGameArchive ? "Play" : "Show Test Pattern"
    }

    private func toggleImmersiveSpace(hideWindow: Bool = true) async {
        if immersiveSpaceOpen {
            await dismissImmersiveSpace()
            immersiveSpaceOpen = false
            SpaghettiPad_SetImmersiveActive(0)
            log.info("immersive space dismissed")
            return
        }

        // Logged either way: "the space opened" is a claim worth being able to
        // check against the system's own answer rather than against whether
        // something appeared on screen.
        let result = await openImmersiveSpace(id: SpaghettiPadApp.immersiveSpaceID)
        immersiveSpaceOpen = result == .opened
        log.info("openImmersiveSpace returned \(String(describing: result), privacy: .public)")
        guard immersiveSpaceOpen else { return }
        SpaghettiPad_SetImmersiveActive(1)

        // Started here rather than at launch because the game loop has nowhere
        // to draw until a compositor exists, and started only once: closing the
        // space leaves the engine running where it was, so reopening returns to
        // the same race rather than restarting it.
        if status.hasGameArchive, SpaghettiPad_EngineRunning() == 0 {
            if SpaghettiPad_StartEngine() == 0 {
                log.error("the engine refused to start; see the shell log")
            }
        }

        // Last, after the engine has been asked to start, because this window
        // owns the task the request runs on. A window floating in front of a
        // fully immersive game is a hole in the immersion a wearer asked to
        // have closed; the Digital Crown is the system's own way out of the
        // space, and leaving brings this window back. The Simulator's scripted
        // path passes hideWindow: false and manages the window itself.
        if hideWindow {
            dismissWindow(id: SpaghettiPadApp.launchWindowID)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("SpaghettiPad")
                .font(.extraLargeTitle2)

            if status.ready {
                Label(
                    status.hasGameArchive
                        ? "Game data found."
                        : "No game data yet. Copy a Mario Kart 64 (US) ROM into "
                            + "the app's Documents folder.",
                    systemImage: status.hasGameArchive
                        ? "checkmark.circle" : "questionmark.folder"
                )
            } else {
                Label(
                    "The engine could not prepare its storage.",
                    systemImage: "exclamationmark.triangle"
                )
            }

            // The immersive space is offered with or without game data: with it,
            // the engine runs and its frames appear on a screen inside the
            // space; without it, the space shows the compositor's test pattern
            // rather than pretending to be a way into a race that does not
            // exist yet.
            Button(buttonTitle) {
                Task { await toggleImmersiveSpace() }
            }

            Text(
                immersiveSpaceOpen
                    ? "Closing the space leaves the game running where it is."
                    : "Opening the space hides this window. Press the Digital "
                        + "Crown to leave the space and bring it back."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Divider()

            // Mode B. Offered rather than assumed, and described by what it does
            // rather than by its name: the alternative is a flat screen hanging
            // in a room, which is a thing worth being able to go back to if
            // stereo turns out to be uncomfortable on a given track.
            Toggle("Draw the game in 3D around me", isOn: $stereoRequested)
                .onChange(of: stereoRequested) { _, on in
                    SpaghettiPad_RenderSetStereoRequested(on ? 1 : 0)
                }
            Text(
                stereoRequested
                    ? "The world has depth and your head is the camera. "
                        + "Falls back to the flat screen where there is no second eye to draw — the Simulator, for one."
                    : "The game is drawn flat on a screen in front of you."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            if stereoRequested {
                // Nothing in the ROM says how big a Mario Kart 64 unit is, so
                // this is the wearer's judgement rather than a measurement. The
                // range runs from a tabletop to something well over life size.
                LabeledContent("World scale") {
                    HStack {
                        Slider(value: $worldScale, in: 0.02...0.15)
                            .frame(width: 220)
                        Text(String(format: "%.0f mm per unit", worldScale * 1000))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: worldScale) { _, scale in
                    SpaghettiPad_RenderSetWorldScale(Float(scale))
                }
            }

            Divider()

            // Content. Both are the user's to supply and neither is ever
            // bundled: the ROM for legal reasons that need no explaining, and
            // MK64 Reloaded because it carries no license and its art is
            // derivative of Nintendo's.
            HStack(spacing: 12) {
                Button("Import ROM…") { importingRom = true }
                    .disabled(importInProgress != nil)
                Button(
                    installedPacks > 0 ? "Replace Texture Pack…" : "Import Texture Pack…"
                ) { importingPack = true }
                    .disabled(importInProgress != nil)
            }

            if let importing = importInProgress {
                Label(
                    "Copying \(importing). A 4K pack is over a gigabyte; this takes a while.",
                    systemImage: "arrow.down.circle"
                )
                .font(.caption)
            } else if installedPacks > 0 {
                // Not gated on the engine running. It used to be, which made the
                // one moment the switch mattered — before a 4K pack had been
                // loaded — the one moment it could not be reached, and left it
                // reading "off" for a pack that was about to load, because the
                // engine answers 0 for every console variable until it has one.
                Toggle("Use enhanced textures", isOn: $enhancedTextures)
                    .onChange(of: enhancedTextures) { _, on in
                        SpaghettiPad_SetAlternateAssetsPreference(on ? 1 : 0)
                    }
                Text(
                    SpaghettiPad_EngineRunning() == 0
                        ? "\(installedPacks) pack(s) in mods/. A 4K pack costs "
                            + "gigabytes of memory; the system stops the app if it "
                            + "asks for more than it is allowed."
                        : "\(installedPacks) pack(s) in mods/. Switching now "
                            + "reloads every texture."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Text(status.documentsPath)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .fileImporter(
            isPresented: $importingRom,
            allowedContentTypes: [fileType("z64")]
        ) { result in
            Task {
                importInProgress = "ROM"
                let imported = await importPickedFile(
                    result, using: SpaghettiPad_ImportRom, what: "ROM")
                importInProgress = nil
                if imported {
                    // Extraction is the engine's, and it runs on the engine's
                    // first launch. What changes here is only whether there is
                    // now something for it to extract.
                    status = RuntimeStatus.prepare()
                }
            }
        }
        .fileImporter(
            isPresented: $importingPack,
            allowedContentTypes: [fileType("o2r")]
        ) { result in
            Task {
                importInProgress = "texture pack"
                _ = await importPickedFile(
                    result, using: SpaghettiPad_ImportModArchive, what: "texture pack")
                importInProgress = nil
                installedPacks = Int(SpaghettiPad_InstalledModCount())
            }
        }
        .onAppear {
            installedPacks = Int(SpaghettiPad_InstalledModCount())
            // Re-read rather than trusted from launch: coming back through the
            // Digital Crown means the engine is up, and its live console
            // variable is the authority from then on.
            enhancedTextures = SpaghettiPad_AlternateAssetsPreference() != 0

            // The Digital Crown ends an immersive space without any SwiftUI
            // code being asked, so a window reappearing is the one moment this
            // view can learn it happened: the compositor thread noticed its
            // renderer go invalid and exited on its own. Setting the binding
            // false routes through the app's onChange, which joins that thread.
            if immersiveSpaceOpen && SpaghettiPad_CompositorRunning() == 0 {
                log.info("the system ended the immersive space; resyncing")
                immersiveSpaceOpen = false
                SpaghettiPad_SetImmersiveActive(0)
            }
        }
        .task {
            // A Simulator device can be driven with no Simulator.app window, and
            // a headless device has no button to press. Opening the space from
            // here is the only way a scripted run can reach it. Compiled out of
            // every device build, and inert unless the variable is set.
            #if targetEnvironment(simulator)
            let hook = ProcessInfo.processInfo
                .environment["SPAGHETTIPAD_AUTO_OPEN_IMMERSIVE_SPACE"]
            if hook == "1" || hook == "cycle", !immersiveSpaceOpen {
                await toggleImmersiveSpace(hideWindow: false)

                // "cycle" closes and reopens once before settling. Starting the
                // compositor twice is not the same test as starting it once:
                // only a close makes the render thread notice its renderer go
                // invalid, and only a reopen proves that thread was joined and
                // a new one took a different renderer. This has to happen while
                // the window still exists, since it owns this task — which is
                // why these calls keep the window up and the dismissal below
                // stays explicit.
                if hook == "cycle", immersiveSpaceOpen {
                    try? await Task.sleep(for: .seconds(2))
                    await toggleImmersiveSpace(hideWindow: false)
                    try? await Task.sleep(for: .seconds(1))
                    await toggleImmersiveSpace(hideWindow: false)
                }

                if immersiveSpaceOpen {
                    // This window sits in front of the compositor's output and
                    // shows the container path, neither of which belongs in a
                    // capture of what the compositor drew.
                    dismissWindow(id: SpaghettiPadApp.launchWindowID)
                }
            }
            #endif
        }
    }
}

@main
struct SpaghettiPadApp: App {
    static let launchWindowID = "SpaghettiPadLaunchWindow"
    static let immersiveSpaceID = "SpaghettiPadImmersiveSpace"

    @State private var status = RuntimeStatus.prepare()
    @State private var immersiveSpaceOpen = false
    @State private var immersionStyle: ImmersionStyle = .full

    var body: some Scene {
        WindowGroup(id: Self.launchWindowID) {
            LaunchView(status: status, immersiveSpaceOpen: $immersiveSpaceOpen)
        }
        .defaultSize(width: 620, height: 400)

        ImmersiveSpace(id: Self.immersiveSpaceID) {
            CompositorLayer(configuration: SpaghettiPadLayerConfiguration()) {
                layerRenderer in
                // Unretained on purpose: the compositor keeps the renderer
                // alive for as long as this space is open, and the shell holds
                // its own strong reference for as long as its thread runs.
                SpaghettiPad_StartCompositor(
                    Unmanaged.passUnretained(layerRenderer).toOpaque())
            }
        }
        .immersionStyle(selection: $immersionStyle, in: .full)
        .onChange(of: immersiveSpaceOpen) { _, open in
            if !open {
                SpaghettiPad_StopCompositor()
            }
        }
    }
}
