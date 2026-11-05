# lueya M0 historical preview testing — Apple Silicon macOS 26/27

**2026-11-04:** further testing of the anonymous shared-track WebKit
probe is discontinued by project decision. This page documents the
previous preview only. The current API-first plan is
[here](M0-API-FEASIBILITY.md). The historical OAuth experiment is documented [here](AUTH-RESEARCH-RELEASE-NOTES.md).
The current feedback-driven signed test candidate is [v0.5.4](releases/v0.5.4.md).
Use the current release for M0 audio tests; the old embed tests below are
preserved as historical evidence only.

**Development and builds remain on GitHub.** To test, download
only the built application ZIP(s), not the source code.

## Download and verify

Open [v0.0.2 M0 research prerelease](https://github.com/StanleyLl0yd/lueya/releases/tag/v0.0.2-m0-embed.1).
Get the ZIP you need and the accompanying `SHA256SUMS.txt`:

- `lueya-macos-arm64-m0-preview.zip` — existing native menu-bar shell
- `lueya-embed-probe-macos-arm64-m0.zip` — standalone embed test

Put the ZIPs and checksum file into the same folder. To verify a
downloaded ZIP without downloading the other one:

```bash
shasum -a 256 lueya-embed-probe-macos-arm64-m0.zip
```

Compare its output with the matching line in `SHA256SUMS.txt`.
If both ZIPs are present, `shasum -a 256 -c SHA256SUMS.txt`
checks both. Refuse any mismatch.

## Launch

Unzip either file and open the contained `.app` on an arm64 Mac
running macOS 26 or 27. No Xcode, developer checkout or compilation
is required.

**Important:** These builds are ad-hoc signed, not Apple Developer ID
notarized. Gatekeeper may block them. Do not disable Gatekeeper.
After independent checksum/source verification, System Settings
→ Privacy & Security may offer **Open Anyway**. If not, report
the block for a notarized build.

## Menu-bar app checklist

- [ ] Launches with only a menu bar icon (no Dock window)
- [ ] Clicking it shows the compact lueya preview
- [ ] UI is legible at current resolution and system appearance
- [ ] Opens official Yandex Music website in default browser
- [ ] Quit works and relaunches

## Historical standalone shared-track embed checklist (no new tests)

The probe is **not** the eventual player UI.

- [ ] Launches as a separate standard window, before network access
- [ ] Shows a Load button and network-off notice
- [ ] Clicking Load displays Yandex's published embed, or a clear
      network/region/provider error (record which)
- [ ] User-initiated Play on the embedded player produces audio, if
      available in the selected region — **report outcome**
- [ ] No Yandex password is requested by lueya
- [ ] No external browser/account access occurs unexpectedly
- [ ] Closing and reopening does not retain a sign-in session
- [ ] The main lueya menu bar app remains unaffected

The historical outcome (~15–20 seconds of audio) is recorded in
[closed issue #6](https://github.com/StanleyLl0yd/lueya/issues/6).
Do not perform additional manual tests for this legacy probe.

## Historical limitations

This archived prerelease did not contain account login, a native
streaming engine, My Wave, search or media-key support. Current
functionality is documented in the v0.4.0 release notes above.
The old embed probe must not be used as a test for full-track playback.

## Player interaction acceptance matrix (v0.5.4)

This is the developer's verification scope, **not an end-user button-by-button checklist**.
The owner is expected to assess the overall build; the developer owns regressions.
Source inspection does not count as a completed on-device interaction test.

| Surface | States and interactions to verify |
| --- | --- |
| Sign in | Hover, pressed, code request, Copy, Open sign-in page, Cancel, retry on failure |
| Sign out | Hover, pressed, visible transition, player cancellation, Keychain removal and signed-out state |
| Search | All/Songs/Artists scope, scroll through multiple results, select actual artist and track, click rows at every scroll offset and buttons with cursor over results, empty input, errors, rapid queries |
| Track rows | Hover, pressed, selecting during playback, rapid selection, long text truncation, keyboard focus and VoiceOver |
| Play/Pause | Hover, pressed, icon change, buffering, play/resume/stop/replay, stale-source renewal |
| Previous/Next | Disabled boundary, previous after 3 seconds, prev/next during playback, automatic queue advancement |
| Stop/Seek/Volume | Disabled and active states, scrubbing, pause/resume after seek, clamp volume to [0,1] |
| Quit | Hover, pressed, application exits and playback stops |
| Accessibility | Reduce Motion, Reduce Transparency, keyboard navigation, focus, accessible labels |
| macOS | macOS 26 and 27; native arm64 ad-hoc package, no network redirect or token leakage |

Do not mark the matrix as complete until each interaction has been verified
on an actual macOS build and relevant synthetic transport tests pass.
The feedback-authorized signed test release must be delivered only after CI and package integrity
verification; afterward the owner-feedback freeze resumes.

## Signing and session continuity (v0.5.0 and later)

CI can check code identity, not the owner's existing macOS Keychain ACL.
No real OAuth credentials or private tokens are ever used in CI.

- [ ] Owner's `.p12` imported only in the protected `lueya-signing` job;
      fingerprint matches the pinned public SHA-256 and has Code Signing EKU
- [ ] Release ZIP contains the certificate-signed arm64 app, not the ad-hoc
      artifact from the ordinary PR build
- [ ] `codesign --verify --strict` and a separately resigned build-number
      variant have identical non-cdhash Designated Requirements
- [ ] Test one-time ad-hoc v0.4.1 → certificate-signed upgrade without
      deleting the original Keychain item; a one-time ACL prompt is possible
- [ ] v0.5.3 preserves the v0.5.2 Keychain account; v0.5.2 reads legacy `oauth-session` once and migrates it to the
      same-service `oauth-session-v2` only after verifying a complete copy.
      Confirm no repeated access prompt on reopen or restart.
- [ ] Subsequent builds with the same certificate restore the account
      without a new Yandex login; temporary network failures do not
      initiate OAuth device authorization.
- [ ] Relaunch and Mac reboot retain the session; explicit Sign out removes
      the Keychain entry and does not allow playback after logout
- [ ] Expired/revoked token is distinguished from missing entitlement or
      denied Keychain access; no silent session deletion on read failure
- [ ] macOS Gatekeeper behavior documented separately: a self-signed
      certificate is not Developer ID/notarization

Signed-package verification remains **PENDING** until the protected signing
smoke job has actually run with the owner's uploaded identity. The final
macOS-session checks remain pending an actual device migration.
