#!/usr/bin/env bash
set -euo pipefail
umask 077

[[ "$(uname -s)" == "Darwin" ]] || { echo "macOS runner required" >&2; exit 1; }
[[ -n "$RUNNER_TEMP" && -n "$GITHUB_ENV" ]] ||
    { echo "GitHub Actions environment required" >&2; exit 1; }
[[ -n "$MACOS_SIGNING_CERTIFICATE_BASE64" &&
   -n "$MACOS_SIGNING_CERTIFICATE_PASSWORD" &&
   -n "$MACOS_SIGNING_CERTIFICATE_SHA256" ]] ||
    { echo "Missing protected lueya-signing environment credentials" >&2; exit 1; }

keychain="$RUNNER_TEMP/lueya-signing-$GITHUB_RUN_ID.keychain-db"
p12="$RUNNER_TEMP/lueya-signing-$GITHUB_RUN_ID.p12"
cert="$RUNNER_TEMP/lueya-signing-$GITHUB_RUN_ID.pem"
keychain_password="$(openssl rand -hex 24)"
printf '%s' "$MACOS_SIGNING_CERTIFICATE_BASE64" | base64 -D > "$p12"
chmod 600 "$p12"
unset MACOS_SIGNING_CERTIFICATE_BASE64

openssl pkcs12 -in "$p12" \
    -passin env:MACOS_SIGNING_CERTIFICATE_PASSWORD \
    -nokeys -out "$cert" >/dev/null 2>&1 ||
    { echo "Invalid identity archive or password" >&2; exit 1; }

fingerprint="$(openssl x509 -in "$cert" -noout -fingerprint -sha256 |
    awk -F= '{print $2}' | tr -d ':\r\n' | tr '[:upper:]' '[:lower:]')"
[[ "$fingerprint" == "$MACOS_SIGNING_CERTIFICATE_SHA256" ]] ||
    { echo "Certificate does not match pinned fingerprint" >&2; exit 1; }
openssl x509 -in "$cert" -noout -checkend 86400 >/dev/null ||
    { echo "Signing identity is expired or about to expire" >&2; exit 1; }
openssl x509 -in "$cert" -noout -text |
    grep -q 'Code Signing' ||
    { echo "Certificate is not a Code Signing certificate" >&2; exit 1; }

security create-keychain -p "$keychain_password" "$keychain"
security set-keychain-settings -lut 7200 "$keychain"
security unlock-keychain -p "$keychain_password" "$keychain"
security list-keychains -d user -s "$keychain"
security import "$p12" -k "$keychain" \
    -P "$MACOS_SIGNING_CERTIFICATE_PASSWORD" -T /usr/bin/codesign
# Per-user trust would request a GUI authorization on a headless runner.
# Limit administrator trust to code signing and fail fast if unavailable.
/usr/bin/perl -e 'alarm 20; exec @ARGV or die "exec: $!"' \
    /usr/bin/sudo -n /usr/bin/security add-trusted-cert -d \
    -r trustRoot -p codeSign -k "$keychain" "$cert" || {
    echo "Could not establish noninteractive, code-signing-only trust" >&2
    exit 1
}
security set-key-partition-list -S apple-tool:,apple:,codesign: \
    -s -k "$keychain_password" "$keychain" >/dev/null

identity="$(openssl x509 -in "$cert" -noout -fingerprint -sha1 |
    awk -F= '{print $2}' | tr -d ':\r\n' | tr '[:lower:]' '[:upper:]')"
security find-identity -v -p codesigning "$keychain" | grep -F "$identity" >/dev/null ||
    { echo "Imported certificate is not a valid macOS signing identity" >&2; exit 1; }

printf 'LUEYA_CODESIGN_IDENTITY=%s\n' "$identity" >> "$GITHUB_ENV"
printf 'LUEYA_CODESIGN_KEYCHAIN=%s\n' "$keychain" >> "$GITHUB_ENV"
printf 'LUEYA_CODESIGN_P12=%s\n' "$p12" >> "$GITHUB_ENV"
printf 'LUEYA_CODESIGN_CERT=%s\n' "$cert" >> "$GITHUB_ENV"
echo "Imported pinned lueya code-signing identity into a temporary keychain."
