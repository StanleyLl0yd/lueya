# Roadmap

## M0 — API-first feasibility (OPEN; v0.4.0 still needs on-device playback and provider rights)

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
- [x] User test of track 99338938 on v0.1.1: metadata accepted; quality-specific hq raw source returned HTTP 403
- [x] User macOS v0.2.0 test: 99338938 yields an AAC-MP4 hq source candidate; actual audio still untested
- [x] Implement experimental AVPlayer playback through capped in-memory HTTPS ranges, Play/Pause/Stop/Seek (v0.3.0)
- [x] Implement bounded same-track/codec/quality renewal for expired signed media, with native generated-AAC resource-loader tests (v0.4.0, #27; on-device verification still pending)
- [x] Confirm user-owned macOS v0.3.1 has real audible playback beyond 30 seconds (screen shows 1:17/4:09)
- [ ] Prove natural track completion, seek, pause, expiry and network recovery on physical Mac; separately validate v0.4.0
- [ ] Review third-party streaming/distribution rights before M0 go/no-go
- [ ] Decide whether My Wave/Ynison/queues can be supported safely and legally
- [ ] Resolve outstanding M0 audit findings, perform full repository-wide verification and explicit go/no-go (#1)

M0 remains blocked on provider permission, full end-to-end completion
and on-device recovery behavior. A voluntary research/testing disclaimer
does not itself grant third-party service authorization.
A working unofficial endpoint or anonymous preview is not sufficient.
See [API feasibility](M0-API-FEASIBILITY.md).

## M1 — Native foundation

- [ ] Establish permanent Developer ID-signed Xcode app target
- [x] Implement warm matte-glass menu-bar appearance, dynamic version footer and gentle accessible interactions (v0.2.0)
- [ ] Validate on-device appearance, accessibility and window behavior; finalize
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

## Release freeze (owner approval required)

Each iteration ends with a versioned, downloadable test release and a
**hard stop**: all development, test runs, audits, milestone acceptance,
new PR/merge/release activity and further planning are suspended until the
owner gives explicit feedback on that exact build. Handoffs, CI completion
and partial playback evidence never bypass the stop. v0.4.1 is the current
owner-trial build. A narrowly scoped one-shot publish on its protected-main
merge is permitted; all subsequent publishing requires fresh owner approval
via manual workflow dispatch *after* the freeze is lifted.

## Mandatory milestone gate

Every milestone requires full repository-wide code, security,
dependency, architecture and refactoring audits (not only changed
files), actual regression verification and explicit acceptance.
