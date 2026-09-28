import AppKit
import Carbon

final class AppDelegate: NSObject, NSApplicationDelegate {
    let preferences = Preferences()
    let hotKey = HotKey()
    let chooser = ChooserPanel()
    let hud = ModeHUD()
    private let profileLauncher = ProfileLauncher()
    private var statusItem: NSStatusItem!
    private var pending: [URL] = []
    private var settings: SettingsController?
    private var ready = false
    private var initialRequests: [(urls: [URL], source: String?)] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        hotKey.onPress = { [weak self] in guard let self else { return }; self.setMode(self.preferences.mode.next) }
        chooser.onChoose = { [weak self] choice in
            guard let self else { return }
            let urls = self.pending
            self.pending.removeAll()
            self.chooser.hide()
            switch choice {
            case .browser(let browser): self.open(urls, in: browser, remember: true)
            case .profile(let profile): self.openProfile(urls, profile: profile)
            }
        }
        chooser.onCancel = { [weak self] in self?.cancelPending() }
        refreshMenu()
        ready = true
        let code = hotKey.register(preferences.shortcut)
        if code != noErr {
            alert(L("Shortcut unavailable", "Skrót jest niedostępny"), L("Choose another shortcut in Settings. System code: \(code).", "Wybierz inną kombinację w ustawieniach. Kod systemowy: \(code)."))
        }
        let requests = initialRequests
        initialRequests.removeAll()
        for request in requests { receive(request.urls, sourceBundleID: request.source) }
        if CommandLine.arguments.contains("--preview-chooser") { chooser.show(preferred: preferences.lastBrowser, extras: preferences.activeProfiles, style: preferences.chooserStyle) }
        if CommandLine.arguments.contains("--preview-hud") { hud.show(preferences.mode) }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        let urls = webURLs(urls)
        guard !urls.isEmpty else { return }
        // Preserve the source with each request, including cold-launch delivery.
        // Never infer the source from the foreground app: it may be unrelated.
        let event = NSAppleEventManager.shared().currentAppleEvent
        let source = event?.attributeDescriptor(forKeyword: AEKeyword(keySenderPIDAttr))
            .flatMap { NSRunningApplication(processIdentifier: $0.int32Value) }
            .map { application -> String? in
                // Electron helpers may live inside the enclosing application's bundle.
                if let url = application.bundleURL {
                    var current = url
                    var enclosingID: String?
                    while current.path != "/" {
                        if current.pathExtension == "app", let id = Bundle(url: current)?.bundleIdentifier { enclosingID = id }
                        current.deleteLastPathComponent()
                    }
                    if let enclosingID { return enclosingID }
                }
                return application.bundleIdentifier
            } ?? nil
        if ready { receive(urls, sourceBundleID: source) }
        else { initialRequests.append((urls, source)) }
    }

    func receive(_ urls: [URL], sourceBundleID: String? = nil) {
        // Launch Services can activate all windows of the receiving app. An
        // existing Settings window must not come forward with the link chooser.
        settings?.dismissForLink()
        if let browser = destination(sourceBundleID: sourceBundleID, mode: preferences.mode, rules: preferences.applicationRules) { open(urls, in: browser) }
        else {
            pending.append(contentsOf: urls)
            chooser.show(preferred: preferences.lastBrowser, extras: preferences.activeProfiles, style: preferences.chooserStyle)
        }
    }

    func setMode(_ mode: Mode) {
        preferences.mode = mode
        refreshMenu()
        settings?.refresh()
        hud.show(mode)
        // Switching modes never activates a browser, including with a chooser open.
        cancelPending()
    }

    private func cancelPending() { pending.removeAll(); chooser.hide() }

    private func open(_ urls: [URL], in browser: Browser, remember: Bool = false) {
        guard !urls.isEmpty else { return }
        if let profile = preferences.mainProfile(for: browser) {
            if openProfile(urls, profile: profile), remember { preferences.lastBrowser = browser }
            return
        }
        guard let application = browser.applicationURL else {
            offerFallback(urls, browser: browser, message: L("Could not find \(browser.name).", "Nie znaleziono aplikacji \(browser.name)."), remember: remember)
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open(urls, withApplicationAt: application, configuration: configuration) { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.offerFallback(urls, browser: browser, message: error.localizedDescription, remember: remember)
                } else if remember { self.preferences.lastBrowser = browser }
            }
        }
    }

    @discardableResult private func openProfile(_ urls: [URL], profile: BrowserProfile) -> Bool {
        guard !urls.isEmpty else { return false }
        do {
            try profileLauncher.open(urls, profile: profile) { [weak self] message in
                self?.alert(L("Cannot open profile", "Nie można otworzyć profilu"), message)
            }
            return true
        } catch {
            alert(L("Cannot open profile", "Nie można otworzyć profilu"), error.localizedDescription)
            return false
        }
    }

    private func offerFallback(_ urls: [URL], browser: Browser, message: String, remember: Bool) {
        let dialog = NSAlert()
        dialog.messageText = L("Cannot open in \(browser.name)", "Nie można otworzyć w \(browser.name)")
        dialog.informativeText = message
        let available = browser.other.applicationURL != nil
        dialog.addButton(withTitle: available ? L("Open in \(browser.other.name)", "Otwórz w \(browser.other.name)") : "OK")
        if available { dialog.addButton(withTitle: L("Cancel", "Anuluj")) }
        NSApp.activate(ignoringOtherApps: true)
        if dialog.runModal() == .alertFirstButtonReturn, available { open(urls, in: browser.other, remember: remember) }
    }

    func alert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    func refreshMenu() {
        let mode = preferences.mode
        statusItem.length = 18 // 16 pt icon with 1 pt of space on either side.
        statusItem.button?.title = ""
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.image = mode.menuBarIcon
        statusItem.button?.setAccessibilityLabel("Chooser — \(mode.name)")
        statusItem.button?.toolTip = "Chooser — \(mode.name) (\(preferences.shortcut.label))"
        let menu = NSMenu()
        for mode in Mode.allCases {
            let item = NSMenuItem(title: mode.name, action: #selector(selectMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            item.state = preferences.mode == mode ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let shortcut = NSMenuItem(title: L("Switch mode: \(preferences.shortcut.label)", "Przełącz tryb: \(preferences.shortcut.label)"), action: nil, keyEquivalent: "")
        menu.addItem(shortcut)
        let settings = NSMenuItem(title: L("Settings…", "Ustawienia…"), action: #selector(showSettings(_:)), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: L("Quit Chooser", "Zakończ Chooser"), action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }
    @objc private func selectMode(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let mode = Mode(rawValue: raw) { setMode(mode) }
    }
    @objc func showSettings(_ sender: Any?) {
        cancelPending()
        if settings == nil { settings = SettingsController(app: self) }
        settings?.refresh()
        settings?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        settings?.window?.makeKeyAndOrderFront(nil)
    }
    func changeLanguage(_ language: AppLanguage) {
        let origin = settings?.window?.frame.origin
        settings?.close()
        settings = nil
        Localization.select(language)
        refreshMenu()
        showSettings(nil)
        if let origin { settings?.window?.setFrameOrigin(origin) }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Launch Services may reopen the app as part of delivering a URL.
        // Settings are opened explicitly from the menu, never
        // from reopen; calling showSettings here also cancels queued links.
        return false
    }
    @objc private func quit() { NSApp.terminate(nil) }
}
