# lueya M0 testing — Apple Silicon macOS 26/27

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

## Standalone official shared-track embed checklist

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

Log failures, OS version, network/region, and screenshots **without
personal details or auth tokens** in
[M0 embed issue #6](https://github.com/StanleyLl0yd/lueya/issues/6).

## Not yet supported

My Wave, personalized tracks, search, history, media keys,
music-service login or a native streaming engine.

This prerelease is an experimental research artifact, not a release
candidate. Both macOS CI jobs must pass before publication.
