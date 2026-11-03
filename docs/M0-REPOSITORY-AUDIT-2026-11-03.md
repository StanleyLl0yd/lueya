# M0 repository-wide pre-acceptance audit — 2026-11-03

**Base commit:** `4c47d2c62bd7141288c40ad9d67d516b5b6585a6` (PR #7 merged).

**Scope:** Full tracked repository tree at that commit, **not a diff-only review**. Examined all 30 tracked files and their contents: root configuration/policy (`.editorconfig`, `.gitattributes`, `.gitignore`, `AGENTS.md`, `CHANGELOG.md`, `LICENSE`, `README.md`, `SECURITY.md`, `Package.swift`), App plists and entitlements, all Swift app/core/probe sources, both XCTest files, the entire GitHub workflow and PR template, packaging script, and all six `docs/` files. Reviewed repository configuration, the branch/ruleset API read, and exact post-merge Actions run #41711659060. This report does **not** claim a local Xcode review/build or on-device macOS 26 and 27 coverage.

## Verified baseline

- Native Swift 6 / SwiftUI / AppKit on arm64 macOS 26+, with macOS 27 CI; no third-party Swift package dependencies or application backend.
- Main application is a non-playing menu-bar shell, sandboxed without network entitlement. The isolated official shared-track WebKit probe is sandboxed with outbound network access and `WKWebsiteDataStore.nonPersistent()`, loaded only after an explicit user action.
- The official music site/link validation rejects non-HTTPS, lookalike hosts, userinfo and non-default ports; the probe also limits **top-level** navigation to the official `/iframe` path and disallows query strings. It does **not** restrict all subframe or subresource requests, which are controlled by the loaded third-party site and WebKit.
- CI workflow runs on pull requests and main pushes. It pins GitHub actions by commit SHA; read-only contents permission at workflow level, write only for the main-push release job. Both platform matrix jobs and publishing passed post-merge, with six URL unit tests run per environment. Both packaged app bundles and arm64 architectures were checked.
- Proprietary All Rights Reserved licensing is explicit, with a third-party terms disclaimer. Distribution builds are ad-hoc signed, not notarized; documentation discloses this limitation.
- On-device user report: the official embedded player produced audio for roughly **15–20 seconds** and then stopped. User perceived the track as arbitrary; its identity and duration have not been verified. This is **partial playback evidence only**. See issue #6.

## Findings

| ID | Severity / area | Evidence | Recommended action | Status |
| --- | --- | --- | --- | --- |
| M0-B1 | **M0 blocker** / lawful playback | Official track-share iframe does not establish rights or an API for full music playback, My Wave, search, personal library, queue, or metadata. Yandex ID OAuth is not sufficient on its own. | Obtain explicit authorized service scope, or document a formal full-product no-go; never use undocumented tokens, scraped streams or DRM bypass. | OPEN, issue #1 |
| M0-B2 | **M0 blocker** / runtime evidence | Single on-device report confirms 15–20 seconds of audio, but not full-length playback, exact track identity, region/account conditions, or tests on both macOS 26 and 27. | Repeat documented-embed test with clear OS/region and visible error/preview state; retain privacy. | OPEN, issue #6 |
| M0-B3 | **Security blocker** / repository governance | `main.protected=false` and `GET /rulesets=[]` at audit time. Two real required CI job contexts already verified. | Owner to activate a no-bypass ruleset requiring PRs and both exact CI checks, then independently verify effective branch rules/PR behavior. | OPEN, issue #8 |
| M0-F1 | **Medium** / probe diagnostics | `EmbedProbeView.swift` implements a navigation-allowlist delegate but does not expose `didFailProvisionalNavigation`, `didFail`, WebContent process termination or a visible timeout/error state. A failed provider or network load may appear blank. | Add explicit, privacy-safe loading/failure UI and testable view-state handling in a focused PR without changing the original menu-bar UI. | OPEN |
| M0-F2 | **Medium** / release lifecycle | `swift.yml` publishes the hardcoded `v0.0.2-m0-embed.1` tag on main; subsequent successful pushes intentionally skip publication if the tag exists. This is safe immutability, but newer builds can be mistaken for the old downloadable prerelease. | Make future prerelease version/trigger explicit and ensure test instructions link to the matching SHA; do not overwrite immutable tags. | OPEN |
| M0-F3 | **Low–Medium** / entitlement verification | Workflow checks ad-hoc signature, executable, minimum OS and arm64. It does not explicitly assert that main's signed entitlements lack network access while the probe has it. | Add `codesign -d --entitlements` / property-list assertions to both macOS CI paths. | OPEN |
| M0-F4 | **Low** / URL/navigation contract | `OfficialSharedEmbed.allowsNavigation` checks the HTTPS origin, `/iframe` path and absence of query, but accepts arbitrary URL fragments; subframe navigation is explicitly allowed. Documentation should not imply a universal network-origin lockdown. | Document scope precisely and retain behavior until provider compatibility is characterized; expand negative URL tests if policy is tightened. | OPEN |
| M0-F5 | **Low** / coverage and operational security | Six XCTest cases cover URL validation, not actual WKWebView navigation, error presentation, permission preservation, first-run UX, accessibility, or playback. Security reporting provides no named private channel. | Add relevant tests and manual acceptance evidence; consider GitHub private vulnerability reporting. | OPEN |

## Refactoring assessment

- The current three-target split (main UI, reusable URL policy, standalone probe) is reasonable for M0. **No repository-wide rewrite, new abstraction or new dependency is justified**.
- Prefer small testable fixes around observable probe state and CI entitlement checks. Keep the existing native lueya design unchanged.
- The shared-embed experiment must remain isolated; an arbitrary native streaming engine is **not** authorized by partial audio playback.
- Scripts and CI should retain the GitHub-only workflow with an immutable build/artifact provenance trail.

## Acceptance and verification matrix

| Gate | Result |
| --- | --- |
| Full tracked-tree code/config/test/workflow/documentation review | **DONE**, this pre-acceptance review |
| On-GitHub arm64 build/test/package for macOS 26 and Xcode 27 | **PASS** at #41711659060; six core tests per environment |
| On-device official embed starts audio | **PARTIAL PASS** (15–20 seconds, user report) |
| Full authorized Yandex Music playback & metadata | **BLOCKED / not demonstrated** |
| Main branch protection effective | **NOT YET VERIFIED** |
| Audit findings remediated and regression checked | **PENDING** |
| M0 milestone accepted / M1 started | **NO** |

## Reference sources

- Official shared-track embed: https://www.yandex.ru/support/wiki/ru/actions/iframe
- Yandex Music conditions: https://yandex.ru/legal/music_termsofuse/ru
- Yandex ID application registration: https://www.yandex.ru/dev/id/doc/ru/register-client
- Apple ephemeral WebKit website data: https://developer.apple.com/documentation/webkit/wkwebsitedatastore/nonpersistent()
- GitHub run #41711659060: https://github.com/StanleyLl0yd/lueya/actions/runs/41711659060
- Issues: [#1](https://github.com/StanleyLl0yd/lueya/issues/1), [#6](https://github.com/StanleyLl0yd/lueya/issues/6), [#8](https://github.com/StanleyLl0yd/lueya/issues/8)

**Decision:** Keep M0 OPEN. The full tracked-tree pre-acceptance audit is documented, but M0 cannot be accepted until the external authorization/playback decision, repository protection, relevant fixes, and final exact-head/regression verification are resolved.
