// The visionOS side of SpaghettiPadBridge.h.
//
// Successor to ios/SpaghettiPadShell.mm. That file bridged a UIKit touch
// overlay into an SDL virtual joystick; this one will bridge the SwiftUI app
// lifecycle, a Compositor Services immersive space, and GameController / ARKit
// accessory input into the same engine.
//
// Storage, the engine thread, and — in SpaghettiPadCompositor.mm — the
// compositor are live. The import and input entry points below are declared by
// the header and called by the shell, so they exist here as explicit, logged
// refusals rather than as silent no-ops that would look like success.

#import "SpaghettiPadBridge.h"

#import <AVFAudio/AVFAudio.h>
#import <Foundation/Foundation.h>

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
        os_log_error(ShellLog(),
                     "refusing to start the engine: no game archive exists yet");
        gEngineStarted.store(false, std::memory_order_release);
        return 0;
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

} // namespace

void SpaghettiPad_InputDevicesChanged(int count, const char* names) {
    gConnectedDevices.store(count, std::memory_order_release);

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

void SpaghettiPad_InputInit(void) {
    // Nothing to initialise: the engine's own SDL_Init(SDL_INIT_GAMECONTROLLER)
    // and control deck do all of it, and doing it twice here would open the same
    // devices a second time.
    os_log(InputLog(), "input is handled by the engine's control deck; nothing to initialise");
}

void SpaghettiPad_InputShutdown(void) {
    os_log(InputLog(), "input shutdown is the engine's; nothing to tear down");
}

void SpaghettiPad_AttachAccessoryTracking(void* arSession) {
    // The session this will join already exists and is running world tracking;
    // SpaghettiPad_ARSession() is where Phase 5 gets it. What is missing is the
    // accessory provider, not the session.
    (void)arSession;
    Unimplemented("accessory tracking");
}

void SpaghettiPad_SetMotionSteeringEnabled(int enabled) {
    (void)enabled;
    Unimplemented("motion steering");
}

void SpaghettiPad_SetMotionSensitivity(float sensitivity) {
    (void)sensitivity;
    Unimplemented("motion sensitivity");
}

void SpaghettiPad_RecenterMotionSteering(void) {
    Unimplemented("motion recenter");
}

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
    (void)visible;
}

void SpaghettiPad_SetGameplayActive(int active) {
    (void)active;
}

void SpaghettiPad_PresentAlert(const char* title, const char* body) {
    os_log_error(ShellLog(), "engine alert: %{public}s — %{public}s",
                 title != nullptr ? title : "", body != nullptr ? body : "");
}
