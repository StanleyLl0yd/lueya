#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "macOS is required to package lueya." >&2
    exit 1
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
cd "$root"

swift build --configuration release --product LueyaApp
bin_dir="$(swift build --configuration release --show-bin-path)"
app="$root/dist/lueya.app"

mkdir -p "$app/Contents/MacOS"
cp "$root/App/Info.plist" "$app/Contents/Info.plist"
cp "$bin_dir/LueyaApp" "$app/Contents/MacOS/LueyaApp"
chmod 755 "$app/Contents/MacOS/LueyaApp"

/usr/bin/plutil -lint "$app/Contents/Info.plist"
/usr/bin/codesign --force --sign - "$app"

printf 'Packaged: %s\n' "$app"
printf '%s\n' "Local ad-hoc signature only; not notarized or distribution-ready."
