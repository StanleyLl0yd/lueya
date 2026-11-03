# Building lueya

## Toolchain

- macOS 26 or 27 on Apple Silicon
- Latest stable compatible Xcode; Swift 6 language mode
- Swift Package Manager (bundled with Xcode)
- No third-party packages or generators

The Package.swift Swift tools minimum is 6.2 to build with both
Xcode 26.6 and Xcode 27.1; the installed compiler is used.

## Build and run

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

The Xcode 27 runner may be in preview. CI does not substitute for
interactive manual smoke tests on both macOS releases.

## Current limitations

This M0 preview displays a non-playing menu-bar interface and
opens the provider's official website externally. It has no
in-app authentication, track control, media engine or library.
