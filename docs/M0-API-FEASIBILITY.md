# M0: authenticated Music API feasibility — 2026-11-04

**Decision:** API-first. The anonymous shared-track WebKit probe is retired from the active test plan. No full Yandex Music streaming interface has yet been authorized or validated.

## Evidence and source distinction

| Surface | What is established | What is not established |
| --- | --- | --- |
| Official Yandex Music terms | User authorization is normally required for access to protected tracks. | A subscription or Yandex ID login does **not**, by itself, grant third-party application distribution or streaming API permission. |
| Yandex ID OAuth | Developers can register general OAuth clients and request documented service scopes. | The community Music API token guide specifically states that a **custom Music-capable OAuth app cannot be created**. An official independent macOS Music streaming scope has not been found; treat this as a serious provider-access blocker, not as an established universal prohibition. |
| Official music-artist Partner API | The documented Partner API serves Bandlink smartlinks using `api.band.link`. | It is **not** a consumer playback SDK. |
| MarshalX `yandex-music-api` 3.2.2 (2026-10-11) | Unofficial community-maintained reverse-engineered interface, about 150 documented OpenAPI methods covering account, search, playlists, radio, My Wave and device/queue synchronization via Ynison. Documents 30-second anonymous preview limits and device-code OAuth. | It is **not** an official Yandex Music SDK or proof that independent apps are licensed to play protected tracks. Upstream `device_auth` uses publicly documented Android Music client identifiers; the owner explicitly **approved use in lueya on 2026-11-04** for a user-initiated Device Flow. This remains unofficial, revocable, and **not official authorization**. |
| Native macOS | `URLSession` can make HTTP requests; `AVPlayer` can play provider-permitted media URLs. | Neither supplies a Music account permission, a licensed audio URL, a working session or My Wave on its own. |

Community auth caveat: [MarshalX token guide](https://ym.marshal.dev/token/) states that a custom Music OAuth app cannot be created. The owner chose to use the **publicly documented Android OAuth client ID and publicly embedded client secret**, for **per-user first-party Yandex Device Flow login**, instead. These values are not lueya credentials; Yandex can revoke them. Never extract a private token from another app or request a user's password in lueya.

Sources: [Music terms](https://yandex.ru/legal/music_termsofuse/ru), [Yandex ID OAuth](https://yandex.ru/dev/id/doc/ru/register-api), [Yandex artist Partner API](https://yandex.com/support/music-artists/ru/performers-and-copyright-holders/partners-api), [unofficial implementation](https://github.com/MarshalX/yandex-music-api), [unofficial OpenAPI 3.2.2](https://ym.marshal.dev/api/openapi.json).

## Candidate architecture

- **Native Swift 6** `MusicProvider` interface to abstract authenticated account status, track metadata/search, playlists, radio sessions and actual playback authorization.
- `URLSession` with an ephemeral session, no cookies/cache, HTTPS-only trusted host and redirect rejection for any authorization-bearing request.
- Experimental **user-initiated OAuth Device Flow**, with public upstream client identifiers approved by the owner. Each user authenticates separately; tokens stay in this Mac's device-only Keychain. No credentials in GitHub, logs, URLs or app-owned analytics.
- `AVPlayer` or another Apple audio framework only after confirming that the provider permits returning usable stream URLs to this client. Do not derive streaming URLs by defeating DRM, extract another application's private token or store copyrighted media.
- Ynison may synchronize playback and remote device state; it does **not** independently provide audio for a native player.
- The native warm-glass SwiftUI shell is preserved; PR #15 only adds compact sign-in controls. Main App Sandbox adds `network.client` for explicit OAuth and API access; no server entitlement.
- Zero third-party runtime dependencies by default. The MarshalX project is LGPL-3.0-only; incorporating its code or generated OpenAPI client would require a separate provenance, license and maintenance review. The initial Swift code is handwritten, not vendored from the library.

## Implemented research foundation (unreleased)

`Sources/LueyaCore/YandexMusicAPIClient.swift` provides a concrete, read-only HTTP client for **`GET https://api.music.yandex.net/account/status`**, using the endpoint documented in the unofficial OpenAPI spec. It takes a caller-provided OAuth token; account status is now called by the experimental `YandexMusicSession` (PR #15) after Device Flow. The `KeychainOAuthTokenStore` holds tokens locally; no audio playback is implemented. It limits requests to the fixed endpoint, uses ephemeral networking, rejects redirects and classifies authentication, quota, HTTP and parsing failures.

`Tests/LueyaCoreTests/YandexMusicAPIClientTests.swift` uses an entirely synthetic transport and sample payload; no account, subscription, network call or token is exercised in CI. This is a **testable client transport foundation**, not an end-to-end connection.

## M0 go/no-go gate

1. Validate the explicitly selected unofficial Device Flow on a physical Mac, review real account status and record possible service restrictions or revocation risks. Obtain a separate provider/terms review before public distribution.
2. Test authenticated status/metadata using a real user's own account **only on a physical Mac** with explicit consent and no credential sharing.
3. Prove full-track **online** audio (not a 30-second preview), session renewal, pause, seek, queue and My Wave where permitted. Do **not** implement offline downloads.
4. Confirm macOS 26 + 27 compatibility, error/revocation and region behavior; keep secrets local.
5. Complete full repository-wide audit and pass exact-head CI before M0 acceptance.

If Music scopes or legal permissions are unavailable, record **NO-GO for a native full-player API** rather than treating reverse-engineered behavior as official authorization. See [issue #13](https://github.com/StanleyLl0yd/lueya/issues/13), [M0 parent #1](https://github.com/StanleyLl0yd/lueya/issues/1). The previous [shared-track experiment #6](https://github.com/StanleyLl0yd/lueya/issues/6) is closed as de-scoped.
