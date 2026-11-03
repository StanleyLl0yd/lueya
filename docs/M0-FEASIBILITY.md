# M0 feasibility: evidence and constraints

Status: OPEN — research and non-playing proof-of-concept, 2026-11-03.

## References and initial findings

- Apple's MenuBarExtra permits native menu-bar-only applications:
  https://developer.apple.com/documentation/swiftui/menubarextra
- WebKit has a default persistent data store for website cookies,
  but persistence alone is not permission to embed or automate:
  https://developer.apple.com/documentation/webkit/wkwebsitedatastore
- Yandex Music terms restrict use of the service, player, database,
  and materials beyond permitted personal, non-commercial use and
  the service's provided technical capabilities:
  https://yandex.ru/legal/music_termsofuse/ru

## Options

| Approach | Design | State |
| --- | --- | --- |
| Official website in external browser | Native menu bar app opens a trusted HTTPS URL | Implemented prototype baseline; not in-app playback |
| Official website embedded with WKWebView | Website auth/session and media playback | Needs rights/terms review and live testing |
| Custom streaming engine | Direct audio API and native playback | Not approved; no authorized public playback API established |

## Prototype security constraints

- No credentials, cookies, token import or session extraction.
- No DOM injection, scraping, undocumented API use or DRM bypass.
- No bundled media, playlists or provider artwork.
- No network backend, telemetry or background web automation.
- Only a predefined official HTTPS website is opened externally.

## Remaining acceptance criteria

- [ ] Identify and document a permitted in-app integration.
- [ ] Validate authentication and session persistence.
- [ ] Test real playback and media-control behavior on macOS 26/27.
- [ ] Measure resource use and accessibility.
- [ ] Decide technical and legal go/no-go with evidence.
- [ ] Run complete repository-wide security/code review and tests.

This is preliminary technical research, not legal clearance.
