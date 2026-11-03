# Roadmap

## M0 — Feasibility

- [ ] Verify supported authentication approaches
- [ ] Evaluate compliant playback integration
- [ ] Evaluate WebKit/native trade-offs
- [ ] Validate session handling
- [ ] Verify relevant provider terms
- [ ] Confirm technical go/no-go
- [ ] Document architecture decision

Exit gate:
A reproducible, permitted integration path
or an explicit documented blocker.

## M1 — Native foundation

- [ ] Create Swift/Xcode project
- [ ] Implement application lifecycle
- [ ] Implement menu bar integration
- [ ] Implement mini-player shell
- [ ] Implement appearance preferences
- [ ] Establish executable CI and tests

Exit gate:
Native app shell is functional and tested.

## M2 — Core music experience

- [ ] Implement selected playback integration
- [ ] Play/pause/next/previous
- [ ] Metadata and artwork
- [ ] Media key integration
- [ ] Search
- [ ] Library access where supported
- [ ] Playback error handling

Exit gate:
Reliable end-to-end core playback.

## M3 — Zen experience

- [ ] Zen mode
- [ ] Artwork-based atmosphere
- [ ] Floating player
- [ ] Global shortcuts
- [ ] Motion and accessibility
- [ ] Light/dark themes
- [ ] Performance optimization

Exit gate:
Complete intended user experience.

## M4 — Release readiness

- [ ] Full regression testing
- [ ] Privacy and security review
- [ ] Third-party license review
- [ ] Trademark and naming clearance
- [ ] App signing and notarization
- [ ] Release packaging
- [ ] Distribution documentation

Exit gate:
Approved release candidate.

## Mandatory milestone gate

After every milestone:

1. Full repository-wide code review.
2. Full security and dependency audit.
3. Full architecture and maintainability review.
4. Refactoring where justified.
5. Complete relevant regression testing.
6. Document findings and remaining risks.
7. Accept or reject milestone explicitly.

Audits must cover the entire repository,
not merely recent diffs.
