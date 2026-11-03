# Architecture

Status: M0 native shell prototype, playback design unapproved.

## Platform and toolchain

- macOS 26 minimum; macOS 27 target; Apple Silicon arm64
- Latest stable compatible Swift/Xcode/SDK, Swift 6 language mode
- SwiftPM 6.2 tools minimum for Xcode 26.6 and Xcode 27 compatibility
- SwiftUI interface; AppKit for native system integration
- Zero third-party dependencies, telemetry or application backend

## Implemented M0 skeleton

- `LueyaApp`: native window-style SwiftUI MenuBarExtra
- `PlayerPreview`: non-playing warm-glass interface
- `LueyaCore`: validated official website destination
- `App/Info.plist`: background-menu agent, macOS 26 deployment
- `scripts/package-app.sh`: locally ad-hoc-signed app bundle
- XCTest suite and two-runner macOS native CI

There is NO audio playback, provider login, custom player,
queue, library, search, or media-key control yet.

## Boundaries after feasibility

- App: lifecycle, menu bar, windows, preferences, global shortcuts
- Presentation: mini-player, zen mode, search and library
- Playback: testable abstraction, concrete engine only after M0
- Provider: integration via supported, authorized capabilities only
- Persistence: UserDefaults for state; Keychain for secrets if needed

## Constraints

- WKWebView is not approved until provider permissions and behavior
  are verified; website cookies must not be used as API tokens.
- No scraping, DRM bypass or redistribution of provider media.
- No macOS 27-only API without a functional macOS 26 fallback.
- Keep accessibility, reduced motion and resource use in scope.
- No dependencies without justification, licensing and security review.

See [M0 feasibility](M0-FEASIBILITY.md) and [Building](BUILDING.md).
