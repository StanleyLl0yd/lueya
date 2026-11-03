# M0 raw streaming feasibility — 2026-11-04

Status: **experimental adapter, synthetic tests only; no in-app audio yet**.
Tracked in [issue #16](https://github.com/StanleyLl0yd/lueya/issues/16).
Do not treat this code as confirmation of provider permission, subscriber
entitlement, media decoder compatibility, or full-track playback.

## Source and protocol review

- The upstream unofficial `MarshalX/yandex-music-api` `tracks_file_info`
  method uses `GET /get-file-info` with a user OAuth token and signed
  query parameters. The signature in its desktop-client variant is an
  HMAC-SHA256 over timestamp, track ID, requested quality, concatenated
  codecs and transport, with an unusual final-character truncation.
- The published desktop client identifier and signing string in the
  upstream source are **not issued to lueya**. Like the previously
  approved publicly documented mobile OAuth identifiers, they are
  unofficial dependencies that may be revoked. Their technical
  availability does **not** establish provider approval, terms compliance
  or rights to redistribute a client.
- The response may offer `raw` or `encraw`. The latter is encrypted:
  lueya does not request it, does not process decryption keys and does
  not provide circumvention. If the service only returns `encraw`,
  playback remains unavailable.
- The adapter requests `lossless`, then `hq`, then `nq` with a bounded
  three-request quality negotiation. The server can select a lower
  quality. Actual returned quality, transport and codec are validated.
- FLAC and FLAC-in-MP4 are intentionally **not** accepted by the native
  playback format allowlist until verified with AVFoundation on both
  supported macOS versions. `aac-mp4`, `mp3` and other supported AAC
  variants are currently the allowed candidates. The current adapter
  cannot claim lossless playback. Prefer native-decoding compatibility
  over a nominal requested quality.
- The track metadata request uses the upstream documented
  `POST /tracks` endpoint. Explicitly unavailable tracks cannot be
  resolved. Metadata alone is not proof of subscription or region
  authorization, which must be assessed on the user's Mac.

## Security properties

- The authenticated metadata and source-info requests go only to
  `api.music.yandex.net` over HTTPS. `EphemeralMusicHTTPTransport`
  does not persist cookies or response caches and rejects HTTP redirects.
  Each response origin and request path/query is verified.
- The returned media URL must be HTTPS with no embedded credentials,
  port or fragment, and must be within narrow known Yandex streaming
  CDN zones (`*.strm.yandex.net` or `*.storage.yandex.net`). Unknown
  future CDN hosts fail closed; broaden only after live evidence and
  security review.
- Provider media URLs can themselves contain short-lived signed query
  credentials. They must never be logged, copied to issue comments or
  persisted. The `PlayableSource` debug and text descriptions redact
  them. The client imposes a conservative 45-second maximum reuse
  window, **not** a provider-guaranteed expiry.
- **Critical playback boundary:** Directly handing a signed URL to
  `AVPlayer` would delegate HTTP redirect handling to the system,
  without an app-owned redirect policy. Do not wire a player until
  signed media URLs and any redirects have a strictly controlled path
  (e.g. a tested in-memory `AVAssetResourceLoader` transport backed by
  ephemeral `URLSession` that rejects redirects) and no OAuth headers
  are forwarded to media hosts.
- No offline mode, persistent media files, cache database or media
  download implementation. No user credentials or real media in CI.

## Next verification

1. Build and test the adapter on both GitHub macOS runners; inspect
   exact-head CI. Synthetic fixtures are not real provider responses.
2. Run the current `v0.0.3-m0-auth.1` app on the user's Mac. Confirm
   Device Flow, account status, Keychain persistence and sign-out.
3. Add an opt-in native playback prototype behind the controlled
   media-transport boundary, plus pause/seek/end/error/cancellation tests.
   Do not enable audio before resolving the redirect security design.
4. Test a subscribed user's own allowed track on device, including
   region/entitlement checks, original duration and audio beyond 30 s,
   through completion, interruption/recovery and expiring URLs.
5. Review Yandex provider terms and app distribution rights separately.
   Full repository-wide audit/security review and explicit M0 go/no-go
   are mandatory before M0 acceptance.

## Public references

- [Upstream track client](https://github.com/MarshalX/yandex-music-api/blob/main/yandex_music/_client/tracks.py)
- [Upstream signature utility](https://github.com/MarshalX/yandex-music-api/blob/main/yandex_music/utils/sign_request.py)
- [Upstream `FileDownloadInfo` model](https://github.com/MarshalX/yandex-music-api/blob/main/yandex_music/track/file_download_info.py)
- [Yandex Music service terms](https://yandex.ru/legal/music_termsofuse/ru)
