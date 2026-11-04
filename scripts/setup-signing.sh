#!/usr/bin/env bash
set -euo pipefail
umask 077
ulimit -c 0

# Keep one identity for all future versions. Re-running uploads the same .p12.
REPO="StanleyLl0yd/lueya"
ENVIRONMENT="lueya-signing"
IDENTITY_NAME="lueya Local Code Signing"
OUTPUT_DIR="$HOME/Library/Application Support/lueya/signing"
P12="$OUTPUT_DIR/lueya-code-signing.p12"
CERT="$OUTPUT_DIR/lueya-code-signing.cer"
API="repos/$REPO/environments/$ENVIRONMENT"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(uname -s)" == "Darwin" ]] || fail "Requires macOS."
for cmd in gh openssl base64 awk grep cmp; do
    command -v "$cmd" >/dev/null 2>&1 || fail "Missing $cmd"
done
gh auth status -h github.com >/dev/null 2>&1 || fail "Run gh auth login first."
[[ "$(gh repo view "$REPO" --json nameWithOwner --jq '.nameWithOwner')" == "$REPO" ]] ||
    fail "Cannot access $REPO."
[[ "$(gh api "repos/$REPO/branches/main" --jq '.protected')" == true ]] ||
    fail "main is not protected; refusing to upload a signing key."

mkdir -p "$OUTPUT_DIR"
chmod 700 "$OUTPUT_DIR"
[[ ! -L "$OUTPUT_DIR" && ! -L "$P12" && ! -L "$CERT" ]] ||
    fail "Symlink found in signing identity path."
tmp="$(mktemp -d)"
cleanup() { unset LUEYA_SIGNING_PASS confirm; rm -rf "$tmp"; }
trap cleanup EXIT

if [[ -f "$P12" ]]; then
    echo "Existing identity found. Reusing it; NOT rotating the private key."
    read -r -s -p "Existing .p12 password: " LUEYA_SIGNING_PASS </dev/tty
    printf '\n'
else
    echo "Creating separate 10-year RSA-3072/SHA-256 Code Signing certificate."
    echo "Choose a unique 24+ character password and save it in your password manager."
    read -r -s -p "New .p12 password: " LUEYA_SIGNING_PASS </dev/tty
    printf '\n'
    [[ "$(printf %s "$LUEYA_SIGNING_PASS" | wc -c | tr -d ' ')" -ge 24 ]] ||
        fail "Password must be at least 24 bytes."
    read -r -s -p "Repeat password: " confirm </dev/tty
    printf '\n'
    [[ "$LUEYA_SIGNING_PASS" == "$confirm" ]] || fail "Passwords do not match."
    unset confirm

    cat > "$tmp/codesign.cnf" <<'OPENSSL_CONFIG'
[ req ]
prompt = no
distinguished_name = identity
x509_extensions = codesign
[ identity ]
CN = lueya Local Code Signing
O = lueya Personal Research
[ codesign ]
basicConstraints = critical, CA:TRUE
keyUsage = critical, digitalSignature, keyCertSign
extendedKeyUsage = codeSigning
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
OPENSSL_CONFIG

    export LUEYA_SIGNING_PASS
    openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:3072 \
        -aes-256-cbc -pass env:LUEYA_SIGNING_PASS \
        -out "$tmp/key.pem" >/dev/null 2>&1 || fail "Key generation failed."
    openssl req -new -x509 -sha256 -days 3650 \
        -key "$tmp/key.pem" -passin env:LUEYA_SIGNING_PASS \
        -config "$tmp/codesign.cnf" -extensions codesign \
        -out "$tmp/cert.pem" || fail "Certificate generation failed."
    openssl x509 -in "$tmp/cert.pem" -outform DER -out "$tmp/cert.cer"
    openssl pkcs12 -export -inkey "$tmp/key.pem" -in "$tmp/cert.pem" \
        -name "$IDENTITY_NAME" \
        -passin env:LUEYA_SIGNING_PASS -passout env:LUEYA_SIGNING_PASS \
        -out "$tmp/identity.p12" || fail ".p12 export failed."
    [[ ! -e "$P12" && ! -e "$CERT" ]] ||
        fail "Files appeared during generation; refusing to replace."
    mv "$tmp/identity.p12" "$P12"
    mv "$tmp/cert.cer" "$CERT"
    chmod 600 "$P12" "$CERT"
    echo "Created: $P12"
fi

[[ -f "$P12" && -f "$CERT" ]] || fail "Both .p12 and .cer are required."
export LUEYA_SIGNING_PASS
openssl pkcs12 -in "$P12" -passin env:LUEYA_SIGNING_PASS \
    -nokeys -out "$tmp/extracted.pem" >/dev/null 2>&1 ||
    fail "Wrong password or invalid .p12."
openssl x509 -in "$tmp/extracted.pem" -noout -ext extendedKeyUsage |
    grep -q 'Code Signing' || fail "Code Signing EKU is missing."
openssl x509 -in "$tmp/extracted.pem" -outform DER -out "$tmp/extracted.cer"
cmp -s "$tmp/extracted.cer" "$CERT" ||
    fail "Certificate does not match identity; refusing silent rotation."
fingerprint="$(openssl x509 -in "$tmp/extracted.pem" -noout -fingerprint -sha256 |
    awk -F= '{print $2}' | tr -d ':\r\n' | tr '[:upper:]' '[:lower:]')"
[[ "$fingerprint" =~ ^[0-9a-f]{64}$ ]] || fail "Invalid SHA-256 fingerprint."
printf 'Certificate SHA-256: %s\n' "$fingerprint"
openssl x509 -in "$tmp/extracted.pem" -noout -subject -dates

if gh api "$API" >/dev/null 2>&1; then
    [[ "$(gh api "$API" --jq '.deployment_branch_policy.protected_branches')" == true ]] ||
        fail "Existing environment allows unprotected branches. Fix it first."
else
    printf '%s' '{"deployment_branch_policy":{"protected_branches":true,"custom_branch_policies":false}}' |
        gh api --method PUT "$API" --input - >/dev/null ||
        fail "Environment creation failed; check gh authorization."
    echo "Created GitHub Environment $ENVIRONMENT (protected branches only)."
fi

base64 < "$P12" | tr -d '\r\n' |
    gh secret set MACOS_SIGNING_CERTIFICATE_BASE64 --repo "$REPO" --env "$ENVIRONMENT" ||
    fail "Certificate upload failed."
printf '%s' "$LUEYA_SIGNING_PASS" |
    gh secret set MACOS_SIGNING_CERTIFICATE_PASSWORD --repo "$REPO" --env "$ENVIRONMENT" ||
    fail "Password upload failed."
printf '%s' "$fingerprint" |
    gh variable set MACOS_SIGNING_CERTIFICATE_SHA256 --repo "$REPO" --env "$ENVIRONMENT" ||
    fail "Fingerprint upload failed."
unset LUEYA_SIGNING_PASS

echo "Uploaded identity to protected GitHub Environment $ENVIRONMENT."
gh secret list --repo "$REPO" --env "$ENVIRONMENT"
gh variable list --repo "$REPO" --env "$ENVIRONMENT"
echo "Keep your encrypted .p12 backup and its password. No CI/release triggered."
