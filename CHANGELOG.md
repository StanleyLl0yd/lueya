# Changelog

From v0.1.0 onward, public versions follow [Semantic Versioning](https://semver.org/).
Every version has release notes in [docs/releases](docs/releases).

## v0.1.1

Correctly identify which request stage the music service denied:
track metadata versus raw audio source (with quality). The UI now
reports stage-specific HTTP failures without including sensitive
request URLs, tokens or provider payloads. Provider access is still
under investigation; this does not implement audio playback.

## v0.1.0

First regular early-access build: native macOS interface, per-user login,
local Keychain session and non-playing online track check. Improved
source-error diagnosis, bilingual README, compact arm64 packaging and
permanent versioned GitHub release ZIP. **Audio playback is not available.**

Earlier v0.0.x releases were experimental previews.
