#!/usr/bin/env bash
# Exercise in-app ROM extraction on a clean visionOS Simulator container.
#
# This is the half of the ROM-import gate that does not need a headset: whether
# the engine, running inside this app, can turn a user's .z64 into the game
# archive it reads. Every Simulator result before this one was produced with an
# archive Torch had built on the host and copied in, which proves the engine can
# read an archive and says nothing about whether it can make one.
#
# The ROM is a required argument and is never stored in this repository. It is
# copied into the container directly, which is byte-for-byte what
# SpaghettiPad_ImportRom does once a person has picked a file — the file picker
# is the one step a script cannot drive, and it is not the step under test.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${SPAGHETTIPAD_SIM_APP:-$ROOT/build-visionos-sim/Release-xrsimulator/SpaghettiPad.app}"
DEVICE="${SPAGHETTIPAD_SIM_DEVICE:-}"
ROM=""
TIMEOUT_SECONDS="${SPAGHETTIPAD_EXTRACTION_TIMEOUT:-1800}"

fail() {
    echo "Simulator extraction run failed: $*" >&2
    exit 1
}

usage() {
    echo "Usage: scripts/run-visionos-sim-extraction.sh --rom <path.z64>" \
        "[--device <udid>]" >&2
    exit 2
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --rom)
            [ "$#" -ge 2 ] || usage
            ROM="$2"
            shift 2
            ;;
        --device)
            [ "$#" -ge 2 ] || usage
            DEVICE="$2"
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

[ -n "$ROM" ] || usage
[ -f "$ROM" ] || fail "no ROM at $ROM"
[ -d "$APP" ] ||
    fail "no Simulator app at $APP; run scripts/build-visionos.sh --simulator"

for command in plutil rg shasum xcrun; do
    command -v "$command" >/dev/null ||
        fail "required command is unavailable: $command"
done

# The newest available visionOS runtime unless one was named. simctl prints
# runtimes in ascending order, so the last match is the newest.
if [ -z "$DEVICE" ]; then
    DEVICE="$(xcrun simctl list devices available |
        rg -o 'Apple Vision Pro \(([0-9A-F-]{36})\)' -r '$1' | tail -1)"
    [ -n "$DEVICE" ] || fail "no visionOS Simulator is available"
fi

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \
    "$APP/Info.plist")"

echo "==> Simulator $DEVICE"
xcrun simctl bootstatus "$DEVICE" -b >/dev/null 2>&1 ||
    xcrun simctl boot "$DEVICE" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$DEVICE" -b >/dev/null ||
    fail "the Simulator did not finish booting"

# Uninstalling is what makes this a clean-container run: it removes the data
# container outright, so no archive, no config and no log from any previous run
# can be mistaken for this one's result.
echo "==> Clean install of $BUNDLE_ID"
xcrun simctl uninstall "$DEVICE" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$DEVICE" "$APP"

CONTAINER="$(xcrun simctl get_app_container "$DEVICE" "$BUNDLE_ID" data)"
DOCUMENTS="$CONTAINER/Documents"
mkdir -p "$DOCUMENTS"

EXISTING="$(find "$DOCUMENTS" -maxdepth 1 -type f | wc -l | tr -d ' ')"
[ "$EXISTING" = "0" ] ||
    fail "the container is not clean: $EXISTING file(s) already in Documents"

echo "==> Placing the ROM in the container (what the importer does)"
cp "$ROM" "$DOCUMENTS/$(basename "$ROM")"
ROM_SHA256="$(shasum -a 256 "$ROM" | awk '{print $1}')"

ARCHIVE="$DOCUMENTS/mk64.o2r"
[ ! -e "$ARCHIVE" ] || fail "a game archive already exists; this is not a first run"

echo "==> Launching with SPAGHETTIPAD_AUTO_EXTRACT=1"
STARTED="$(date +%s)"
LAUNCH_OUTPUT="$(SIMCTL_CHILD_SPAGHETTIPAD_AUTO_EXTRACT=1 \
    xcrun simctl launch "$DEVICE" "$BUNDLE_ID")"
PID="$(rg -o '[0-9]+$' <<<"$LAUNCH_OUTPUT" || true)"
echo "    $LAUNCH_OUTPUT"

PEAK_RSS_KB=0
ELAPSED=0
while [ "$ELAPSED" -lt "$TIMEOUT_SECONDS" ]; do
    if [ -s "$ARCHIVE" ]; then
        break
    fi
    if [ -n "$PID" ] && ! kill -0 "$PID" 2>/dev/null; then
        fail "the app exited after ${ELAPSED}s without producing an archive; see
    $DOCUMENTS/logs/"
    fi
    if [ -n "$PID" ]; then
        RSS_KB="$(ps -o rss= -p "$PID" 2>/dev/null | tr -d ' ' || true)"
        if [ -n "$RSS_KB" ] && [ "$RSS_KB" -gt "$PEAK_RSS_KB" ]; then
            PEAK_RSS_KB="$RSS_KB"
        fi
    fi
    sleep 2
    ELAPSED="$(( $(date +%s) - STARTED ))"
done

[ -s "$ARCHIVE" ] ||
    fail "no archive after ${ELAPSED}s (timeout ${TIMEOUT_SECONDS}s)"

# The archive is written before it is finished; wait for its size to settle so
# the entry count below describes a complete file.
SETTLED=""
while :; do
    SIZE="$(wc -c < "$ARCHIVE" | tr -d ' ')"
    sleep 3
    [ "$SIZE" = "$(wc -c < "$ARCHIVE" | tr -d ' ')" ] && break
    SETTLED="still growing"
done
ELAPSED="$(( $(date +%s) - STARTED ))"

ARCHIVE_LISTING="$(unzip -Z1 "$ARCHIVE")"
ARCHIVE_ENTRIES="$(wc -l <<<"$ARCHIVE_LISTING" | tr -d ' ')"

# The archive is ROM-derived by definition — that is what it is for. What must
# not be inside it is the ROM itself, which would make a container backup a
# redistribution.
if rg -qi '\.(z64|n64|v64|rom)$' <<<"$ARCHIVE_LISTING"; then
    fail "the extracted archive contains a ROM image"
fi

# Plain file hash, not scripts/hash-port-archive.sh. That script exists to
# compare the *clean port archive* across machines with ZIP timestamps ignored,
# and it costs two processes per entry — tolerable for the 2.7 MB port archive
# and not for 32,000 game entries. Nothing here is reproducible across hosts
# anyway: this archive is built from the person's own ROM.
ARCHIVE_SHA256="$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')"

echo
echo "In-app extraction succeeded:"
echo "  simulator        $DEVICE"
echo "  container        $DOCUMENTS"
echo "  ROM sha256       $ROM_SHA256"
echo "  elapsed          ${ELAPSED}s ${SETTLED}"
echo "  peak RSS         $((PEAK_RSS_KB / 1024)) MiB"
echo "  archive          $(wc -c < "$ARCHIVE" | tr -d ' ') bytes, $ARCHIVE_ENTRIES entries"
echo "  archive sha256   $ARCHIVE_SHA256"
echo "  no ROM image inside the archive"
echo
echo "Engine log: $DOCUMENTS/logs/"
