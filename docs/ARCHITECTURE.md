# Architecture

Status: v0.3.0 experimental AVFoundation playback; M0 OPEN pending real full-track evidence, provider rights and repository-wide acceptance audit.

## Platform and toolchain

- macOS 26 minimum; macOS 27 target; Apple Silicon arm64
- Latest stable compatible Swift/Xcode/SDK, Swift 6 language mode
- SwiftPM 6.2 tools minimum for Xcode 26.6 and Xcode 27 compatibility
- SwiftUI interface; AppKit for native system integration
- Zero third-party dependencies, telemetry or application backend

## Implemented M0 skeleton

- `LueyaApp`: native window-style SwiftUI MenuBarExtra
- `PlayerPreview`: warm matte-glass menu with source checking, experimental playback controls, dynamic version footer and accessibility settings
- `LueyaCore`: account/OAuth/Keychain, source negotiation and `SecureMediaRangeClient` for ephemeral 128-KiB media chunks and strict CDN/response validation
- `OnlineAudioPlayback`: native AVPlayer through a private in-memory resource delegate, play/pause/stop/seek, cancellation on sign-out
- `App/Info.plist`: background-menu agent, macOS 26 deployment
- `scripts/package-app.sh`: size-optimized arm64 app, stripped before ad-hoc signing
- XCTest suite and two-runner macOS native CI

The AVPlayer path has no physical-Mac end-to-end playback evidence.
A user has confirmed login and raw AAC-MP4 hq source discovery; actual
bytes, decoding, seek, expiry, interruptions and track completion remain
unverified. Synthetic CI alone cannot prove audio functionality.
No queue, search, My Wave, library or media-key controls yet.
Outbound HTTPS is limited by application policy and sandbox entitlements.

## Boundaries after feasibility

- App: lifecycle, menu bar, windows, preferences, global shortcuts
- Presentation: mini-player, zen mode, search and library
- Playback: AVPlayer consumes only an internal custom-scheme asset; the signed remote URL stays in a private bounded resource loader
- Provider: native Swift `URLSession` adapter with fixed trusted origin,
  ephemeral transport and redirect blocking; integration via supported,
  authorized capabilities only
- Persistence: local macOS Keychain for OAuth tokens (Data Protection preferred; traditional fallback for test signatures); UserDefaults for non-secret UI settings only

## Constraints

- WKWebView is not approved until provider permissions and behavior
  are verified; website cookies must not be used as API tokens.
- No scraping, DRM bypass, offline downloads or redistribution of provider media.
- Public first-party Music OAuth identifiers are an **approved project research decision**, but may be revoked and do not provide provider endorsement.
- No app-owned backend or token telemetry; tokens never enter GitHub.
- No macOS 27-only API without a functional macOS 26 fallback.
- Keep accessibility, reduced motion and resource use in scope.
- No dependencies without justification, licensing and security review.

See [API-first feasibility](M0-API-FEASIBILITY.md),
[historical embed research](M0-FEASIBILITY.md) and [Building](BUILDING.md).
