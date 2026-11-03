# Architecture

Status: M0 authenticated API feasibility. Device Flow and raw stream source lookup have synthetic CI coverage; on-device verification and actual playback remain open.

## Platform and toolchain

- macOS 26 minimum; macOS 27 target; Apple Silicon arm64
- Latest stable compatible Swift/Xcode/SDK, Swift 6 language mode
- SwiftPM 6.2 tools minimum for Xcode 26.6 and Xcode 27 compatibility
- SwiftUI interface; AppKit for native system integration
- Zero third-party dependencies, telemetry or application backend

## Implemented M0 skeleton

- `LueyaApp`: native window-style SwiftUI MenuBarExtra
- `PlayerPreview`: non-playing warm-glass interface
- `LueyaCore`: site validators, isolated Music account/OAuth/session clients and local Keychain, plus typed `YandexMusicStreamProvider` raw-source negotiation with strict CDN guards (#17)
- `App/Info.plist`: background-menu agent, macOS 26 deployment
- `scripts/package-app.sh`: locally ad-hoc-signed app bundle
- XCTest suite and two-runner macOS native CI

There is NO audio playback, custom player, queue, library, search or
media-key control yet. The menu-bar UI supports experimental user-owned
OAuth sign-in and an optional **non-playing** raw-source check. OAuth,
account status and media source lookup have synthetic CI tests only;
all require verification on a physical Mac. The main App Sandbox
allows outbound OAuth and Music API calls.

## Boundaries after feasibility

- App: lifecycle, menu bar, windows, preferences, global shortcuts
- Presentation: mini-player, zen mode, search and library
- Playback: testable abstraction, concrete engine only after M0
- Provider: native Swift `URLSession` adapter with fixed trusted origin,
  ephemeral transport and redirect blocking; integration via supported,
  authorized capabilities only
- Persistence: local macOS Keychain for OAuth tokens (Data Protection preferred; traditional fallback for test signatures); UserDefaults for non-secret UI settings only

## Constraints

- WKWebView is not approved until provider permissions and behavior
  are verified; website cookies must not be used as API tokens.
- No scraping, DRM bypass, offline downloads or redistribution of provider media.
- Public official Yandex Music Android OAuth client identifiers from community docs are an **approved project research decision**, but may be revoked and do not provide provider endorsement.
- No app-owned backend or token telemetry; tokens never enter GitHub.
- No macOS 27-only API without a functional macOS 26 fallback.
- Keep accessibility, reduced motion and resource use in scope.
- No dependencies without justification, licensing and security review.

See [API-first feasibility](M0-API-FEASIBILITY.md),
[historical embed research](M0-FEASIBILITY.md) and [Building](BUILDING.md).
