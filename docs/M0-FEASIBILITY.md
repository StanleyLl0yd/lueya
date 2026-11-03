# M0 feasibility: playback and integration evidence

Status: HISTORICAL EMBED RESEARCH — superseded 2026-11-04 by [API-first feasibility](M0-API-FEASIBILITY.md). M0 remains OPEN and no full Yandex Music integration is approved.

## Confirmed public capabilities

1. Yandex Music offers a **documented HTML track-sharing embed**:
   https://www.yandex.ru/support/wiki/ru/actions/iframe
   The service's own help gives the example
   `https://music.yandex.ru/iframe/#track/71263/419460` and
   instructs users to obtain embeds via **Share → HTML code**.
   This documents **sharing individual tracks**, not control of
   personal queues, My Wave, likes, search or subscription playback.
2. Apple WKWebView is available for embedding first-party web content.
   `WKWebsiteDataStore.nonPersistent()` keeps web site data in memory:
   https://developer.apple.com/documentation/webkit/wkwebsitedatastore
3. Yandex ID OAuth supports registered applications and PKCE but
   those tokens **do not automatically confer Yandex Music streaming
   permissions**: https://yandex.ru/dev/id/doc/ru/codes/code-url
4. Yandex Music terms restrict reuse, copying and redistribution of
   the service/player/data beyond the technical possibilities offered:
   https://yandex.ru/legal/music_termsofuse/ru

## Evidence matrix

| Option | Authority | Implementation | Current conclusion |
| --- | --- | --- | --- |
| Open official website | Public URL | lueya native menu bar | Available; playback remains outside app |
| Official shared-track embed | Yandex Wiki Share → HTML | Separate opt-in WKWebView diagnostic | On-device audio starts but stops at ~15–20 seconds; complete playback and service restrictions unverified |
| Full website within WKWebView | Generic WebKit API, no explicit service authorization established | Not implemented | Needs permission/terms and compatibility review |
| Native Yandex streaming/Ynison | Unofficial community reverse engineering, no public licensed Music playback API established | Not implemented | Not authorized for project at present |
| Yandex ID OAuth | Official identity scopes | Not implemented | Doesn't solve Music playback rights |

## Historical isolated native embed test (further testing cancelled)

Issue [#6](https://github.com/StanleyLl0yd/lueya/issues/6)
tracks a separate `LueyaEmbedProbe` app. It:

- Opens the exact **published** shared-track player, not a custom API.
- Makes **no network request** until a user selects Load.
- Uses a **nonpersistent WebKit website data store**.
- Has an independent App Sandbox with only outbound network permission;
  the regular lueya app keeps its network entitlement disabled.
- Does not request login, capture passwords or extract cookies/tokens.
- Adds no injection, site scripts, custom stream extraction or DRM bypass.
- Intends to reject **top-level** navigation away from the known official embed origin/path; however Xcode 27 exposed a Swift 6 `WKNavigationDelegate` signature mismatch. [Fix PR #11](https://github.com/StanleyLl0yd/lueya/pull/11) is now MERGED with 2/2 macOS CI PASS and no delegate signature warning, but an on-device negative-navigation test is still required before claiming effective runtime enforcement. WebKit subframes and provider-managed subresources are not globally restricted.
- Does not save a music catalog, account details, or audio to disk.

This limited technical study does not establish broad rights to
distribute a Yandex Music client or modify the Yandex player.

## On-device user report — 2026-11-03

The released `lueya-embed-probe.app` loaded an apparently arbitrary track and produced audible playback for approximately **15–20 seconds**, then stopped on a real Mac. Track identity, expected duration, exact OS version, network region, subscription/account state, and the failure/preview UI were not reported. This is **PARTIAL PASS** for basic WebKit audio, **not** proof of full-length playback or rights to integrate with the user's Music account. A provider preview limit is a hypothesis, not a verified cause. See [issue #6](https://github.com/StanleyLl0yd/lueya/issues/6#issuecomment-6614721015).

A [full tracked-tree pre-acceptance audit](M0-REPOSITORY-AUDIT-2026-11-03.md) is documented. Branch protection is ACTIVE (ruleset #26484158; issue #8 closed), signed-entitlement CI is merged in PR #10, and WebKit delegate/diagnostic improvements are merged in PR #11. Remaining audit findings and runtime verification still need resolution. No M0 acceptance or M1 transition is authorized.

## Updated decision

The owner explicitly ended additional unauthenticated iframe testing on 2026-11-04.
A community client documents approximately **30-second anonymous previews**,
consistent with the observed shorter playback. The probe stays as recorded
research evidence only; issue #6 is CLOSED / not planned for further work.

From now on the active M0 work is [authenticated API feasibility](M0-API-FEASIBILITY.md)
and [issue #13](https://github.com/StanleyLl0yd/lueya/issues/13).
No credentials or music are included in GitHub; no user account is connected.
This historical report must not be mistaken for the current test plan.
