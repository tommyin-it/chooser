#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP="$PWD/build/Chooser.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
if [[ "${1:-}" == "--universal" ]]; then
  # Compile both slices directly: multi-arch SwiftPM otherwise requires full Xcode.
  for arch in arm64 x86_64; do
    swiftc -O -target "$arch-apple-macosx13.0" Sources/Chooser/*.swift -o "build/Chooser-$arch"
  done
  lipo -create build/Chooser-arm64 build/Chooser-x86_64 -output "$APP/Contents/MacOS/Chooser"
else
  swift build -c release
  cp "$(swift build -c release --show-bin-path)/Chooser" "$APP/Contents/MacOS/Chooser"
fi
cp Resources/Chooser.icns "$APP/Contents/Resources/Chooser.icns"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - --identifier local.tomasz.Chooser "$APP"
echo "$APP"
