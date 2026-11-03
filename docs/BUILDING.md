# Building lueya

## Toolchain

- macOS 26 or 27 on Apple Silicon
- Latest stable compatible Xcode; Swift 6 language mode
- Swift Package Manager (bundled with Xcode)
- No third-party packages or generators

The Package.swift Swift tools minimum is 6.2 to build with both
Xcode 26.6 and Xcode 27.1; the installed compiler is used.

## Cloud builds and test distribution

CI performs release-mode compilation, XCTest, code signing and app
packaging on GitHub-hosted macOS runners. The Xcode 27 job preserves
a valid app bundle as a ZIP and uploads it to GitHub Actions.
The ZIP has a macOS 26 deployment target and is compiled with
our newest supported stable compiler.
After **both** macOS 26 and macOS 27 checks succeed on `main`,
the workflow publishes a clearly marked M0 prerelease for testing.
No local source clone or local Xcode build is required for testers.

See [Testing](TESTING.md) for the prebuilt app download and checks.

## Optional local developer build

```bash
xcodebuild -version
swift --version
swift test
./scripts/package-app.sh
open dist/lueya.app
```

Look for the waveform icon in the macOS menu bar, not the Dock.
Use **Quit lueya** in the menu to stop the application.

The local app receives an ad-hoc code signature. It is neither
notarized nor ready for public redistribution.

## Platform

- macOS 26 minimum; macOS 27 target
- Apple Silicon arm64
- Xcode stable toolchain with Swift 6 mode
- macOS 27-only APIs require runtime availability checks and a
  functional macOS 26 fallback.

## CI

CI builds, runs XCTest, packages the app, checks Info.plist,
verifies an arm64 Mach-O binary, and validates the local signature
on macOS 26 and the Xcode 27 (macOS 27) runner.

The Xcode 27 runner has been generally available since 2026-10-15.
CI does not substitute for interactive manual smoke tests on both OS releases.
For this project, GitHub Actions is the authoritative build and
binary distribution channel. Local builds are optional diagnostics only.

## Current limitations

This M0 preview displays a non-playing menu-bar interface and
opens the provider's official website externally. It has no
in-app authentication, track control, media engine or library.
