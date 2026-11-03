# lueya

**a softer way to listen.**

A minimal, native macOS music player experience
designed for Yandex Music.

Warm glass. Quiet interaction. Music first.

> Project status: early development / feasibility.

## Philosophy

lueya is designed around four principles:

- **Music first.** The interface stays out of the way.
- **Calm by default.** No unnecessary visual noise.
- **Native by design.** SwiftUI and AppKit, not Electron.
- **Private by nature.** No proprietary analytics
  or advertising infrastructure.

## Experience

The intended experience includes:

- Menu bar player
- Compact floating mini-player
- Zen listening mode
- Global keyboard shortcuts
- Native media key integration
- Search and library access
- Yandex Music personal recommendations
- "My Wave" playback, where supported
- Dynamic artwork-based visual atmosphere
- Light, dark, and system appearance
- Soft transitions and reduced-motion support

Features are planned, not yet implemented.

## Technology

- Swift
- SwiftUI
- AppKit
- macOS
- WebKit / AVFoundation where appropriate
- Keychain for sensitive credentials

The playback integration is subject to a technical
and legal feasibility assessment.

See [Architecture](docs/ARCHITECTURE.md).

## Development

The project follows milestones.

See [Roadmap](docs/ROADMAP.md).

A complete repository-wide audit, code review,
and refactoring assessment is required at the
end of each milestone.

## Status

M0 — Feasibility and playback research.

No working playback integration is claimed yet.

## Privacy and security

- No application-owned analytics
- No advertising SDKs
- No application backend by default
- No committed credentials or tokens
- Authentication secrets stored securely
- Minimum necessary platform permissions

The music provider may process data according
to its own terms and privacy policy.

## Disclaimer

lueya is an independent, unofficial project.

It is not affiliated with, endorsed by, or
sponsored by Yandex.

Yandex Music and related trademarks belong
to their respective owners.

Integration must comply with applicable terms,
copyright requirements, and technical restrictions.

## License

Copyright © 2026. All rights reserved.

This is proprietary software.

See [LICENSE](LICENSE).

No open-source license is granted.
