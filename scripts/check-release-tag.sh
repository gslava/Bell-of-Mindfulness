#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
BELL_VERSION_PATTERN='(0|[1-9][0-9]*)'
if [ "$#" -ne 1 ] || ! [[ "$1" =~ ^v$BELL_VERSION_PATTERN\.$BELL_VERSION_PATTERN\.$BELL_VERSION_PATTERN$ ]]; then
    echo "Expected one release tag: v<major>.<minor>.<patch> (no leading zeroes)." >&2
    exit 2
fi
BELL_APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
BELL_BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Resources/Info.plist)"
if [ "$1" != "v$BELL_APP_VERSION" ]; then
    echo "Tag $1 does not match app version $BELL_APP_VERSION in Resources/Info.plist." >&2
    exit 1
fi
if ! [[ "$BELL_BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
    echo "CFBundleVersion must be a positive integer." >&2
    exit 1
fi
echo "Release tag $1 matches app version $BELL_APP_VERSION (build $BELL_BUILD_NUMBER)."
