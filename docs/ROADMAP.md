# Roadmap

## M0 — API-first feasibility (OPEN)

- [x] Establish native macOS 26/27 SwiftUI menu-bar shell and GitHub-only CI
- [x] Document anonymous shared-track preview limits and de-scope further WebKit probe testing (#6)
- [x] Identify official Yandex ID OAuth vs unofficial Music API/Ynison boundaries (#13)
- [x] Implement isolated read-only native Swift Music HTTP transport with synthetic tests (not connected to main UI)
- [ ] Establish whether Music permits a distinct OAuth client/scope; obtain explicit provider-approved authentication and playback permission (community reports custom Music OAuth registration unavailable)
- [ ] Prove authorized account status, metadata and full-length in-app playback on real Macs
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
