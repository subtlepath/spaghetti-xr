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
import Metal
import OSLog
import SwiftUI
import UniformTypeIdentifiers

private let log = Logger(subsystem: "com.subtlepath.spaghettipad", category: "app")

/// Where the engine reads and writes, resolved once at launch.
private struct RuntimeStatus {
    var ready = false
    var hasGameArchive = false
    /// A ROM is in the container and nothing has turned it into a game archive
    /// yet. Starting the engine in this state means extracting.
    var extractionPending = false
    /// The previous launch started extracting and never produced an archive.
    /// Fixed for the lifetime of the process by the shell.
    var extractionFailed = false
    var documentsPath = ""

    static func prepare() -> RuntimeStatus {
        let documents = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0].path
        let ready = SpaghettiPad_RuntimeInit(documents, Bundle.main.bundlePath) != 0
        return RuntimeStatus(
            ready: ready,
            hasGameArchive: ready && SpaghettiPad_GameArchiveReady() != 0,
            extractionPending: ready && SpaghettiPad_ExtractionPending() != 0,
            extractionFailed: ready && SpaghettiPad_PreviousExtractionFailed() != 0,
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

        // One texture array with a slice per eye, because progressive
        // immersion admits nothing else.
        //
        // This was `dedicated` — one texture per eye — and the reason is worth
        // keeping, because it is the bug this layout has to not reintroduce.
        // An Apple Vision Pro hands `layered` back as **two views, one texture
        // and one rasterization rate map**, since under that layout the single
        // map carries a layer per eye and the layer is selected by the
        // `render_target_array_index` a vertex shader emits. The renderer drew
        // one pass per view and selected the eye by the attachment's slice, so
        // both eyes rasterized through layer 0 — the left eye's foveation
        // pattern — and the wearer saw a uniform grid in the left eye and a
        // warped one in the right. `dedicated` gave each view its own texture
        // and own rate map, which sidestepped it.
        //
        // Progressive immersion closes that exit. The portal is drawn by a
        // drawable render context, and a render context refuses every layout
        // but `layered` on a drawable with more than one view. So the renderer
        // now does what it declined to do then: every vertex program emits its
        // view's `render_target_array_index`, all views are encoded into one
        // layered pass, and the rate map's per-eye layer follows the index the
        // shader emits. See SpaghettiPadCompositor.mm's EncodeViews.
        var options: LayerRenderer.Capabilities.SupportedLayoutsOptions =
            [.progressiveImmersionEnabled]
        if foveation {
            options.insert(.foveationEnabled)
        }
        let layouts = capabilities.supportedLayouts(options: options)
        configuration.layout =
            layouts.contains(.layered) ? .layered
            : layouts.contains(.dedicated) ? .dedicated
            : .shared

        // Neither known platform reaches this: an Apple Vision Pro offers
        // [dedicated, layered] and the Simulator offers layered once the
        // progressive option is asked for. It is logged rather than handled
        // because there is no handling available from here — the immersion
        // style is chosen by a scene modifier, not by this method, and a layer
        // that supports the progressive style aborts the process at present
        // time on any drawable it cannot give a render context to. A platform
        // that lands here needs the scene put back to `.full`, and this is the
        // line that says so.
        if !layouts.contains(.layered) {
            log.error(
                """
                no layered layout is offered for progressive immersion; \
                a drawable with more than one view cannot be presented under \
                the progressive style and Compositor Services will abort
                """)
        }

        // Depth is not optional on visionOS: the compositor reprojects each
        // presented frame against it to hold the image still as the wearer
        // moves.
        configuration.depthFormat = .depth32Float
        let colorFormats =
            capabilities.supportedColorFormats(options: [.progressiveImmersionEnabled])
        if colorFormats.contains(.bgra8Unorm_srgb) {
            configuration.colorFormat = .bgra8Unorm_srgb
        }

        // Where the portal's shape arrives. The render context cuts the mask
        // for the current immersion amount into this attachment, and the
        // renderer then tests against it so nothing outside the portal is
        // shaded — which is what progressive immersion saves.
        //
        // An optimisation and not the portal itself, which matters because the
        // Vision Pro Simulator offers no stencil format at all. The portal is
        // still drawn there, through a render context that is mandatory once
        // the layer supports the progressive style; only the saving is lost.
        // See SpaghettiPadCompositor.mm's EncodeViews.
        let stencilFormats = capabilities.drawableRenderContextSupportedStencilFormats
        var stencilFormat = MTLPixelFormat.invalid
        if stencilFormats.contains(.stencil8) {
            stencilFormat = .stencil8
            configuration.drawableRenderContextStencilFormat = stencilFormat
            // No multisampling anywhere in this renderer, so the mask is drawn
            // at one sample per pixel like everything else.
            configuration.drawableRenderContextRasterSampleCount = 1
        }

        // What was on offer, not only what was taken: the Simulator and a real
        // headset differ here, and a build that quietly settled for less should
        // say so in its own log rather than leave it to be inferred.
        let offered = layouts.map { String($0.rawValue) }.joined(separator: ", ")
        let stencilsOffered = stencilFormats.isEmpty
            ? "none"
            : stencilFormats.map { String($0.rawValue) }.joined(separator: ", ")
        // Copied out first: os.Logger interpolation is an autoclosure, and an
        // autoclosure cannot capture an inout parameter.
        let chosen = configuration.layout.rawValue
        let stencil = stencilFormat.rawValue
        log.info(
            """
            compositor capabilities: foveation \(foveation ? "supported" : "unsupported", privacy: .public), \
            layouts offered [\(offered, privacy: .public)], \
            chose layout \(chosen, privacy: .public), \
            portal stencil formats offered [\(stencilsOffered, privacy: .public)], \
            chose \(stencil, privacy: .public)
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
    @State private var extracting = false
    @State private var extractionElapsed = 0
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

    /// Turns an imported ROM into the engine's game archive.
    ///
    /// There is nothing to call: extraction is not a function the shell can
    /// invoke, it is something `GameEngine::Create()` does on its way to the
    /// game loop when it finds no archive. So this starts the engine and waits,
    /// and the archive appearing on disk is the definition of done. The engine
    /// keeps running afterwards, which is exactly what pressing Play would have
    /// done anyway.
    ///
    /// Deliberately not folded into opening the immersive space: extraction
    /// takes minutes, and minutes of test pattern inside a headset is not a way
    /// to tell someone their ROM is being converted.
    private func extractGameData() async {
        extracting = true
        extractionElapsed = 0
        defer { extracting = false }

        let started = await Task.detached(priority: .userInitiated) {
            SpaghettiPad_StartEngine() != 0
        }.value
        guard started else {
            log.error("the engine refused to start for extraction; see the shell log")
            status = RuntimeStatus.prepare()
            return
        }

        // Polled, because Torch reports progress to the engine's log and the
        // engine has no callback to offer. The second condition is the failure
        // case: every extraction failure ends in _Exit(1), which takes this
        // process with it — but if the engine thread ever exits without one,
        // this stops waiting for an archive that is not coming.
        while SpaghettiPad_GameArchiveReady() == 0, SpaghettiPad_EngineRunning() != 0 {
            try? await Task.sleep(for: .seconds(1))
            extractionElapsed += 1
        }

        status = RuntimeStatus.prepare()
        log.info(
            """
            extraction finished after \(extractionElapsed, privacy: .public)s: \
            archive \(status.hasGameArchive ? "created" : "MISSING", privacy: .public)
            """)
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

            if !status.ready {
                Label(
                    "The engine could not prepare its storage.",
                    systemImage: "exclamationmark.triangle"
                )
            } else if status.hasGameArchive {
                Label("Game data found.", systemImage: "checkmark.circle")
            } else if status.extractionPending {
                Label(
                    status.extractionFailed
                        ? "A ROM is here, but the last extraction did not finish. "
                            + "If it fails again the ROM is probably not a "
                            + "supported Mario Kart 64 (US) dump — see logs/ in "
                            + "this folder."
                        : "A ROM is here and has not been converted yet.",
                    systemImage: status.extractionFailed
                        ? "exclamationmark.triangle" : "shippingbox"
                )
            } else {
                Label(
                    "No game data yet. Import a Mario Kart 64 (US) ROM below, or "
                        + "copy one into this folder with Files.",
                    systemImage: "questionmark.folder"
                )
            }

            // Extraction comes before anything else can be offered, because
            // until it has run there is no game to play and the immersive space
            // has only a test pattern to show.
            if status.extractionPending {
                Button(extracting ? "Converting…" : "Convert ROM to Game Data") {
                    Task { await extractGameData() }
                }
                .disabled(extracting || importInProgress != nil)

                Text(
                    extracting
                        ? "Torch is converting the ROM — \(extractionElapsed)s so far. "
                            + "This takes minutes and only happens once. Leave the "
                            + "app in front of you until it finishes."
                        : "Converts the ROM into the archive the engine reads. "
                            + "Runs once, takes minutes, and needs about a "
                            + "gigabyte of free space."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            // The immersive space is offered with or without game data: with it,
            // the engine runs and its frames appear on a screen inside the
            // space; without it, the space shows the compositor's test pattern
            // rather than pretending to be a way into a race that does not
            // exist yet.
            Button(buttonTitle) {
                Task { await toggleImmersiveSpace() }
            }
            .disabled(extracting)

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
            // Same reasoning for extraction, which is the one step that has to
            // happen before any of the above is meaningful on a fresh
            // container. A scripted run imports a ROM, sets this, and waits for
            // the archive.
            if ProcessInfo.processInfo.environment["SPAGHETTIPAD_AUTO_EXTRACT"] == "1",
                status.extractionPending, !extracting {
                await extractGameData()
            }

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

/// Whether the engine wants its settings menu on screen.
///
/// The pad's menu button reaches ImGui, not SwiftUI, so this is the only path
/// between them: the engine posts a visibility edge from its own thread, the
/// shell forwards it to the main queue, and this turns it into something a scene
/// can watch. Going the other way — a wearer closing the window with its own
/// close button — is SettingsWindow's job, through
/// `SpaghettiPad_MenuRequestVisible`.
///
/// Owned by the App rather than by a view because the launch window is dismissed
/// the moment the immersive space opens, and settings are wanted long after
/// that. An observer living on a view that no longer exists would work exactly
/// once, at the only time nobody needs it.
@MainActor
@Observable
final class MenuVisibility {
    private(set) var visible = false

    // nonisolated because deinit is, and a token that is only ever assigned once
    // and read once has nothing to race. The alternative is no deinit at all —
    // this object does live for the whole process — but an observer that is
    // registered and never removed is the kind of thing that is true until it
    // suddenly is not.
    nonisolated(unsafe) private var observer: (any NSObjectProtocol)?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: Notification.Name(SPAGHETTIPAD_MENU_VISIBILITY_NOTIFICATION),
            object: nil,
            queue: .main
        ) { [weak self] note in
            let wanted = (note.userInfo?["visible"] as? NSNumber)?.boolValue ?? false
            MainActor.assumeIsolated { self?.visible = wanted }
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

@main
struct SpaghettiPadApp: App {
    static let launchWindowID = "SpaghettiPadLaunchWindow"
    static let immersiveSpaceID = "SpaghettiPadImmersiveSpace"
    static let settingsWindowID = "SpaghettiPadSettingsWindow"

    /// How far the Digital Crown can wind the world open.
    ///
    /// The floor is not zero. At the bottom of the dial the portal is a small
    /// window and everything around it is the wearer's own room, which for a
    /// racing game is a picture too small to steer by; a third of the way up is
    /// about where the track still reads. The ceiling is 1.0 — the top of the
    /// dial is the fully immersive space this app was until now, so nothing is
    /// taken away from someone who never touches the Crown.
    static let immersionRange = 0.35...1.0

    /// The style the space opens under, and the one thing about progressive
    /// immersion that is not the same on both platforms.
    ///
    /// **The Vision Pro Simulator cannot run it.** Not "renders it differently"
    /// — the first frame of a progressive-style space fails on its GPU with
    /// `MTLCommandBufferErrorDomain error 1`, takes the simulator's Metal
    /// service down with it, and every Metal call in the process aborts through
    /// XPC afterwards. That was isolated rather than assumed: the identical
    /// build under `.full`, with the same layered layout, the same
    /// `render_target_array_index` in every vertex program and the same
    /// drawable render context in the loop, presented 1801 frames at 60 Hz with
    /// no command buffer failures at all. The only difference between the run
    /// that dies on frame 1 and the run that does not is this value.
    ///
    /// Consistent with what the Simulator reports of itself: it offers no
    /// render-context stencil format, so the portal cannot be masked there, and
    /// CompositorServices' own headers say of this API that it "is not
    /// available on simulator".
    ///
    /// So the Simulator lane keeps the fully immersive space it has always had
    /// — every Simulator result in docs/remaining-work.md was collected under
    /// it — and the Digital Crown is a device claim, like stereo, world-locking
    /// and comfort before it.
    static var initialImmersionStyle: ImmersionStyle {
        #if targetEnvironment(simulator)
        return .full
        #else
        return .progressive(immersionRange, initialAmount: 1.0)
        #endif
    }

    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var status = RuntimeStatus.prepare()
    @State private var immersiveSpaceOpen = false
    /// Progressive rather than full on a headset, which is the whole of what
    /// makes the Digital Crown mean anything here: under `.full` the system has
    /// no immersion amount to dial and the Crown only closes the space. Opened
    /// at the top of the range so a wearer who wants what they had before gets
    /// it without doing anything.
    @State private var immersionStyle: ImmersionStyle =
        SpaghettiPadApp.initialImmersionStyle
    @State private var menuVisibility = MenuVisibility()

    var body: some Scene {
        WindowGroup(id: Self.launchWindowID) {
            LaunchView(status: status, immersiveSpaceOpen: $immersiveSpaceOpen)
        }
        .defaultSize(width: 620, height: 400)

        // The settings menu, native. Its own scene rather than a sheet on the
        // launch window, because the launch window is dismissed the moment the
        // immersive space opens and settings are wanted mid-race.
        WindowGroup(id: Self.settingsWindowID) {
            SettingsWindow()
        }
        .defaultSize(width: 900, height: 640)
        .windowResizability(.contentMinSize)

        ImmersiveSpace(id: Self.immersiveSpaceID) {
            CompositorLayer(configuration: SpaghettiPadLayerConfiguration()) {
                layerRenderer in
                // Unretained on purpose: the compositor keeps the renderer
                // alive for as long as this space is open, and the shell holds
                // its own strong reference for as long as its thread runs.
                SpaghettiPad_StartCompositor(
                    Unmanaged.passUnretained(layerRenderer).toOpaque())
            }
            // Nothing in the renderer needs this number — the portal's shape
            // arrives on the drawable's own stencil, frame by frame, and no
            // matrix here is derived from the amount. It is recorded because a
            // wearer reporting that something looked wrong is reporting it at
            // some particular immersion, and a log that cannot say which one
            // cannot tell a portal-edge artefact from a rendering fault.
            .onImmersionChange { _, immersion in
                SpaghettiPad_SetImmersionAmount(immersion.amount ?? -1.0)
            }
        }
        // The same value the selection starts at, rather than a second spelling
        // of it. A style's range and initial amount are part of its identity, so
        // a `.progressive` listed here that did not match the one selected would
        // not be the style that gets applied — and on the Simulator, where the
        // first is already `.full`, this list must not offer progressive at all.
        // A layer that merely *supports* the progressive style is a layer whose
        // frames the Simulator cannot present.
        .immersionStyle(selection: $immersionStyle, in: Self.initialImmersionStyle, .full)
        .onChange(of: immersiveSpaceOpen) { _, open in
            if !open {
                SpaghettiPad_StopCompositor()
            }
        }
        // On the immersive space rather than on the launch window: this is the
        // scene that is alive while someone is racing, which is when the menu
        // button gets pressed.
        .onChange(of: menuVisibility.visible) { _, visible in
            if visible {
                openWindow(id: Self.settingsWindowID)
            } else {
                dismissWindow(id: Self.settingsWindowID)
            }
        }
    }
}
