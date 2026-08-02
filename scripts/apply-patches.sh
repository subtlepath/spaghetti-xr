#!/usr/bin/env bash
# Apply one maintained patch lane to the pinned upstream checkouts.
#
# A lane is an ordered list of patches. Order is significant: later patches in a
# lane are written against the tree the earlier ones produce. Only one lane may
# be applied to a checkout at a time.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SPAGHETTIKART_DIR="$ROOT/sources/spaghettikart"
LUS_DIR="$ROOT/sources/spaghettikart/libultraship"
PATCH_DIR="$ROOT/patches"
EXPECTED_SPAGHETTIKART="5b28472d477bab101dee2a0f469fe2aee2c58a01"
EXPECTED_LUS="f5c3843fe937320b64ff754fa6bf71b13ff5e7a1"

# Ordered patch lists. Each entry is "<tree>:<patch file>", where <tree> is
# either "lus" (libultraship) or "sk" (SpaghettiKart).
IOS_LANE=(
    "lus:libultraship-ios.patch"
    "lus:libultraship-ios-touch.patch"
    "lus:libultraship-ios-controller-ports.patch"
    "sk:spaghettikart-ios.patch"
    "sk:spaghettikart-ios-firstrun.patch"
    "sk:spaghettikart-ios-touch.patch"
    "sk:spaghettikart-ios-ux.patch"
    "sk:spaghettikart-ios-tilt.patch"
    "sk:spaghettikart-ios-texture-packs.patch"
    "sk:spaghettikart-ios-custom-touch.patch"
)

VISIONOS_LANE=(
    "lus:libultraship-visionos.patch"
    "sk:spaghettikart-visionos.patch"
)

fail() {
    echo "Patch application failed: $*" >&2
    exit 1
}

usage() {
    echo "Usage: scripts/apply-patches.sh [--lane ios|visionos]" >&2
    exit 2
}

LANE="${SPAGHETTIPAD_LANE:-ios}"
while [ "$#" -gt 0 ]; do
    case "$1" in
        --lane)
            [ "$#" -ge 2 ] || usage
            LANE="$2"
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

case "$LANE" in
    ios)
        LANE_PATCHES=("${IOS_LANE[@]}")
        ;;
    visionos)
        LANE_PATCHES=("${VISIONOS_LANE[@]}")
        ;;
    *)
        fail "unknown lane: $LANE (expected ios or visionos)"
        ;;
esac

[ -e "$SPAGHETTIKART_DIR/.git" ] ||
    fail "pinned sources are missing; run scripts/clone-sources.sh first"
[ -e "$LUS_DIR/.git" ] ||
    fail "pinned sources are missing; run scripts/clone-sources.sh first"
[ "$(git -C "$SPAGHETTIKART_DIR" rev-parse HEAD)" = \
    "$EXPECTED_SPAGHETTIKART" ] ||
    fail "SpaghettiKart is not at the planned revision"
[ "$(git -C "$LUS_DIR" rev-parse HEAD)" = "$EXPECTED_LUS" ] ||
    fail "libultraship is not at the planned revision"
git -C "$SPAGHETTIKART_DIR" diff --cached --quiet ||
    fail "SpaghettiKart has staged files"
git -C "$LUS_DIR" diff --cached --quiet ||
    fail "libultraship has staged files"

tree_dir() {
    case "$1" in
        lus) echo "$LUS_DIR" ;;
        sk) echo "$SPAGHETTIKART_DIR" ;;
        *) fail "unknown tree: $1" ;;
    esac
}

# Reset guidance for a tree that carries something other than this lane. Both
# checkouts are disposable by design, so discarding them is always safe.
reset_hint() {
    cat >&2 <<EOF

The checkout carries changes this lane does not own — most often the other
lane's patches. Both source trees are disposable; reset them with:

  git -C sources/spaghettikart/libultraship checkout -- .
  git -C sources/spaghettikart checkout -- . ':(exclude)libultraship'

then re-run this script.
EOF
}

# Fails when a tree holds edits this lane did not make. Only meaningful before
# the lane's first patch goes on.
assert_pristine() {
    case "$1" in
        lus)
            git -C "$LUS_DIR" diff --quiet ||
                { echo "Patch application failed: libultraship has modified tracked files" >&2
                  reset_hint; exit 1; }
            ;;
        sk)
            git -C "$SPAGHETTIKART_DIR" diff --quiet -- . \
                ':(exclude)libultraship' ||
                { echo "Patch application failed: SpaghettiKart has modified tracked files" >&2
                  reset_hint; exit 1; }
            ;;
    esac
}

# Applies one tree's ordered sub-list. Patches within a tree stack, so an
# earlier patch stops reverse-checking as soon as a later one rewrites its
# context: the LAST patch that still reverse-checks marks the applied prefix.
apply_tree_lane() {
    local tree="$1"
    shift
    local patches
    patches=("$@")
    [ "${#patches[@]}" -gt 0 ] || return 0

    local dir
    dir="$(tree_dir "$tree")"

    local name
    for name in "${patches[@]}"; do
        [ -f "$PATCH_DIR/$name" ] ||
            fail "maintained patch is missing: $PATCH_DIR/$name"
    done

    local start=0 i
    for ((i = ${#patches[@]} - 1; i >= 0; i--)); do
        if git -C "$dir" apply --reverse --check \
            "$PATCH_DIR/${patches[$i]}" 2>/dev/null; then
            start=$((i + 1))
            break
        fi
    done

    if [ "$start" -eq 0 ]; then
        assert_pristine "$tree"
    else
        for ((i = 0; i < start; i++)); do
            echo "Already applied: ${patches[$i]}"
        done
    fi

    for ((i = start; i < ${#patches[@]}; i++)); do
        name="${patches[$i]}"
        if ! git -C "$dir" apply --check "$PATCH_DIR/$name" 2>/dev/null; then
            echo "Patch application failed: $name does not apply cleanly" >&2
            reset_hint
            exit 1
        fi
        git -C "$dir" apply "$PATCH_DIR/$name"
        git -C "$dir" apply --reverse --check "$PATCH_DIR/$name" ||
            fail "$name does not pass its reverse check after application"
        echo "Applied: $name"
    done
}

# Split the lane into per-tree sub-lists, preserving order within each tree.
LUS_LANE_PATCHES=()
SK_LANE_PATCHES=()
for entry in "${LANE_PATCHES[@]}"; do
    case "${entry%%:*}" in
        lus) LUS_LANE_PATCHES+=("${entry#*:}") ;;
        sk) SK_LANE_PATCHES+=("${entry#*:}") ;;
        *) fail "unknown tree in lane entry: $entry" ;;
    esac
done

echo "Patch lane: $LANE"
# libultraship first: SpaghettiKart's CMake pulls it in as a subdirectory.
apply_tree_lane lus ${LUS_LANE_PATCHES[@]+"${LUS_LANE_PATCHES[@]}"}
apply_tree_lane sk ${SK_LANE_PATCHES[@]+"${SK_LANE_PATCHES[@]}"}
