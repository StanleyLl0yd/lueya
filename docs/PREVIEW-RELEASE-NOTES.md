# lueya — M0 Native UI Preview

**Early test build only. This is NOT a working Yandex Music player.**

This Apple Silicon/macOS 26–27 preview demonstrates:

- A real native SwiftUI menu-bar application with a compact,
  warm-glass interface.
- An external button opening the official Yandex Music website
  in the default browser.
- A Quit control and basic accessible labels.

**Not implemented:** in-app playback, Yandex account login,
search, metadata, queue, library, media keys, or My Wave.

The build is produced only by GitHub Actions after successful Swift
compilation, XCTest and arm64 bundle validation on **macOS 26 and 27**.
It contains no third-party Swift dependencies.

Assets:
- `lueya-macos-arm64-m0-preview.zip` — native test app bundle.
- `SHA256SUMS.txt` — integrity checksum for the ZIP.

The app is **ad-hoc signed and not notarized**. macOS Gatekeeper may
refuse to open it. Do not disable Gatekeeper. See
[Testing instructions](https://github.com/StanleyLl0yd/lueya/blob/main/docs/TESTING.md)
for checksum verification and manual test expectations.

Independent and unofficial; not affiliated with Yandex.
This is a proprietary All Rights Reserved project.
