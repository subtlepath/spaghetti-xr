#!/usr/bin/env bash
# Configure the maintained SpaghettiKart visionOS application project.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="$ROOT/sources/spaghettikart"
PORT_ARCHIVE="${SPAGHETTIPAD_PORT_ARCHIVE:-$ROOT/build-oracle/spaghetti.o2r}"
MODE="device"

fail() {
    echo "visionOS configure failed: $*" >&2
    exit 1
}

if [ "${1:-}" = "--simulator" ]; then
    MODE="simulator"
    shift
fi
[ "$#" -eq 0 ] || fail "unexpected argument: $1"

for command in cmake git xcrun; do
    command -v "$command" >/dev/null ||
        fail "required command is unavailable: $command"
done

# CMake gained native visionOS support in 3.28. The leetal/ios-cmake toolchain
# used by the retired iOS lane is deliberately NOT used here: it sets IOS=ON for
# every non-Mac platform, which poisons if(IOS ...) throughout SpaghettiKart,
# libultraship, and SDL2.
CMAKE_VERSION="$(cmake --version | head -1 | awk '{print $3}')"
CMAKE_MAJOR="${CMAKE_VERSION%%.*}"
CMAKE_MINOR="$(echo "$CMAKE_VERSION" | cut -d. -f2)"
if [ "$CMAKE_MAJOR" -lt 3 ] ||
    { [ "$CMAKE_MAJOR" -eq 3 ] && [ "$CMAKE_MINOR" -lt 28 ]; }; then
    fail "cmake 3.28 or newer is required for visionOS (found $CMAKE_VERSION)"
fi

xcrun --sdk xros --show-sdk-path >/dev/null 2>&1 ||
    fail "the visionOS SDK is unavailable; install an Xcode with visionOS support"

# Host package managers must never satisfy a cross-compile. libultraship's
# dependency CMake is written as `find_package(X QUIET)` with a FetchContent
# fallback, so any host install of spdlog/fmt/SDL2 that CMake can see will be
# linked into a visionOS build instead of being fetched and cross-built.
#
# The retired iOS lane got this protection for free from leetal/ios-cmake, which
# set CMAKE_FIND_ROOT_PATH_MODE_*. This lane deliberately does not use that
# toolchain (it sets IOS=ON for visionOS), so the modes are set explicitly here.
IGNORE_PREFIXES=""
if [ -n "${CONDA_PREFIX:-}" ]; then
    echo "warning: an active conda environment is on CMake's search path" >&2
    echo "         ($CONDA_PREFIX) and will be ignored for this configure." >&2
    IGNORE_PREFIXES="$CONDA_PREFIX"
fi

SPAGHETTIPAD_VERSION="${SPAGHETTIPAD_VERSION:-0.2.0}"
SPAGHETTIPAD_BUILD_NUMBER="${SPAGHETTIPAD_BUILD_NUMBER:-1}"
[[ "$SPAGHETTIPAD_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
    fail "SPAGHETTIPAD_VERSION must use numeric major.minor.patch form"
[[ "$SPAGHETTIPAD_BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] ||
    fail "SPAGHETTIPAD_BUILD_NUMBER must be a positive integer"

[ -d "$SOURCE_DIR/.git" ] ||
    fail "pinned sources are missing; run scripts/clone-sources.sh first"
[ -s "$PORT_ARCHIVE" ] ||
    fail "clean port archive is missing; run scripts/build-oracle.sh first"

"$ROOT/scripts/apply-patches.sh" --lane visionos

if [ "$MODE" = "simulator" ]; then
    BUILD_DIR="${SPAGHETTIPAD_SIM_BUILD_DIR:-$ROOT/build-visionos-sim}"
    SDK="xrsimulator"
else
    BUILD_DIR="${SPAGHETTIPAD_VISIONOS_BUILD_DIR:-$ROOT/build-visionos}"
    SDK="xros"
fi

# The find-root has to be the SDK actually being built against, or a simulator
# configure would resolve device libraries.
SDK_PATH="$(xcrun --sdk "$SDK" --show-sdk-path 2>/dev/null)" ||
    fail "the $SDK SDK is unavailable"

# CMAKE_TRY_COMPILE_TARGET_TYPE is deliberately left at its default. The retired
# iOS lane inherited STATIC_LIBRARY from leetal/ios-cmake, which turns every
# link-based feature probe into a compile-only one: CheckFunctionExists declares
# the function itself, so with no link step check_function_exists() reports
# every symbol as present. That silently mis-detects Annex K in libzip
# (HAVE_MEMCPY_S), among others. Linking a real test executable works against
# both xros and xrsimulator, so the probes are allowed to be honest here.

# -GXcode is mandatory, not stylistic: CMake mixes Swift with C/C++/Objective-C++
# in a single target only under the Xcode generator, and the app target is
# Swift (@main, ImmersiveSpace) + Objective-C++ (shell) + C++ (engine).
cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" -GXcode \
    -DCMAKE_SYSTEM_NAME=visionOS \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=26.0 \
    -DCMAKE_OSX_SYSROOT="$SDK" \
    -DCMAKE_FIND_ROOT_PATH="$SDK_PATH" \
    -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=BOTH \
    -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
    -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
    -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
    -DCMAKE_IGNORE_PREFIX_PATH="$IGNORE_PREFIXES" \
    -DENABLE_SCRIPTING=OFF \
    -DSPAGHETTIPAD_SHELL_DIR="$ROOT/visionos" \
    -DSPAGHETTIPAD_PORT_ARCHIVE="$PORT_ARCHIVE" \
    -DSPAGHETTIPAD_VERSION="$SPAGHETTIPAD_VERSION" \
    -DSPAGHETTIPAD_BUILD_NUMBER="$SPAGHETTIPAD_BUILD_NUMBER" \
    -DBUNDLE_ID="${BUNDLE_ID:-com.subtlepath.spaghettipad}" \
    -DDEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}"

echo
echo "Configured $MODE project: $BUILD_DIR/Spaghettify.xcodeproj"
