# Architecture

Status: M0 authenticated API research, PR #15 pending CI/on-device validation; playback unimplemented.

## Platform and toolchain

- macOS 26 minimum; macOS 27 target; Apple Silicon arm64
- Latest stable compatible Swift/Xcode/SDK, Swift 6 language mode
- SwiftPM 6.2 tools minimum for Xcode 26.6 and Xcode 27 compatibility
- SwiftUI interface; AppKit for native system integration
- Zero third-party dependencies, telemetry or application backend

## Implemented M0 skeleton

- `LueyaApp`: native window-style SwiftUI MenuBarExtra
- `PlayerPreview`: non-playing warm-glass interface
- `LueyaCore`: site validators, isolated `YandexMusicAPIClient`, `YandexOAuthClient`, `YandexMusicSession`, and local `KeychainOAuthTokenStore` (Data Protection preferred; traditional Keychain fallback for ad-hoc signatures) (PR #15)
- `App/Info.plist`: background-menu agent, macOS 26 deployment
- `scripts/package-app.sh`: locally ad-hoc-signed app bundle
- XCTest suite and two-runner macOS native CI

There is NO audio playback, custom player, queue, library, search or
media-key control yet. Draft PR #15 integrates **experimental user-owned
OAuth sign-in** into the menu bar, without a UI redesign. OAuth and Music
account status have **mock CI tests only**; login must be verified on a
physical Mac and the interface is unofficial. The main App Sandbox gains
outbound network access for explicit login and API calls.

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
