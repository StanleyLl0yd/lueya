# lueya

**a softer way to listen.**

A minimalist, native warm-glass macOS client for Yandex Music.
Independent and **unofficial**. macOS 26 minimum / macOS 27 target, Apple Silicon arm64.

> **M0 authenticated API research:** this app is **not yet a music player**.
> Draft [PR #15](https://github.com/StanleyLl0yd/lueya/pull/15) introduces
> user-initiated Yandex Device Flow authentication and locally stored Keychain
> sessions. Full-track playback has **not** been implemented or verified.

## Principles

- Native Swift 6, SwiftUI + AppKit, no Electron/Tauri/Qt or Python runtime.
- Zen-style minimal UI, no app-owned analytics or ads.
- Each listener signs in with **their own** Yandex account.
- **Streaming only. No offline downloads or stored music library.**
- Modular Swift API adapter separate from UI, session and audio engine.
- No custom backend, no developer-hosted accounts or tokens.

## Authentication research

The optional native OAuth sign-in uses **public** application identifiers of
Yandex's official Android Music client documented in the community
[MarshalX/yandex-music-api](https://github.com/MarshalX/yandex-music-api)
project. These identifiers are not issued to lueya, can be revoked or blocked
and **do not imply official provider permission or endorsement**.

The app directs users to Yandex's own website and never asks for a password.
Access/refresh tokens, if granted, are held only in a **device-only macOS
Keychain** item. Sign out removes them. This feature has synthetic XCTest
coverage but still needs physical-Mac acceptance with a real user-owned account.
Do not post or email access tokens, refresh tokens or login screenshots.

## Development builds

All authoritative source, CI, artifacts and prereleases are on
[GitHub](https://github.com/StanleyLl0yd/lueya).
After CI approval and merge of PR #15, the planned M0 test build is
[v0.0.3-m0-auth.1](https://github.com/StanleyLl0yd/lueya/releases/tag/v0.0.3-m0-auth.1).
Before publication, obtain the latest exact-commit GitHub Actions artifact
from the PR, not the obsolete anonymous embed prerelease.

The test app is ad-hoc signed, not notarized. Follow macOS Gatekeeper; do not
disable system security controls.

## Planned work

Full-length authenticated music streaming, automatic best available quality,
lossless where supported, playback controls, search, likes, playlists, My Wave
and later Ynison. **No offline mode is planned.**

See [API feasibility](docs/M0-API-FEASIBILITY.md),
[Architecture](docs/ARCHITECTURE.md), [Roadmap](docs/ROADMAP.md)
and [Building](docs/BUILDING.md).

## License and security

Copyright © 2026. All rights reserved. Proprietary software, not open source.
See [LICENSE](LICENSE) and [SECURITY.md](SECURITY.md).

lueya is not affiliated with, endorsed by or sponsored by Yandex.
Yandex Music and related trademarks are owned by their respective holders.
