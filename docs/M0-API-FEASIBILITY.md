# M0: authenticated Music API feasibility — 2026-11-04

**Decision:** API-first. The anonymous shared-track WebKit probe is retired from the active test plan. No full Yandex Music streaming interface has yet been authorized or validated.

## Evidence and source distinction

| Surface | What is established | What is not established |
| --- | --- | --- |
| Official Yandex Music terms | User authorization is normally required for access to protected tracks. | A subscription or Yandex ID login does **not**, by itself, grant third-party application distribution or streaming API permission. |
| Yandex ID OAuth | Developers can register their own OAuth clients and request service-specific scopes. | A Music-specific streaming scope available to independent macOS clients has not been identified in official public documentation. |
| Official music-artist Partner API | The documented Partner API serves Bandlink smartlinks using `api.band.link`. | It is **not** a consumer playback SDK. |
| MarshalX `yandex-music-api` 3.2.2 (2026-10-11) | Unofficial community-maintained reverse-engineered interface, about 150 documented OpenAPI methods covering account, search, playlists, radio, My Wave and device/queue synchronization via Ynison. Documents 30-second anonymous preview limits and device-code OAuth. | It is **not** an official Yandex Music SDK or proof that independent apps are licensed to play protected tracks. Upstream `device_auth` may use Yandex's embedded Android application client ID by default; lueya must **not reuse another app's client identity**. |
| Native macOS | `URLSession` can make HTTP requests; `AVPlayer` can play provider-permitted media URLs. | Neither supplies a Music account permission, a licensed audio URL, a working session or My Wave on its own. |

Sources: [Music terms](https://yandex.ru/legal/music_termsofuse/ru), [Yandex ID OAuth](https://yandex.ru/dev/id/doc/ru/register-api), [Yandex artist Partner API](https://yandex.com/support/music-artists/ru/performers-and-copyright-holders/partners-api), [unofficial implementation](https://github.com/MarshalX/yandex-music-api), [unofficial OpenAPI 3.2.2](https://ym.marshal.dev/api/openapi.json).

## Candidate architecture

- **Native Swift 6** `MusicProvider` interface to abstract authenticated account status, track metadata/search, playlists, radio sessions and actual playback authorization.
- `URLSession` with an ephemeral session, no cookies/cache, HTTPS-only trusted host and redirect rejection for any authorization-bearing request.
- Explicit user-controlled Yandex ID authorization with a **lueya-owned** OAuth client and Music permissions, if these can be established. Tokens stay in macOS Keychain, never GitHub, logs, URL query strings or app-owned analytics.
- `AVPlayer` or another Apple audio framework only after confirming that the provider permits returning usable stream URLs to this client. Do not derive streaming URLs by defeating DRM, extract another application's private token or store copyrighted media.
- Ynison may synchronize playback and remote device state; it does **not** independently provide audio for a native player.
- Main SwiftUI menu-bar design remains **unchanged** until the next design pass. Main app retains its current network-disabled App Sandbox until an authorized API mode is approved.
- Zero third-party runtime dependencies by default. The MarshalX project is LGPL-3.0-only; incorporating its code or generated OpenAPI client would require a separate provenance, license and maintenance review. The initial Swift code is handwritten, not vendored from the library.

## Implemented research foundation (unreleased)

`Sources/LueyaCore/YandexMusicAPIClient.swift` provides a concrete, read-only HTTP client for **`GET https://api.music.yandex.net/account/status`**, using the endpoint documented in the unofficial OpenAPI spec. It takes a caller-provided OAuth token; it does not obtain or persist credentials, does not run in the main app and cannot play music. It limits requests to the fixed endpoint, uses ephemeral networking, rejects redirects and classifies authentication, quota, HTTP and parsing failures.

`Tests/LueyaCoreTests/YandexMusicAPIClientTests.swift` uses an entirely synthetic transport and sample payload; no account, subscription, network call or token is exercised in CI. This is a **testable client transport foundation**, not an end-to-end connection.

## M0 go/no-go gate

1. Establish a permitted lueya-owned OAuth client flow with Music-specific read/playback scope (or obtain express provider permission).
2. Test authenticated status/metadata using a real user's own account **only on a physical Mac** with explicit consent and no credential sharing.
3. Prove lawful full-track audio (not a 30-second preview), session renewal, pause, seek, queue and My Wave where permitted.
4. Confirm macOS 26 + 27 compatibility, error/revocation and region behavior; keep secrets local.
5. Complete full repository-wide audit and pass exact-head CI before M0 acceptance.

If Music scopes or legal permissions are unavailable, record **NO-GO for a native full-player API** rather than treating reverse-engineered behavior as official authorization. See [issue #13](https://github.com/StanleyLl0yd/lueya/issues/13), [M0 parent #1](https://github.com/StanleyLl0yd/lueya/issues/1). The previous [shared-track experiment #6](https://github.com/StanleyLl0yd/lueya/issues/6) is closed as de-scoped.
