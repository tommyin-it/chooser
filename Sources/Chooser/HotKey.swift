import AppKit
import Carbon

final class HotKey {
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var isPressed = false
    var onPress: (() -> Void)?
    init() {
        var types = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context, let event else { return OSStatus(eventNotHandledErr) }
            let hotKey = Unmanaged<HotKey>.fromOpaque(context).takeUnretainedValue()
            if GetEventKind(event) == UInt32(kEventHotKeyReleased) { hotKey.isPressed = false }
            else if !hotKey.isPressed { hotKey.isPressed = true; hotKey.onPress?() }
            return noErr
        }, types.count, &types, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    @discardableResult func register(_ shortcut: Shortcut) -> OSStatus {
        unregister()
        let id = EventHotKeyID(signature: 0x43485352, id: 1)
        return RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, id, GetApplicationEventTarget(), 0, &reference)
    }
    func unregister() {
        if let reference { UnregisterEventHotKey(reference) }
        reference = nil
        isPressed = false
    }
    deinit {
        unregister()
        if let handler { RemoveEventHandler(handler) }
    }
}

final class ShortcutRecorder: NSButton {
    var onBegin: (() -> Void)?
    var onRecord: ((Shortcut) -> Void)?
    var onCancel: (() -> Void)?
    private(set) var recording = false
    override var acceptsFirstResponder: Bool { true }
    init() {
        super.init(frame: .zero)
        bezelStyle = .rounded
        target = self
        action = #selector(begin)
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc private func begin() {
        guard !recording else { return }
        recording = true
        onBegin?()
        title = L("Press a shortcut…", "Naciśnij kombinację…")
        window?.makeFirstResponder(self)
    }
    func cancel() {
        guard recording else { return }
        recording = false
        onCancel?()
    }
    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }
        if event.keyCode == 53 { cancel(); return }
        let flags = event.modifierFlags.intersection([.control, .option, .command, .shift])
        guard !flags.intersection([.control, .option, .command]).isEmpty else {
            title = L("Include Control, Option or Command", "Dodaj Control, Option lub Command")
            NSSound.beep()
            return
        }
        var modifiers: UInt32 = 0
        var label = ""
        for (flag, carbon, symbol) in [(NSEvent.ModifierFlags.control, controlKey, "⌃"), (.option, optionKey, "⌥"), (.command, cmdKey, "⌘"), (.shift, shiftKey, "⇧")] {
            if flags.contains(flag) { modifiers |= UInt32(carbon); label += symbol }
        }
        let special: [UInt16: String] = [36: "↩", 48: "⇥", 49: L("Space", "Spacja"), 51: "⌫", 123: "←", 124: "→", 125: "↓", 126: "↑"]
        let character = special[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased() ?? L("Key \(event.keyCode)", "Klawisz \(event.keyCode)")
        recording = false
        onRecord?(Shortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers, label: label + character))
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if recording { keyDown(with: event); return true }
        return super.performKeyEquivalent(with: event)
    }
}
