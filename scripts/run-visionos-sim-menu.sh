#!/usr/bin/env bash
# Drive the settings menu on a visionOS Simulator with a controller and nothing else.
#
# This is the half of the settings gate that does not need a headset: whether the
# menu can be opened, navigated and closed by someone holding only a game
# controller. It is not an accessibility nicety on this platform — an immersive
# space has no keyboard for F1 or Escape and no pointer to click a menu bar, so a
# pad is the only input the settings UI has, and until now nothing fed one to
# ImGui at all.
#
# The pad is synthetic. No game controller can be attached to a Simulator, and
# SDL's virtual-joystick driver is unavailable in this lane (SDL declares it
# dependent on SDL_HIDAPI, which visionOS cannot compile), so the engine carries
# a Simulator-only scripted pad that merges into the same mapping, the same
# merge and the same ImGuiKey a real controller's buttons would. What that
# cannot prove is SDL reporting real hardware. See docs/remaining-work.md.
#
# The game archive is a required argument and is never stored in this
# repository: it is built from the person's own ROM by
# scripts/run-visionos-sim-extraction.sh, and it is placed here directly because
# the file picker is the one step a script cannot drive and is not under test.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${SPAGHETTIPAD_SIM_APP:-$ROOT/build-visionos-sim/Release-xrsimulator/SpaghettiPad.app}"
DEVICE="${SPAGHETTIPAD_SIM_DEVICE:-}"
ARCHIVE_SOURCE=""
OUT_DIR="${SPAGHETTIPAD_MENU_OUT:-$ROOT/build-visionos-sim/menu-evidence}"

# Every page the menu has, as registered by PortMenu::AddSidebarEntry. Kept here
# rather than discovered, so that a page added upstream makes this run report a
# shortfall instead of quietly walking twelve of thirteen and calling it every.
EXPECTED_PAGES=(
    "Settings / General" "Settings / Audio" "Settings / Graphics" "Settings / Controls"
    "Enhancements / General" "Enhancements / Cheats" "Enhancements / Freecam" "Enhancements / Rulesets"
    "Developer / General" "Developer / Gfx Debugger" "Developer / Stats" "Developer / Console"
    "Developer / Scene Visibility"
)
TAB_SECTION_COUNTS=(4 4 5) # Settings, Enhancements, Developer

# Milliseconds from the engine's first frame. The engine has to reach a title
# screen before a menu means anything, and on this Simulator that has been taking
# well under a minute, so the first press waits 45 s.
STEP_AT=45000
PAD_STEPS=()
step() {
    PAD_STEPS+=("${STEP_AT}:$1")
    STEP_AT=$((STEP_AT + 1500))
}

# The shape of the walk, which is ImGui's and not this menu's invention: a child
# window is entered with A and left with B, and the d-pad moves within whichever
# scope you are in. Directions alone go nowhere, which is why an earlier version
# of this script pressed only the d-pad and reported one page for twenty seconds.
#
# One press is spent before any of that: the first directional press only makes
# navigation visible and puts focus somewhere. And the first item inside the menu
# block is the close button, so the walk steps right off it before ever pressing
# A — pressing A there shuts the menu, which is how that ordering was found.
step back      # open the menu
step dpaddown  # nav becomes visible, focus lands on the menu block
step a         # enter the menu block; focus is the close button
for tab in 0 1 2; do
    step dpadright # off the close button, onto the header tabs
    # Entering the header focuses the tab that is *currently selected*, not the
    # leftmost one, so each pass steps right exactly once from wherever the last
    # pass left it. Stepping right `tab` times instead walks off the end of the
    # row on the third pass and presses A on whatever is past it.
    step a
    if [ "$tab" -gt 0 ]; then
        step dpadright
    fi
    step a        # select this tab
    step b        # back up to the menu block
    step dpaddown # onto the sidebar
    step a        # enter it; focus is the first section
    for ((i = 0; i < ${TAB_SECTION_COUNTS[$tab]}; i++)); do
        step a # select this section, which is what changes the page
        step dpaddown
    done
    step b      # back up to the menu block
    step dpadup # onto the close-button row, ready to step right again
done
step back # close the menu
CLOSE_AT="$((STEP_AT - 1500))"

DEFAULT_SCRIPT="$(
    IFS=,
    echo "${PAD_STEPS[*]}"
)"
PAD_SCRIPT="${SPAGHETTIPAD_SCRIPTED_PAD:-$DEFAULT_SCRIPT}"

fail() {
    echo "Simulator menu run failed: $*" >&2
    exit 1
}

usage() {
    echo "Usage: scripts/run-visionos-sim-menu.sh --archive <mk64.o2r>" \
        "[--device <udid>]" >&2
    exit 2
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --archive)
            [ "$#" -ge 2 ] || usage
            ARCHIVE_SOURCE="$2"
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

[ -n "$ARCHIVE_SOURCE" ] || usage
[ -s "$ARCHIVE_SOURCE" ] || fail "no game archive at $ARCHIVE_SOURCE"
[ -d "$APP" ] ||
    fail "no Simulator app at $APP; run scripts/build-visionos.sh --simulator"

for command in rg xcrun; do
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

# Uninstalling removes the data container outright, so no imgui.ini and no saved
# console variable from a previous run can decide which page this one opens on.
echo "==> Clean install of $BUNDLE_ID"
xcrun simctl uninstall "$DEVICE" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$DEVICE" "$APP"

CONTAINER="$(xcrun simctl get_app_container "$DEVICE" "$BUNDLE_ID" data)"
DOCUMENTS="$CONTAINER/Documents"
mkdir -p "$DOCUMENTS"
cp "$ARCHIVE_SOURCE" "$DOCUMENTS/mk64.o2r"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

echo "==> Pad script: $PAD_SCRIPT"
echo "==> Launching into the immersive space"
LAUNCH_OUTPUT="$(SIMCTL_CHILD_SPAGHETTIPAD_AUTO_OPEN_IMMERSIVE_SPACE=1 \
    SIMCTL_CHILD_SPAGHETTIPAD_SCRIPTED_PAD="$PAD_SCRIPT" \
    xcrun simctl launch "$DEVICE" "$BUNDLE_ID")"
PID="$(rg -o '[0-9]+$' <<<"$LAUNCH_OUTPUT" || true)"
echo "    $LAUNCH_OUTPUT"

# Run for the length of the script plus a settling margin, screenshotting on the
# way. A headset cannot be screenshotted at all, so these are the only pictures
# this gate will ever produce and they are worth taking often.
DEADLINE=$(( (CLOSE_AT / 1000) + 12 ))
STARTED="$(date +%s)"
SHOT=0
while :; do
    ELAPSED="$(( $(date +%s) - STARTED ))"
    [ "$ELAPSED" -lt "$DEADLINE" ] || break
    if [ -n "$PID" ] && ! kill -0 "$PID" 2>/dev/null; then
        fail "the app exited after ${ELAPSED}s; see $DOCUMENTS/logs/"
    fi
    if [ "$ELAPSED" -ge 44 ]; then
        SHOT=$((SHOT + 1))
        xcrun simctl io "$DEVICE" screenshot \
            "$(printf '%s/%02d-t%03ds.png' "$OUT_DIR" "$SHOT" "$ELAPSED")" \
            >/dev/null 2>&1 || true
    fi
    sleep 3
done

LOG_DIR="$DOCUMENTS/logs"
ENGINE_LOG="$(find "$LOG_DIR" -type f -name '*.log' 2>/dev/null | head -1 || true)"
[ -n "$ENGINE_LOG" ] || fail "no engine log under $LOG_DIR"
cp "$ENGINE_LOG" "$OUT_DIR/engine.log"

# What the run has to have produced. Each of these is a separate claim and a
# missing one is a different failure, so they are reported rather than summed.
PRESSES="$(rg -c '\[scripted-pad\] ' "$OUT_DIR/engine.log" || echo 0)"
PAGES="$(rg -o '\[menu\] page (.+)$' -r '$1' "$OUT_DIR/engine.log" | awk '!seen[$0]++' || true)"
PAGE_COUNT="$(printf '%s' "$PAGES" | rg -c '' || echo 0)"

MISSED=()
for page in "${EXPECTED_PAGES[@]}"; do
    printf '%s\n' "$PAGES" | rg -qxF "$page" || MISSED+=("$page")
done

echo
echo "Simulator menu run finished:"
echo "  simulator        $DEVICE"
echo "  app              $APP"
echo "  screenshots      $SHOT in $OUT_DIR"
echo "  scripted presses $PRESSES"
echo "  pages reached    $PAGE_COUNT of ${#EXPECTED_PAGES[@]}"
if [ -n "$PAGES" ]; then
    printf '%s\n' "$PAGES" | sed 's/^/                   /'
fi
if [ "${#MISSED[@]}" -gt 0 ]; then
    echo "  NOT reached      ${#MISSED[@]}"
    printf '%s\n' "${MISSED[@]}" | sed 's/^/                   /'
fi
echo "  engine log       $OUT_DIR/engine.log"
echo
echo "Shell log (menu open/close) is os_log only; read it with:"
echo "  xcrun simctl spawn $DEVICE log show --last 10m \\"
echo "    --predicate 'subsystem == \"com.subtlepath.spaghettipad\"' --info"

[ "$PRESSES" -gt 0 ] ||
    fail "the scripted pad never reported a press; nothing was driven"
[ "$PAGE_COUNT" -gt 0 ] ||
    fail "no settings page was ever drawn; the menu did not open"
[ "${#MISSED[@]}" -eq 0 ] ||
    fail "${#MISSED[@]} page(s) were never reached; the walk is incomplete"
