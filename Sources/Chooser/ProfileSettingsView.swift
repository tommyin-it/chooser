import AppKit

final class ProfileSettingsView: NSView, NSTableViewDataSource, NSTableViewDelegate {
    private let preferences: Preferences
    private let chrome = NSPopUpButton()
    private let brave = NSPopUpButton()
    private let picker = NSPopUpButton()
    private let add = NSButton(title: "Dodaj", target: nil, action: nil)
    private let master = NSButton(checkboxWithTitle: "Pokaż dodatkowe profile w okienku", target: nil, action: nil)
    private let table = NSTableView()
    private let status = NSTextField(labelWithString: "")
    private var available: [Browser: [BrowserProfile]] = [:]
    private var candidates: [BrowserProfile] = []

    init(preferences: Preferences) {
        self.preferences = preferences
        super.init(frame: .zero)
        let title = NSTextField(labelWithString: "Twoje profile")
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        let subtitle = NSTextField(labelWithString: "Zapisz raz. Włączaj wtedy, gdy ich potrzebujesz.")
        subtitle.textColor = .secondaryLabelColor
        let grid = NSGridView(views: [[NSTextField(labelWithString: "Główny Brave"), brave], [NSTextField(labelWithString: "Główny Chrome"), chrome]])
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
        picker.target = self; picker.action = #selector(pickerChanged)
        picker.widthAnchor.constraint(equalToConstant: 390).isActive = true
        add.bezelStyle = .rounded
        add.target = self; add.action = #selector(addProfile)
        let addRow = NSStackView(views: [picker, add]); addRow.spacing = 12
        let refresh = NSButton(title: "Odśwież profile", target: self, action: #selector(reload))
        refresh.bezelStyle = .rounded
        status.font = .systemFont(ofSize: 11); status.textColor = .secondaryLabelColor
        let tip = NSTextField(labelWithString: "Wyłączenie zachowuje profil. Kosz usuwa go tylko z Choosera.")
        tip.font = .systemFont(ofSize: 11); tip.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [title, subtitle, grid, master, scroll, status, addRow, refresh, tip])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 13
        stack.setCustomSpacing(5, after: title)
        stack.setCustomSpacing(20, after: subtitle)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 22),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scroll.heightAnchor.constraint(equalToConstant: 170)
        ])
        reload()
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc func reload() {
        available = [.brave: ProfileCatalog.profiles(for: .brave), .chrome: ProfileCatalog.profiles(for: .chrome)]
        for (browser, popup) in [(Browser.brave, brave), (.chrome, chrome)] {
            if let saved = preferences.mainProfile(for: browser), !available[browser, default: []].contains(where: { $0.directory == saved.directory }) { available[browser, default: []].append(saved) }
            popup.removeAllItems(); popup.addItem(withTitle: "Według przeglądarki")
            for (index, profile) in available[browser, default: []].enumerated() {
                append(profile, to: popup, includeBrowser: false)
                if preferences.mainProfile(for: browser)?.directory == profile.directory { popup.selectItem(at: index + 1) }
            }
        }
        let savedIDs = Set(preferences.savedProfiles.map(\.id))
        candidates = Browser.allCases.flatMap { available[$0, default: []] }.filter { !savedIDs.contains(SavedProfile(profile: $0).id) }
        picker.removeAllItems(); picker.addItem(withTitle: "Wybierz profil do zapisania…")
        for profile in candidates { append(profile, to: picker, includeBrowser: true) }
        add.isEnabled = false
        master.state = preferences.showsExtraProfiles ? .on : .off
        table.reloadData()
        updateStatus()
    }
    private func append(_ profile: BrowserProfile, to popup: NSPopUpButton, includeBrowser: Bool) {
        let duplicates = available[profile.browser, default: []].filter { $0.name == profile.name }.count > 1
        let title = (includeBrowser ? profile.label : profile.name) + (duplicates ? " (\(profile.directory))" : "")
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let icon = profile.browser.icon.copy() as! NSImage; icon.size = NSSize(width: 16, height: 16)
        item.image = icon; popup.menu?.addItem(item)
    }
    private func updateStatus() {
        status.stringValue = preferences.savedProfiles.isEmpty ? "Dodaj pierwszy dodatkowy profil poniżej." : "Zapisane: \(preferences.savedProfiles.count) · widoczne: \(preferences.activeProfiles.count)"
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
                button.setAccessibilityLabel("Pokaż profil \(entry.profile.label)")
                button.toolTip = "Włącz lub wyłącz profil, zachowując go na liście"
            } else {
                button = NSButton(image: NSImage(systemSymbolName: "trash", accessibilityDescription: "Usuń")!, target: self, action: #selector(removeProfile(_:)))
                button.isBordered = false; button.contentTintColor = .secondaryLabelColor
                button.setAccessibilityLabel("Usuń zapisany profil \(entry.profile.label)")
            }
            button.tag = row; button.translatesAutoresizingMaskIntoConstraints = false; cell.addSubview(button)
            NSLayoutConstraint.activate([button.centerXAnchor.constraint(equalTo: cell.centerXAnchor), button.centerYAnchor.constraint(equalTo: cell.centerYAnchor)])
        default: break
        }
        return cell
    }
    @objc private func pickerChanged() { add.isEnabled = picker.indexOfSelectedItem > 0 }
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
    @objc private func addProfile() {
        let index = picker.indexOfSelectedItem - 1
        guard candidates.indices.contains(index) else { return }
        preferences.savedProfiles.append(SavedProfile(profile: candidates[index]))
        for browser in Browser.allCases where preferences.mainProfile(for: browser) == nil { preferences.setMainProfile(ProfileCatalog.currentProfile(for: browser), for: browser) }
        reload()
    }
}
