# Roadmap

## M0 — API-first feasibility (OPEN; v0.1.x is an early-release series, not M0 acceptance)

- [x] Establish native macOS 26/27 SwiftUI menu-bar shell and GitHub-only CI
- [x] Document anonymous shared-track preview limits and de-scope further WebKit probe testing (#6)
- [x] Identify official Yandex ID OAuth vs unofficial Music API/Ynison boundaries (#13)
- [x] Implement isolated read-only native Swift Music HTTP transport with synthetic tests (not connected to main UI)
- [x] Implement and verify experimental Device Flow, public upstream OAuth identifiers and local Keychain session in CI (PR #15)
- [ ] Validate real Device Flow, Keychain session restore, renewal and sign-out on a physical Mac
- [ ] Record official provider/terms and distribution limitations of the **unofficial** authentication and streaming interface
- [ ] Confirm login and account status on a physical Mac with a user-owned subscription
- [x] Implement typed raw source negotiation with mocked transport, HMAC signature and CDN allowlist (#17)
- [x] Confirm user-owned Mac sign-in and HTTP 403 for track 99338938 on v0.1.0 (denied request stage remains unknown)
- [ ] Repeat track 99338938 on v0.1.1 to identify whether the 403 concerns metadata or a raw-source request (including quality)
- [ ] Prove full-length in-app streaming using the user's account and supported media formats (never offline)
- [ ] Decide whether My Wave/Ynison/queues can be supported safely and legally
- [ ] Resolve outstanding M0 audit findings, perform full repository-wide verification and explicit go/no-go (#1)

M0 remains blocked on provider authorization and real end-to-end playback.
A working unofficial endpoint or anonymous preview is not sufficient.
See [API feasibility](M0-API-FEASIBILITY.md).

## M1 — Native foundation

- [ ] Establish permanent Developer ID-signed Xcode app target
- [ ] Finalize menu bar lifecycle, windowing and appearance
- [ ] Implement floating mini-player and accessibility settings
- [ ] Expand manual tests on macOS 26/27

Exit: tested, functional, stable native app foundation.

## M2 — Core music experience

- [ ] Implement authorized provider integration
- [ ] Play/pause/next/previous, metadata, artwork, media keys
- [ ] Search, library and My Wave where supported and permitted
- [ ] Session expiration, errors, recovery

Exit: reproducible permitted end-to-end music playback.

## M3 — Zen experience

- [ ] Zen mode and artwork-driven native ambiance
- [ ] Floating controls, shortcuts and accessibility
- [ ] CPU, memory and launch optimization

Exit: fully polished tested experience.

## M4 — Release readiness

- [ ] Full regressions on macOS 26/27
- [ ] Privacy/security/dependency and license review
- [ ] Trademark clearance for lueya
- [ ] Developer ID signing and notarization
- [ ] Packaging and distribution documentation

Exit: approved release candidate.

## Mandatory milestone gate

Every milestone requires full repository-wide code, security,
dependency, architecture and refactoring audits (not only changed
files), actual regression verification and explicit acceptance.
