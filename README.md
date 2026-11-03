# lueya

**a softer way to listen.**

A minimal, native warm-glass macOS music experience for Yandex Music.
Independent and unofficial.

> **M0 development preview only:** the menu-bar UI is native, but
> in-app playback, login, search and library are NOT implemented.

## Principles

- Music first; almost invisible controls and soft ambient design.
- Native SwiftUI and AppKit; not Electron, Tauri or Qt.
- No application-owned analytics or advertisements.
- Minimal dependencies (**zero third-party packages** today).

## Platform

- **macOS 26 minimum; macOS 27 target**
- **Apple Silicon / arm64**
- Latest stable compatible Xcode, Swift and Apple SDK, Swift 6 mode
- SwiftPM tools minimum 6.2 for Xcode 26/27 compatibility

## Build the M0 preview

On a supported Mac with Xcode installed:

```bash
swift test
./scripts/package-app.sh
open dist/lueya.app
```

The app appears in the menu bar. Its **Open official Yandex Music**
button opens the official service in the default browser; it does
not control playback or read your account from inside lueya.

See [Building](docs/BUILDING.md), [Architecture](docs/ARCHITECTURE.md),
[M0 feasibility](docs/M0-FEASIBILITY.md), and [Roadmap](docs/ROADMAP.md).

## Planned, not implemented

Menu-bar mini-player, Zen mode, floating view, global hotkeys,
media controls, search, library, dynamic artwork and My Wave
where supported by a technically and legally permitted integration.

## Development and security

Every completed milestone requires a whole-repository code/security
audit, refactoring assessment and regression verification.
Never commit provider credentials, cookies or signing keys.

lueya is not affiliated with, endorsed by or sponsored by Yandex.
Yandex Music and related trademarks belong to their owners.

## Proprietary license

Copyright © 2026. All rights reserved.
Not open source. See [LICENSE](LICENSE).
