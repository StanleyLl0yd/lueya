# Testing the lueya M0 preview

**This build is a native UI prototype, not a music player.**

## Requirements

- Mac with Apple Silicon (arm64)
- macOS 26 or macOS 27
- No Xcode, local source checkout or local Git repository required

## Download from GitHub

Open the [M0 testing prerelease](https://github.com/StanleyLl0yd/lueya/releases/tag/v0.0.1-m0-preview.1)
and download the two assets:

- `lueya-macos-arm64-m0-preview.zip`
- `SHA256SUMS.txt`

On macOS, with both files in the same folder:

```bash
shasum -a 256 -c SHA256SUMS.txt
```

The result must say `OK`. If it does not, do not open the app.

Unzip the file in Finder and launch `lueya.app`. The app lives in the
menu bar (waveform icon), **not** the Dock. Only the downloaded app
needs to exist on your Mac for testing; development and compilation
stay exclusively in GitHub.

## macOS Gatekeeper

This M0 preview has an **ad-hoc code signature**, not a trusted
Developer ID signature, and has **not been notarized**. Gatekeeper
may prevent it from launching. Do not disable Gatekeeper or install
untrusted profiles. After verifying the GitHub source and SHA-256
checksum, you may use the macOS System Settings > Privacy & Security
**Open Anyway** option, if your system offers it. Otherwise, report
the block; a future notarized build will remove this limitation.

## Manual test checklist

- [ ] The app launches without a Dock window.
- [ ] A waveform icon appears in the menu bar.
- [ ] Clicking the icon opens a compact, legible warm-glass popover.
- [ ] The content is not clipped at default display scaling.
- [ ] Text and buttons remain usable in light and dark system modes.
- [ ] Keyboard navigation / VoiceOver can reach the button and Quit.
- [ ] **Open official Yandex Music** launches the official site in
      the default browser; lueya never asks for account passwords.
- [ ] **Quit lueya** terminates the process and clears the menu icon.
- [ ] The app can be reopened without crashing.

Do not expect: playback, login, track metadata, search, library,
media keys or My Wave. These features have not been implemented.

Record your macOS version, Apple Silicon model, scaling settings,
the step that failed, and any screenshots in
[the M0 issue](https://github.com/StanleyLl0yd/lueya/issues/1).

## Build provenance

The GitHub Actions [Native Swift validation](https://github.com/StanleyLl0yd/lueya/actions/workflows/swift.yml)
workflow runs actual build, XCTest, code-signature and architecture
checks on macOS 26 and 27 before publishing the test prerelease.
The release tag points to the exact tested `main` commit.

This is not a production release and is not signed for general
macOS distribution.
