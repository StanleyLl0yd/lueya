# lueya v0.0.2 — M0 native preview + official shared-track experiment

**Developer test build only. Not a working Yandex Music client.**

The download contains **two independent applications**:

- `lueya.app` — the unchanged native SwiftUI menu-bar interface,
  with a link opening the official music website in your browser.
- `lueya-embed-probe.app` — a standalone research-only WKWebView
  experiment that loads one **officially documented** Yandex Music
  shared-track embed, **only after a user clicks Load**. It does
  not authenticate, load a private API or control other Yandex tracks.

The embed app has an ephemeral (nonpersistent) WebKit data store,
separate sandbox and outbound network permission. The main lueya
app remains offline and has no network entitlement.

**Unknown until manual test:** whether the published example can
actually play sound on your OS/region. Success is not asserted.

**Not implemented:** Yandex Music account, My Wave, native track
controls, queue, recommendations, search, likes or offline music.

Each ZIP is built and verified by GitHub Actions using Xcode 27,
with compilation/XCTest and bundle checks passing on macOS 26 and 27.
There are no third-party Swift packages, ads or app-owned telemetry.

Assets: `lueya-macos-arm64-m0-preview.zip`,
`lueya-embed-probe-macos-arm64-m0.zip`, and `SHA256SUMS.txt`.

These applications are ad-hoc signed, **not notarized**. Gatekeeper
may block them. Never disable system protections. See
[Testing](https://github.com/StanleyLl0yd/lueya/blob/main/docs/TESTING.md).

Independent and unofficial; no affiliation with or endorsement
by Yandex. Proprietary All Rights Reserved project.
