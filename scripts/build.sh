#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP="$PWD/build/Chooser.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/Chooser.icns "$APP/Contents/Resources/Chooser.icns"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp "$(swift build -c release --show-bin-path)/Chooser" "$APP/Contents/MacOS/Chooser"
codesign --force --sign - --identifier local.tomasz.Chooser "$APP"
echo "$APP"
