# Development and releases

Requires macOS 14+, Swift 6+, and Apple’s Command Line Tools or Xcode. Open `Package.swift` in Xcode or run from the project root:

```sh
bash scripts/check.sh
bash scripts/build-app.sh
open 'build/Bell of Mindfulness.app'
```

Use `--universal` with the build script for Apple Silicon and Intel. `--no-ui` on the check script skips the native window check in hosted CI. Render fixtures with the bundled executable’s `--render-previews "$PWD/build/previews"` option.

## Versioning

Edit `CFBundleShortVersionString` and increment `CFBundleVersion` in `Resources/Info.plist` before a new release. The UI and `--version` read the same bundled version and display it with a `v` prefix.

The tag must match exactly. For the version currently in the plist:

```sh
bash scripts/check-release-tag.sh v1.0.1
bash scripts/package-release.sh
```

The packaging script creates a verified Universal ZIP and DMG with SHA-256 files and a versioned release manifest in `dist/`. `bash scripts/verify-release.sh` rechecks existing artifacts without rebuilding them. Bundles are ad-hoc signed, not Developer ID signed or notarized.

## GitHub

Run `bash scripts/setup-git.sh` after cloning. All commits must have both author and committer `gslava <itic1gm@gmail.com>`; the local commit guard and CI history audit enforce this.

Target repository: `gslava/Bell-of-Mindfulness`. CI checks pushes to `main` and pull requests. A pushed matching `vX.Y.Z` tag starts the release workflow; malformed or mismatching tags fail before publication. The workflow can also be run manually for an existing tag.

Once versioned changes have been committed and publication is intended, create and push that exact tag. The workflow checks the tagged source, runs tests, builds and verifies artifacts, then publishes them with release notes. It fails if a release already exists rather than replace its assets.

Keep `.github/RELEASE_NOTES.md` current before tagging. Actual audio output, login startup, and Gatekeeper approval after a browser download require manual checks on the target Mac; local checks do not exercise them.
