# Changelog

## Unreleased

### OAuth research (PR #15, pending)

- Native Swift Device Flow with user-confirmed Yandex login
- Per-device, non-synchronizing Keychain token store and session restoration
- Isolated auth and session actor with synthetic request/response tests
- Compact sign-in controls preserving the existing warm-glass UI
- Outbound network sandbox entitlement for the main app's authenticated API
- Immutable 0.0.3 auth research test ZIP and release notes
- Online streaming only is a fixed product requirement; no offline mode

### Changed

- Retired anonymous shared-track playback testing in favor of API-first M0 (#13)
- Added isolated native URLSession read-only account-status client, synthetic transport tests and explicit provider authorization gates

### Added

- Initial proprietary repository, documentation and policies
- M0 native SwiftUI menu-bar preview for macOS 26/27
- Zero-dependency SwiftPM modules with XCTest coverage
- Trusted official-site link and security checks
- GitHub-only build, tests, artifact upload and preview releases
- M0 isolated shared-track WebKit probe with ephemeral website data
- Separate network sandbox entitlement only for the probe
- Official embed URI and host/path validation tests
- Architecture, feasibility and manual-test documentation
