# M0 repository-wide pre-acceptance audit — 2026-11-04

**Audited tree:** protected `main=d1b13a2ad218c8058a7b1ac0d0cf743eb3b16a1d`,
released as `v0.3.0`. **Scope: all 54 tracked files**, not only
PR #24. This is a static code/security/architecture/dependency/build/
test/release/documentation assessment, **not a Mac runtime certification**.
No end-user credentials, live CDN responses or app-binary analysis were
available inside the GitHub connector.

## Repository-wide coverage

| Area | Inspected | Result |
| --- | --- | --- |
| Repository policy, LICENSE, README EN/RU, SECURITY, .editorconfig, .gitattributes, .gitignore, PR template | All | No open-source licensing implied; privacy disclosures and versioned direct download URLs are present |
| SwiftPM manifest, 4 app sources, 8 core sources, 2 historical probe sources | All | Swift 6, native UI/AVFoundation, zero third-party packages; media and OAuth responsibilities separated |
| 7 XCTest source files | All | 60/60 synthetic tests per runner; tests cover OAuth, account, source, URL and HTTP range constraints but not native audio runtime |
| App and historical probe Info.plist and entitlements, shell packager | All | Main sandbox + outbound network only; ad-hoc signed arm64; binary stripped before signing; no offline media storage |
| Entire GitHub CI/release workflow | All | SHA-pinned actions, no credentials persisted at checkout, read-only default permissions, scoped release write token, exact version checks, signature and checksum verification, immutable versioned release assets |
| All 17 documentation files (including historical release notes and previous audit) | All | Current roadmap/release notes describe M0 as OPEN; two older research pages contain stale current-version statements |
| Branch governance | Effective PR #24 merged after both exact-head checks | Protected main observed; historical ruleset #26484158 active. Direct-push bypass was not attempted |
| Release v0.3.0 | GitHub release + Actions #41746065914 | Regular, immutable ZIP `lueya-0.3.0-macos-arm64.zip` 185,536 bytes, SHA256SUMS.txt, 3/3 SUCCESS |

## Findings and disposition

| ID | Severity | Finding | Required resolution | Status |
| --- | --- | --- | --- | --- |
| M0-24-B1 | **M0 blocker** | A third-party Music client can technically resolve a raw candidate, but service terms and public distribution permissions have not been independently established | Review actual applicable service permissions; record provider-authorized scope or explicit NO-GO | OPEN |
| M0-24-B2 | **M0 blocker** | `AVAssetResourceLoader` and the player have not been exercised with real authorized bytes on a Mac. Only candidate `aac-mp4/hq` for track `99338938` has been reported | Prove audible playback beyond 30 seconds through the natural track end; pause/seek/replay/network errors; macOS 26 and 27 as practical | OPEN |
| M0-24-H1 | **High / player state** | AVPlayer failure detection is largely periodic-time and notification based. An unsupported asset can fail before time advances, leaving the UI in `connecting` without a deterministic error path | Observe `AVPlayerItem.status` / load state and provide a bounded startup timeout; never expose system errors containing signed URLs | OPEN |
| M0-24-M1 | **Medium / expiry** | The signed source freshness window is checked before start/replay, but expiry and denied ranges during the middle of playback stop the player rather than refreshing and safely resuming | Add bounded same-track/same-codec source renewal, safe resumption and clear terminal errors; verify on device | OPEN |
| M0-24-M2 | **Medium / integration coverage** | Synthetic tests validate the HTTP range parser, URL guards and no-auth headers, but do not exercise the actual `AVAssetResourceLoader` callback lifecycle or reject a live HTTP redirect | Create an original/synthetic integration fixture and tests for resource-loader callbacks, cancellation, data seeking and redirect rejection | OPEN |
| M0-24-M3 | **Medium / performance** | `URLSession.AsyncBytes` delivers individual bytes into Data for each 128-KiB range. Memory is bounded, but CPU/throughput under playback load is not measured | Instrument on-device audio stalls, transfer latency, CPU/energy; retain bounded streaming when optimizing | OPEN |
| M0-24-M4 | **Medium / account lifecycle** | Real Device Flow login was reported, but refresh, restart restore, sign-out during concurrent media activity and both Keychain backends lack live acceptance evidence; session tests are limited | Document real device test and extend synthetic race/refresh coverage | OPEN |
| M0-24-L1 | **Low / docs drift** | Legacy feasibility/testing pages still describe v0.1.0 or earlier as current and say native playback is absent | Mark pages historical or update to v0.3.0 while retaining prior research | FIX IN AUDIT PR |
| M0-24-L2 | **Low / disclosure process** | SECURITY.md has no defined private vulnerability report link/SLA | Evaluate enabling GitHub private vulnerability reporting and document actual contact route | OPEN |
| M0-24-L3 | **Low / historical probe** | Separate WebKit embed research remains in the tree but is not part of the shipping app; top-level navigation gate is not tested live | Retain isolated legacy target; do not represent it as a current supported player | OPEN |

## Confirmed defensive boundaries (static)

- App Sandbox restricts the main target; only outbound client networking is
  provisioned. OAuth tokens remain in a locally encrypted macOS Keychain;
  ad-hoc signatures can require the traditional Keychain fallback.
- API and media requests use ephemeral sessions and disable cookies/caches.
  The authenticated API's HTTPS origin and redirect policy are validated.
- The media source is resolved per signed-in user; the private AVFoundation
  asset identity contains no provider URL. Media HTTP requests do not
  forward OAuth credentials or browser cookies.
- Media requests fail closed on nonallowlisted URLs, redirects,
  unverified partial responses, inconsistent byte counts and invalid MIME
  types, and cap each in-memory response to 128 KiB. This can also reject
  legitimate yet uncharacterized provider behavior.
- Raw, native-decodable AAC/MP3 candidates only; no encrypted `encraw`
  decryption, DRM circumvention, offline media or persistent downloads.
- Source and token `description` implementations redact credentials.
  Their presence in system network diagnostics has not been tested, so
  user-facing logs must still be treated as potentially sensitive.
- No ad SDK, app-owned analytics, Electron/Tauri/Qt or third-party Swift
  package dependencies were found.

## Refactoring assessment

The current native SwiftPM architecture remains a reasonable M0 base.
Avoid a broad rewrite or adding an external media player. Prefer narrow,
testable changes to AVPlayer error state, bounded loading, source-renewal
and cancellation. If automated native playback tests require testability,
extract the playback bridge into a small native module only when a real
fixture demonstrates the need. Preserve the warm-glass design and zero
offline policy.

## Verification and M0 decision

- `v0.3.0` exact-head PR #24: required macOS 26 and Xcode 27 checks PASS.
- Post-merge `main` CI: [run 41746065914](https://github.com/StanleyLl0yd/lueya/actions/runs/41746065914)
  **3/3 SUCCESS, 60/60 synthetic tests per platform**, signed arm64
  packaging and release/checksum publishing passed.
- **No physical-Mac audio test** and no independent provider-rights grant
  have been established.
- **M0: OPEN / NOT ACCEPTED.** All high and blocking findings must be
  resolved, and the mandatory final **repository-wide verification**
  repeated after material code changes. The user must not be told that
  synthetic CI proves complete playback.

Tracked next step: [issue #16](https://github.com/StanleyLl0yd/lueya/issues/16).
Historical baseline: [2026-11-03 audit](M0-REPOSITORY-AUDIT-2026-11-03.md).
