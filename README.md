# Chooser

<img src="Resources/Chooser.png" alt="Chooser branching-arrow icon" width="128">

A small, local macOS menu bar app that opens links in **Brave or Google Chrome**, with browser profiles and per-app rules. Built with Swift and AppKit. No extensions, server, cloud, telemetry, or third-party dependencies.

**[Download for macOS](https://github.com/tommyin-it/chooser/releases/latest)** · [Polska instrukcja](README.pl.md)

## Install — no developer tools needed

Requires **macOS 13 or later**, on Apple Silicon or Intel, and Brave and/or Google Chrome.

1. Download **Chooser-1.1.0-universal.dmg** from [Releases](https://github.com/tommyin-it/chooser/releases/latest).
2. Open the DMG and drag **Chooser.app** into **Applications**.
3. Eject the disk image, then open Chooser from Applications.
4. Click the branching-arrow icon in the menu bar → **Settings… → Get started**.
5. Click **Connect…** to make Chooser the default HTTP/HTTPS handler. Record your preferred shortcut and optionally enable launch at login.

Chooser runs in the menu bar; it does not show a Dock icon or automatically open Settings. A ZIP download is also available: unzip it and move Chooser.app to Applications before opening it.

### First launch and signing

This release is **ad-hoc signed, not Apple-notarized**. macOS may block the downloaded app because it cannot verify the developer. If you trust this release, follow [Apple’s instructions](https://support.apple.com/en-am/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac): after trying to open it, use **System Settings → Privacy & Security → Open Anyway**, if offered. Keep system security protections enabled. Alternatively, build from source below.

Release assets include `SHA256SUMS.txt` for checking download integrity. The universal binary contains both arm64 and x86_64 code; runtime testing was performed on Apple Silicon, not on an Intel Mac.

## English and Polish

English is the default. Choose **Settings → Get started → Language → English / Polski**. The interface updates immediately and remembers your choice after restart. Browser profile names are your own data and are not translated; native macOS dialogs use the system language.

## Features

- **Choose / Brave / Chrome:** show a picker at the cursor, or open directly in one browser.
- **Global shortcut:** record a custom combination, including Hyper (Control + Option + Command + Shift). Default: Hyper + B. Karabiner can map Caps Lock to Hyper.
- **Remembered choice:** the last main browser comes first. In the compact strip it receives ⅔ of the width. Near screen edges the picker stays on screen.
- **Profiles:** save extra Chrome/Brave profiles, enable them individually or hide all extras without deleting them, and choose a primary profile for each browser.
- **Grouped layouts:** Strip, Tiles, List, or Two columns. Within each browser’s fixed area, its primary profile occupies the upper ⅔ and extra profiles share the lower ⅓. Extra profiles scroll horizontally when necessary.
- **Picker shortcuts:** ⌘1/⌘2 choose the main browsers; ⌘3–⌘9 choose extra profiles. Escape or an outside click cancels pending links.
- **Per-app rules:** for example, Slack → Chrome. Rules override the global mode. Unknown sources use the global mode.
- **Mode HUD:** a brief, nonactivating notification. Optional launch at login. Settings persist locally.

Links clicked inside Brave or Chrome stay there. Chooser handles links that apps hand to macOS; it does not intercept webpage clicks or force every browser link into a new tab. If the sender can be identified as a browser, its links stay with that browser.

Source-app detection uses Apple Event sender information, not a guess based on the frontmost window. Profile discovery supports the browsers’ standard local data directories. Missing profiles show an error instead of silently opening another profile. URLs are passed as arguments, never interpreted by a shell.

The global shortcut uses Carbon `RegisterEventHotKey`; Accessibility, Input Monitoring, and Automation permissions are not required. Native system prompts apply to default link handling and optional launch at login.

## Update or uninstall

To update, quit Chooser from its menu, replace the app in Applications with the new version, and reopen it. Your settings, profiles, and rules remain saved. Keep the application at the same path once link handling and launch at login are configured.

To uninstall, disable launch at login, select another default browser in macOS, quit Chooser, and move the app to Trash. Browser profiles are never deleted by Chooser.

## Build from source

Install Apple Command Line Tools (`xcode-select --install`), with Swift 5.9 or newer (Xcode 15+ tools). Full Xcode is not required.

```sh
git clone https://github.com/tommyin-it/chooser.git
cd chooser
./scripts/build.sh
mkdir -p "$HOME/Applications"
ditto build/Chooser.app "$HOME/Applications/Chooser.app"
open "$HOME/Applications/Chooser.app"
```

For a universal app and distributable DMG/ZIP:

```sh
./scripts/release.sh
```

Outputs are written to `build/release/`. Builds are ad-hoc signed locally. No signing credentials or notarization are included.

## Verification and performance

```sh
./scripts/test.sh
./scripts/benchmark.sh
codesign --verify --deep --strict build/Chooser.app
```

Tests cover geometry across displays, preference persistence, routing, profiles, grouped layouts, language selection, native panel lifecycle, and preventing Settings from opening during link handling. Native UI checks require a logged-in graphical macOS session.

The app waits for system events rather than polling. Mouse monitoring only runs while the picker is visible, and HUD timers are one-shot. Menu icons are cached; button logos are loaded lazily. The benchmark measures icon reuse, rendering a picker with ten profiles, and creation/release of shadow panels. It does not measure browser launch latency or full GPU performance.

## Implementation

Swift/AppKit controls, with SwiftUI Canvas used only for the decorative shadow. Card and shadow live in separate transparent panels so shadow margins pass clicks through. Only the shadow is rasterized. See [icon generation notes](docs/icon.md) for the artwork source and prompt.
