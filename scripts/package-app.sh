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

swift build --configuration release --product "$executable" -Xswiftc -Osize -Xlinker -dead_strip
bin_dir="$(swift build --configuration release --show-bin-path)"
app="$root/dist/$app_name.app"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$root/$info_file" "$app/Contents/Info.plist"
cp "$bin_dir/$executable" "$app/Contents/MacOS/$executable"
chmod 755 "$app/Contents/MacOS/$executable"
/usr/bin/strip -S -x "$app/Contents/MacOS/$executable"

/usr/bin/plutil -lint "$app/Contents/Info.plist"
if [[ -n "${LUEYA_CODESIGN_IDENTITY:-}" ]]; then
    [[ -n "${LUEYA_CODESIGN_KEYCHAIN:-}" ]] || {
        echo "Signed packaging requires a temporary signing keychain" >&2
        exit 1
    }
    /usr/bin/codesign --force --sign "$LUEYA_CODESIGN_IDENTITY" \
        --keychain "$LUEYA_CODESIGN_KEYCHAIN" \
        --entitlements "$root/$entitlements_file" "$app"
    /usr/bin/codesign --verify --strict "$app"
    echo "Code-signed with pinned local research identity."
else
    /usr/bin/codesign --force --sign - --entitlements "$root/$entitlements_file" "$app"
    echo "Ad-hoc CI test build; not for owner distribution."
fi

printf 'Executable bytes: %s\n' "$(stat -f %z "$app/Contents/MacOS/$executable")"
printf 'Packaged: %s\n' "$app"
printf '%s\n' "Not notarized; signed test releases require verified owner feedback and CI."
