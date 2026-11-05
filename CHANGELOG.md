# Changelog

From v0.1.0 onward, public versions follow [Semantic Versioning](https://semver.org/).
Every version has release notes in [docs/releases](docs/releases).

## [0.5.2] — selectable search and resilient saved sessions

- Place search results in a dedicated, fixed-height scrolling view inside
  the compact menu-bar panel instead of clipping them beneath its footer.
- Display title, artist and duration for every result. Playing one selected
  row returns to the normal player; no automatic first-result playback.
- Migrate legacy ad-hoc-created Keychain credentials into a versioned
  entry created by the certificate-signed app. Verify the new entry before
  best-effort cleanup and retain the old copy if migration fails.
- Preserve loaded tokens in memory through network errors. An HTTP 503 or
  temporary connection failure no longer forces fresh Yandex sign-in.
- Distinguish retrying session restoration from starting a new OAuth flow.
- Add synthetic 401 and 503 restoration regression coverage.
- On-device Keychain ACL behavior and actual search panel usability remain
  pending the owner's testing. No change to the audio engine or offline policy.

## [0.5.1] — search and tactile interaction fixes

- Run catalog search automatically after a short typing debounce; Enter and
  search-arrow submit immediately, and a new query invalidates stale responses.
- Show visible search progress, no-results and retry/error states.
- Retry artist/song queries across the provider's all-category search when
  a track-only lookup is empty, retaining bounded authenticated HTTPS requests.
- Restore the spring hover and press feel from v0.4.1 for every button, with
  stronger visual feedback and Reduce Motion support.
- Add a synthetic Cyrillic artist search fallback regression test.
- Signed owner test build; actual account search and real-device animations
  still require owner verification.

## [0.5.0] — owner trial

- Replace track-ID experiment UI with an accessible native music player.
- Search catalog by song/artist; start streaming from results, skip in a temporary queue, and adjust volume.
- Apply unified hover and pressed animation to all buttons, including Sign out.
- Keep the existing Keychain session, HTTPS streaming range guards and source renewal.
- Add synthetic authenticated search tests; device/real-service acceptance remains open.
- No offline media, third-party runtime dependencies, or rights assertions.

## v0.4.1

Subtle animated hover/press reactions on Play/Pause/Stop, smooth native
symbol swap and Stop reveal; respects Reduce Motion. Clarify personal
noncommercial research intent, limited voluntary testing permission and
non-waivable liability limits in both READMEs and proprietary LICENSE.
Releases and development freeze after each owner test build until the owner
explicitly provides their findings. No changes to the audio transport.

## v0.4.0

Renew short-lived signed media URLs during playback only on HTTP 410 or
aged-source HTTP 403, using the active Keychain-backed user session. Keep
track ID, codec, quality and resource length consistent, retry each range
once and cap renewals to six per playback. Ignore large HTML error bodies
when classifying HTTP denial rather than misreporting oversized media.
Move the native asset resource loader into the tested core module and
exercise original generated AAC with AVFoundation on both CI runners:
206 ranges, expiry, redirects and cancellation. User-owned full-track
audio testing and provider distribution rights remain outstanding.

## v0.3.1

Handle AVPlayerItem failures and player time-control transitions even
before playback time advances. Add a cancellable 15-second startup
watchdog, guard stale resource-loader errors after track replacement,
and never expose sensitive system decoder error text. Native
Play/Pause/Stop/Seek and secure memory-only streaming remain unchanged.
End-to-end playback still requires a user's Mac test.

## v0.3.0

Experimental native online audio using AVPlayer and a private resource loader,
strict HTTPS byte-range transport with 128-KiB memory cap, no redirects,
OAuth headers, cookies, disk media or offline cache. Adds Play, Pause, Stop,
Seek, and signed-source renewal on replay. Synthetic security regression
tests pass; real full-track playback and provider permissions remain OPEN.

## v0.2.1

Refine the accepted warm-glass interface with a gentle, low-frequency
breathing halo in the hero artwork, a short entrance reveal, more
responsive spring hover effects and smoother source-status changes.
The background, colors, spacing and layout stay the same. Animation
stops when the panel closes and respects macOS Reduce Motion.
No new dependencies or changes to authentication, streams or storage.

## v0.2.0

Warm matte-glass menu-bar redesign: cream/champagne palette, airier
spacing, native translucent material, subtle hover motion and
accessibility fallbacks for Reduce Motion and Reduce Transparency.
Bottom-left version label now reads the signed application's bundle
version. A quality-specific HTTP 403 can fall back to the next lower
requested raw format, with regression tests and without decrypting
protected media. Real playback remains unimplemented.

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
