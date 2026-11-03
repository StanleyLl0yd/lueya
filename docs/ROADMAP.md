# Roadmap

## M0 — Feasibility (OPEN)

- [x] Define native macOS 26/27 and latest-stable toolchain policy
- [x] Implement isolated SwiftUI menu bar prototype without secrets
- [x] Record initial provider terms and integration constraints
- [ ] Verify authorized authentication approaches
- [ ] Prove a permitted playback integration in a live prototype
- [ ] Compare WebKit/native playback and session behavior
- [ ] Confirm technical go/no-go and architecture decision
- [ ] Perform full repository-wide milestone audit and verification

Exit gate: reproducible, permitted integration or documented blocker.
A visual menu bar shell does not complete M0.

## M1 — Native foundation

- [ ] Establish permanent signed Xcode app target
- [ ] Finalize app lifecycle and menu bar behaviors
- [ ] Implement floating mini-player
- [ ] Implement appearance and accessibility settings
- [ ] Expand manual verification and stable CI on macOS 26/27

Exit gate: functioning, verified native app shell.

## M2 — Core music experience

- [ ] Implement approved playback integration
- [ ] Play/pause/next/previous, track metadata and artwork
- [ ] Native media keys and Now Playing
- [ ] Search, library and My Wave where permitted
- [ ] Session expiration, network error and recovery handling

Exit gate: end-to-end reliable, permitted music playback.

## M3 — Zen experience

- [ ] Zen mode, artwork ambience and floating controls
- [ ] Global shortcuts and accessibility/motion support
- [ ] Startup, RAM and CPU optimization

Exit gate: tested polished experience.

## M4 — Release readiness

- [ ] Full regressions on macOS 26 and 27
- [ ] Privacy/security and dependency license review
- [ ] Trademark and naming clearance
- [ ] Developer ID signing/notarization
- [ ] Release packaging and documentation

Exit gate: approved release candidate.

## Mandatory milestone gate

After EVERY milestone:
1. Complete repository-wide code/security/dependency audit.
2. Complete architecture/maintainability review.
3. Apply justified fixes and refactoring.
4. Run regression tests and manual smoke tests.
5. Record findings, blockers and acceptance decision.

Never substitute a diff-only audit for a full repository review.
