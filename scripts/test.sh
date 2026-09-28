#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
swiftc Sources/Chooser/Model.swift Sources/Chooser/BrowserProfiles.swift Sources/Chooser/ProfileSettingsView.swift Sources/Chooser/LayoutSettingsView.swift Sources/Chooser/ShadowedPanel.swift Sources/Chooser/Panels.swift Sources/Chooser/HotKey.swift Sources/Chooser/Settings.swift Sources/Chooser/ApplicationRulesView.swift Sources/Chooser/AppDelegate.swift Tests/main.swift -o build/ChooserTests
build/ChooserTests
