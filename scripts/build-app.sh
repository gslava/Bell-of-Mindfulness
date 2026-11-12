#!/bin/bash
set -euo pipefail
umask 022
cd "$(dirname "$0")/.."
PROJECT_ROOT="$PWD"
export CLANG_MODULE_CACHE_PATH="$PROJECT_ROOT/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_ROOT/.build/ModuleCache"
BELL_ARCHITECTURES=("$(uname -m)")
if [ "$#" -gt 1 ]; then echo "Usage: bash scripts/build-app.sh [--native|--universal]" >&2; exit 2; fi
if [ "$#" -eq 1 ]; then
    case "$1" in
        --native) ;;
        --universal) BELL_ARCHITECTURES=(arm64 x86_64) ;;
        *) echo "Usage: bash scripts/build-app.sh [--native|--universal]" >&2; exit 2 ;;
    esac
fi
BELL_APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
bash scripts/check-release-tag.sh "${BELL_RELEASE_TAG:-v$BELL_APP_VERSION}"
mkdir -p "$CLANG_MODULE_CACHE_PATH" build
BELL_BINARIES=()
for BELL_ARCH in "${BELL_ARCHITECTURES[@]}"; do
    BELL_SWIFT_ARGS=(--disable-sandbox --scratch-path ".build/distribution-$BELL_ARCH" --cache-path "$PROJECT_ROOT/.build/cache" --config-path "$PROJECT_ROOT/.build/config" --security-path "$PROJECT_ROOT/.build/security" --manifest-cache local --triple "$BELL_ARCH-apple-macosx14.0" -c release --product BellOfMindfulness)
    swift build "${BELL_SWIFT_ARGS[@]}"
    BELL_BIN_DIR="$(swift build "${BELL_SWIFT_ARGS[@]}" --show-bin-path)"
    BELL_BINARIES+=("$BELL_BIN_DIR/BellOfMindfulness")
done
swift scripts/GenerateIcon.swift "$PROJECT_ROOT/build/AppIcon.iconset"
BELL_APP="$PROJECT_ROOT/build/Bell of Mindfulness.app"
BELL_STAGE="$PROJECT_ROOT/build/package-staging/Bell of Mindfulness.app"
# This fixed path contains generated staging output only.
rm -rf "$BELL_STAGE"
trap 'rm -rf "$BELL_STAGE"' EXIT
mkdir -p "$BELL_STAGE/Contents/MacOS" "$BELL_STAGE/Contents/Resources"
if [ "${#BELL_BINARIES[@]}" -eq 2 ]; then
    lipo -create "${BELL_BINARIES[@]}" -output "$BELL_STAGE/Contents/MacOS/BellOfMindfulness"
else
    cp "${BELL_BINARIES[0]}" "$BELL_STAGE/Contents/MacOS/BellOfMindfulness"
fi
chmod +x "$BELL_STAGE/Contents/MacOS/BellOfMindfulness"
cp Resources/Info.plist "$BELL_STAGE/Contents/Info.plist"
cp 'Resources/Audio/Bell of Mindfulness.mp3' LICENSE THIRD_PARTY_NOTICES.md "$BELL_STAGE/Contents/Resources/"
iconutil -c icns build/AppIcon.iconset -o "$BELL_STAGE/Contents/Resources/AppIcon.icns"
chmod 644 "$BELL_STAGE/Contents/Info.plist" "$BELL_STAGE/Contents/Resources/"*
plutil -lint "$BELL_STAGE/Contents/Info.plist"
codesign --force --sign - --options runtime "$BELL_STAGE"
codesign --verify --strict --all-architectures "$BELL_STAGE"
test "$("$BELL_STAGE/Contents/MacOS/BellOfMindfulness" --version)" = "v$BELL_APP_VERSION"
# Replace the generated bundle only after the staged build has passed validation.
rm -rf "$BELL_APP"
mv "$BELL_STAGE" "$BELL_APP"
echo "Built: $BELL_APP ($(lipo -archs "$BELL_APP/Contents/MacOS/BellOfMindfulness"), v$BELL_APP_VERSION)"
