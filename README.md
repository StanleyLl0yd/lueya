# lueya

**a softer way to listen.**

A minimal, native warm-glass macOS experience designed for Yandex Music.
Independent and unofficial.

> **M0 API-first research:** the regular menu-bar app is native but does
> **not** yet play music. An isolated Swift read-only client for an
> unofficial Yandex Music API account-status endpoint has mock tests.
> It is not wired into the app, has no token/login and has not been live-tested.
> The former 30-second anonymous embed experiment is de-scoped.

## Principles

- Music first; almost invisible controls and soft ambient design.
- Native SwiftUI and AppKit; not Electron, Tauri or Qt.
- No application-owned analytics or advertisements.
- Zero third-party package dependencies today.
- macOS 26 minimum, macOS 27 target; arm64 Apple Silicon.

## Download from GitHub (no local development required)

Test assets are built **entirely in GitHub Actions** and published on
[Releases](https://github.com/StanleyLl0yd/lueya/releases).
The historical v0.0.2 M0 preview contains two separately zipped apps:

- **lueya.app** — unchanged menu-bar UI and external official-site link.
- **lueya-embed-probe.app** — historical anonymous shared-track diagnostic;
  no further testing is requested, and it is not a product playback path.

No source checkout or Xcode install is necessary to test.
See [Testing](docs/TESTING.md) for checksum, Gatekeeper and smoke tests.

The unsigned-for-distribution developer previews use ad-hoc signatures
and are not notarized; Gatekeeper may block them. Do not disable it.

## Technology

Swift 6, SwiftUI, AppKit, SwiftPM, Foundation URLSession (isolated API research),
WebKit (historical probe only).
The main application has no network entitlement. The isolated
probe requires outbound network access to retrieve the official embed
**after explicit user action**; it saves no account credentials.

## Planned (not implemented)

A full audio player, My Wave, library, search, playback history,
media keys and keyboard control require an authorized provider
integration and actual playback proof on macOS 26/27.

See [API-first M0 feasibility](docs/M0-API-FEASIBILITY.md),
[historical embed evidence](docs/M0-FEASIBILITY.md),
[Architecture](docs/ARCHITECTURE.md),
[Roadmap](docs/ROADMAP.md), and
[Building](docs/BUILDING.md).

## Development and security

Every completed milestone requires a full repository-wide
audit and refactoring review, not just a diff review.
Do not commit credentials, cookies, signing keys or media.

lueya is not affiliated with, endorsed by or sponsored by Yandex.
Yandex Music and related trademarks belong to their owners.

## License

Copyright © 2026. All rights reserved. Proprietary, not open source.
See [LICENSE](LICENSE).
