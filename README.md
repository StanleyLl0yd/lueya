# lueya

**A softer way to listen.**

**English** · [Русский](README.ru.md)

lueya is a minimal native macOS companion for Yandex Music, designed for
quiet listening and a compact menu-bar experience. Independent and unofficial.

## Available today

- Airy, warm matte-glass menu-bar interface with soft light and subtle motion.
- Sign in to your own Yandex account using a code and the official login page.
- Restore and end sessions securely via macOS Keychain.
- Native online AAC/MP3 playback with Play/Pause, Stop, Seek, Volume and limited signed-source renewal.
- Authenticated song/artist search, selection and a temporary in-memory next/previous queue.

**v0.5.2 responds to the owner's v0.5.1 testing.** Search results now
have their own compact scrolling panel with clear title, artist and duration;
click the desired song to play it. Saved-session recovery and Keychain entry
migration have been improved to reduce repeated account logins and prompts.
The first migration may still require macOS Keychain consent, and real
on-device continuity remains to be verified. No offline mode. The unofficial
integration remains subject to provider restrictions.

## Download

**After each version, development and releases pause until owner feedback.**
That feedback authorizes the next repair-and-release cycle without a separate
version-specific approval; feedback is not acceptance.

**[Download lueya 0.5.2 for macOS (ZIP)](https://github.com/StanleyLl0yd/lueya/releases/download/v0.5.2/lueya-0.5.2-macos-arm64.zip)**

[Verify SHA-256](https://github.com/StanleyLl0yd/lueya/releases/download/v0.5.2/SHA256SUMS.txt) ·
[All releases](https://github.com/StanleyLl0yd/lueya/releases)

Requires an **Apple Silicon Mac** running **macOS 26 or later** (macOS 27
supported). The v0.5.2 distribution is signed with a persistent self-signed research certificate, but not notarized or Developer ID-signed by Apple.
macOS may block launch; after verifying the checksum, use
System Settings → Privacy & Security → Open Anyway *if offered*.
Do not disable Gatekeeper.

## Built to stay light

Swift 6, SwiftUI and AppKit. No Electron, ads, app-owned analytics,
custom login server, or third-party runtime dependencies. Each listener
signs in individually. **Online music only, without offline downloads**
or permanent local audio storage.

## Personal research and voluntary testing

lueya is a personal, noncommercial research and interoperability experiment:
it is built and evaluated solely for technical study. It is not an official
client or a commercial product and is not intended for general commercial
distribution. The public repository and test binaries exist to support
transparent research and voluntary evaluation, not unrestricted redistribution.

People who independently wish to help test are welcome to do so on a
voluntary, noncommercial basis. Experimental builds are provided **"AS IS"**
and without warranties to the maximum extent permitted by applicable law.
Participation is at the tester's own risk; the developer disclaims liability
for resulting loss to the extent permitted by law, **without excluding any
liability that cannot legally be excluded**. Testers must use their own
credentials and are responsible for compliance with applicable laws and
third-party service terms. This project grants no permission to access a
third-party service or use copyrighted media beyond existing lawful rights.

See [LICENSE](LICENSE) for the limited permission to run unmodified official
test binaries. No permission to redistribute project materials is implied.

## Development

[Personal macOS signing](docs/SIGNING.md) · [Roadmap](docs/ROADMAP.md) · [Issues](https://github.com/StanleyLl0yd/lueya/issues) ·
[Security](SECURITY.md)

Proprietary software, **All Rights Reserved** ([license](LICENSE)).
Not affiliated with or endorsed by Yandex. Yandex Music service terms,
account and regional restrictions apply.
