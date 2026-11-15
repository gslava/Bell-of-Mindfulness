Fixes a crash at midnight when macOS reports a calendar day change from a background thread. The app now updates on the main actor and continues running.

Includes a regression check for background calendar notifications.

A singing bowl reminder for macOS 14 and later.

- Choose the playback interval and volume.
- Set quiet periods with selected weekdays; default: 21:00–08:00 daily.
- Pause or resume reminders from the menu bar.
- Use compact sidebar settings in English or German.
- Enable launch at login if desired.

Download the Universal DMG or ZIP for Apple Silicon and Intel. SHA-256 files are included.

The app is ad-hoc signed and not notarized by Apple. If macOS blocks it, dismiss the alert. If you trust the download, use System Settings → Privacy & Security → Open Anyway, then confirm Open. [Apple’s instructions](https://support.apple.com/en-us/102445).

Code and icons are MIT licensed. The bundled recording is excluded; see THIRD_PARTY_NOTICES.md in the repository or app bundle.
