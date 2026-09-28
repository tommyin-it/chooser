import AppKit
import ServiceManagement
import Carbon

private final class SetupCard: NSView {
    let detail = NSTextField(labelWithString: "")
    private let icon = NSImageView()
    init(symbol: String, title: String, detail: String, action: NSView) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 14
        let heading = NSTextField(labelWithString: title)
        heading.font = .systemFont(ofSize: 14, weight: .semibold)
        self.detail.stringValue = detail
        self.detail.font = .systemFont(ofSize: 11)
        self.detail.textColor = .secondaryLabelColor
        self.detail.lineBreakMode = .byTruncatingTail
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        icon.contentTintColor = .controlAccentColor
        let text = NSStackView(views: [heading, self.detail])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 5
        for view in [icon, text, action] { view.translatesAutoresizingMaskIntoConstraints = false; addSubview(view) }
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 88),
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 26), icon.heightAnchor.constraint(equalToConstant: 26),
            text.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 14),
            text.centerYAnchor.constraint(equalTo: centerYAnchor),
            text.trailingAnchor.constraint(lessThanOrEqualTo: action.leadingAnchor, constant: -12),
            action.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            action.centerYAnchor.constraint(equalTo: centerYAnchor),
            action.widthAnchor.constraint(equalToConstant: 180)
        ])
        updateColor()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); updateColor() }
    private func updateColor() { layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor }
}

final class SettingsController: NSWindowController, NSWindowDelegate, NSTabViewDelegate {
    private unowned let app: AppDelegate
    private let tabs = NSTabView()
    private let mode = NSPopUpButton()
    private let recorder = ShortcutRecorder()
    private let login = NSButton(checkboxWithTitle: L("Launch at login", "Start przy logowaniu"), target: nil, action: nil)
    private let loginApproval = NSButton(title: L("Approve…", "Zatwierdź…"), target: nil, action: nil)
    private let progress = NSTextField(labelWithString: "")
    private var defaultButton: NSButton!
    private var defaultCard: SetupCard!
    private var shortcutCard: SetupCard!
    private var rulesCard: SetupCard!
    private var rulesView: ApplicationRulesView!

    init(app: AppDelegate) {
        self.app = app
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 650), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = L("Chooser — Settings", "Chooser — Ustawienia")
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        super.init(window: window)
        window.delegate = self
        window.center()
        tabs.frame = window.contentView!.bounds.insetBy(dx: 14, dy: 14)
        tabs.autoresizingMask = [.width, .height]
        window.contentView!.addSubview(tabs)
        let general = NSTabViewItem(identifier: "general")
        general.label = L("Get started", "Start")
        let generalView = NSView()
        general.view = generalView
        tabs.addTabViewItem(general)
        let rulesTab = NSTabViewItem(identifier: "rules")
        rulesTab.label = L("App rules", "Reguły aplikacji")
        rulesView = ApplicationRulesView(preferences: app.preferences)
        rulesView.onChange = { [weak self] in self?.refresh() }
        rulesTab.view = rulesView
        tabs.addTabViewItem(rulesTab)
        let profileTab = NSTabViewItem(identifier: "profiles")
        profileTab.label = L("Profiles", "Profile")
        profileTab.view = ProfileSettingsView(preferences: app.preferences)
        tabs.addTabViewItem(profileTab)
        let layoutTab = NSTabViewItem(identifier: "layout")
        layoutTab.label = L("Appearance", "Wygląd")
        layoutTab.view = LayoutSettingsView(preferences: app.preferences)
        tabs.addTabViewItem(layoutTab)
        tabs.delegate = self

        let heading = NSTextField(labelWithString: L("Your links. Your choice.", "Linki po Twojemu."))
        heading.font = .systemFont(ofSize: 25, weight: .bold)
        progress.font = .systemFont(ofSize: 12)
        progress.textColor = .secondaryLabelColor
        defaultButton = NSButton(title: L("Connect…", "Połącz…"), target: self, action: #selector(makeDefault))
        defaultButton.bezelStyle = .rounded
        defaultCard = SetupCard(symbol: "link", title: L("1. Link handling", "1. Obsługa linków"), detail: L("Make Chooser your default browser.", "Ustaw Chooser jako domyślny."), action: defaultButton)
        defaultCard.toolTip = L("macOS will ask to route HTTP and HTTPS links to Chooser. Accessibility and Input Monitoring are not required.", "macOS poprosi o zgodę na obsługę HTTP i HTTPS. Nie potrzebujemy Dostępności ani Monitorowania wprowadzania.")
        shortcutCard = SetupCard(symbol: "keyboard", title: L("2. Your shortcut", "2. Twój skrót"), detail: L("Cycle Choose → Brave → Chrome.", "Przełączaj Wybór → Brave → Chrome."), action: recorder)
        recorder.toolTip = L("Click and press a shortcut. Hyper is Control + Option + Command + Shift. With Karabiner you can use Caps Lock + B. Escape cancels.", "Kliknij i naciśnij kombinację. Hyper to Control + Option + Command + Shift. Z Karabinerem możesz użyć Caps Lock + B. Escape anuluje.")
        let addRule = NSButton(title: L("Add app…", "Dodaj aplikację…"), target: self, action: #selector(addFirstRule))
        addRule.bezelStyle = .rounded
        rulesCard = SetupCard(symbol: "arrow.triangle.branch", title: L("3. App rules", "3. Reguły aplikacji"), detail: L("Optional · e.g. Slack → Chrome.", "Opcjonalnie · np. Slack → Chrome."), action: addRule)
        mode.addItems(withTitles: Mode.allCases.map(\.name))
        mode.target = self
        mode.action = #selector(modeChanged)
        let modeLabel = NSTextField(labelWithString: L("Mode without a rule", "Tryb bez reguły"))
        modeLabel.font = .systemFont(ofSize: 12)
        let modeRow = NSStackView(views: [modeLabel, mode])
        modeRow.spacing = 12
        login.target = self
        login.action = #selector(loginChanged)
        loginApproval.bezelStyle = .rounded
        loginApproval.target = self
        loginApproval.action = #selector(approveLogin)
        let loginRow = NSStackView(views: [login, loginApproval])
        loginRow.spacing = 12
        let language = NSPopUpButton()
        language.addItems(withTitles: AppLanguage.allCases.map(\.name))
        language.selectItem(at: AppLanguage.allCases.firstIndex(of: Localization.language)!)
        language.target = self
        language.action = #selector(languageChanged(_:))
        let languageRow = NSStackView(views: [NSTextField(labelWithString: L("Language", "Język")), language])
        languageRow.spacing = 12
        let stack = NSStackView(views: [heading, progress, defaultCard, shortcutCard, rulesCard, modeRow, loginRow, languageRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.setCustomSpacing(5, after: heading)
        stack.setCustomSpacing(22, after: progress)
        stack.translatesAutoresizingMaskIntoConstraints = false
        generalView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: generalView.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: generalView.trailingAnchor, constant: -22),
            stack.topAnchor.constraint(equalTo: generalView.topAnchor, constant: 22)
        ])
        for card in [defaultCard!, shortcutCard!, rulesCard!] { card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
        recorder.onBegin = { [weak self] in
            self?.app.hotKey.unregister()
            self?.shortcutCard.detail.stringValue = L("Press a shortcut · Esc cancels.", "Naciśnij kombinację · Esc anuluje.")
        }
        recorder.onCancel = { [weak self] in self?.restoreShortcut() }
        recorder.onRecord = { [weak self] shortcut in
            guard let self else { return }
            let result = self.app.hotKey.register(shortcut)
            if result == noErr {
                self.app.preferences.shortcut = shortcut
                self.app.refreshMenu()
                self.refresh()
            } else {
                self.restoreShortcut()
                self.app.alert(L("Shortcut unavailable", "Skrót jest zajęty"), L("Choose another shortcut. System code: \(result).", "Wybierz inną kombinację. Kod systemowy: \(result)."))
            }
        }
        refresh()
    }
    required init?(coder: NSCoder) { fatalError() }
    func refresh() {
        mode.selectItem(at: Mode.allCases.firstIndex(of: app.preferences.mode)!)
        if !recorder.recording {
            recorder.title = app.preferences.hasRecordedShortcut ? app.preferences.shortcut.label + L(" · change", " · zmień") : L("Record shortcut…", "Nagraj skrót…")
            shortcutCard.detail.stringValue = app.preferences.hasRecordedShortcut ? L("Ready · works across apps.", "Gotowe · działa w każdej aplikacji.") : L("Default: Hyper + B. Choose your own.", "Domyślnie Hyper + B. Wybierz własny.")
        }
        let status = SMAppService.mainApp.status
        login.state = status == .enabled || status == .requiresApproval ? .on : .off
        loginApproval.isHidden = status != .requiresApproval
        let schemes = ["http", "https"].filter { scheme in
            guard let handler = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "\(scheme)://example.com")!) else { return false }
            return Bundle(url: handler)?.bundleIdentifier == Bundle.main.bundleIdentifier
        }
        let linked = schemes.count == 2
        defaultCard.detail.stringValue = linked ? L("Ready · links open with Chooser.", "Gotowe · linki trafiają do Chooser.") : L("One-time setup in macOS.", "Jednorazowa zgoda w macOS.")
        defaultButton.title = linked ? L("✓ Connected", "✓ Połączono") : L("Connect…", "Połącz…")
        defaultButton.isEnabled = !linked
        let count = app.preferences.applicationRules.count
        rulesCard.detail.stringValue = count == 0 ? L("Optional · e.g. Slack → Chrome.", "Opcjonalnie · np. Slack → Chrome.") : L("Saved rules: \(count).", "Zapisane reguły: \(count).")
        progress.stringValue = linked && app.preferences.hasRecordedShortcut ? L("You’re all set. Make it your own.", "Wszystko gotowe. Dopasuj resztę do siebie.") : L("Two quick steps to get started.", "Dwa krótkie kroki na początek.")
    }
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        (tabViewItem?.view as? LayoutSettingsView)?.refresh()
        (tabViewItem?.view as? ProfileSettingsView)?.reload()
    }
    func dismissForLink() {
        recorder.cancel()
        if let window {
            for sheet in window.sheets {
                window.endSheet(sheet, returnCode: .cancel)
                sheet.orderOut(nil)
            }
            window.orderOut(nil)
        }
    }
    private func restoreShortcut() {
        let result = app.hotKey.register(app.preferences.shortcut)
        refresh()
        if result != noErr { app.alert(L("Shortcut unavailable", "Skrót jest niedostępny"), L("Record a new shortcut. System code: \(result).", "Nagraj nową kombinację. Kod systemowy: \(result).")) }
    }
    func windowWillClose(_ notification: Notification) { recorder.cancel() }
    func windowDidResignKey(_ notification: Notification) { recorder.cancel() }
    func windowDidBecomeKey(_ notification: Notification) { refresh() }
    @objc private func languageChanged(_ sender: NSPopUpButton) {
        recorder.cancel()
        let language = AppLanguage.allCases[sender.indexOfSelectedItem]
        DispatchQueue.main.async { [weak app] in app?.changeLanguage(language) }
    }
    @objc private func modeChanged() { app.setMode(Mode.allCases[mode.indexOfSelectedItem]) }
    @objc private func addFirstRule() { tabs.selectTabViewItem(at: 1); rulesView.addApplication() }
    @objc private func approveLogin() { SMAppService.openSystemSettingsLoginItems() }
    @objc private func loginChanged() {
        do {
            if login.state == .on {
                if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
                else { try SMAppService.mainApp.register() }
            } else { try SMAppService.mainApp.unregister() }
        } catch { app.alert(L("Cannot change launch at login", "Nie można zmienić startu przy logowaniu"), error.localizedDescription) }
        refresh()
    }
    @objc private func makeDefault() {
        defaultButton.isEnabled = false
        setDefault(schemes: ["http", "https"], errors: [])
    }
    private func setDefault(schemes: [String], errors: [String]) {
        guard let scheme = schemes.first else {
            refresh()
            if !errors.isEmpty { app.alert(L("Some settings could not be changed", "Nie zmieniono wszystkich ustawień"), errors.joined(separator: "\n")) }
            return
        }
        NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpenURLsWithScheme: scheme) { [weak self] error in
            DispatchQueue.main.async {
                self?.setDefault(schemes: Array(schemes.dropFirst()), errors: errors + (error.map { ["\(scheme): \($0.localizedDescription)"] } ?? []))
            }
        }
    }
}
