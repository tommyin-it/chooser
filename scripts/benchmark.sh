#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
swiftc Sources/Chooser/Localization.swift -O Sources/Chooser/Model.swift Sources/Chooser/BrowserProfiles.swift \
  Sources/Chooser/Panels.swift Sources/Chooser/ShadowedPanel.swift \
  Benchmarks/main.swift -o build/ChooserBenchmarks
build/ChooserBenchmarks
