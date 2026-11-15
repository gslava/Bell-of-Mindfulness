#!/usr/bin/env python3
"""Render a versioned Homebrew cask from a release manifest."""

import argparse
import json
from pathlib import Path
import re
import sys


def render(release):
    version = release["version"]
    if not isinstance(version, str) or not re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", version):
        raise ValueError("Invalid release version")
    repository = "gslava/Bell-of-Mindfulness"
    if release["repository"] != repository or release["tag"] != f"v{version}":
        raise ValueError("Unexpected release repository or tag")
    if sorted(release["architectures"]) != ["arm64", "x86_64"] or release["minimum_macos"] != "14.0":
        raise ValueError("Expected a Universal macOS 14+ release")
    archive = release["downloads"]["zip"]
    filename = f"Bell-of-Mindfulness-{version}-universal.zip"
    if archive["file"] != filename or archive["url"] != f"https://github.com/{repository}/releases/download/v{version}/{filename}":
        raise ValueError("Unexpected release archive URL or filename")
    checksum = archive["sha256"]
    if not isinstance(checksum, str) or not re.fullmatch(r"[0-9a-f]{64}", checksum):
        raise ValueError("Expected a SHA-256 checksum")
    return f'''cask "bell-of-mindfulness" do
  version "{version}"
  sha256 "{checksum}"

  url "https://github.com/{repository}/releases/download/v#{{version}}/Bell-of-Mindfulness-#{{version}}-universal.zip"
  name "Bell of Mindfulness"
  desc "Menu bar singing bowl reminder with adjustable intervals and quiet hours"
  homepage "https://github.com/{repository}"

  depends_on macos: :sonoma

  app "Bell of Mindfulness.app"

  uninstall quit: "com.gslava.BellOfMindfulness"

  caveats <<~EOS
    The app is ad-hoc signed and not notarized by Apple.
    macOS may require approval in System Settings > Privacy & Security on first launch.
    Quit Bell of Mindfulness before upgrading, then reopen it from Applications.
  EOS
end
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--check", action="store_true", help="Verify an existing cask without changing it")
    args = parser.parse_args()
    try:
        content = render(json.loads(args.manifest.read_text()))
        if args.check:
            if args.output.read_text() != content:
                raise ValueError("Cask does not match the release manifest")
        else:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(content)
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"Homebrew cask: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
