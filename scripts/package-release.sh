#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
BELL_RELEASE_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
BELL_RELEASE_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Resources/Info.plist)"
BELL_TAG="${BELL_RELEASE_TAG:-v$BELL_RELEASE_VERSION}"
export BELL_REPOSITORY="${BELL_REPOSITORY:-gslava/Bell-of-Mindfulness}"
bash scripts/check-release-tag.sh "$BELL_TAG"
bash scripts/build-app.sh --universal
mkdir -p dist
BELL_STEM="Bell-of-Mindfulness-$BELL_RELEASE_VERSION-universal"
ditto -c -k --sequesterRsrc --keepParent 'build/Bell of Mindfulness.app' "dist/$BELL_STEM.zip"
bash scripts/create-dmg.sh 'build/Bell of Mindfulness.app' "$PWD/dist/$BELL_STEM.dmg"
(cd dist && shasum -a 256 "$BELL_STEM.zip" > "$BELL_STEM.zip.sha256" && shasum -a 256 "$BELL_STEM.dmg" > "$BELL_STEM.dmg.sha256")
python3 - "$BELL_RELEASE_VERSION" "$BELL_RELEASE_BUILD" "$BELL_STEM" <<'PY'
import hashlib
import json
import os
import pathlib
import re
import sys

version, build, stem = sys.argv[1:]
repository = os.environ["BELL_REPOSITORY"]
if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*", repository):
    raise SystemExit("BELL_REPOSITORY must be OWNER/REPO.")
downloads = {}
for extension in ("zip", "dmg"):
    name = f"{stem}.{extension}"
    path = pathlib.Path("dist", name)
    downloads[extension] = {
        "file": name,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "url": f"https://github.com/{repository}/releases/download/v{version}/{name}",
    }
manifest = dict(version=version, build=build, tag=f"v{version}", repository=repository,
                architectures=["arm64", "x86_64"], minimum_macos="14.0",
                signature="ad-hoc", notarized=False, downloads=downloads)
pathlib.Path("dist/release.json").write_text(json.dumps(manifest, indent=2) + "\n")
PY
bash scripts/verify-release.sh
echo "Prepared Universal ZIP and DMG in dist/. Nothing has been uploaded."
