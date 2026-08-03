// The visionOS side of SpaghettiPadBridge.h.
//
// Successor to ios/SpaghettiPadShell.mm. That file bridged a UIKit touch
// overlay into an SDL virtual joystick; this one will bridge the SwiftUI app
// lifecycle, a Compositor Services immersive space, and GameController / ARKit
// accessory input into the same engine.
//
// Storage, the engine thread, and — in SpaghettiPadCompositor.mm — the
// compositor are live. Input is live too, though almost none of it is here:
// routing belongs to the engine's own control deck, and the 6DoF half belongs
// to SpaghettiPadAccessorySteering.mm. What is left in this file is reporting.
//
// The import entry points below are declared by the header and called by the
// shell, so they exist here as explicit, logged refusals rather than as silent
// no-ops that would look like success.

#import "SpaghettiPadBridge.h"

#import <AVFAudio/AVFAudio.h>
#import <Foundation/Foundation.h>
#import <GameController/GameController.h>

#import <os/log.h>

#import <pthread.h>

#import <atomic>
#import <string>

namespace {

os_log_t ShellLog() {
    static os_log_t log = os_log_create("com.subtlepath.spaghettipad", "shell");
    return log;
}

os_log_t AudioLog() {
    static os_log_t log = os_log_create("com.subtlepath.spaghettipad", "audio");
    return log;
}

// Decouples the app's sound from its launch window, once per process.
//
// visionOS spatializes an app's audio by default: a head-tracked sound stage
// whose anchoring strategy is Automatic, and Automatic anchors it to the app's
// window scene. That default is what a wearer reported as "audio stops when
// the launch window closes": dismissing the window for full immersion took
// the sound stage's anchor with it, and the output fell silent with no
// interruption, no error, and nothing for SDL's own listeners to act on —
// reopening the window restored it, which is what tied the symptom to the
// scene. Bypassed opts out of system spatialization entirely. The engine
// already produces a finished stereo mix, panned camera-relative the way the
// game has mixed it since 1996, and re-spatializing that mix against a window
// was never right even while it worked.
//
// The observers are evidence, not control: SDL's CoreAudio backend installs
// its own interruption handling per open device, and a second resume here
// would race it. What no archive has carried so far is any record of whether
// an interruption fired at the moment the audio died; now one would.
void ConfigureAudioSession() {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        AVAudioSession* session = [AVAudioSession sharedInstance];
        NSError* error = nil;
        if ([session setIntendedSpatialExperience:AVAudioSessionSpatialExperienceBypassed
                                          options:nil
                                            error:&error]) {
            os_log(AudioLog(),
                   "audio session spatial experience is bypassed: the engine's "
                   "stereo mix goes straight to the output, anchored to no "
                   "window scene");
        } else {
            os_log_error(AudioLog(),
                         "could not set the audio session's spatial experience: "
                         "%{public}@",
                         error.localizedDescription);
        }

        NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
        [center addObserverForName:AVAudioSessionInterruptionNotification
                            object:session
                             queue:nil
                        usingBlock:^(NSNotification* note) {
                            NSNumber* type =
                                note.userInfo[AVAudioSessionInterruptionTypeKey];
                            os_log(AudioLog(),
                                   "audio session interruption %{public}s",
                                   type.unsignedIntegerValue ==
                                           AVAudioSessionInterruptionTypeBegan
                                       ? "began"
                                       : "ended");
                        }];
        [center addObserverForName:AVAudioSessionMediaServicesWereResetNotification
                            object:session
                             queue:nil
                        usingBlock:^(NSNotification*) {
                            os_log_error(AudioLog(), "media services were reset");
                        }];
    });
}

std::string gDocumentsPath;
std::string gBundlePath;

// The engine expects a user-supplied ROM to have been extracted to this name in
// the writable container. Nothing in this repository ever ships one.
NSString* const kGameArchiveName = @"mk64.o2r";

// Dropped in the container immediately before the engine is started to extract,
// and only then. Extraction runs inside the engine, and every way it can fail
// ends in _Exit(1) — upstream's deliberate choice, because those bail-outs run
// before the game world exists and unwinding through it crashes. From outside,
// _Exit is indistinguishable from the app being closed, so a failed extraction
// would otherwise leave nothing behind but a log nobody thought to read. This
// file is what the next launch reads to say "that did not work" instead of
// silently offering the same button again.
NSString* const kExtractionMarkerName = @".extraction-in-progress";

// Whether the previous launch died during extraction. Resolved once, in
// SpaghettiPad_RuntimeInit, so that later calls describe that launch rather than
// a marker this one has since written.
bool gPreviousExtractionFailed = false;

bool DirectoryExists(NSString* path) {
    BOOL isDirectory = NO;
    return [[NSFileManager defaultManager] fileExistsAtPath:path
                                                isDirectory:&isDirectory] &&
           isDirectory;
}

void Unimplemented(const char* what) {
    os_log_error(ShellLog(), "%{public}s is not implemented in this build", what);
}

} // namespace

// ---------------------------------------------------------------- lifecycle

int SpaghettiPad_RuntimeInit(const char* documentsPath, const char* bundlePath) {
    // Before anything else and regardless of what storage says: the session's
    // spatial experience is process-wide state the system consults whenever
    // this app makes sound, and it has to be set before SDL opens a device.
    ConfigureAudioSession();

    if (documentsPath == nullptr || bundlePath == nullptr) {
        os_log_error(ShellLog(), "runtime init called with a null path");
        return 0;
    }

    NSString* documents = @(documentsPath);
    NSString* bundle = @(bundlePath);

    if (!DirectoryExists(documents)) {
        os_log_error(ShellLog(), "documents container is missing: %{public}s",
                     documentsPath);
        return 0;
    }
    if (!DirectoryExists(bundle)) {
        os_log_error(ShellLog(), "app bundle is missing: %{public}s", bundlePath);
        return 0;
    }

    // Texture packs are read from here. Creating it up front means the folder is
    // visible to the user before anything has been imported.
    NSString* mods = [documents stringByAppendingPathComponent:@"mods"];
    NSError* error = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:mods
                                   withIntermediateDirectories:YES
                                                    attributes:nil
                                                         error:&error]) {
        os_log_error(ShellLog(), "could not create mods directory: %{public}@",
                     error.localizedDescription);
        return 0;
    }

    gDocumentsPath = documentsPath;
    gBundlePath = bundlePath;

    // Read and cleared exactly once per process, before anything can write a new
    // one, so the answer describes the launch that left the marker rather than
    // this one. SwiftUI calls this again whenever the container changes under
    // it, and a second read would consume a marker belonging to an extraction
    // still in flight.
    static dispatch_once_t markerOnce;
    dispatch_once(&markerOnce, ^{
        NSString* marker =
            [documents stringByAppendingPathComponent:kExtractionMarkerName];
        if (![[NSFileManager defaultManager] fileExistsAtPath:marker]) {
            return;
        }
        gPreviousExtractionFailed = SpaghettiPad_GameArchiveReady() == 0;
        if (gPreviousExtractionFailed) {
            os_log_error(ShellLog(),
                         "the previous launch started extracting and did not "
                         "finish; see the engine log in logs/");
        }
        [[NSFileManager defaultManager] removeItemAtPath:marker error:nil];
    });

    return 1;
}

int SpaghettiPad_GameArchiveReady(void) {
    if (gDocumentsPath.empty()) {
        return 0;
    }

    NSString* archive =
        [@(gDocumentsPath.c_str()) stringByAppendingPathComponent:kGameArchiveName];
    NSDictionary* attributes =
        [[NSFileManager defaultManager] attributesOfItemAtPath:archive error:nil];
    return (attributes != nil && attributes.fileSize > 0) ? 1 : 0;
}

// How many importable ROMs the container holds.
//
// Answerable before the engine has started, which is the whole point: with no
// game archive the launch window has to decide between offering extraction and
// offering nothing, and the engine that could tell it is the thing that will not
// start. The extension test matches the engine's own container scan in
// GameExtractor::GetRoms — this counts candidates, and only the engine's hash
// check can say whether one is the supported game.
int SpaghettiPad_ImportedRomCount(void) {
    if (gDocumentsPath.empty()) {
        return 0;
    }

    NSArray<NSString*>* entries = [[NSFileManager defaultManager]
        contentsOfDirectoryAtPath:@(gDocumentsPath.c_str())
                            error:nil];

    int count = 0;
    for (NSString* entry in entries) {
        if ([entry.pathExtension caseInsensitiveCompare:@"z64"] == NSOrderedSame) {
            ++count;
        }
    }
    return count;
}

// Non-zero when the container holds a ROM the engine has not turned into a game
// archive yet, which is exactly when starting the engine means extracting.
int SpaghettiPad_ExtractionPending(void) {
    return (SpaghettiPad_GameArchiveReady() == 0 &&
            SpaghettiPad_ImportedRomCount() > 0)
               ? 1
               : 0;
}

int SpaghettiPad_PreviousExtractionFailed(void) {
    return gPreviousExtractionFailed ? 1 : 0;
}

namespace {

// Copies a user-picked file into the app's container.
//
// Written as a stream rather than -copyItemAtPath: because the file this exists
// for is the MK64 Reloaded 4K pack, which is about 1.2 GiB. A copy that size is
// worth reporting on and worth failing cleanly from, and a partially written
// archive left behind under a name the engine scans for is worse than no archive
// at all — the mod loader would find it, fail to parse it, and the failure would
// look like the pack being incompatible rather than truncated.
bool CopyIntoContainer(NSString* sourcePath, NSString* destinationPath,
                       const char* what) {
    NSFileManager* files = [NSFileManager defaultManager];

    NSDictionary* attributes = [files attributesOfItemAtPath:sourcePath error:nil];
    const unsigned long long bytes = attributes.fileSize;

    NSError* error = nil;
    NSNumber* freeSpace = [[files attributesOfFileSystemForPath:destinationPath.stringByDeletingLastPathComponent
                                                          error:&error] objectForKey:NSFileSystemFreeSize];
    if (freeSpace != nil && freeSpace.unsignedLongLongValue < bytes) {
        os_log_error(ShellLog(),
                     "not enough space to import %{public}s: %llu MiB needed, "
                     "%llu MiB free",
                     what, bytes / (1024 * 1024),
                     freeSpace.unsignedLongLongValue / (1024 * 1024));
        return false;
    }

    // Written beside the destination and moved into place only once whole, so a
    // failure halfway through never leaves something the engine would try to
    // load.
    NSString* partial = [destinationPath stringByAppendingPathExtension:@"partial"];
    [files removeItemAtPath:partial error:nil];

    const CFAbsoluteTime started = CFAbsoluteTimeGetCurrent();
    if (![files copyItemAtPath:sourcePath toPath:partial error:&error]) {
        os_log_error(ShellLog(), "could not import %{public}s: %{public}@", what,
                     error.localizedDescription);
        [files removeItemAtPath:partial error:nil];
        return false;
    }

    [files removeItemAtPath:destinationPath error:nil];
    if (![files moveItemAtPath:partial toPath:destinationPath error:&error]) {
        os_log_error(ShellLog(), "could not place %{public}s: %{public}@", what,
                     error.localizedDescription);
        [files removeItemAtPath:partial error:nil];
        return false;
    }

    const double seconds = CFAbsoluteTimeGetCurrent() - started;
    os_log(ShellLog(),
           "imported %{public}s: %llu MiB in %.1f s (%.0f MiB/s) to %{public}@",
           what, bytes / (1024 * 1024), seconds,
           seconds > 0.0 ? (double)bytes / (1024.0 * 1024.0) / seconds : 0.0,
           destinationPath.lastPathComponent);
    return true;
}

} // namespace

// Copies a user-selected ROM into the container. Extraction itself is the
// engine's: GameExtractor scans this directory for a .z64 and Torch turns it
// into mk64.o2r, which is why this only has to put the file where that scan
// will find it. Nothing in this repository ever ships one.
int SpaghettiPad_ImportRom(const char* sourcePath) {
    if (sourcePath == nullptr || gDocumentsPath.empty()) {
        os_log_error(ShellLog(), "ROM import called before the container exists");
        return 0;
    }

    NSString* source = @(sourcePath);
    NSString* destination = [@(gDocumentsPath.c_str())
        stringByAppendingPathComponent:source.lastPathComponent];
    return CopyIntoContainer(source, destination, "ROM") ? 1 : 0;
}

// Copies a user-selected texture pack into the container's mods directory, where
// the engine's mod loader scans for .o2r archives at startup.
//
// The pack is never bundled and never fetched: MK64 Reloaded carries no license
// and its content is derivative of Nintendo art, so the only way it can be here
// is that the person using the app went and got it.
int SpaghettiPad_ImportModArchive(const char* sourcePath) {
    if (sourcePath == nullptr || gDocumentsPath.empty()) {
        os_log_error(ShellLog(),
                     "texture pack import called before the container exists");
        return 0;
    }

    NSString* source = @(sourcePath);
    if ([source.pathExtension caseInsensitiveCompare:@"o2r"] != NSOrderedSame) {
        os_log_error(ShellLog(),
                     "refusing to import %{public}@: a texture pack must be an "
                     ".o2r archive",
                     source.lastPathComponent);
        return 0;
    }

    NSString* mods =
        [@(gDocumentsPath.c_str()) stringByAppendingPathComponent:@"mods"];
    NSString* destination =
        [mods stringByAppendingPathComponent:source.lastPathComponent];
    return CopyIntoContainer(source, destination, "texture pack") ? 1 : 0;
}

// What the mods directory holds, so the shell can say whether a pack is there
// without the engine having started. Returns the number of .o2r archives found.
int SpaghettiPad_InstalledModCount(void) {
    if (gDocumentsPath.empty()) {
        return 0;
    }

    NSString* mods =
        [@(gDocumentsPath.c_str()) stringByAppendingPathComponent:@"mods"];
    NSArray<NSString*>* entries =
        [[NSFileManager defaultManager] contentsOfDirectoryAtPath:mods error:nil];

    int count = 0;
    for (NSString* entry in entries) {
        if ([entry.pathExtension caseInsensitiveCompare:@"o2r"] == NSOrderedSame) {
            ++count;
        }
    }
    return count;
}

namespace {

// libultraship's console-variable store, written by CVarSave and read once at
// GameEngine::Create(). Whatever is in it is what the next engine start will
// apply, which is what makes it the honest answer for a window that exists
// before the engine does.
NSString* const kConfigName = @"spaghettify.cfg.json";

// The engine's dotted CVar name maps onto nested JSON objects, so the flag lives
// at CVars -> gEnhancements -> Mods -> AlternateAssets.
NSString* const kAlternateAssetsPath[] = { @"CVars", @"gEnhancements", @"Mods",
                                           @"AlternateAssets" };
constexpr size_t kAlternateAssetsDepth =
    sizeof(kAlternateAssetsPath) / sizeof(kAlternateAssetsPath[0]);

NSString* ConfigPath() {
    if (gDocumentsPath.empty()) {
        return nil;
    }
    return [@(gDocumentsPath.c_str()) stringByAppendingPathComponent:kConfigName];
}

// nil when the file is absent, which is the ordinary state before the engine has
// ever run and saved one — not an error worth logging.
NSMutableDictionary* ReadConfig() {
    NSString* path = ConfigPath();
    if (path == nil) {
        return nil;
    }
    NSData* data = [NSData dataWithContentsOfFile:path];
    if (data == nil) {
        return nil;
    }

    NSError* error = nil;
    id parsed = [NSJSONSerialization JSONObjectWithData:data
                                                options:NSJSONReadingMutableContainers
                                                  error:&error];
    if (![parsed isKindOfClass:[NSMutableDictionary class]]) {
        os_log_error(ShellLog(), "could not read %{public}@: %{public}@",
                     kConfigName, error.localizedDescription);
        return nil;
    }
    return parsed;
}

// Only ever called with the engine stopped. Writing this file while the engine
// holds its own copy in memory would be a race the engine wins at its next save,
// which is why the callers below delegate to the CVar system whenever it exists.
//
// Rewritten whole rather than patched textually. That re-serialises every value,
// which is lossless for the integers and strings this file has held so far;
// should the engine ever save a float, this is the line that would round it.
bool WriteConfig(NSDictionary* config) {
    NSString* path = ConfigPath();
    if (path == nil) {
        return false;
    }

    NSError* error = nil;
    NSData* data = [NSJSONSerialization dataWithJSONObject:config
                                                   options:NSJSONWritingPrettyPrinted
                                                     error:&error];
    if (data == nil) {
        os_log_error(ShellLog(), "could not serialise %{public}@: %{public}@",
                     kConfigName, error.localizedDescription);
        return false;
    }

    // Atomically, so an interrupted write can never leave the engine a config it
    // will fail to parse on next launch.
    if (![data writeToFile:path atomically:YES]) {
        os_log_error(ShellLog(), "could not write %{public}@", kConfigName);
        return false;
    }
    return true;
}

} // namespace

void SpaghettiPad_SetAlternateAssetsPreference(int enabled) {
    const int value = enabled != 0 ? 1 : 0;

    // A live session: the CVar system owns the value, and only it can make the
    // engine reload textures for the change.
    if (SpaghettiPad_EngineRunning()) {
        SpaghettiPad_SetAlternateAssets(value);
        return;
    }

    NSMutableDictionary* config = ReadConfig();
    if (config == nil) {
        // No saved config yet. Writing one holding only this choice is safe:
        // libultraship fills every variable it does not find with its default.
        config = [NSMutableDictionary dictionary];
    }

    NSMutableDictionary* node = config;
    for (size_t index = 0; index + 1 < kAlternateAssetsDepth; ++index) {
        id child = node[kAlternateAssetsPath[index]];
        if (![child isKindOfClass:[NSMutableDictionary class]]) {
            child = [NSMutableDictionary dictionary];
            node[kAlternateAssetsPath[index]] = child;
        }
        node = child;
    }
    node[kAlternateAssetsPath[kAlternateAssetsDepth - 1]] = @(value);

    if (WriteConfig(config)) {
        os_log(ShellLog(),
               "enhanced textures %{public}s for the next engine start",
               value != 0 ? "on" : "off");
    }
}

int SpaghettiPad_AlternateAssetsPreference(void) {
    if (SpaghettiPad_EngineRunning()) {
        return SpaghettiPad_AlternateAssetsEnabled();
    }

    NSDictionary* node = ReadConfig();
    for (size_t index = 0; index + 1 < kAlternateAssetsDepth && node != nil; ++index) {
        id child = node[kAlternateAssetsPath[index]];
        node = [child isKindOfClass:[NSDictionary class]] ? child : nil;
    }

    id value = node[kAlternateAssetsPath[kAlternateAssetsDepth - 1]];
    return [value isKindOfClass:[NSNumber class]] && [value intValue] != 0 ? 1 : 0;
}

void SpaghettiPad_RequestShutdown(void) {
    // Upstream's game loop ends in _Exit(0) — deliberately, to skip static
    // destructors that log after spdlog's statics are gone — so there is no way
    // to ask it to return that does not take the process with it. This stays a
    // refusal until there is a shutdown path that leaves the app alive.
    Unimplemented("engine shutdown");
}

// ------------------------------------------------------------------ engine
//
// The compositor half of this section lives in SpaghettiPadCompositor.mm and
// the render handover in SpaghettiPadRenderSurface.mm. What remains here is the
// thread the game loop runs on.

namespace {

// Declared rather than included: the shell has no other reason to pull in SDL's
// headers, and this is the whole of its business with SDL. The app is built with
// SDL_MAIN_HANDLED — SDL_main.h would otherwise rename main out from under the
// engine — and SDL then refuses to initialise any subsystem until it is told the
// application's entry point has run. This is that.
extern "C" void SDL_SetMainReady(void);

std::atomic<bool> gEngineStarted{false};

// Upstream's main(), renamed at compile time (see the maintained SpaghettiKart
// patch), so no upstream source knows this app exists. It does not return: its
// last statement is _Exit(0), which upstream uses to skip static destructors
// that log after spdlog's own statics are gone.
void* EngineThread(void* argument) {
    (void)argument;
    pthread_setname_np("spaghettipad.engine");

    SDL_SetMainReady();

    // argv[0] is all upstream reads, and only to satisfy the signature.
    static char program[] = "SpaghettiPad";
    char* argv[] = { program, nullptr };

    os_log(ShellLog(), "engine thread entering the game loop");
    const int status = SpaghettiPad_GameMain(1, argv);
    os_log(ShellLog(), "engine thread returned %d", status);
    gEngineStarted.store(false, std::memory_order_release);
    return nullptr;
}

} // namespace

int SpaghettiPad_StartEngine(void) {
    bool expected = false;
    if (!gEngineStarted.compare_exchange_strong(expected, true)) {
        os_log(ShellLog(), "the engine is already running");
        return 1;
    }

    if (!SpaghettiPad_GameArchiveReady()) {
        // Without game data upstream puts up a modal asking to extract a ROM,
        // through SDL_ShowMessageBox — which cannot draw anything with
        // SDL_VIDEO off — and then exits the process. Refusing here is the
        // difference between a clear message and the app vanishing.
        //
        // But refusing on the archive alone refused the only thing that could
        // ever create one. Extraction is the engine's: GameExtractor scans this
        // container, Torch builds mk64.o2r, and both run inside GameEngine
        // ::Create() on the way to the game loop. So an imported ROM and no
        // archive is not the empty case — it is the first run, and the engine
        // has to start for it to finish.
        if (!SpaghettiPad_ExtractionPending()) {
            os_log_error(ShellLog(),
                         "refusing to start the engine: the container holds "
                         "neither a game archive nor a ROM to extract");
            gEngineStarted.store(false, std::memory_order_release);
            return 0;
        }

        NSString* marker = [@(gDocumentsPath.c_str())
            stringByAppendingPathComponent:kExtractionMarkerName];
        [[NSData data] writeToFile:marker atomically:YES];
        os_log(ShellLog(),
               "no game archive yet; starting the engine to extract %d ROM(s) "
               "from the container. This takes minutes and the app is not hung.",
               SpaghettiPad_ImportedRomCount());
    }

    // The N64 game loop recurses deeply enough that the 512 KiB a secondary
    // pthread gets by default is not close to sufficient; upstream runs on the
    // main thread, which has 8 MiB. 16 MiB is that with room to spare.
    pthread_attr_t attributes;
    if (pthread_attr_init(&attributes) != 0) {
        os_log_error(ShellLog(), "could not initialise engine thread attributes");
        gEngineStarted.store(false, std::memory_order_release);
        return 0;
    }
    pthread_attr_setstacksize(&attributes, 16 * 1024 * 1024);
    pthread_attr_setdetachstate(&attributes, PTHREAD_CREATE_DETACHED);

    pthread_t thread;
    const int result = pthread_create(&thread, &attributes, EngineThread, nullptr);
    pthread_attr_destroy(&attributes);

    if (result != 0) {
        os_log_error(ShellLog(), "could not create the engine thread: %d", result);
        gEngineStarted.store(false, std::memory_order_release);
        return 0;
    }

    os_log(ShellLog(), "engine thread started with a 16 MiB stack");
    return 1;
}

int SpaghettiPad_EngineRunning(void) {
    return gEngineStarted.load(std::memory_order_acquire) ? 1 : 0;
}

void SpaghettiPad_SetImmersiveActive(int active) {
    // Recorded, not acted on. The engine keeps running while the space is
    // closed; it simply stops producing frames, because the compositor thread —
    // the only thing that consumes them — is what reports the surface live, and
    // the game loop idles rather than rendering into nothing. Restarting the
    // engine on every reopen would restart the game.
    os_log(ShellLog(), "immersive space %{public}s",
           active != 0 ? "active" : "inactive");
}

void SpaghettiPad_SetImmersionAmount(double amount) {
    // Logged on movement rather than on arrival. The Digital Crown reports
    // continuously while it turns, and a line per report would bury the session
    // in a log that is read to find out what a wearer was doing. A twentieth of
    // the dial is finer than anyone sets it deliberately and coarse enough that
    // a full sweep costs twenty lines.
    //
    // -2 is a bucket no amount produces, so the first report of a session is
    // always a change and always logged.
    static std::atomic<int> lastBucket{-2};
    const int bucket = amount < 0.0 ? -1 : (int)(amount * 20.0 + 0.5);
    if (lastBucket.exchange(bucket, std::memory_order_relaxed) == bucket) {
        return;
    }
    if (amount < 0.0) {
        os_log(ShellLog(), "immersion: no amount (a style that does not dial)");
    } else {
        os_log(ShellLog(), "immersion dialled to %.2f", amount);
    }
}

// ------------------------------------------------------------------- input
//
// There is no input layer here, and that is the finding rather than an omission.
// SDL's MFi joystick driver is compiled into this lane, libultraship calls
// SDL_Init(SDL_INIT_GAMECONTROLLER), and its control deck already opens whatever
// SDL enumerates and gives port 0 default gamepad mappings. Every part of the
// path existed; what broke it was one line in the visionOS window backend
// draining SDL_CONTROLLERDEVICEADDED out of the queue before the handler that
// acts on it could run. Adding a shell-side input layer would have papered over
// that rather than fixed it.
//
// So what remains here is reporting, not routing.

namespace {

os_log_t InputLog() {
    static os_log_t log = os_log_create("com.subtlepath.spaghettipad", "input");
    return log;
}

std::atomic<int> gConnectedDevices{0};

// What the GameController framework hands this process, watched separately from
// what the engine ends up holding.
//
// This is still reporting rather than routing, and it exists because a wearer
// lost the sticks on a pair of Sense controllers powered on after launch while
// the buttons kept working. The archive showed why: the app enumerated the right
// Sense and never the left — and the left is where the left thumbstick is, which
// is what Mario Kart 64 steers and navigates menus with. What the archive could
// not say is which layer lost it. Three are stacked here, and only one of them
// is this project's to fix:
//
//   - the framework may never have handed the app the second controller, in
//     which case nothing in this process can conjure it;
//   - SDL's MFi driver may have refused it — IOS_AddMFIJoystickDevice returns
//     false for a device it cannot read, frees it, and says nothing, which for a
//     half-pair with no face buttons on it is a real possibility;
//   - or the SDL_CONTROLLERDEVICEADDED event may have been lost before
//     Ship::SDLAddRemoveDeviceEventHandler could act on it, which is a fault
//     this lane has had once before.
//
// An observer of the framework's own notifications separates the first from the
// other two, because it sits above SDL and hears what SDL was offered. It routes
// nothing: the engine's control deck remains the only thing that opens a device.
std::atomic<int> gFrameworkControllers{0};

NSString* FrameworkControllerNames() {
    NSMutableArray<NSString*>* names = [NSMutableArray array];
    for (GCController* controller in [GCController controllers]) {
        [names addObject:(controller.vendorName ?: @"unnamed")];
    }
    return [[names sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]
        componentsJoinedByString:@", "];
}

// Reports what the framework holds, and — a moment later, so the engine has had
// frames to open it — whether the control deck agrees. A framework count above
// the deck's is a device the app was offered and did not get: the one case worth
// a warning, because it is the one that can be fixed here.
void ReportFrameworkControllers(const char* what, GCController* controller) {
    const int count = static_cast<int>([GCController controllers].count);
    gFrameworkControllers.store(count, std::memory_order_release);

    os_log(InputLog(), "GameController %{public}s: %{public}s; the framework now holds %d: %{public}s",
           what, controller.vendorName.UTF8String ?: "unnamed", count,
           FrameworkControllerNames().UTF8String);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        const int framework = gFrameworkControllers.load(std::memory_order_acquire);
        const int deck = gConnectedDevices.load(std::memory_order_acquire);
        if (framework > deck) {
            os_log_error(InputLog(),
                         "%d controller(s) reached this app but only %d reached the game: "
                         "%{public}s. A Sense pair split this way loses the left stick, which "
                         "is steering and menu selection",
                         framework, deck, FrameworkControllerNames().UTF8String);
        }
    });
}

// Registered once, on the main queue, because that is where the framework posts.
// Deliberately not registered from SpaghettiPad_InputInit: nothing calls it.
void EnsureControllerObservers() {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
            [center addObserverForName:GCControllerDidConnectNotification
                                object:nil
                                 queue:[NSOperationQueue mainQueue]
                            usingBlock:^(NSNotification* note) {
                              ReportFrameworkControllers("connected", note.object);
                            }];
            [center addObserverForName:GCControllerDidDisconnectNotification
                                object:nil
                                 queue:[NSOperationQueue mainQueue]
                            usingBlock:^(NSNotification* note) {
                              ReportFrameworkControllers("disconnected", note.object);
                            }];
            os_log(InputLog(), "watching GameController connections; the framework holds %d: %{public}s",
                   static_cast<int>([GCController controllers].count),
                   FrameworkControllerNames().UTF8String);
        });
    });
}

} // namespace

void SpaghettiPad_InputDevicesChanged(int count, const char* names) {
    gConnectedDevices.store(count, std::memory_order_release);
    EnsureControllerObservers();

    if (count <= 0) {
        os_log(InputLog(), "no game controller is connected");
        return;
    }

    os_log(InputLog(), "%d game controller(s) connected: %{public}s", count,
           names != nullptr ? names : "");
}

void SpaghettiPad_InputFirstActivity(int port, unsigned buttons, int stickX, int stickY) {
    // Once per port, from the engine thread, the first time that port carries
    // something the game will act on. This is the line that separates a
    // controller the app has opened from one the game is actually being driven
    // by, and on a headset it is the only way to tell them apart.
    os_log(InputLog(),
           "port %d first input reached the game: buttons 0x%04x, stick (%d, %d)",
           port, buttons, stickX, stickY);
}

int SpaghettiPad_InputRecentreChordHeld(void) {
    // Merged across every controller the framework holds, for the same reason
    // the menu's gamepad navigation merges: a PS VR2 Sense pair can reach this
    // app as two devices, and this chord needs a hand on each. Asking one
    // controller for all four inputs would make it unreachable on the hardware
    // this lane is developed against.
    bool leftShoulder = false;
    bool rightShoulder = false;
    bool leftTrigger = false;
    bool rightTrigger = false;

    for (GCController* controller in [GCController controllers]) {
        GCExtendedGamepad* pad = controller.extendedGamepad;
        if (pad == nil) {
            continue;
        }
        leftShoulder = leftShoulder || pad.leftShoulder.pressed;
        rightShoulder = rightShoulder || pad.rightShoulder.pressed;
        leftTrigger = leftTrigger || pad.leftTrigger.pressed;
        rightTrigger = rightTrigger || pad.rightTrigger.pressed;
    }

    const bool held = leftShoulder && rightShoulder && leftTrigger && rightTrigger;

    // Logged on its edges only, and at all because a wearer who reports "the
    // recentre does nothing" needs an archive that separates a chord that was
    // never completed from one that was and did not move the room. The
    // compositor logs the other half.
    static std::atomic<int> reported{0};
    const int now = held ? 1 : 0;
    if (reported.exchange(now, std::memory_order_acq_rel) != now) {
        os_log(InputLog(), "recentre chord %{public}s", held ? "held" : "released");
    }
    return now;
}

void SpaghettiPad_InputInit(void) {
    // Nothing to initialise: the engine's own SDL_Init(SDL_INIT_GAMECONTROLLER)
    // and control deck do all of it, and doing it twice here would open the same
    // devices a second time.
    os_log(InputLog(), "input is handled by the engine's control deck; nothing to initialise");
}

void SpaghettiPad_InputShutdown(void) {
    os_log(InputLog(), "input shutdown is the engine's; nothing to tear down");
}

// Accessory tracking and the motion-steering entry points live in
// SpaghettiPadAccessorySteering.mm. They were explicit logged refusals here
// until the 6DoF pose had somewhere to go; the pose is a wheel now, and the file
// that reads it owns them.

int SpaghettiPad_ConnectedPortCount(void) {
    // What the control deck has open, reported to this shell from the engine
    // thread. Not the number of *ports*: upstream always has four, and assigns
    // every controller it opens to port 0 until an Input Editor says otherwise.
    // Splitting them across ports is Phase 5's multiplayer half and is not done.
    return gConnectedDevices.load(std::memory_order_acquire);
}

// --------------------------------------------------- engine -> shell (weak)
//
// libultraship declares these weak with no-op defaults so it links without a
// shell. Defining them here is what makes the engine's calls reach the app.

void SpaghettiPad_SetMenuVisible(int visible) {
    // Called every frame from Gui::StartDraw, so only the edges are logged.
    //
    // This is the shell's only sight of the settings UI: the menu is ImGui's,
    // drawn into the same surface as the game, and nothing about it reaches
    // SwiftUI. A wearer who says "I could not open the settings" and a wearer
    // who opened them and found them unreadable are two different bugs, and
    // before this pair of lines existed a log archive could not tell them apart.
    static std::atomic<int> reported{-1};
    const int now = visible != 0 ? 1 : 0;
    if (reported.exchange(now, std::memory_order_acq_rel) == now) {
        return;
    }
    os_log(ShellLog(), "menu %{public}s", now != 0 ? "opened" : "closed");

    // Onto the main queue, because the far end of this is a SwiftUI scene and
    // this runs on the engine thread. Posting an edge rather than a level: the
    // window opens and closes, it does not need telling every frame that it is
    // still open.
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter]
            postNotificationName:@SPAGHETTIPAD_MENU_VISIBILITY_NOTIFICATION
                          object:nil
                        userInfo:@{ @"visible" : @(now) }];
    });
}

namespace {
// Whether a native settings window is on screen right now. Written by SwiftUI as
// the window appears and disappears, read by the engine every frame it draws a
// menu.
std::atomic<bool> gNativeMenuPresent{false};
} // namespace

void SpaghettiPad_MenuNativeWindowPresent(int present) {
    const bool now = present != 0;
    if (gNativeMenuPresent.exchange(now, std::memory_order_acq_rel) == now) {
        return;
    }
    os_log(ShellLog(), "native settings window %{public}s; the ImGui menu %{public}s",
           now ? "presented" : "dismissed", now ? "stands down" : "draws again");
}

int SpaghettiPad_MenuUsesNativeWindow(void) {
    return gNativeMenuPresent.load(std::memory_order_acquire) ? 1 : 0;
}

void SpaghettiPad_SetGameplayActive(int active) {
    (void)active;
}

void SpaghettiPad_PresentAlert(const char* title, const char* body) {
    os_log_error(ShellLog(), "engine alert: %{public}s — %{public}s",
                 title != nullptr ? title : "", body != nullptr ? body : "");
}
