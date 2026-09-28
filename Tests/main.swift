import Foundation

private var checks = 0
func check(_ value: Bool, _ message: String = "Assertion failed") {
    checks += 1
    if !value { fatalError(message) }
}
func equal<T: Equatable>(_ actual: T, _ expected: T) { check(actual == expected, "Expected \(expected), got \(actual)") }
func equal(_ actual: CGFloat, _ expected: CGFloat, accuracy: CGFloat) { check(abs(actual - expected) <= accuracy) }

import AppKit

struct ChooserTests {
    func testCompactLayoutAcrossDisplays() {
        let screens = [NSRect(x: 0, y: 0, width: 1512, height: 982), NSRect(x: -1920, y: -300, width: 1920, height: 1080), NSRect(x: 1512, y: 200, width: 1080, height: 1920)]
        for screen in screens {
            for x in stride(from: screen.minX, to: screen.maxX, by: 17) {
                for y in stride(from: screen.minY, to: screen.maxY, by: 19) {
                    let cursor = NSPoint(x: x, y: y)
                    let layout = ChooserLayout.make(cursor: cursor, screen: screen)
                    check(screen.contains(layout.frame))
                    let local = NSPoint(x: x - layout.frame.minX, y: y - layout.frame.minY)
                    // A fixed left-first order cannot keep the preferred target under
                    // a cursor in the rightmost third of a screen while staying visible.
                    if cursor.x < screen.maxX - layout.frame.width / 3 {
                        check(layout.preferredFrame.contains(local), "Cursor \(cursor), frame \(layout.frame)")
                    }
                    equal(layout.preferredFrame.minX, 0)
                    check(layout.frame.width <= 165 && layout.frame.height <= 56)
                    equal(layout.preferredFrame.width / layout.frame.width, 2.0 / 3.0, accuracy: 0.0001)
                }
            }
        }
    }
    func testPreferencesSurviveRecreation() {
        let suite = "ChooserTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        equal(preferences.mode, .choice)
        equal(preferences.lastBrowser, .brave)
        equal(preferences.shortcut, .initial)
        preferences.applicationRules = [ApplicationRule(bundleID: "com.tinyspeck.slackmacgap", name: "Slack", browser: .chrome)]
        preferences.mode = .chrome
        preferences.lastBrowser = .chrome
        preferences.shortcut = Shortcut(keyCode: 8, modifiers: 4352, label: "⌃⌘C")
        let restored = Preferences(defaults: UserDefaults(suiteName: suite)!)
        equal(restored.applicationRules, preferences.applicationRules)
        equal(restored.mode, .chrome)
        equal(restored.lastBrowser, .chrome)
        equal(restored.shortcut, preferences.shortcut)
    }
    func testModeCycle() {
        equal(Mode.choice.next, .brave)
        equal(Mode.brave.next, .chrome)
        equal(Mode.chrome.next, .choice)
    }
    func testOnlyValidWebLinksAreAccepted() {
        let urls = ["https://example.com/a?b=c#d", "http://example.com", "file:///etc/passwd", "javascript:alert(1)", "https:"] .compactMap(URL.init(string:))
        equal(webURLs(urls).map(\.absoluteString), Array(urls.prefix(2)).map(\.absoluteString))
    }
}

let tests = ChooserTests()
tests.testCompactLayoutAcrossDisplays()
tests.testPreferencesSurviveRecreation()
tests.testModeCycle()
tests.testOnlyValidWebLinksAreAccepted()
print("PASS: \(checks) assertions — geometry, persistence, modes, URL filtering")

// Exercise the real native windows. This guards geometry, clipping ownership,
// click-through and HUD teardown; on-screen compositor artifacts still need live QA.
let application = NSApplication.shared
application.setActivationPolicy(.accessory)
for radius: CGFloat in [10, 18] {
    let cardFrame = NSRect(x: 200, y: 200, width: 165, height: 56)
    let panel = ShadowedPanel(cardFrame: cardFrame, cornerRadius: radius)
    let card = panel.makeCard(material: .popover)
    panel.contentView = card
    panel.orderFrontRegardless()
    panel.showShadow()
    check(!panel.hasShadow && !panel.isOpaque)
    equal(card.layer?.cornerRadius, radius)
    equal(card.layer?.masksToBounds, true)
    let shadow = panel.childWindows!.first!
    check(shadow.ignoresMouseEvents && !shadow.hasShadow && !shadow.isOpaque)
    equal(shadow.frame, cardFrame.insetBy(dx: -48, dy: -48))
    check(shadow.contentView !== card)
    check(shadow.contentView?.layer?.masksToBounds != true)
    let resized = NSRect(x: 250, y: 260, width: 200, height: 100)
    panel.setFrame(resized, display: true)
    equal(shadow.frame, resized.insetBy(dx: -48, dy: -48))
    panel.setOpacity(0.4, animated: false)
    equal(panel.alphaValue, shadow.alphaValue)
    panel.orderOut(nil)
    check(!panel.isVisible && !shadow.isVisible)
    check(panel.childWindows?.isEmpty != false)
}
let keyWindowBeforeHUD = application.keyWindow
let hud = ModeHUD()
hud.show(.brave)
RunLoop.main.run(until: Date().addingTimeInterval(0.2))
hud.show(.chrome)
RunLoop.main.run(until: Date().addingTimeInterval(0.2))
let visibleHUDs = application.windows.compactMap { $0 as? ShadowedPanel }.filter(\.isVisible)
equal(visibleHUDs.count, 1)
check(application.keyWindow === keyWindowBeforeHUD)
check(visibleHUDs[0].ignoresMouseEvents)
check(visibleHUDs[0].childWindows?.first?.ignoresMouseEvents == true)
RunLoop.main.run(until: Date().addingTimeInterval(1.8))
check(!visibleHUDs[0].isVisible)
check(visibleHUDs[0].childWindows?.isEmpty != false)
print("PASS: shadow windows, resize, click-through flags, HUD replacement, focus and teardown")

// Launch Services can send reopen around URL delivery. Neither event order
// may open Settings or discard the link that is awaiting browser selection.
let delegate = AppDelegate()
let previousMode = delegate.preferences.mode
delegate.preferences.mode = .choice
defer { delegate.preferences.mode = previousMode }
let handlesReopen = delegate.applicationShouldHandleReopen(application, hasVisibleWindows: false)
check(!application.windows.contains { $0.isVisible && $0.title == L("Chooser — Settings", "Chooser — Ustawienia") }, "Reopen unexpectedly opened Settings")
check(!handlesReopen, "Reopen should not ask AppKit to reopen windows")
delegate.receive([URL(string: "https://example.com/chooser-regression")!])
check(delegate.chooser.visible)
_ = delegate.applicationShouldHandleReopen(application, hasVisibleWindows: true)
check(delegate.chooser.visible, "Reopen dismissed the pending chooser")
check(!application.windows.contains { $0.isVisible && $0.title == L("Chooser — Settings", "Chooser — Ustawienia") })
delegate.chooser.hide()
// A previously opened Settings window must not accompany the next URL.
delegate.showSettings(nil)
check(application.windows.contains { $0.isVisible && $0.title == L("Chooser — Settings", "Chooser — Ustawienia") })
delegate.receive([URL(string: "https://example.com/chooser-settings-regression")!])
check(delegate.chooser.visible)
check(!application.windows.contains { $0.isVisible && $0.title == L("Chooser — Settings", "Chooser — Ustawienia") }, "Link delivery left Settings visible alongside the chooser")
delegate.chooser.hide()
print("PASS: reopen around link delivery never opens Settings or cancels the chooser")

let appRules = [ApplicationRule(bundleID: "com.tinyspeck.slackmacgap", name: "Slack", browser: .chrome)]
for mode in Mode.allCases {
    equal(destination(sourceBundleID: "com.tinyspeck.slackmacgap", mode: mode, rules: appRules), .chrome)
    equal(destination(sourceBundleID: "com.example.unmatched", mode: mode, rules: appRules), mode.browser)
    equal(destination(sourceBundleID: nil, mode: mode, rules: appRules), mode.browser)
    equal(destination(sourceBundleID: Browser.brave.bundleID, mode: mode, rules: appRules), .brave)
    equal(destination(sourceBundleID: Browser.chrome.bundleID, mode: mode, rules: appRules), .chrome)
}
equal(destination(sourceBundleID: "com.tinyspeck.slackmacgap", mode: .choice, rules: []), nil)
equal(destination(sourceBundleID: "com.tinyspeck.slackmacgap", mode: .chrome, rules: [ApplicationRule(bundleID: "com.tinyspeck.slackmacgap", name: "Slack", browser: .brave)]), .brave)
print("PASS: per-app rule precedence, unmatched/unknown sources, browser continuity, persisted rules")

let profileFixture = FileManager.default.temporaryDirectory.appendingPathComponent("ChooserProfiles-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: profileFixture.appendingPathComponent("Profile 2"), withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: profileFixture) }
let profileJSON: [String: Any] = ["profile": ["info_cache": ["Profile 2": ["name": "Praca"], "Deleted": ["name": "Usunięty"], "../escape": ["name": "Invalid"]]]]
try JSONSerialization.data(withJSONObject: profileJSON).write(to: profileFixture.appendingPathComponent("Local State"))
let discovered = ProfileCatalog.profiles(for: .chrome, root: profileFixture)
equal(discovered, [BrowserProfile(browser: .chrome, directory: "Profile 2", name: "Praca")])
for invalid in ["", ".", "..", "../Default", "a/b", "a\\b", "a\0b"] { check(!ProfileCatalog.validDirectory(invalid)) }
let extraProfile = discovered[0]
let trickyURL = URL(string: "https://example.com/?a=%22&b=$(test)#fragment")!
equal(ProfileLauncher.arguments(profile: extraProfile, urls: [trickyURL]), ["--profile-directory=Profile 2", "--", trickyURL.absoluteString])
let profileSuite = "ChooserProfileTests.\(UUID().uuidString)"
let profileDefaults = UserDefaults(suiteName: profileSuite)!
defer { profileDefaults.removePersistentDomain(forName: profileSuite) }
let profilePreferences = Preferences(defaults: profileDefaults)
profilePreferences.savedProfiles = [SavedProfile(profile: extraProfile)]
profilePreferences.setMainProfile(extraProfile, for: .chrome)
let restoredProfiles = Preferences(defaults: UserDefaults(suiteName: profileSuite)!)
equal(restoredProfiles.activeProfiles, [extraProfile])
equal(restoredProfiles.mainProfile(for: .chrome), extraProfile)
profilePreferences.showsExtraProfiles = false
equal(restoredProfiles.activeProfiles, [])
equal(restoredProfiles.savedProfiles, [SavedProfile(profile: extraProfile)])
profilePreferences.showsExtraProfiles = true
equal(restoredProfiles.activeProfiles, [extraProfile])
profilePreferences.savedProfiles = [SavedProfile(profile: extraProfile, isEnabled: false)]
equal(restoredProfiles.activeProfiles, [])
equal(restoredProfiles.savedProfiles.count, 1)
profilePreferences.setMainProfile(nil, for: .chrome)
equal(restoredProfiles.mainProfile(for: .chrome), nil)
let threeLayout = ChooserLayout.make(cursor: NSPoint(x: 500, y: 400), screen: NSRect(x: 0, y: 0, width: 1000, height: 800), extras: [extraProfile])
equal(threeLayout.groups.map { $0.frame.width }, [110, 55])
equal(threeLayout.frame.width, 165)
equal(threeLayout.groups[0].mainFrame, threeLayout.groups[0].frame)
equal(threeLayout.groups[1].mainFrame.height / threeLayout.groups[1].frame.height, 2.0 / 3.0, accuracy: 0.0001)
let profileChooser = ChooserPanel()
var selection: BrowserChoice?
profileChooser.onChoose = { selection = $0 }
profileChooser.show(preferred: .brave, extras: [extraProfile])
let actualChooser = application.windows.compactMap { $0 as? FloatingPanel }.first { $0.isVisible }!
func descendantButtons(_ view: NSView) -> [BrowserButton] {
    view.subviews.flatMap { child -> [BrowserButton] in
        if let button = child as? BrowserButton { return [button] }
        return descendantButtons(child)
    }
}
let actualButtons = descendantButtons(actualChooser.contentView!)
equal(actualButtons.count, 3)
equal(actualButtons.map(\.choice), [.browser(.brave), .browser(.chrome), .profile(extraProfile)])
actualButtons[2].performClick(nil)
RunLoop.main.run(until: Date().addingTimeInterval(0.2))
equal(selection, .profile(extraProfile))
profileChooser.hide()
print("PASS: profile discovery, missing/path validation, safe argv, profile persistence, three-button layout and selection")

// Migration keeps the old extra profile enabled and never resurrects removed entries.
profileDefaults.removeObject(forKey: "savedProfiles")
profileDefaults.set(try JSONEncoder().encode(extraProfile), forKey: "extraProfile")
equal(profilePreferences.savedProfiles, [SavedProfile(profile: extraProfile)])
check(profileDefaults.object(forKey: "extraProfile") == nil)
profilePreferences.savedProfiles = []
equal(profilePreferences.savedProfiles, [])
let anotherProfile = BrowserProfile(browser: .brave, directory: "Default", name: "Prywatny")
profilePreferences.savedProfiles = [SavedProfile(profile: extraProfile, isEnabled: false), SavedProfile(profile: anotherProfile)]
equal(restoredProfiles.activeProfiles, [anotherProfile])
profilePreferences.showsExtraProfiles = false
equal(restoredProfiles.activeProfiles, [])
equal(restoredProfiles.savedProfiles.count, 2)
profilePreferences.showsExtraProfiles = true
equal(restoredProfiles.activeProfiles, [anotherProfile])
for style in ChooserStyle.allCases {
    profilePreferences.chooserStyle = style
    equal(restoredProfiles.chooserStyle, style)
    for count in [0, 1, 2, 7, 15, 50] {
        // Both an unbalanced group and profiles split between both browsers.
        for split in [false, true] {
            let extras = (0..<count).map { BrowserProfile(browser: split && $0 % 2 == 0 ? .chrome : .brave, directory: "Profile \($0)", name: "Profil \($0)") }
            for preferred in Browser.allCases {
                for screen in [NSRect(x: -1920, y: -200, width: 1920, height: 1080), NSRect(x: 0, y: 0, width: 640, height: 480)] {
                    for cursor in [NSPoint(x: screen.minX + 1, y: screen.minY + 1), NSPoint(x: screen.maxX - 1, y: screen.maxY - 1), NSPoint(x: screen.midX, y: screen.midY)] {
                        let layout = ChooserLayout.make(cursor: cursor, screen: screen, preferred: preferred, extras: extras, style: style)
                        let plain = ChooserLayout.make(cursor: cursor, screen: screen, preferred: preferred, style: style)
                        equal(layout.frame.size, plain.frame.size)
                        equal(layout.groups.map(\.frame), plain.groups.map(\.frame))
                        check(screen.insetBy(dx: -0.001, dy: -0.001).contains(layout.frame))
                        let choices = chooserChoices(preferred: preferred, extras: extras)
                        equal(layout.groups.flatMap(\.profileIndices).count, count)
                        for group in layout.groups {
                            equal(group.profileFrames.count, group.profileIndices.count)
                            if let band = group.profileBand {
                                equal(group.mainFrame.height / group.frame.height, 2.0 / 3.0, accuracy: 0.0001)
                                equal(band.height / group.frame.height, 1.0 / 3.0, accuracy: 0.0001)
                                equal(band.maxY, group.mainFrame.minY)
                                equal(band.minX, group.frame.minX)
                                equal(band.width, group.frame.width)
                                for (position, index) in group.profileIndices.enumerated() {
                                    equal(choices[index].browser, group.browser)
                                    let rect = group.profileFrames[position]
                                    check(NSRect(origin: .zero, size: group.documentSize).insetBy(dx: -0.001, dy: -0.001).contains(rect))
                                    if position > 0 { equal(group.profileFrames[position - 1].maxX, rect.minX) }
                                }
                            } else { equal(group.mainFrame, group.frame); check(group.profileIndices.isEmpty) }
                        }
                    }
                }
            }
        }
    }
}
print("PASS: migration, saved profile switches, grouped 2/3–1/3 layout, fixed browser footprints, correct browser ownership and scrolling geometry")

for style in ChooserStyle.allCases {
    var picked: BrowserChoice?
    let chooser = ChooserPanel()
    chooser.onChoose = { picked = $0 }
    chooser.show(preferred: .chrome, extras: [extraProfile, anotherProfile], style: style)
    let window = application.windows.compactMap { $0 as? FloatingPanel }.first { $0.isVisible }!
    let buttons = descendantButtons(window.contentView!)
    equal(buttons.count, 4)
    buttons.first(where: { $0.choice == .profile(anotherProfile) })!.performClick(nil)
    RunLoop.main.run(until: Date().addingTimeInterval(0.15))
    equal(picked, .profile(anotherProfile))
    chooser.hide()
}
print("PASS: fourth-button profile selection in all four actual chooser layouts")

// Language preference is isolated from the real application defaults.
let languageSuite = "ChooserLanguageTests.\(UUID().uuidString)"
let languageDefaults = UserDefaults(suiteName: languageSuite)!
let originalLanguage = Localization.language
equal(Localization.load(from: languageDefaults), .english)
for language in AppLanguage.allCases {
    Localization.select(language, defaults: languageDefaults)
    equal(Localization.load(from: UserDefaults(suiteName: languageSuite)!), language)
    equal(Mode.choice.name, language == .english ? "Choose" : "Wybór")
    equal(ChooserStyle.sidebar.name, language == .english ? "Two columns" : "Dwie kolumny")
    let controller = SettingsController(app: delegate)
    equal(controller.window?.title, language == .english ? "Chooser — Settings" : "Chooser — Ustawienia")
    controller.close()
}
languageDefaults.set("unknown", forKey: "appLanguage")
equal(Localization.load(from: languageDefaults), .english)
languageDefaults.removePersistentDomain(forName: languageSuite)
Localization.language = originalLanguage
print("PASS: English/Polish settings, persisted language and unsupported-language fallback")
