# Personal code signing for lueya (macOS)

This is a **development/test-only** self-signed identity, not Apple Developer ID
and not Apple notarization. It gives new lueya builds a stable cryptographic
Designated Requirement so the traditional login Keychain can recognize the
same code publisher across versions. It does **not** guarantee no one-time
Keychain prompt when moving away from ad-hoc v0.4.1. No private OAuth
credentials are needed in GitHub. Mac App Sandbox/Data Protection entitlements
remain unchanged.

## One-time owner setup (on the Mac)

Prerequisites: macOS, OpenSSL (system or Homebrew), authenticated GitHub CLI
(`gh auth status`) with repository administration and Actions Secrets rights.
`main` must remain protected and the signing Environment must allow protected
branches only. This script does not trigger CI or a release.

Download `scripts/setup-signing.sh` from this repository, inspect it, and run:

```bash
bash scripts/setup-signing.sh
```

The script:

1. Generates an encrypted RSA-3072 private key and a **self-signed SHA-256,
   Code Signing EKU** certificate valid for 3650 days (first run only).
2. Creates a password-protected macOS-importable `.p12` and matching public
   `.cer` under `~/Library/Application Support/lueya/signing/`, file mode
   `0600` and directory mode `0700`.
3. Checks that existing identities are reused rather than silently rotated.
   **Keep the `.p12` and its password backed up privately**; losing either
   requires new identity migration and may trigger fresh Keychain permissions.
4. Creates protected GitHub Environment `lueya-signing` if absent, verifies
   branch protection when present, and uploads:

   - Environment secret `MACOS_SIGNING_CERTIFICATE_BASE64`
   - Environment secret `MACOS_SIGNING_CERTIFICATE_PASSWORD`
   - Environment variable `MACOS_SIGNING_CERTIFICATE_SHA256`

The `.p12` uses compatibility PKCS#12 transport algorithms (3DES/SHA-1)
because macOS Security.framework can reject modern OpenSSL 3 PBE defaults.
This is **not** the certificate signature algorithm: the X.509 identity
and macOS code use SHA-256. Protect `.p12` with a long unique password.

The private key is **not** stored in the Git repository, build artifacts,
versioned ZIP, logs or published GitHub Release.

## Pipeline and security boundaries

- PR and push CI still use **ad-hoc** signatures solely for validation.
- A separate owner-only `Verify protected local signing identity`
  workflow on protected `main` imports the identity and verifies that an
  independently resigned app with a new build number has the **same**
  Designated Requirement. The smoke test never creates a release.
- The `publish-release` job in `swift.yml` imports the same pinned
  identity after either a version-specific owner-feedback guarded merge,
  or an optional owner-initiated `workflow_dispatch` with matching
  `release_version` and `release_confirmation`. The guarded exact
  merge marker can trigger a **single** authorized main-branch release push;
  arbitrary pushes or PR jobs cannot publish.
- Release ZIPs must contain **certificate-signed**, verified arm64 applications;
  unsigned/ad-hoc CI artifacts are not promoted to releases.
- Environment access is restricted to **protected branches**, with no secrets
  sent to ordinary PR jobs. Preserve branch protection and review requirements
  when updating CI and release workflows.
- The runner uses a temporary Keychain, validates the certificate fingerprint,
  signs, verifies both code and DR, and removes the temporary identity.
- macOS Gatekeeper may still block unnotarized self-signed binaries: this
  certificate is for owner testing, not trusted general distribution.

## Keychain consent during legacy migration

The signing identity and Keychain service/account remain unchanged from
v0.5.2 onward. Updating from historical ad-hoc builds may legitimately
request permission to read the older `oauth-session` item. If macOS offers
**Always Allow** (Russian: «Разрешать всегда») for the expected, verified
lueya app, it can retain that authorization; choosing **Allow** only grants
the current access. Never type the Keychain password into lueya's own UI,
remove Keychain entries manually or turn off Keychain protection.
The owner-device ACL cannot be inspected from CI and zero future prompts
cannot be guaranteed by a self-signed certificate.

## Updating an installed app

Keep the same `CFBundleIdentifier` (`com.stanleylloyd.lueya`) and Keychain
service (`com.stanleylloyd.lueya.yandex-music`). As of v0.5.2 the account
name is `oauth-session-v2` to create a new item under the stable certificate
rather than reuse the old ad-hoc app's access-control list. On its first load,
lueya reads the historical `oauth-session`, verifies a saved replacement
and attempts non-interactive cleanup. If migration fails, the original is
retained. Explicit Sign out clears both entries. Do not manually delete
Keychain items or sign out before installing.

macOS may still require a **one-time** grant to read the historical entry.
If prompted for the correct lueya app, use `Always Allow` after checking
the app identity. A repeated prompt on v0.5.2 must still be reported; CI
cannot reproduce the owner's existing Keychain ACL. Never select the
unsafe `Allow all applications` setting.

Never upload the account's OAuth token; it remains on the owner's Mac.
Token expiration/revocation is a separate OAuth issue and cannot be fixed by
a signing certificate. Refresh tokens can only be used when actually granted
and permitted by the active OAuth flow.

## Owner test / release gate

The owner now authorizes each complete repair-and-release cycle by providing
feedback about the previous delivered build (2026-11-05). No separate
version-specific permission is needed. Use the guarded single-version
merge marker and require passing exact-head CI before releasing. Once the
signed build is delivered, stop development, CI/testing, audits and further
releases until the owner's next feedback. Feedback does not imply acceptance.

References: Apple's Code Signing Guide and TN3127/Code Signing Requirements,
GitHub's deployment environment and GitHub CLI secret documentation.
