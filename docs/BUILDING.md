# Building lueya through GitHub

All canonical sources, code reviews, builds, test logs, and preview
artifacts live on GitHub. No local Xcode, source clone or Git repository
is required to download and test the app.

## Toolchain and compatibility

- Apple Silicon (arm64), macOS 26 deployment minimum, macOS 27 target
- Latest compatible stable Xcode and Swift 6 language mode
- SwiftPM tools floor 6.2 for cross-Xcode compatibility
- Zero third-party package dependencies

## Build and test workflow

[Native Swift validation](https://github.com/StanleyLl0yd/lueya/actions/workflows/swift.yml)
runs on macOS 26 and Xcode 27:

```bash
swift build --configuration release
swift test --parallel
./scripts/package-app.sh
./scripts/package-app.sh embed-probe
```

Each generated bundle is verified for executable, arm64 architecture,
macOS 26 minimum, and ad-hoc code signature. Xcode 27 produces
independent ZIPs using `ditto`, and each is extracted and verified
again before upload as an unwrapped GitHub Actions artifact.

On protected `main` after both platform jobs succeed, the pipeline
publishes a versioned **prerelease** with the app ZIP and SHA-256 checksum.
Existing tags are never overwritten.

See [Testing](TESTING.md) and [M0 feasibility](M0-FEASIBILITY.md).

## Sandbox and privacy

The main lueya app uses outbound HTTPS for experimental OAuth, account
status and user-initiated raw media source lookup. User tokens remain
in macOS Keychain, while API networking uses ephemeral sessions with
cookies/caches disabled. Source lookup does not load or save audio.
The separate historical WebKit probe is de-scoped. No provider media
or secrets are committed to GitHub.

These builds are **ad-hoc signed and not notarized**, so they may
be rejected by Gatekeeper and are not suitable for public distribution.
A future Developer ID signing/notarization process remains required.

## Local developer diagnosis (optional)

For developers who choose to work locally, the commands above produce
`dist/lueya.app` and `dist/lueya-embed-probe.app`. The project does
**not** require this local workflow from users or testers.
