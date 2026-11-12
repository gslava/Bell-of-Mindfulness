#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "$#" -ne 2 ] || [[ "$2" != *.dmg ]]; then
    echo "Usage: bash scripts/create-dmg.sh <app-directory> <output.dmg>" >&2
    exit 2
fi
BELL_DMG_APP="$(cd "$1" && pwd)"
BELL_DMG_OUTPUT="$2"
BELL_DMG_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$BELL_DMG_APP/Contents/Info.plist")"
codesign --verify --strict --all-architectures "$BELL_DMG_APP"
mkdir -p build "$(dirname "$BELL_DMG_OUTPUT")"
BELL_DMG_STAGE="$(mktemp -d "$PWD/build/dmg-staging.XXXXXX")"
trap 'rm -rf "$BELL_DMG_STAGE"' EXIT
ditto "$BELL_DMG_APP" "$BELL_DMG_STAGE/Bell of Mindfulness.app"
ln -s /Applications "$BELL_DMG_STAGE/Applications"
cat > "$BELL_DMG_STAGE/Read Me.txt" <<'TEXT'
Install Bell of Mindfulness

Drag Bell of Mindfulness.app to Applications, then eject this disk image.

This app is ad-hoc signed and not notarized by Apple. If macOS blocks it,
dismiss the alert. If you trust the download, open System Settings >
Privacy & Security > Open Anyway, then confirm Open.
https://support.apple.com/en-us/102445

Click the bowl in the menu bar for controls. Closing Settings keeps the app
running; the menu's power button quits it. Launch at login is optional.
TEXT
hdiutil create -volname "Bell of Mindfulness $BELL_DMG_VERSION" -srcfolder "$BELL_DMG_STAGE" -fs HFS+ -format UDZO -ov "$BELL_DMG_OUTPUT"
hdiutil verify "$BELL_DMG_OUTPUT"
echo "Created: $BELL_DMG_OUTPUT"
