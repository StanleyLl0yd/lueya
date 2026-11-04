# lueya

**A softer way to listen.**

**English** · [Русский](README.ru.md)

lueya is a minimal native macOS companion for Yandex Music, designed for
quiet listening and a compact menu-bar experience. Independent and unofficial.

## Available today

- Airy, warm matte-glass menu-bar interface with soft light and subtle motion.
- Sign in to your own Yandex account using a code and the official login page.
- Restore and end sessions securely via macOS Keychain.
- Experimental online track metadata and audio-source check with permitted-quality fallback.

**v0.2.1 is an early release, not yet a working audio player.**
Full-length playback, search, playlists and My Wave are not implemented.

## Download

**[Download lueya 0.2.1 for macOS (ZIP)](https://github.com/StanleyLl0yd/lueya/releases/download/v0.2.1/lueya-0.2.1-macos-arm64.zip)**

[Verify SHA-256](https://github.com/StanleyLl0yd/lueya/releases/download/v0.2.1/SHA256SUMS.txt) ·
[All releases](https://github.com/StanleyLl0yd/lueya/releases)

Requires an **Apple Silicon Mac** running **macOS 26 or later** (macOS 27
supported). Builds are ad-hoc signed but not yet notarized by Apple.
macOS may block launch; after verifying the checksum, use
System Settings → Privacy & Security → Open Anyway *if offered*.
Do not disable Gatekeeper.

## Built to stay light

Swift 6, SwiftUI and AppKit. No Electron, ads, app-owned analytics,
custom login server, or third-party runtime dependencies. Each listener
signs in individually. **Online music only, without offline downloads**
or permanent local audio storage.

## Development

[Roadmap](docs/ROADMAP.md) · [Issues](https://github.com/StanleyLl0yd/lueya/issues) ·
[Security](SECURITY.md)

Proprietary software, **All Rights Reserved** ([license](LICENSE)).
Not affiliated with or endorsed by Yandex. Yandex Music service terms,
account and regional restrictions apply.
