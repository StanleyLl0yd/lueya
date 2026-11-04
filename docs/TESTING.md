# lueya M0 historical preview testing — Apple Silicon macOS 26/27

**2026-11-04:** further testing of the anonymous shared-track WebKit
probe is discontinued by project decision. This page documents the
previous preview only. The current API-first plan is
[here](M0-API-FEASIBILITY.md). The historical OAuth experiment is documented [here](AUTH-RESEARCH-RELEASE-NOTES.md).
The current experimental native playback build is [v0.4.0](releases/v0.4.0.md).
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
