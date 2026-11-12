# Project instructions

## Clarification

Ask any necessary questions before writing code or creating a plan. Number questions and offer lettered answers, with the recommended answer first.

## Version and release invariant

- `Resources/Info.plist` is the single source of truth for the app version (`CFBundleShortVersionString`) and build number (`CFBundleVersion`).
- UI version labels must read the bundled metadata through `AppVersion.label`, always prefixed with lowercase `v`. Never hardcode a version in Swift views.
- Every release tag must be exactly `v<major>.<minor>.<patch>` and match `CFBundleShortVersionString`. For example, tag `v1.0.0`, bundle version `1.0.0`, and UI label `v1.0.0` must agree.
- Before a release, update the plist version and increment its positive integer build number. Do not generate a mismatching version from a tag or silently rewrite metadata in CI.
- Run `bash scripts/check-release-tag.sh vX.Y.Z` before tagging. The build, package verification, and GitHub release workflow must reject a mismatch before publication.
- A pushed matching `v*` tag triggers `.github/workflows/release.yml`, which builds and verifies Universal DMG/ZIP files before publishing a GitHub Release. Keep write permissions in the publication job only.
- Do not commit, tag, push, or publish unless the user requests that action. Never replace an existing published version’s assets or move its tag.

## Build and verification

- `bash scripts/check.sh`: schedule tests, release-policy tests, a native build, bundled runtime checks, and an isolated window/menu lifecycle check. No audible playback or login-item changes.
- `bash scripts/check.sh --no-ui`: omit the native window check in hosted CI.
- `bash scripts/build-app.sh`: build the native architecture; `--universal` builds Apple Silicon and Intel.
- `bash scripts/package-release.sh`: prepare and verify local DMG/ZIP artifacts; it does not upload them.
- `bash scripts/verify-release.sh`: independently verify packaged checksums, architectures, metadata, resources, and signing.
- For visual changes, render previews using the bundled executable’s `--render-previews` option and inspect EN/DE and light/dark layouts.

## Git identity

- Every commit must use `gslava <itic1gm@gmail.com>` as both author and committer. Do not add other authors or co-author trailers.
- Run `bash scripts/setup-git.sh` in a fresh clone to configure repository-local identity and the commit guard.
- Before committing, verify `git var GIT_AUTHOR_IDENT` and `git var GIT_COMMITTER_IDENT`. Preserve `.githooks/prepare-commit-msg`.
- Run `bash scripts/check-git-identity.sh` to audit all reachable history. CI must fetch full history before running this check.

## Project conventions

- Keep scheduling logic in `Sources/BellCore`, and AppKit/SwiftUI/audio integration in `Sources/BellOfMindfulness`. Keep UI and platform state on `@MainActor`.
- Preserve offline operation, one-shot scheduling, sleep support, and low idle resource use. Closing Settings must restore accessory activation; opening it must allow Dock and Command+Tab.
- Keep generated output in ignored `.build/`, `build/`, and `dist/`. Audio source belongs in `Resources/Audio/`.
- README is a concise user guide: features, installation, first-launch approval, and controls. Put development and release details in `docs/DEVELOPMENT.md`.
- Code and project-created icons use MIT. The recording is excluded; preserve `THIRD_PARTY_NOTICES.md` in the repository and packaged apps.
