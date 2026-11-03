# Roadmap

## M0 — Feasibility (OPEN)

- [x] Define native macOS 26/27 and latest-stable toolchain policy
- [x] Implement isolated SwiftUI menu bar preview without secrets
- [x] Establish GitHub-only build/test/artifact and release process
- [x] Research provider terms and official shared-track embed support
- [x] Implement standalone opt-in official embed diagnostic (#6)
- [ ] Verify actual shared-track playback and limitations on macOS 26/27
- [ ] Establish permitted full Music account/playback integration
- [ ] Compare WebKit vs native end-to-end playback with evidence
- [ ] Confirm go/no-go for full product and architecture decision
- [ ] Perform full repository-wide audit and verification

M0 exits only with a reproducible permitted music integration
or a documented blocker. An official single-track embed is only
partial technical evidence, not full personalized playback.

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
