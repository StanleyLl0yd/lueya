# M0 — authenticated music integration feasibility

**Status: OPEN.** The v0.4.0 experimental AVPlayer adds bounded signed-source
renewal and native synthetic AAC loader tests, but full-length playback with
user-authorized provider media has **not** been verified on a Mac.
Technical accessibility of an unofficial API is separate from subscriber
entitlements and permission to distribute a client.

## Evidence

- lueya implements user-initiated Yandex OAuth Device Flow using publicly
  available identifiers of a first-party Music client. They were not issued
  to lueya and may be revoked without notice.
- Swift 6 account status, session refresh, local macOS Keychain and sign-out
  are implemented. A user reported successful authorization on a real Mac.
- The handwritten Swift adapter requests track metadata and direct raw
  source candidates. CI uses synthetic fixtures, never real credentials.
- Physical-Mac v0.2.0 research with track 99338938 confirmed metadata
  and an `aac-mp4 / hq` raw URL candidate. It did **not** confirm playable
  media bytes, track completion or provider permission.
- v0.3.0 adds a private, bounded in-memory HTTPS range loader to native
  AVPlayer, with Play/Pause/Stop/Seek. v0.4.0 adds renewal of expired
  signed media sources through the current authenticated session, with
  strict track/codec/quality and retry guards. Native CI uses original
  generated AAC to test AVAsset resource-loading behavior; this is not an
  end-to-end provider playback test. Playlists, search and My Wave are absent.

## Boundaries

Follow [Yandex Music terms](https://yandex.ru/legal/music_termsofuse/ru)
and [Yandex ID OAuth documentation](https://yandex.ru/dev/id/doc/ru/register-api).
A service subscription or account token does not by itself authorize
independent streaming-client distribution. No password or browser-cookie
extraction, externally hosted token storage, DRM bypass, offline music
or permanent copyrighted media files.

API requests require ephemeral HTTPS, fixed host and redirect rejection.
Encrypted tracks cannot be decoded by circumvention. The first native
resource-loader implementation never passes an OAuth header to media
hosts, requires allowlisted CDN HTTPS and valid partial-content responses,
and refuses redirects. Runtime behavior remains to be verified on-device.

M0 acceptance requires live account/stream proof, audio past 30 seconds
and through completion, controls and error recovery, macOS 26/27 checks,
provider permissions, and a complete repository-wide security and
architecture audit. Otherwise record an explicit NO-GO.

See [M0 parent issue](https://github.com/StanleyLl0yd/lueya/issues/1).
