#!/usr/bin/env bash
set -euo pipefail
umask 077

app="dist/lueya.app"
if [[ $# -ge 1 ]]; then app="$1"; fi
[[ "$(uname -s)" == Darwin ]] || { echo "macOS is required" >&2; exit 1; }
[[ -n "$LUEYA_CODESIGN_IDENTITY" && -n "$LUEYA_CODESIGN_KEYCHAIN" ]] ||
    { echo "Pinned signing identity is missing" >&2; exit 1; }
[[ -d "$app" ]] || { echo "App not found: $app" >&2; exit 1; }

/usr/bin/codesign --verify --strict --verbose=2 "$app"
original="$(/usr/bin/codesign -dr - "$app" 2>&1 | grep '^designated => ')"
[[ -n "$original" && "$original" == *'com.stanleylloyd.lueya'* ]] ||
    { echo "Unexpected app identifier in designated requirement" >&2; exit 1; }
[[ "$original" != *cdhash* ]] ||
    { echo "Code-hash-based identity cannot survive an update" >&2; exit 1; }

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
/usr/bin/ditto "$app" "$scratch/lueya.app"
info="$scratch/lueya.app/Contents/Info.plist"
build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$info")"
[[ "$build" =~ ^[1-9][0-9]*$ ]] || exit 1
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $((build + 1))" "$info"
/usr/bin/codesign --force --sign "$LUEYA_CODESIGN_IDENTITY" \
    --keychain "$LUEYA_CODESIGN_KEYCHAIN" \
    --entitlements App/Lueya.entitlements \
    "$scratch/lueya.app"
/usr/bin/codesign --verify --strict "$scratch/lueya.app"
updated="$(/usr/bin/codesign -dr - "$scratch/lueya.app" 2>&1 | grep '^designated => ')"
[[ "$original" == "$updated" ]] || {
    echo "ERROR: Designated Requirement changed across app revisions" >&2
    exit 1
}
echo "Code signature verified; Designated Requirement is stable across app revisions."
