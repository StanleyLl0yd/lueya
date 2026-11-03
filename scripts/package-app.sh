#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "macOS is required to package lueya." >&2
    exit 1
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
cd "$root"

case "${1:-main}" in
    main)
        executable="LueyaApp"
        app_name="lueya"
        info_file="App/Info.plist"
        entitlements_file="App/Lueya.entitlements"
        ;;
    embed-probe)
        executable="LueyaEmbedProbe"
        app_name="lueya-embed-probe"
        info_file="App/EmbedProbe.Info.plist"
        entitlements_file="App/EmbedProbe.entitlements"
        ;;
    *)
        echo "Usage: $0 [main|embed-probe]" >&2
        exit 2
        ;;
esac

swift build --configuration release --product "$executable"
bin_dir="$(swift build --configuration release --show-bin-path)"
app="$root/dist/$app_name.app"

mkdir -p "$app/Contents/MacOS"
cp "$root/$info_file" "$app/Contents/Info.plist"
cp "$bin_dir/$executable" "$app/Contents/MacOS/$executable"
chmod 755 "$app/Contents/MacOS/$executable"

/usr/bin/plutil -lint "$app/Contents/Info.plist"
/usr/bin/codesign --force --sign - --entitlements "$root/$entitlements_file" "$app"

printf 'Packaged: %s\n' "$app"
printf '%s\n' "Ad-hoc developer test signature only; not notarized."
