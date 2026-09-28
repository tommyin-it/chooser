import AppKit
import Darwin
setbuf(stdout, nil)
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
func measure(_ label: String, count: Int, work: () -> Void) {
    autoreleasepool { work() }
    let start = ProcessInfo.processInfo.systemUptime
    for _ in 0..<count { autoreleasepool { work() } }
    print("\(label): \((ProcessInfo.processInfo.systemUptime - start) * 1000 / Double(count)) ms/op (\(count) repetitions)")
}
measure("menu icon", count: 60) { _ = Mode.chrome.menuBarIcon }
let profiles = (0..<10).map { BrowserProfile(browser: $0 % 2 == 0 ? .chrome : .brave, directory: "Profile \($0)", name: "Profile \($0)") }
let layout = ChooserLayout.make(cursor: .zero, screen: NSRect(x: 0, y: 0, width: 1920, height: 1080), extras: profiles)
measure("card with 10 profiles", count: 60) {
    let content = NSView(frame: NSRect(origin: .zero, size: layout.frame.size))
    populateChooser(content, choices: chooserChoices(preferred: .brave, extras: profiles), layout: layout, style: .strip)
    _ = content.bitmapImageRepForCachingDisplay(in: content.bounds).map { content.cacheDisplay(in: content.bounds, to: $0) }
}

final class WeakPanel {
    weak var value: ShadowedPanel?
    init(_ value: ShadowedPanel) { self.value = value }
}
var releasedPanels: [WeakPanel] = []
measure("panel + shadow lifecycle", count: 100) {
    let panel = ShadowedPanel(cardFrame: NSRect(x: 0, y: 0, width: 165, height: 56), cornerRadius: 10)
    panel.contentView = panel.makeCard(material: .popover)
    releasedPanels.append(WeakPanel(panel))
    panel.orderOut(nil)
}
RunLoop.current.run(until: Date().addingTimeInterval(0.2))
let retained = releasedPanels.filter { $0.value != nil }.count
print("Panels retained after lifecycle benchmark: \(retained)/\(releasedPanels.count)")
precondition(retained == 0, "Panel lifecycle retained windows")
