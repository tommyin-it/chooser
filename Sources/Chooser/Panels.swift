import AppKit

final class FloatingPanel: ShadowedPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class BrowserButton: NSButton {
    let choice: BrowserChoice
    private lazy var browserIcon = choice.browser.icon
    private let preferred: Bool
    private let shortcut: String
    private let horizontal: Bool
    private var hovered = false
    private var pressed = false
    private var selectionFlashing = false
    private var tracking: NSTrackingArea?
    private let fill = CALayer()
    var onChoose: ((BrowserChoice) -> Void)?

    init(choice: BrowserChoice, index: Int, frame: NSRect, horizontal: Bool = false) {
        self.choice = choice
        self.horizontal = horizontal
        self.preferred = index == 0
        shortcut = index < 9 ? "⌘\(index + 1)" : ""
        super.init(frame: frame)
        title = choice.name
        isBordered = false
        wantsLayer = true
        fill.frame = bounds.insetBy(dx: 3, dy: 3)
        fill.cornerRadius = 7
        layer?.addSublayer(fill)
        setAccessibilityLabel(L("Open in \(choice.browser.name), \(choice.name), \(shortcut)", "Otwórz w \(choice.browser.name), \(choice.name), \(shortcut)"))
        toolTip = "\(choice.browser.name) · \(choice.name) · \(shortcut)"
        target = self
        action = #selector(choose)
        updateFill(animated: false)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
        tracking = area
        if let window {
            hovered = bounds.contains(convert(window.mouseLocationOutsideOfEventStream, from: nil))
            updateFill(animated: false)
        }
    }
    override func mouseEntered(with event: NSEvent) { hovered = true; updateFill() }
    override func mouseExited(with event: NSEvent) { hovered = false; updateFill() }
    override func mouseDown(with event: NSEvent) {
        pressed = true
        updateFill()
        super.mouseDown(with: event)
        if !selectionFlashing { pressed = false; updateFill() }
    }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); updateFill(animated: false) }
    private func updateFill(animated: Bool = true) {
        let alpha: CGFloat = pressed ? 0.38 : (hovered ? 0.24 : (preferred ? 0.10 : 0))
        let color = NSColor.controlAccentColor.withAlphaComponent(alpha).cgColor
        if animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            let animation = CABasicAnimation(keyPath: "backgroundColor")
            animation.fromValue = fill.presentation()?.backgroundColor ?? fill.backgroundColor
            animation.toValue = color
            animation.duration = pressed ? 0.06 : 0.14
            fill.add(animation, forKey: "hover")
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fill.backgroundColor = color
        CATransaction.commit()
    }
    override func draw(_ dirtyRect: NSRect) {
        func text(_ value: String, rect: NSRect, size: CGFloat, color: NSColor, alignment: NSTextAlignment = .center) {
            let style = NSMutableParagraphStyle()
            style.alignment = alignment
            style.lineBreakMode = .byTruncatingTail
            (value as NSString).draw(in: rect, withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: .medium), .foregroundColor: color, .paragraphStyle: style])
        }
        if bounds.height < 34 {
            // Profile bands use a single compact line. Narrow bands keep the
            // full name in their tooltip and accessibility label.
            let showIcon = bounds.width >= 100
            let showShortcut = bounds.width >= 90 && !shortcut.isEmpty
            let leading: CGFloat = showIcon ? 24 : 5
            if showIcon {
                browserIcon.draw(in: NSRect(x: 5, y: (bounds.height - 14) / 2, width: 14, height: 14), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            }
            text(choice.name, rect: NSRect(x: leading, y: (bounds.height - 12) / 2, width: bounds.width - leading - (showShortcut ? 26 : 5), height: 12), size: 10, color: .labelColor, alignment: showIcon ? .left : .center)
            if showShortcut { text(shortcut, rect: NSRect(x: bounds.width - 26, y: (bounds.height - 11) / 2, width: 23, height: 11), size: 8, color: .secondaryLabelColor) }
        } else if horizontal {
            let iconSize: CGFloat = bounds.height >= 50 ? 26 : 20
            browserIcon.draw(in: NSRect(x: 9, y: (bounds.height - iconSize) / 2, width: iconSize, height: iconSize), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            let textX = iconSize + 17
            text(choice.name, rect: NSRect(x: textX, y: (bounds.height - 14) / 2, width: max(0, bounds.width - textX - 29), height: 14), size: 11, color: .labelColor, alignment: .left)
            text(shortcut, rect: NSRect(x: bounds.width - 28, y: (bounds.height - 12) / 2, width: 23, height: 12), size: 9, color: .secondaryLabelColor)
        } else if bounds.height < 54 {
            let iconSize: CGFloat = 18
            let offset = max(0, (bounds.height - 34) / 2)
            browserIcon.draw(in: NSRect(x: (bounds.width - iconSize) / 2, y: offset + 1, width: iconSize, height: iconSize), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            text(choice.name, rect: NSRect(x: 2, y: offset + 21, width: bounds.width - 4, height: 13), size: 10, color: .labelColor)
            if bounds.width >= 80 { text(shortcut, rect: NSRect(x: bounds.width - 26, y: 3, width: 22, height: 11), size: 8, color: .secondaryLabelColor) }
        } else {
            let offset = max(0, (bounds.height - 56) / 2)
            browserIcon.draw(in: NSRect(x: (bounds.width - 22) / 2, y: offset + 5, width: 22, height: 22), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            text(choice.name, rect: NSRect(x: 2, y: offset + 28, width: bounds.width - 4, height: 14), size: 10, color: .labelColor)
            text(shortcut, rect: NSRect(x: 2, y: offset + 41, width: bounds.width - 4, height: 14), size: 9, color: .secondaryLabelColor)
        }
    }

    @objc private func choose() { onChoose?(choice) }
    func flashSelection() { selectionFlashing = true; pressed = true; updateFill() }
}

private final class ProfileBandScrollView: NSScrollView {
    override func scrollWheel(with event: NSEvent) {
        let delta = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) ? event.scrollingDeltaX : event.scrollingDeltaY
        let maximum = max(0, (documentView?.bounds.width ?? 0) - contentView.bounds.width)
        contentView.scroll(to: NSPoint(x: min(max(0, contentView.bounds.minX - delta), maximum), y: 0))
        reflectScrolledClipView(contentView)
    }
}

@discardableResult
func populateChooser(_ content: NSView, choices: [BrowserChoice], layout: ChooserLayout, style: ChooserStyle, onChoose: ((BrowserChoice) -> Void)? = nil) -> [BrowserButton] {
    var buttons: [Int: BrowserButton] = [:]
    for (groupIndex, group) in layout.groups.enumerated() {
        let background = NSView(frame: group.frame.insetBy(dx: 1, dy: 1))
        background.wantsLayer = true
        background.layer?.cornerRadius = 8
        background.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(groupIndex == 0 ? 0.035 : 0.015).cgColor
        content.addSubview(background)
        let main = BrowserButton(choice: choices[groupIndex], index: groupIndex, frame: group.mainFrame, horizontal: style.horizontalButton(at: groupIndex))
        main.onChoose = onChoose
        content.addSubview(main); buttons[groupIndex] = main
        if let band = group.profileBand {
            let scroll = ProfileBandScrollView(frame: band)
            scroll.drawsBackground = false
            scroll.borderType = .noBorder
            scroll.hasHorizontalScroller = true
            scroll.hasVerticalScroller = false
            scroll.scrollerStyle = .overlay
            scroll.autohidesScrollers = true
            scroll.toolTip = L("\(group.browser.name) profiles. Scroll to see more.", "Profile \(group.browser.name). Przewiń, aby zobaczyć pozostałe.")
            let document = NSView(frame: NSRect(origin: .zero, size: group.documentSize))
            for (position, index) in group.profileIndices.enumerated() {
                let button = BrowserButton(choice: choices[index], index: index, frame: group.profileFrames[position], horizontal: true)
                button.onChoose = onChoose
                document.addSubview(button); buttons[index] = button
            }
            scroll.documentView = document
            content.addSubview(scroll)
            let divider = NSBox(frame: NSRect(x: band.minX + 4, y: band.maxY - 0.5, width: max(0, band.width - 8), height: 1))
            divider.boxType = .separator
            content.addSubview(divider)
        }
    }
    return choices.indices.compactMap { buttons[$0] }
}

final class ChooserPanel {
    private var panel: FloatingPanel?
    private var monitors: [Any] = []
    private var selecting = false
    private var buttons: [BrowserButton] = []
    var onChoose: ((BrowserChoice) -> Void)?
    var onCancel: (() -> Void)?
    var visible: Bool { panel?.isVisible == true }
    func show(preferred: Browser, extras: [BrowserProfile] = [], style: ChooserStyle = .strip) {
        guard !visible else { return }
        let cursor = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(cursor) }) ?? NSScreen.main!
        // Keep the entire panel visible; the remembered browser always stays left.
        let layout = ChooserLayout.make(cursor: cursor, screen: screen.frame, preferred: preferred, extras: extras, style: style)
        let panel = FloatingPanel(cardFrame: layout.frame, cornerRadius: 10)
        panel.level = .popUpMenu
        let content = panel.makeCard(material: .popover)
        selecting = false
        let choices = chooserChoices(preferred: preferred, extras: extras)
        buttons = populateChooser(content, choices: choices, layout: layout, style: style) { [weak self] choice in self?.select(choice) }
        panel.contentView = content
        self.panel = panel
        panel.makeKeyAndOrderFront(nil)
        panel.showShadow()
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown], handler: { [weak self] _ in self?.onCancel?() }) { monitors.append(monitor) }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown], handler: { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown {
                if event.keyCode == 53 { self.onCancel?(); return nil }
                let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
                if modifiers == .command, let key = event.charactersIgnoringModifiers,
                   let index = (1...9).map(String.init).firstIndex(of: key), self.buttons.indices.contains(index) {
                    if !event.isARepeat { self.select(self.buttons[index].choice) }
                    return nil
                }
            } else if event.window !== self.panel { self.onCancel?() }
            return event
        }) { monitors.append(monitor) }
    }
    private func select(_ choice: BrowserChoice) {
        guard !selecting, let currentPanel = panel else { return }
        selecting = true
        if let button = buttons.first(where: { $0.choice == choice }) {
            button.scrollToVisible(button.bounds)
            button.flashSelection()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { [weak self, weak currentPanel] in
            guard let self, let currentPanel, self.panel === currentPanel else { return }
            self.onChoose?(choice)
        }
    }
    func hide() {
        buttons.removeAll()
        selecting = false
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        panel?.orderOut(nil)
        panel = nil
    }
}

final class ModeHUD {
    private var panel: ShadowedPanel?
    private var timer: Timer?
    func show(_ mode: Mode) {
        timer?.invalidate()
        panel?.orderOut(nil)
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main!
        let frame = NSRect(x: screen.visibleFrame.midX - 100, y: screen.visibleFrame.minY + 95, width: 200, height: 100)
        let panel = ShadowedPanel(cardFrame: frame, cornerRadius: 18)
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        let content = panel.makeCard(material: .hudWindow)
        let icon = NSImageView(frame: NSRect(x: 80, y: 47, width: 40, height: 40))
        icon.image = mode.icon
        let label = NSTextField(labelWithString: mode.name)
        label.frame = NSRect(x: 10, y: 15, width: 180, height: 25)
        label.alignment = .center
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        content.addSubview(icon)
        content.addSubview(label)
        panel.contentView = content
        panel.setOpacity(0, animated: false)
        panel.orderFrontRegardless()
        panel.showShadow()
        panel.setOpacity(1, animated: true)
        self.panel = panel
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            guard let self, let current = self.panel else { return }
            current.setOpacity(0, animated: true) { [weak self, weak current] in
                guard let self, let current, self.panel === current else { return }
                current.orderOut(nil)
                self.panel = nil
            }
        }
    }
}
