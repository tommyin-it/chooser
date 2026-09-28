#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build.sh --universal
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
output="$PWD/build/release"
mkdir -p "$output"
stage=$(mktemp -d "$PWD/build/dmg-stage.XXXXXX")
trap 'rm -rf "$stage"' EXIT
ditto build/Chooser.app "$stage/Chooser.app"
ln -s /Applications "$stage/Applications"
cat > "$stage/Install.txt" <<'INSTALL'
Drag Chooser.app into Applications, eject this disk, and launch Chooser from Applications.
The app appears in the menu bar. Open Settings to connect link handling and select English or Polski.

This build is ad-hoc signed, not Apple-notarized. Read the first-launch instructions:
https://github.com/tommyin-it/chooser#first-launch-and-signing
INSTALL
hdiutil create -volname "Chooser $version" -srcfolder "$stage" -ov -format UDZO "$output/Chooser-$version-universal.dmg"
ditto -c -k --sequesterRsrc --keepParent build/Chooser.app "$output/Chooser-$version-universal.zip"
cd "$output"
shasum -a 256 "Chooser-$version-universal.dmg" "Chooser-$version-universal.zip" > SHA256SUMS.txt
