import AppKit

final class ProfileSettingsView: NSView, NSTableViewDataSource, NSTableViewDelegate {
    private let preferences: Preferences
    private let chrome = NSPopUpButton()
    private let brave = NSPopUpButton()
    private var profileBrowser: ProfileBrowserController?
    private let master = NSButton(checkboxWithTitle: L("Show extra profiles in the chooser", "Pokaż dodatkowe profile w okienku"), target: nil, action: nil)
    private let table = NSTableView()
    private let status = NSTextField(labelWithString: "")
    private let catalogStatus = NSTextField(wrappingLabelWithString: "")
    private var available: [Browser: [BrowserProfile]] = [:]
    private var blockedBrowsers: [Browser] = []
    private var hasPresentedAccessHelp = false
    private var accessRequest: ProfileAccessRequest?
    private let accessButton = NSButton(title: L("Allow access…", "Zezwól na dostęp…"), target: nil, action: nil)
    private let loadProfiles: (Browser, ((Error) -> Void)?) -> [BrowserProfile]

    init(preferences: Preferences, loadProfiles: @escaping (Browser, ((Error) -> Void)?) -> [BrowserProfile] = { ProfileCatalog.profiles(for: $0, onError: $1) }) {
        self.preferences = preferences
        self.loadProfiles = loadProfiles
        super.init(frame: .zero)
        let title = NSTextField(labelWithString: L("Your profiles", "Twoje profile"))
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        let subtitle = NSTextField(labelWithString: L("Save once. Enable whenever you need them.", "Zapisz raz. Włączaj wtedy, gdy ich potrzebujesz."))
        subtitle.textColor = .secondaryLabelColor
        let grid = NSGridView(views: [[NSTextField(labelWithString: L("Primary Brave", "Główny Brave")), brave], [NSTextField(labelWithString: L("Primary Chrome", "Główny Chrome")), chrome]])
        grid.columnSpacing = 18; grid.rowSpacing = 10; grid.rowAlignment = .firstBaseline
        for popup in [brave, chrome] {
            popup.widthAnchor.constraint(equalToConstant: 330).isActive = true
            popup.target = self; popup.action = #selector(mainChanged(_:))
        }
        master.target = self; master.action = #selector(masterChanged)
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.wantsLayer = true
        scroll.layer?.cornerRadius = 10
        scroll.layer?.masksToBounds = true
        table.headerView = nil
        table.style = .fullWidth
        table.rowHeight = 44
        table.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        for (id, width) in [("name", CGFloat(380)), ("enabled", CGFloat(44)), ("remove", CGFloat(36))] {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
            column.width = width
            if id != "name" { column.minWidth = width; column.maxWidth = width }
            table.addTableColumn(column)
        }
        table.dataSource = self; table.delegate = self
        scroll.documentView = table
        let add = NSButton(title: L("Add profiles…", "Dodaj profile…"), target: self, action: #selector(showProfileBrowser))
        add.bezelStyle = .rounded
        add.image = NSImage(systemSymbolName: "plus", accessibilityDescription: nil)
        add.imagePosition = .imageLeading
        let refresh = NSButton(title: L("Refresh profiles", "Odśwież profile"), target: self, action: #selector(reload))
        refresh.bezelStyle = .rounded
        let addRow = NSStackView(views: [add, refresh]); addRow.spacing = 12
        status.font = .systemFont(ofSize: 11); status.textColor = .secondaryLabelColor
        catalogStatus.font = .systemFont(ofSize: 11)
        catalogStatus.textColor = .secondaryLabelColor
        accessButton.bezelStyle = .rounded
        accessButton.target = self; accessButton.action = #selector(showAccessHelp)
        let accessRow = NSStackView(views: [catalogStatus, accessButton])
        accessRow.alignment = .centerY; accessRow.spacing = 12
        let tip = NSTextField(labelWithString: L("Disabling keeps the profile. Delete only removes it from Chooser.", "Wyłączenie zachowuje profil. Kosz usuwa go tylko z Choosera."))
        tip.font = .systemFont(ofSize: 11); tip.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [title, subtitle, grid, accessRow, master, scroll, status, addRow, tip])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 13
        stack.setCustomSpacing(5, after: title)
        stack.setCustomSpacing(20, after: subtitle)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 22),
            accessRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            catalogStatus.widthAnchor.constraint(lessThanOrEqualTo: stack.widthAnchor, constant: -180),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scroll.heightAnchor.constraint(equalToConstant: 170)
        ])
        NotificationCenter.default.addObserver(self, selector: #selector(recheckAccess), name: NSApplication.didBecomeActiveNotification, object: nil)
        reload()
    }
    deinit { NotificationCenter.default.removeObserver(self) }
    required init?(coder: NSCoder) { fatalError() }
    @objc func reload() {
        var failures: [String] = []
        blockedBrowsers = []
        for browser in Browser.allCases {
            available[browser] = loadProfiles(browser, { error in
                let failure = error as NSError
                if failure.domain == NSCocoaErrorDomain && failure.code == NSFileReadNoPermissionError {
                    self.blockedBrowsers.append(browser)
                } else {
                    failures.append("\(browser.name): \(error.localizedDescription)")
                }
            })
        }
        if !blockedBrowsers.isEmpty {
            let names = blockedBrowsers.map(\.name).joined(separator: ", ")
            failures.insert(L("Allow access to load profiles from \(names).", "Zezwól na dostęp, aby wczytać profile z \(names)."), at: 0)
        }
        catalogStatus.stringValue = failures.joined(separator: "\n")
        catalogStatus.isHidden = failures.isEmpty
        accessButton.isHidden = blockedBrowsers.isEmpty
        catalogStatus.superview?.isHidden = failures.isEmpty
        for (browser, popup) in [(Browser.brave, brave), (.chrome, chrome)] {
            if let saved = preferences.mainProfile(for: browser), !available[browser, default: []].contains(where: { $0.directory == saved.directory }) { available[browser, default: []].append(saved) }
            popup.removeAllItems(); popup.addItem(withTitle: L("Browser default", "Według przeglądarki"))
            for (index, profile) in available[browser, default: []].enumerated() {
                append(profile, to: popup, includeBrowser: false)
                if preferences.mainProfile(for: browser)?.directory == profile.directory { popup.selectItem(at: index + 1) }
            }
        }
        master.state = preferences.showsExtraProfiles ? .on : .off
        table.reloadData()
        updateStatus()
    }
    /// Called only when the Profiles tab is selected, never during app startup.
    func prepareForDisplay() {
        reload()
        DispatchQueue.main.async { [weak self] in self?.requestAccessIfNeeded() }
    }
    func requestAccessIfNeeded() {
        guard !blockedBrowsers.isEmpty, !hasPresentedAccessHelp,
              !isHiddenOrHasHiddenAncestor, let window, window.isVisible, window.attachedSheet == nil else { return }
        showAccessHelp()
    }
    @objc private func recheckAccess() {
        guard !isHiddenOrHasHiddenAncestor, window?.isVisible == true else { return }
        reload()
    }
    @objc private func showAccessHelp() {
        guard !blockedBrowsers.isEmpty, let window, window.attachedSheet == nil else { return }
        hasPresentedAccessHelp = true
        let request = ProfileAccessRequest(browsers: blockedBrowsers, window: window) { [weak self] in
            self?.accessRequest = nil
            self?.reload()
        }
        accessRequest = request
        request.start()
    }

    private func append(_ profile: BrowserProfile, to popup: NSPopUpButton, includeBrowser: Bool) {
        let duplicates = available[profile.browser, default: []].filter { $0.name == profile.name }.count > 1
        let title = (includeBrowser ? profile.label : profile.name) + (duplicates ? " (\(profile.directory))" : "")
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let icon = profile.browser.icon.copy() as! NSImage; icon.size = NSSize(width: 16, height: 16)
        item.image = icon; popup.menu?.addItem(item)
    }
    private func updateStatus() {
        status.stringValue = preferences.savedProfiles.isEmpty ? L("Add your first extra profile below.", "Dodaj pierwszy dodatkowy profil poniżej.") : L("Saved: \(preferences.savedProfiles.count) · visible: \(preferences.activeProfiles.count)", "Zapisane: \(preferences.savedProfiles.count) · widoczne: \(preferences.activeProfiles.count)")
    }
    func numberOfRows(in tableView: NSTableView) -> Int { preferences.savedProfiles.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let entry = preferences.savedProfiles[row]
        let cell = NSView()
        switch tableColumn?.identifier.rawValue {
        case "name":
            let icon = NSImageView(); icon.image = entry.profile.browser.icon
            let text = NSTextField(labelWithString: entry.profile.label)
            text.font = .systemFont(ofSize: 12, weight: .medium); text.lineBreakMode = .byTruncatingTail
            cell.toolTip = entry.profile.directory
            for view in [icon, text] { view.translatesAutoresizingMaskIntoConstraints = false; cell.addSubview(view) }
            NSLayoutConstraint.activate([
                icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 10), icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: 24), icon.heightAnchor.constraint(equalToConstant: 24),
                text.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10), text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6), text.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        case "enabled", "remove":
            let button: NSButton
            if tableColumn?.identifier.rawValue == "enabled" {
                button = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleProfile(_:)))
                button.state = entry.isEnabled ? .on : .off
                button.setAccessibilityLabel(L("Show profile \(entry.profile.label)", "Pokaż profil \(entry.profile.label)"))
                button.toolTip = L("Enable or disable this profile without removing it", "Włącz lub wyłącz profil, zachowując go na liście")
            } else {
                button = NSButton(image: NSImage(systemSymbolName: "trash", accessibilityDescription: L("Delete", "Usuń"))!, target: self, action: #selector(removeProfile(_:)))
                button.isBordered = false; button.contentTintColor = .secondaryLabelColor
                button.setAccessibilityLabel(L("Remove saved profile \(entry.profile.label)", "Usuń zapisany profil \(entry.profile.label)"))
            }
            button.tag = row; button.translatesAutoresizingMaskIntoConstraints = false; cell.addSubview(button)
            NSLayoutConstraint.activate([button.centerXAnchor.constraint(equalTo: cell.centerXAnchor), button.centerYAnchor.constraint(equalTo: cell.centerYAnchor)])
        default: break
        }
        return cell
    }
    @objc private func mainChanged(_ sender: NSPopUpButton) {
        let browser: Browser = sender === brave ? .brave : .chrome
        let index = sender.indexOfSelectedItem - 1
        let profiles = available[browser, default: []]
        preferences.setMainProfile(profiles.indices.contains(index) ? profiles[index] : nil, for: browser)
    }
    @objc private func masterChanged() { preferences.showsExtraProfiles = master.state == .on; updateStatus() }
    @objc private func toggleProfile(_ sender: NSButton) {
        var entries = preferences.savedProfiles
        guard entries.indices.contains(sender.tag) else { return }
        entries[sender.tag].isEnabled = sender.state == .on
        preferences.savedProfiles = entries; updateStatus()
    }
    @objc private func removeProfile(_ sender: NSButton) {
        var entries = preferences.savedProfiles
        guard entries.indices.contains(sender.tag) else { return }
        entries.remove(at: sender.tag); preferences.savedProfiles = entries; reload()
    }
    @objc private func showProfileBrowser() {
        guard let window else { return }
        reload()
        if !blockedBrowsers.isEmpty && !hasPresentedAccessHelp {
            showAccessHelp()
            return
        }
        let controller = ProfileBrowserController(
            profiles: Browser.allCases.flatMap { available[$0, default: []] },
            savedIDs: Set(preferences.savedProfiles.map(\.id)),
            message: catalogStatus.stringValue
        ) { [weak self] profile in
            guard let self else { return }
            let entry = SavedProfile(profile: profile)
            guard !self.preferences.savedProfiles.contains(where: { $0.id == entry.id }) else { return }
            self.preferences.savedProfiles.append(entry)
            for browser in Browser.allCases where self.preferences.mainProfile(for: browser) == nil {
                self.preferences.setMainProfile(ProfileCatalog.currentProfile(for: browser), for: browser)
            }
            self.reload()
        }
        profileBrowser = controller
        window.beginSheet(controller.window!) { [weak self] _ in self?.profileBrowser = nil }
    }
}

/// A persistent selection surface: adding a profile leaves the other choices in place.
final class ProfileBrowserController: NSWindowController, NSSearchFieldDelegate {
    private let profiles: [BrowserProfile]
    private var savedIDs: Set<String>
    private let onAdd: (BrowserProfile) -> Void
    private let search = NSSearchField()
    private let filter = NSSegmentedControl(labels: [L("All", "Wszystkie"), "Brave", "Chrome"], trackingMode: .selectOne, target: nil, action: nil)
    private let rows = NSStackView()
    private let scroll = NSScrollView()

    init(profiles: [BrowserProfile], savedIDs: Set<String>, message: String = "", onAdd: @escaping (BrowserProfile) -> Void) {
        self.profiles = profiles
        self.savedIDs = savedIDs
        self.onAdd = onAdd
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 560, height: 540), styleMask: [.titled], backing: .buffered, defer: false)
        panel.title = L("Add profiles", "Dodaj profile")
        super.init(window: panel)
        let title = NSTextField(labelWithString: L("Choose your profiles", "Wybierz swoje profile"))
        title.font = .systemFont(ofSize: 22, weight: .semibold)
        let subtitle = NSTextField(wrappingLabelWithString: L("Add the profiles you want to see in Chooser.", "Dodaj profile, które chcesz widzieć w Chooserze."))
        subtitle.textColor = .secondaryLabelColor
        search.placeholderString = L("Search profiles…", "Szukaj profili…")
        search.setAccessibilityLabel(L("Search profiles", "Szukaj profili"))
        search.delegate = self
        search.sendsSearchStringImmediately = true
        filter.selectedSegment = 0
        filter.target = self; filter.action = #selector(filterChanged)
        let warning = NSTextField(wrappingLabelWithString: message)
        warning.font = .systemFont(ofSize: 11)
        warning.textColor = .secondaryLabelColor
        warning.isHidden = message.isEmpty
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = true
        scroll.backgroundColor = .controlBackgroundColor
        scroll.wantsLayer = true; scroll.layer?.cornerRadius = 10
        rows.orientation = .vertical; rows.alignment = .leading; rows.spacing = 4
        rows.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        let document = ProfileListDocument()
        document.translatesAutoresizingMaskIntoConstraints = false
        rows.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(rows)
        scroll.documentView = document
        NSLayoutConstraint.activate([
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            rows.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            rows.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            rows.topAnchor.constraint(equalTo: document.topAnchor),
            rows.bottomAnchor.constraint(equalTo: document.bottomAnchor)
        ])
        let done = NSButton(title: L("Done", "Gotowe"), target: self, action: #selector(closeBrowser))
        done.bezelStyle = .rounded; done.keyEquivalent = "\r"
        let footer = NSStackView(views: [NSView(), done])
        let stack = NSStackView(views: [title, subtitle, search, filter, warning, scroll, footer])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 12
        stack.setCustomSpacing(4, after: title)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = panel.contentView!
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20)
        ])
        for view in [subtitle, search, warning, scroll, footer] {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        panel.initialFirstResponder = search
        rebuildRows()
    }
    required init?(coder: NSCoder) { fatalError() }
    func controlTextDidChange(_ obj: Notification) { rebuildRows() }
    @objc private func filterChanged() { rebuildRows() }
    @objc private func closeBrowser() {
        guard let window else { return }
        window.sheetParent?.endSheet(window)
    }
    override func cancelOperation(_ sender: Any?) { closeBrowser() }
    private func rebuildRows() {
        for view in rows.arrangedSubviews { rows.removeArrangedSubview(view); view.removeFromSuperview() }
        let query = search.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        var count = 0
        for browser in Browser.allCases {
            guard filter.selectedSegment == 0 || (filter.selectedSegment == 1 ? browser == .brave : browser == .chrome) else { continue }
            let matches = profiles.enumerated().filter { _, profile in
                profile.browser == browser && (query.isEmpty || profile.label.localizedStandardContains(query) || profile.directory.localizedStandardContains(query))
            }
            guard !matches.isEmpty else { continue }
            let heading = NSTextField(labelWithString: "\(browser.name) · \(matches.count)")
            heading.font = .systemFont(ofSize: 11, weight: .semibold)
            heading.textColor = .secondaryLabelColor
            rows.addArrangedSubview(heading)
            for (index, profile) in matches {
                count += 1
                let icon = NSImageView(); icon.image = browser.icon
                icon.widthAnchor.constraint(equalToConstant: 28).isActive = true
                icon.heightAnchor.constraint(equalToConstant: 28).isActive = true
                let duplicates = profiles.filter { $0.browser == browser && $0.name == profile.name }.count > 1
                let name = NSTextField(labelWithString: profile.name)
                name.font = .systemFont(ofSize: 13, weight: .medium)
                name.lineBreakMode = .byTruncatingTail
                let detail = NSTextField(labelWithString: duplicates ? profile.directory : browser.name)
                detail.font = .systemFont(ofSize: 11); detail.textColor = .secondaryLabelColor
                let labels = NSStackView(views: [name, detail])
                labels.orientation = .vertical; labels.alignment = .leading; labels.spacing = 2
                let added = savedIDs.contains(SavedProfile(profile: profile).id)
                let button = NSButton(title: added ? L("Added", "Dodano") : L("Add", "Dodaj"), target: self, action: #selector(addProfile(_:)))
                button.bezelStyle = .rounded; button.tag = index; button.isEnabled = !added
                button.image = NSImage(systemSymbolName: added ? "checkmark" : "plus", accessibilityDescription: nil)
                button.imagePosition = .imageLeading
                button.setAccessibilityLabel(added ? L("Added \(profile.label)", "Dodano \(profile.label)") : L("Add \(profile.label)", "Dodaj \(profile.label)"))
                button.widthAnchor.constraint(equalToConstant: 92).isActive = true
                let row = NSStackView(views: [icon, labels, NSView(), button])
                row.spacing = 10; row.toolTip = profile.label + " (" + profile.directory + ")"
                rows.addArrangedSubview(row)
                row.widthAnchor.constraint(equalTo: rows.widthAnchor, constant: -20).isActive = true
                row.heightAnchor.constraint(equalToConstant: 52).isActive = true
            }
        }
        if count == 0 {
            let empty = NSTextField(wrappingLabelWithString: query.isEmpty
                ? L("No profiles found. Open your browser and create a profile, then refresh profiles in Settings.", "Nie znaleziono profili. Utwórz profil w przeglądarce, a następnie odśwież profile w ustawieniach.")
                : L("No matching profiles. Try another name or browser.", "Brak pasujących profili. Spróbuj innej nazwy lub przeglądarki."))
            empty.textColor = .secondaryLabelColor
            rows.addArrangedSubview(empty)
            empty.widthAnchor.constraint(equalTo: rows.widthAnchor, constant: -20).isActive = true
        }
    }
    @objc private func addProfile(_ sender: NSButton) {
        guard profiles.indices.contains(sender.tag) else { return }
        let profile = profiles[sender.tag]
        guard savedIDs.insert(SavedProfile(profile: profile).id).inserted else { return }
        onAdd(profile)
        // Keep scroll position, keyboard focus, and every other Add button stable.
        sender.title = L("Added", "Dodano")
        sender.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)
        sender.setAccessibilityLabel(L("Added \(profile.label)", "Dodano \(profile.label)"))
        sender.isEnabled = false
    }
}

private final class ProfileListDocument: NSView {
    override var isFlipped: Bool { true }
}


enum ProfileAccessHelp {
    static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!

    static func alert(browsers: [Browser]) -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = L("Allow Chooser to read browser profiles", "Pozwól Chooserowi odczytać profile przeglądarek")
        let names = browsers.map(\.name).joined(separator: ", ")
        alert.informativeText = L(
            "macOS blocked profile access for \(names).\n\n1. Click Open Settings to open Full Disk Access.\n2. Enable Chooser. If it is missing, click + and select Chooser in Applications.\n3. If macOS asks, choose Quit & Reopen. Otherwise, return to Chooser to check access again.\n\nFull Disk Access is a broad macOS permission. Chooser uses it to read the browser profile list; only you can enable it.",
            "macOS zablokował dostęp do profili: \(names).\n\n1. Kliknij Otwórz ustawienia — otworzy się Pełny dostęp do dysku.\n2. Włącz Chooser. Jeśli go nie ma, kliknij + i wybierz Chooser z folderu Aplikacje.\n3. Jeśli macOS zapyta, wybierz Zakończ i otwórz ponownie. W przeciwnym razie wróć do Choosera, aby ponownie sprawdzić dostęp.\n\nPełny dostęp do dysku to szerokie uprawnienie macOS. Chooser używa go do odczytu listy profili; tylko Ty możesz je włączyć."
        )
        alert.addButton(withTitle: L("Open Settings", "Otwórz ustawienia"))
        alert.addButton(withTitle: L("Not now", "Nie teraz"))
        return alert
    }

    static func openSettings() {
        if !NSWorkspace.shared.open(settingsURL) {
            // The deep link is OS-owned; retain a usable fallback if it changes.
            let fallback = NSAlert()
            fallback.messageText = L("Open Privacy & Security", "Otwórz Prywatność i ochronę")
            fallback.informativeText = L("In System Settings, choose Privacy & Security → Full Disk Access, then enable Chooser.", "W Ustawieniach systemowych wybierz Prywatność i ochrona → Pełny dostęp do dysku i włącz Chooser.")
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
            fallback.runModal()
        }
    }
}


/// macOS grants access when the user confirms this pre-positioned system panel.
final class ProfileAccessRequest: NSObject, NSOpenSavePanelDelegate {
    private var pending: [Browser]
    private weak var parent: NSWindow?
    private let completion: () -> Void
    private var currentBrowser: Browser?
    private var panel: NSOpenPanel?

    init(browsers: [Browser], window: NSWindow, completion: @escaping () -> Void) {
        pending = browsers; parent = window; self.completion = completion
    }
    static func makePanel(for browser: Browser) -> NSOpenPanel {
        let panel = NSOpenPanel()
        panel.title = L("Connect \(browser.name) profiles", "Połącz profile \(browser.name)")
        panel.message = L("Click Allow Access to read your \(browser.name) profile list. The correct folder is already open.", "Kliknij Zezwól na dostęp, aby odczytać listę profili \(browser.name). Właściwy folder jest już otwarty.")
        panel.prompt = L("Allow Access", "Zezwól na dostęp")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.directoryURL = ProfileCatalog.root(for: browser)
        return panel
    }
    func start() {
        guard let parent, parent.isVisible, !pending.isEmpty else { completion(); return }
        let browser = pending.removeFirst()
        currentBrowser = browser
        let panel = Self.makePanel(for: browser)
        self.panel = panel
        panel.delegate = self
        panel.beginSheetModal(for: parent) { [weak self, weak panel] response in
            guard let self, let panel else { return }
            guard response == .OK, let url = panel.url else { self.completion(); return }
            do {
                try ProfileFolderAccess.shared.remember(url, for: browser)
                var readError: Error?
                _ = ProfileCatalog.profiles(for: browser, onError: { readError = $0 })
                if let readError { throw readError }
                self.panel = nil
                DispatchQueue.main.async { self.start() }
            } catch {
                self.panel = nil
                self.showFallback(for: browser, error: error)
            }
        }
    }
    func panel(_ sender: Any, validate url: URL) throws {
        guard let browser = currentBrowser, ProfileFolderAccess.isExpectedFolder(url, for: browser) else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadInvalidFileNameError,
                          userInfo: [NSLocalizedDescriptionKey: L("Use the browser folder opened for you. Cancel and try again to return to it.", "Użyj folderu przeglądarki otwartego automatycznie. Anuluj i spróbuj ponownie, aby do niego wrócić.")])
        }
    }
    private func showFallback(for browser: Browser, error: Error) {
        guard let parent, parent.isVisible else { completion(); return }
        let alert = ProfileAccessHelp.alert(browsers: [browser])
        alert.messageText = L("macOS still blocks profile access", "macOS nadal blokuje dostęp do profili")
        alert.informativeText = error.localizedDescription + "\n\n" + alert.informativeText
        alert.beginSheetModal(for: parent) { [weak self] response in
            if response == .alertFirstButtonReturn { ProfileAccessHelp.openSettings() }
            self?.completion()
        }
    }
}
