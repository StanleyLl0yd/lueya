# M0 — authenticated music integration feasibility

**Status: OPEN.** The public v0.1.0 early-access app does **not**
play audio. Technical accessibility of an unofficial API is separate
from subscriber entitlements and permission to distribute a client.

## Evidence

- lueya implements user-initiated Yandex OAuth Device Flow using publicly
  available identifiers of a first-party Music client. They were not issued
  to lueya and may be revoked without notice.
- Swift 6 account status, session refresh, local macOS Keychain and sign-out
  are implemented. A user reported successful authorization on a real Mac.
- The handwritten Swift adapter requests track metadata and direct raw
  source candidates. CI uses synthetic fixtures, never real credentials.
- The v0.0.4 test with track 99338938 returned an ambiguous unavailable
  error. v0.1.0 separates metadata-unavailable, provider HTTP 403 and
  absence of a compatible raw stream. None proves the track is blocked
  in the official application.
- In-app AVPlayer playback, playlists, search and My Wave are not ready.

## Boundaries

Follow [Yandex Music terms](https://yandex.ru/legal/music_termsofuse/ru)
and [Yandex ID OAuth documentation](https://yandex.ru/dev/id/doc/ru/register-api).
A service subscription or account token does not by itself authorize
independent streaming-client distribution. No password or browser-cookie
extraction, externally hosted token storage, DRM bypass, offline music
or permanent copyrighted media files.

API requests require ephemeral HTTPS, fixed host and redirect rejection.
Encrypted tracks cannot be decoded by circumvention. Before native media
playback, verify a controlled in-memory HTTP resource loader with safe
redirect behavior and no OAuth credential forwarding.

M0 acceptance requires live account/stream proof, audio past 30 seconds
and through completion, controls and error recovery, macOS 26/27 checks,
provider permissions, and a complete repository-wide security and
architecture audit. Otherwise record an explicit NO-GO.

See [M0 parent issue](https://github.com/StanleyLl0yd/lueya/issues/1).
