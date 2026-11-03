# lueya 0.0.4 — M0 authenticated raw-stream source check

This is an **unofficial experimental diagnostic prerelease** for Apple
Silicon on macOS 26 or 27, **not** a working music player. lueya is not
affiliated with or endorsed by Yandex.

## What can be tested

- User-initiated Yandex OAuth Device Flow, an account-status check,
  per-user local Keychain storage and session restore/sign-out.
- In the signed-in menu bar panel, enter a **numeric track ID** from a
  track in your own Yandex Music library and choose **Check**.
- The app requests track metadata and tries to resolve an authenticated,
  direct `raw` media candidate through the unofficial provider protocol.
  It displays only the track name, codec, quality, or a safe error.
- Network access uses ephemeral HTTPS and no request redirects for
  authenticated API calls. Signed audio CDN URLs are **never displayed
  or copied** by the diagnostic panel.
- The existing warm-glass menu bar UI remains largely unchanged.

## What this does not prove

- **No audio playback.** Resolving a CDN URL is not proof that the
  media is a complete track, that playback exceeds 30 seconds or that
  the source can be consumed by AVPlayer.
- FLAC/FLAC-MP4 and encrypted `encraw` transports are unsupported in
  the current native candidate allowlist. Some tracks and regions may
  not provide compatible `raw` media.
- The unofficial OAuth and media endpoint details can be changed or
  revoked; public client identifiers/signing material are not issued
  to lueya. The provider's licensing/distribution policy is not
  established by technical API accessibility.
- There is **no offline mode** and there never will be one.

## Download and verify

From **this exact GitHub prerelease**, download
`lueya-macos-arm64-m0-stream-check.zip` and `SHA256SUMS.txt`.

```sh
shasum -a 256 lueya-macos-arm64-m0-stream-check.zip
```

Compare the digest with the matching line in `SHA256SUMS.txt`, then
extract and open `lueya.app`. These artifacts are ad-hoc-signed,
**not notarized**. Do not disable Gatekeeper. Following checksum
verification, use System Settings → Privacy & Security → Open Anyway
only if that option is offered, or report a blocked launch.

## Safe feedback

Report your macOS version; whether Device Flow and Keychain restore
worked; whether a numeric track ID returned a candidate, unsupported
codec, forbidden/unauthorized result, or another error. If possible,
include only the generic status text from the app and whether the
track is expected to be accessible with your subscription.

**Never share** passwords, OAuth tokens, active device codes, signed
media URLs, browser cookies or account-specific screenshots.

M0 and [issue #16](https://github.com/StanleyLl0yd/lueya/issues/16)
remain OPEN until a safe in-memory AVPlayer media transport is ready,
full-length playback is validated with a user's own account, provider
rights are reviewed and the mandatory repository-wide audit passes.
