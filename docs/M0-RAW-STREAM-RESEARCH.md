# M0 — raw streaming source negotiation

Status: **experimental metadata check, not audio playback**.

The native Swift 6 adapter requests user-authorized metadata and signed
short-lived source candidates through an unofficial interface. It tries
lossless, hq and nq in bounded order; the provider's returned quality,
transport and codec determine eligibility. AAC/MP3 candidates may be
natively decoded; FLAC/FLAC-MP4 have not been validated across macOS 26
and macOS 27 and are not currently advertised as supported.

Transport `raw` is potentially eligible. Encrypted `encraw` is
unsupported; the app does not use decryption keys or bypass DRM.

## Security

- API requests go via ephemeral HTTPS to a fixed service origin, with
  redirect rejection, no cookies and no disk cache.
- Signed media URLs are restricted to reviewed provider CDN zones,
  HTTPS only, without embedded credentials or custom ports.
- Signed URLs may themselves contain secret query values. They are
  redacted from debug descriptions and never displayed, logged or saved.
- Media links are short-lived; local freshness checks are conservative,
  not a guarantee of server validity.
- Do **not** hand provider URLs straight to AVPlayer before implementing
  a verified redirect-controlled, in-memory loading boundary that
  cannot forward OAuth authorization to arbitrary hosts.
- **Online only:** no offline cache, persistent audio or downloads.

## Real-device diagnostic

In v0.0.4, a user's own track 99338938 produced a generic unavailable
message. The old message could mean a metadata availability flag,
an HTTP 403 or simply no compatible raw source. It did not prove a
regional block. v0.1.0 distinguishes these categories without exposing
credentials. Full-length playback and provider rights remain unverified.

See [provider terms](https://yandex.ru/legal/music_termsofuse/ru)
and [issue #16](https://github.com/StanleyLl0yd/lueya/issues/16).

## v0.1.1 on-device diagnostic

The user has observed an HTTP 403 response on a track check after
successful login. The previous client did not retain which request was
rejected. The new client labels the exact stage as `track metadata`
or `audio source (lossless/hq/nq)`. These fixed labels never include
URLs, signed media query parameters, request bodies or user tokens.
The original 403 remains unexplained pending a physical-Mac retest.
