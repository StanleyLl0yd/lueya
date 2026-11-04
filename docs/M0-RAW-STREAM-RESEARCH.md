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

## v0.2.0 quality negotiation observation

The user's real v0.1.1 test of track `99338938` confirmed
successful metadata retrieval and a quality-specific HTTP 403 at
`hq`. The previous implementation stopped immediately and did not
attempt the planned lower `nq` raw quality. v0.2.0 attempts the
lower format after per-quality 403, without retrying HTTP 401/429,
decrypting `encraw` or bypassing access controls. If no separately
permitted raw source is returned, the lookup fails as before.
This does **not** establish access rights or full-length playback.
A physical-Mac retest is necessary.

## v0.3.0 native streaming experiment

AVPlayer now receives a private `lueya-stream://` identity rather than
a signed CDN URL. Its asset resource delegate obtains data through a
separate HTTPS byte-range client that enforces the CDN allowlist,
response origin identity, rejection of redirects, a maximum 128 KiB
of memory per request, Content-Range and MIME verification, strict
length checks, no cookies and no provider OAuth headers.

Data remains in memory and is handed to AVFoundation in segments.
No file downloads, offline mode, persistent media cache or decrypting
encraw media are introduced. Play, Pause, Stop and Seek are available
only for a resolved candidate. Replaying an expired link triggers a
new source lookup under the user's session. Sign-out cancels playback.

Physical Mac evidence before this release established raw AAC-MP4 hq
source discovery for track 99338938, but **not actual audio bytes**.
The resource-loading delegate and full-track end-to-end playback
cannot be proven through the synthetic transport CI. CDN responses
that require redirects may fail closed until reviewed; never disable
the safety guards without a specific tested provider behavior.
Track expiry mid-stream, network recovery and distribution rights
still require validation. The M0 repository-wide audit and explicit
go/no-go remain pending.
