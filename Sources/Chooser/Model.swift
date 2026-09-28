import AppKit
import CoreImage

enum Browser: String, CaseIterable, Codable {
    case brave, chrome
    var name: String { self == .brave ? "Brave" : "Chrome" }
    var bundleID: String { self == .brave ? "com.brave.Browser" : "com.google.Chrome" }
    var other: Browser { self == .brave ? .chrome : .brave }
    var applicationURL: URL? { NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) }
    var icon: NSImage {
        if let url = applicationURL { return NSWorkspace.shared.icon(forFile: url.path) }
        return NSImage(systemSymbolName: "globe", accessibilityDescription: name)!
    }
}

enum Mode: String, CaseIterable {
    case choice, brave, chrome
    var name: String { self == .choice ? L("Choose", "Wybór") : (self == .brave ? "Brave" : "Chrome") }
    var browser: Browser? { Browser(rawValue: rawValue) }
    var next: Mode { Self.allCases[(Self.allCases.firstIndex(of: self)! + 1) % Self.allCases.count] }
    var icon: NSImage { browser?.icon ?? NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: L("Choose", "Wybór"))! }
    // Only three tiny images are retained. Regenerate them on the next launch
    // if the installed browsers change; URL resolution for opening stays live.
    private static var menuIcons: [String: NSImage] = [:]
    var menuBarIcon: NSImage {
        if let cached = Self.menuIcons[rawValue] { return cached }
        let image = makeMenuBarIcon()
        Self.menuIcons[rawValue] = image
        return image
    }
    private func makeMenuBarIcon() -> NSImage {
        guard browser != nil else {
            let symbol = icon.copy() as! NSImage
            symbol.size = NSSize(width: 16, height: 16)
            symbol.isTemplate = true
            return symbol
        }
        // Preserve the logos' internal detail. A template of an app icon would
        // flatten its opaque rounded-square background into a solid silhouette.
        var rect = NSRect(x: 0, y: 0, width: 16, height: 16)
        guard let source = icon.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return icon }
        let gray = CIImage(cgImage: source)
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0.7, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 0.7, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 0.7, w: 0),
                "inputBiasVector": CIVector(x: 0.3, y: 0.3, z: 0.3, w: 0)
            ])
        guard let output = CIContext().createCGImage(gray, from: gray.extent) else { return icon }
        return NSImage(cgImage: output, size: NSSize(width: 16, height: 16))
    }
}

struct Shortcut: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
    let label: String
    // Carbon modifier flags: control, option, command, shift.
    static let initial = Shortcut(keyCode: 11, modifiers: 4096 | 2048 | 256 | 512, label: "⌃⌥⌘⇧B")
}

struct ApplicationRule: Codable, Equatable {
    let bundleID: String
    var name: String
    var browser: Browser
}

// An explicit app rule overrides the global mode. Browser-originated links
// continue to stay in their browser, as in the original routing contract.
func destination(sourceBundleID: String?, mode: Mode, rules: [ApplicationRule]) -> Browser? {
    if let sourceBundleID {
        if let browser = Browser.allCases.first(where: { $0.bundleID == sourceBundleID }) { return browser }
        if let rule = rules.first(where: { $0.bundleID == sourceBundleID }) { return rule.browser }
    }
    return mode.browser
}

final class Preferences {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    var savedProfiles: [SavedProfile] {
        get {
            if let data = defaults.data(forKey: "savedProfiles") {
                return (try? JSONDecoder().decode([SavedProfile].self, from: data)) ?? []
            }
            // Upgrade the former single extra profile without losing it.
            if let data = defaults.data(forKey: "extraProfile"),
               let profile = try? JSONDecoder().decode(BrowserProfile.self, from: data) {
                let migrated = [SavedProfile(profile: profile)]
                self.savedProfiles = migrated
                return migrated
            }
            return []
        }
        set {
            defaults.set(try? JSONEncoder().encode(newValue), forKey: "savedProfiles")
            defaults.removeObject(forKey: "extraProfile")
        }
    }
    var showsExtraProfiles: Bool {
        get { defaults.object(forKey: "showsExtraProfiles") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showsExtraProfiles") }
    }
    var activeProfiles: [BrowserProfile] { showsExtraProfiles ? savedProfiles.filter(\.isEnabled).map(\.profile) : [] }
    var chooserStyle: ChooserStyle {
        get { ChooserStyle(rawValue: defaults.string(forKey: "chooserStyle") ?? "") ?? .strip }
        set { defaults.set(newValue.rawValue, forKey: "chooserStyle") }
    }
    func mainProfile(for browser: Browser) -> BrowserProfile? {
        defaults.data(forKey: "mainProfile.\(browser.rawValue)").flatMap { try? JSONDecoder().decode(BrowserProfile.self, from: $0) }
    }
    func setMainProfile(_ profile: BrowserProfile?, for browser: Browser) {
        let key = "mainProfile.\(browser.rawValue)"
        if let profile { defaults.set(try? JSONEncoder().encode(profile), forKey: key) }
        else { defaults.removeObject(forKey: key) }
    }
    var applicationRules: [ApplicationRule] {
        get { defaults.data(forKey: "applicationRules").flatMap { try? JSONDecoder().decode([ApplicationRule].self, from: $0) } ?? [] }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: "applicationRules") }
    }
    var mode: Mode {
        get { Mode(rawValue: defaults.string(forKey: "mode") ?? "") ?? .choice }
        set { defaults.set(newValue.rawValue, forKey: "mode") }
    }
    var lastBrowser: Browser {
        get { Browser(rawValue: defaults.string(forKey: "lastBrowser") ?? "") ?? .brave }
        set { defaults.set(newValue.rawValue, forKey: "lastBrowser") }
    }
    var hasRecordedShortcut: Bool { defaults.data(forKey: "shortcut") != nil }
    var shortcut: Shortcut {
        get { defaults.data(forKey: "shortcut").flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) } ?? .initial }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: "shortcut") }
    }
}

enum ChooserStyle: String, CaseIterable {
    case strip, tiles, list, sidebar
    var name: String {
        switch self { case .strip: return L("Strip", "Pasek"); case .tiles: return L("Tiles", "Kafelki"); case .list: return L("List", "Lista"); case .sidebar: return L("Two columns", "Dwie kolumny") }
    }
    func horizontalButton(at index: Int) -> Bool { self == .list || index >= 2 }
}

struct BrowserGroupLayout {
    let browser: Browser
    let frame: NSRect
    let mainFrame: NSRect
    let profileBand: NSRect?
    let profileIndices: [Int]
    let profileFrames: [NSRect] // In the horizontally scrolling band's document.
    var documentSize: NSSize {
        NSSize(width: profileFrames.last?.maxX ?? 0, height: profileBand?.height ?? 0)
    }
}

struct ChooserLayout {
    let frame: NSRect
    let groups: [BrowserGroupLayout]
    var preferredFrame: NSRect { groups[0].mainFrame }
    static func make(cursor: NSPoint, screen: NSRect, preferred: Browser = .brave, extras: [BrowserProfile] = [], style: ChooserStyle = .strip) -> Self {
        // The browser footprints do not grow or shrink when profiles are toggled.
        let raw: [NSRect]
        switch style {
        case .strip: raw = [NSRect(x: 0, y: 0, width: 110, height: 56), NSRect(x: 110, y: 0, width: 55, height: 56)]
        case .tiles: raw = [NSRect(x: 0, y: 0, width: 140, height: 72), NSRect(x: 140, y: 0, width: 100, height: 72)]
        case .list: raw = [NSRect(x: 0, y: 54, width: 240, height: 54), NSRect(x: 0, y: 0, width: 240, height: 54)]
        case .sidebar: raw = [NSRect(x: 0, y: 0, width: 160, height: 96), NSRect(x: 160, y: 0, width: 160, height: 96)]
        }
        let width = raw.map(\.maxX).max()!
        let height = raw.map(\.maxY).max()!
        let scale = min(1, screen.width / width, screen.height / height)
        let size = NSSize(width: width * scale, height: height * scale)
        let choices = chooserChoices(preferred: preferred, extras: extras)
        let groups = [preferred, preferred.other].enumerated().map { index, browser -> BrowserGroupLayout in
            let original = raw[index]
            let rect = NSRect(x: original.minX * scale, y: original.minY * scale, width: original.width * scale, height: original.height * scale)
            let indices = choices.indices.filter { $0 >= 2 && choices[$0].browser == browser }
            guard !indices.isEmpty else { return BrowserGroupLayout(browser: browser, frame: rect, mainFrame: rect, profileBand: nil, profileIndices: [], profileFrames: []) }
            let bandHeight = rect.height / 3
            let band = NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: bandHeight)
            let main = NSRect(x: rect.minX, y: band.maxY, width: rect.width, height: rect.height - bandHeight)
            let itemWidth = indices.count == 1 ? rect.width : max(64 * scale, rect.width / CGFloat(indices.count))
            let profileFrames = indices.indices.map { NSRect(x: CGFloat($0) * itemWidth, y: 0, width: itemWidth, height: bandHeight) }
            return BrowserGroupLayout(browser: browser, frame: rect, mainFrame: main, profileBand: band, profileIndices: indices, profileFrames: profileFrames)
        }
        let first = groups[0].mainFrame
        let x = min(max(cursor.x - first.midX, screen.minX), screen.maxX - size.width)
        let y = min(max(cursor.y - first.midY, screen.minY), screen.maxY - size.height)
        return Self(frame: NSRect(origin: NSPoint(x: x, y: y), size: size), groups: groups)
    }
}

func webURLs(_ urls: [URL]) -> [URL] {
    urls.filter { ["http", "https"].contains($0.scheme?.lowercased() ?? "") && $0.host != nil }
}
