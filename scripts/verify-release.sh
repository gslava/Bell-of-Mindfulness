#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "$#" -gt 1 ]; then
    echo "Usage: bash scripts/verify-release.sh [distribution-directory]" >&2
    exit 2
fi
BELL_DIST="$(cd "${1:-dist}" && pwd)"
BELL_EXPECTED_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
BELL_EXPECTED_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Resources/Info.plist)"
bash scripts/check-release-tag.sh "${BELL_RELEASE_TAG:-v$BELL_EXPECTED_VERSION}"
BELL_STEM="Bell-of-Mindfulness-$BELL_EXPECTED_VERSION-universal"
BELL_ZIP="$BELL_DIST/$BELL_STEM.zip"
BELL_DMG="$BELL_DIST/$BELL_STEM.dmg"
(cd "$BELL_DIST" && shasum -a 256 -c "$BELL_STEM.zip.sha256" && shasum -a 256 -c "$BELL_STEM.dmg.sha256")
hdiutil verify "$BELL_DMG"
mkdir -p build
BELL_VERIFY_DIR="$(mktemp -d "$PWD/build/release-verify.XXXXXX")"
BELL_MOUNT="$BELL_VERIFY_DIR/dmg"
BELL_MOUNTED=false
cleanup() {
    BELL_VERIFY_STATUS=$?
    if "$BELL_MOUNTED"; then
        if ! hdiutil detach "$BELL_MOUNT" -quiet; then
            echo "Could not eject $BELL_MOUNT; verification files retained." >&2
            return 1
        fi
    fi
    rm -rf "$BELL_VERIFY_DIR"
    return "$BELL_VERIFY_STATUS"
}
trap cleanup EXIT
ditto -x -k "$BELL_ZIP" "$BELL_VERIFY_DIR"
BELL_VERIFY_APP="$BELL_VERIFY_DIR/Bell of Mindfulness.app"
plutil -lint "$BELL_VERIFY_APP/Contents/Info.plist"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$BELL_VERIFY_APP/Contents/Info.plist")" = "$BELL_EXPECTED_VERSION"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$BELL_VERIFY_APP/Contents/Info.plist")" = "$BELL_EXPECTED_BUILD"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$BELL_VERIFY_APP/Contents/Info.plist")" = 'com.gslava.BellOfMindfulness'
test "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$BELL_VERIFY_APP/Contents/Info.plist")" = '14.0'
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$BELL_VERIFY_APP/Contents/Info.plist")" = 'AppIcon'
for BELL_RESOURCE in AppIcon.icns LICENSE THIRD_PARTY_NOTICES.md 'Bell of Mindfulness.mp3'; do
    test -s "$BELL_VERIFY_APP/Contents/Resources/$BELL_RESOURCE"
done
cmp 'Resources/Audio/Bell of Mindfulness.mp3' "$BELL_VERIFY_APP/Contents/Resources/Bell of Mindfulness.mp3"
cmp LICENSE "$BELL_VERIFY_APP/Contents/Resources/LICENSE"
cmp THIRD_PARTY_NOTICES.md "$BELL_VERIFY_APP/Contents/Resources/THIRD_PARTY_NOTICES.md"
lipo "$BELL_VERIFY_APP/Contents/MacOS/BellOfMindfulness" -verify_arch arm64 x86_64
codesign --verify --strict --all-architectures "$BELL_VERIFY_APP"
case "$(codesign -dv "$BELL_VERIFY_APP" 2>&1)" in
    *Signature=adhoc*) ;;
    *) echo "Expected the documented ad-hoc signature." >&2; exit 1 ;;
esac
test "$("$BELL_VERIFY_APP/Contents/MacOS/BellOfMindfulness" --version)" = "v$BELL_EXPECTED_VERSION"
mkdir "$BELL_MOUNT"
hdiutil attach "$BELL_DMG" -readonly -nobrowse -noautoopen -mountpoint "$BELL_MOUNT" -quiet
BELL_MOUNTED=true
test -L "$BELL_MOUNT/Applications"
test "$(readlink "$BELL_MOUNT/Applications")" = '/Applications'
test -s "$BELL_MOUNT/Read Me.txt"
codesign --verify --strict --all-architectures "$BELL_MOUNT/Bell of Mindfulness.app"
diff -qr "$BELL_VERIFY_APP" "$BELL_MOUNT/Bell of Mindfulness.app"
python3 - "$BELL_DIST" "$BELL_EXPECTED_VERSION" "$BELL_EXPECTED_BUILD" <<'PY'
import hashlib
import json
import os
import pathlib
import re
import sys

dist = pathlib.Path(sys.argv[1])
version, build = sys.argv[2:]
release = json.loads((dist / "release.json").read_text())
repository = os.environ.get("BELL_REPOSITORY", "gslava/Bell-of-Mindfulness")
assert re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*", repository)
assert release["repository"] == repository
assert release["version"] == version and release["build"] == build and release["tag"] == f"v{version}"
assert sorted(release["architectures"]) == ["arm64", "x86_64"]
assert release["minimum_macos"] == "14.0" and release["signature"] == "ad-hoc" and release["notarized"] is False
for extension in ("zip", "dmg"):
    name = f"Bell-of-Mindfulness-{version}-universal.{extension}"
    assert release["downloads"][extension] == {
        "file": name,
        "sha256": hashlib.sha256((dist / name).read_bytes()).hexdigest(),
        "url": f"https://github.com/{repository}/releases/download/v{version}/{name}",
    }
PY
echo "Verified ZIP/DMG checksums, matching Universal apps, bundle/UI version, audio, licenses, metadata and signatures."
