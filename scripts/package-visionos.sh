#!/usr/bin/env bash
# Audit a visionOS device app and wrap it as a ROM-free artifact.
#
# visionOS ships in the same Payload/ container iOS does, so this is the iOS
# packager's contract on a different bundle — with one addition the iPadOS lane
# never needed. This lane's active toolchain is a beta Xcode, and the project
# forbids publishing a release artifact from one without saying so. A record of
# what built the artifact therefore travels inside the artifact, where it cannot
# drift from it, rather than being remembered at release time.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$ROOT/build-visionos/Release-xros/SpaghettiPad.app}"

if [[ "$APP" != /* ]]; then
    APP="$ROOT/$APP"
fi

REQUIRE_SIGNED="${REQUIRE_SIGNED:-0}"
case "$REQUIRE_SIGNED" in
    0)
        REQUIRE_UNSIGNED=1
        ;;
    1)
        REQUIRE_UNSIGNED=0
        ;;
    *)
        echo "REQUIRE_SIGNED must be 0 or 1." >&2
        exit 2
        ;;
esac

REQUIRE_SIGNED="$REQUIRE_SIGNED" REQUIRE_UNSIGNED="$REQUIRE_UNSIGNED" \
    "$ROOT/scripts/audit-visionos-app.sh" "$APP"

INFO="$APP/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO")"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO")"
MINIMUM_OS="$(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$INFO")"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
   [[ ! "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
    echo "Refusing app with invalid release version: $VERSION ($BUILD_NUMBER)" >&2
    exit 1
fi

# The toolchain that built the app. Recorded rather than judged: this script
# cannot tell a beta Xcode from a released one, and guessing wrong in either
# direction is worse than stating the build exactly. Set
# SPAGHETTIPAD_EXPECTED_XCODE_BUILD to make a specific toolchain a hard gate.
XCODE_VERSION="$(xcodebuild -version 2>/dev/null | head -1 || true)"
XCODE_BUILD="$(xcodebuild -version 2>/dev/null | sed -n 's/^Build version //p' || true)"
SDK_VERSION="$(xcrun --sdk xros --show-sdk-version 2>/dev/null || true)"
SDK_BUILD="$(xcrun --sdk xros --show-sdk-build-version 2>/dev/null || true)"
[ -n "$XCODE_VERSION" ] && [ -n "$XCODE_BUILD" ] && [ -n "$SDK_VERSION" ] || {
    echo "Could not read the Xcode and visionOS SDK versions." >&2
    exit 1
}
if [ -n "${SPAGHETTIPAD_EXPECTED_XCODE_BUILD:-}" ] &&
   [ "$SPAGHETTIPAD_EXPECTED_XCODE_BUILD" != "$XCODE_BUILD" ]; then
    echo "Refusing to package: expected Xcode build" \
        "$SPAGHETTIPAD_EXPECTED_XCODE_BUILD, found $XCODE_BUILD." >&2
    exit 1
fi

SPAGHETTIKART_REV="$(git -C "$ROOT/sources/spaghettikart" rev-parse HEAD)"
LUS_REV="$(git -C "$ROOT/sources/spaghettikart/libultraship" rev-parse HEAD)"
PROJECT_REV="$(git -C "$ROOT" rev-parse HEAD)"
# Untracked files count as dirty: the scripts and shell sources that produce
# this app are only tracked once committed, and "clean" has to mean the revision
# above reproduces the artifact.
PROJECT_DIRTY="clean"
[ -z "$(git -C "$ROOT" status --porcelain)" ] || PROJECT_DIRTY="dirty"

BINARY_SHA256="$(shasum -a 256 "$APP/SpaghettiPad" | awk '{print $1}')"
PORT_ARCHIVE_SHA256="$("$ROOT/scripts/hash-port-archive.sh" "$APP/spaghetti.o2r")"

SIGNATURE_STATE="unsigned"
if codesign --verify --strict "$APP" >/dev/null 2>&1 &&
   [ -f "$APP/embedded.mobileprovision" ]; then
    SIGNATURE_STATE="signed"
fi

OUTPUT="${2:-$ROOT/artifacts/SpaghettiPad-visionOS-${VERSION}-preview.${BUILD_NUMBER}-${SIGNATURE_STATE}.ipa}"
if [[ "$OUTPUT" != /* ]]; then
    OUTPUT="$ROOT/$OUTPUT"
fi

[ -f "$ROOT/RIGHTS_AND_LICENSES.md" ] || {
    echo "Required rights and licensing notice is missing." >&2
    exit 1
}
[ -f "$ROOT/THIRD_PARTY_NOTICES/SDL_GameControllerDB.LICENSE" ] || {
    echo "SDL_GameControllerDB license notice is missing." >&2
    exit 1
}

mkdir -p "$(dirname "$OUTPUT")"
PACKAGE_ROOT="$(mktemp -d /tmp/spaghettipad-visionos-package.XXXXXX)"
trap 'rm -rf "$PACKAGE_ROOT"' EXIT
mkdir "$PACKAGE_ROOT/Payload"
ditto "$APP" "$PACKAGE_ROOT/Payload/SpaghettiPad.app"
cp "$ROOT/RIGHTS_AND_LICENSES.md" "$PACKAGE_ROOT/RIGHTS_AND_LICENSES.md"

cat >"$PACKAGE_ROOT/BUILD_PROVENANCE.txt" <<EOF
SpaghettiPad visionOS build provenance

application
  version               $VERSION ($BUILD_NUMBER)
  bundle identifier     $BUNDLE_ID
  minimum visionOS      $MINIMUM_OS
  signing               $SIGNATURE_STATE
  executable sha256     $BINARY_SHA256
  port archive content  $PORT_ARCHIVE_SHA256

toolchain
  $XCODE_VERSION
  Xcode build           $XCODE_BUILD
  visionOS SDK          $SDK_VERSION${SDK_BUILD:+ ($SDK_BUILD)}

sources
  spaghettipad          $PROJECT_REV ($PROJECT_DIRTY working tree)
  HarbourMasters/SpaghettiKart
                        $SPAGHETTIKART_REV
  Kenix3/libultraship   $LUS_REV

This artifact contains no ROM, no ROM-derived game data, and no texture pack.
A Mario Kart 64 (US) .z64 that the person running it legally owns has to be
imported on device before the game will start.

If this build is published, its release notes must state the Xcode build above.
EOF

LICENSES_DIR="$PACKAGE_ROOT/ThirdPartyLicenses"
mkdir "$LICENSES_DIR"
cp "$ROOT/THIRD_PARTY_NOTICES/SDL_GameControllerDB.LICENSE" \
    "$LICENSES_DIR/SDL_GameControllerDB.LICENSE"
LICENSE_COUNT=1
while IFS= read -r -d '' LICENSE_FILE; do
    RELATIVE="${LICENSE_FILE#"$ROOT/"}"
    DESTINATION="$LICENSES_DIR/$RELATIVE"
    mkdir -p "$(dirname "$DESTINATION")"
    cp "$LICENSE_FILE" "$DESTINATION"
    LICENSE_COUNT=$((LICENSE_COUNT + 1))
done < <(
    find "$ROOT/sources/spaghettikart" "$ROOT/build-visionos/_deps" -type f \
        \( -iname 'LICENSE*' -o -iname 'COPYING*' -o -iname 'NOTICE*' \) \
        -print0 | sort -z
)
[ "$LICENSE_COUNT" -gt 1 ] || {
    echo "No third-party license files were found for packaging." >&2
    exit 1
}

ditto -c -k --norsrc --keepParent "$PACKAGE_ROOT/Payload" "$OUTPUT"
(
    cd "$PACKAGE_ROOT"
    zip -q -r "$OUTPUT" RIGHTS_AND_LICENSES.md BUILD_PROVENANCE.txt \
        ThirdPartyLicenses
)

ENTRIES="$(unzip -Z1 "$OUTPUT")"
rg -q '^Payload/SpaghettiPad\.app/SpaghettiPad$' <<<"$ENTRIES" ||
    { echo "Payload verification failed: $OUTPUT" >&2; exit 1; }
rg -q '^Payload/SpaghettiPad\.app/spaghetti\.o2r$' <<<"$ENTRIES" ||
    { echo "Clean port archive is missing: $OUTPUT" >&2; exit 1; }
rg -q '^RIGHTS_AND_LICENSES\.md$' <<<"$ENTRIES" ||
    { echo "Rights notice is missing: $OUTPUT" >&2; exit 1; }
rg -q '^BUILD_PROVENANCE\.txt$' <<<"$ENTRIES" ||
    { echo "Build provenance is missing: $OUTPUT" >&2; exit 1; }
rg -q '^ThirdPartyLicenses/' <<<"$ENTRIES" ||
    { echo "Third-party licenses are missing: $OUTPUT" >&2; exit 1; }
rg -q '^ThirdPartyLicenses/SDL_GameControllerDB\.LICENSE$' <<<"$ENTRIES" ||
    { echo "Controller database license is missing: $OUTPUT" >&2; exit 1; }

if rg -qi '\.(z64|n64|v64|rom|otr)$' <<<"$ENTRIES"; then
    echo "Refusing artifact containing ROM or ROM-derived data: $OUTPUT" >&2
    exit 1
fi
# spaghetti.o2r is the clean port archive, audited by content hash above. Every
# other archive of that shape would be extracted game data or a texture pack, so
# the archives are enumerated and the list has to be exactly that one file — an
# allowlist rather than a pattern, because the pattern is what a new kind of
# ROM-derived archive would slip past.
UNEXPECTED_ARCHIVES="$(rg -i '\.o2r$' <<<"$ENTRIES" |
    rg -v '^Payload/SpaghettiPad\.app/spaghetti\.o2r$' || true)"
if [ -n "$UNEXPECTED_ARCHIVES" ]; then
    printf '%s\n' "$UNEXPECTED_ARCHIVES" >&2
    echo "Refusing artifact containing ROM or ROM-derived data: $OUTPUT" >&2
    exit 1
fi
if [ "$SIGNATURE_STATE" = "unsigned" ] &&
   rg -q 'Payload/SpaghettiPad\.app/(_CodeSignature/|embedded\.mobileprovision$)' \
      <<<"$ENTRIES"; then
    echo "Refusing unsigned artifact containing signing material: $OUTPUT" >&2
    exit 1
fi

echo
echo "Packaged $SIGNATURE_STATE SpaghettiPad visionOS $VERSION ($BUILD_NUMBER)"
echo "  bundle identifier   $BUNDLE_ID"
echo "  minimum visionOS    $MINIMUM_OS"
echo "  toolchain           $XCODE_VERSION ($XCODE_BUILD), visionOS SDK $SDK_VERSION"
echo "  third-party notices $LICENSE_COUNT"
echo "  artifact            $OUTPUT"
shasum -a 256 "$OUTPUT"
if [ "$SIGNATURE_STATE" = "unsigned" ]; then
    echo "This proof artifact must be re-signed before it will install on a headset."
fi
