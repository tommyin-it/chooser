import AppKit
import SwiftUI

// Like Scribe's IslandShadow: only the decoration is rasterized, with enough
// room for its entire blur. AppKit controls never enter the drawing group.
private struct PanelShadow: View, Animatable {
    var cornerRadius: CGFloat
    var animatableData: CGFloat {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
                .insetBy(dx: ShadowedPanel.shadowPadding, dy: ShadowedPanel.shadowPadding)
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .circular)
            context.addFilter(.shadow(color: .black.opacity(0.28), radius: 14,
                                      y: 6, options: .shadowOnly))
            context.fill(shape.path(in: rect), with: .color(.black))
        }
        .drawingGroup(opaque: false)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// Separate windows make click-through reliable at the WindowServer level:
// even the nonzero-alpha shadow pixels cannot swallow a click outside the card.
// The shadow window is larger; the interactive window is exactly the card.
class ShadowedPanel: NSPanel {
    static let shadowPadding: CGFloat = 48
    let cornerRadius: CGFloat
    private var shadowPanel: NSPanel?

    init(cardFrame: NSRect, cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
        super.init(contentRect: cardFrame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let shadow = NSPanel(contentRect: Self.shadowFrame(for: frame), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        shadow.isOpaque = false
        shadow.backgroundColor = .clear
        shadow.hasShadow = false
        shadow.ignoresMouseEvents = true
        shadow.hidesOnDeactivate = false
        shadow.isReleasedWhenClosed = false
        shadow.collectionBehavior = collectionBehavior
        let hosting = NSHostingView(rootView: PanelShadow(cornerRadius: cornerRadius))
        hosting.frame = NSRect(origin: .zero, size: shadow.frame.size)
        hosting.autoresizingMask = [.width, .height]
        shadow.contentView = hosting
        shadowPanel = shadow
    }

    static func shadowFrame(for cardFrame: NSRect) -> NSRect {
        cardFrame.insetBy(dx: -shadowPadding, dy: -shadowPadding)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func showShadow() {
        guard let shadowPanel else { return }
        shadowPanel.level = level
        shadowPanel.alphaValue = alphaValue
        shadowPanel.setFrame(Self.shadowFrame(for: frame), display: true)
        addChildWindow(shadowPanel, ordered: .below)
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(frameRect, display: flag)
        shadowPanel?.setFrame(Self.shadowFrame(for: frame), display: flag)
    }

    func setOpacity(_ opacity: CGFloat, animated: Bool, completion: (() -> Void)? = nil) {
        guard animated, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            alphaValue = opacity
            shadowPanel?.alphaValue = opacity
            completion?()
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().alphaValue = opacity
            shadowPanel?.animator().alphaValue = opacity
        } completionHandler: { completion?() }
    }

    override func orderOut(_ sender: Any?) {
        if let shadowPanel {
            removeChildWindow(shadowPanel)
            shadowPanel.orderOut(sender)
        }
        super.orderOut(sender)
    }

    func makeCard(material: NSVisualEffectView.Material) -> NSVisualEffectView {
        let card = NSVisualEffectView(frame: NSRect(origin: .zero, size: frame.size))
        card.material = material
        card.state = .active
        card.wantsLayer = true
        card.layer?.cornerRadius = cornerRadius
        card.layer?.masksToBounds = true
        card.autoresizingMask = [.width, .height]
        return card
    }
}
