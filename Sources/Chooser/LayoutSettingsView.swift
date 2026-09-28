import AppKit

private final class LayoutOption: NSButton {
    let layoutStyle: ChooserStyle
    init(style: ChooserStyle, target: AnyObject, action: Selector) {
        layoutStyle = style
        super.init(frame: .zero)
        title = style.name
        isBordered = false
        self.target = target; self.action = action
        setAccessibilityLabel("Układ: \(style.name)")
        widthAnchor.constraint(equalToConstant: 250).isActive = true
        heightAnchor.constraint(equalToConstant: 76).isActive = true
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) {
        let shape = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 11, yRadius: 11)
        (state == .on ? NSColor.controlAccentColor.withAlphaComponent(0.10) : NSColor.controlBackgroundColor).setFill(); shape.fill()
        if state == .on { NSColor.controlAccentColor.setStroke(); shape.lineWidth = 2; shape.stroke() }
        let examples = [BrowserProfile(browser: .brave, directory: "Default", name: "Praca"), BrowserProfile(browser: .chrome, directory: "Default", name: "Osobisty")]
        let layout = ChooserLayout.make(cursor: .zero, screen: NSRect(x: 0, y: 0, width: 1000, height: 1000), extras: examples, style: layoutStyle)
        let scale = min(95 / layout.frame.width, 54 / layout.frame.height)
        for (index, group) in layout.groups.enumerated() {
            let segments: [(NSRect, NSColor)] = [(group.mainFrame, NSColor.controlAccentColor.withAlphaComponent(index == 0 ? 0.7 : 0.4))] + (group.profileBand.map { [($0, NSColor.tertiaryLabelColor)] } ?? [])
            for (rect, color) in segments {
                let thumbnail = NSRect(x: 12 + rect.minX * scale, y: (bounds.height - layout.frame.height * scale) / 2 + (layout.frame.height - rect.maxY) * scale, width: rect.width * scale, height: rect.height * scale).insetBy(dx: 1, dy: 1)
                color.setFill()
                NSBezierPath(roundedRect: thumbnail, xRadius: 3, yRadius: 3).fill()
            }
        }
        (layoutStyle.name as NSString).draw(in: NSRect(x: 120, y: 29, width: 124, height: 22), withAttributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: NSColor.labelColor])
    }
}

final class LayoutSettingsView: NSView {
    private let preferences: Preferences
    private var options: [LayoutOption] = []
    private let preview = NSView()
    private var lastPreviewSize = NSSize.zero
    init(preferences: Preferences) {
        self.preferences = preferences
        super.init(frame: .zero)
        let title = NSTextField(labelWithString: "Jak chcesz wybierać?")
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        let subtitle = NSTextField(labelWithString: "Wybierz układ okienka, które pojawia się po kliknięciu linku.")
        subtitle.font = .systemFont(ofSize: 12); subtitle.textColor = .secondaryLabelColor
        options = ChooserStyle.allCases.map { LayoutOption(style: $0, target: self, action: #selector(selectLayout(_:))) }
        let grid = NSGridView(views: [[options[0], options[1]], [options[2], options[3]]])
        grid.rowSpacing = 10; grid.columnSpacing = 10
        let caption = NSTextField(labelWithString: "Podgląd Twoich aktywnych opcji")
        caption.font = .systemFont(ofSize: 12, weight: .semibold)
        preview.widthAnchor.constraint(equalToConstant: 510).isActive = true
        preview.heightAnchor.constraint(equalToConstant: 190).isActive = true
        let hint = NSTextField(labelWithString: "Profile są pod swoją przeglądarką · ⌘1–⌘9 wybiera opcje.")
        hint.font = .systemFont(ofSize: 11); hint.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [title, subtitle, grid, caption, preview, hint])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 16
        stack.setCustomSpacing(5, after: title)
        stack.translatesAutoresizingMaskIntoConstraints = false; addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22), stack.topAnchor.constraint(equalTo: topAnchor, constant: 22)])
        refresh()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layout() {
        super.layout()
        if preview.bounds.size != lastPreviewSize { lastPreviewSize = preview.bounds.size; updatePreview() }
    }
    func refresh() {
        for option in options { option.state = option.layoutStyle == preferences.chooserStyle ? .on : .off; option.needsDisplay = true }
        updatePreview()
    }
    @objc private func selectLayout(_ sender: LayoutOption) { preferences.chooserStyle = sender.layoutStyle; refresh() }
    private func updatePreview() {
        preview.subviews.forEach { $0.removeFromSuperview() }
        guard preview.bounds.width > 0 else { return }
        let style = preferences.chooserStyle
        let choices = chooserChoices(preferred: preferences.lastBrowser, extras: preferences.activeProfiles)
        let layout = ChooserLayout.make(cursor: .zero, screen: NSRect(x: 0, y: 0, width: 2000, height: 2000), preferred: preferences.lastBrowser, extras: preferences.activeProfiles, style: style)
        let scale = min(1, (preview.bounds.width - 12) / layout.frame.width, (preview.bounds.height - 12) / layout.frame.height)
        let size = NSSize(width: layout.frame.width * scale, height: layout.frame.height * scale)
        let card = NSView(frame: NSRect(x: (preview.bounds.width - size.width) / 2, y: (preview.bounds.height - size.height) / 2, width: size.width, height: size.height))
        card.bounds = NSRect(origin: .zero, size: layout.frame.size)
        card.wantsLayer = true; card.layer?.cornerRadius = 10; card.layer?.masksToBounds = true
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        populateChooser(card, choices: choices, layout: layout, style: style)
        preview.addSubview(card)
    }
}
