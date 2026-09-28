import AppKit
import UniformTypeIdentifiers

final class ApplicationRulesView: NSView, NSTableViewDataSource, NSTableViewDelegate {
    var onChange: (() -> Void)?
    private let preferences: Preferences
    private let table = NSTableView()
    private let empty = NSTextField(labelWithString: "Zacznij od aplikacji, z której najczęściej otwierasz linki.")
    private var rules: [ApplicationRule] { preferences.applicationRules }

    init(preferences: Preferences) {
        self.preferences = preferences
        super.init(frame: .zero)
        let title = NSTextField(labelWithString: "Przeglądarka dla aplikacji")
        title.font = .systemFont(ofSize: 18, weight: .semibold)
        let explanation = NSTextField(wrappingLabelWithString: "Wybierz aplikację, a potem jej przeglądarkę.")
        explanation.textColor = .secondaryLabelColor
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.wantsLayer = true
        scroll.layer?.cornerRadius = 12
        scroll.layer?.masksToBounds = true
        table.rowHeight = 60
        table.headerView = nil
        table.style = .fullWidth
        table.intercellSpacing = NSSize(width: 0, height: 1)
        table.usesAlternatingRowBackgroundColors = false
        table.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        for (id, name, width) in [("app", "Aplikacja", CGFloat(220)), ("browser", "Przeglądarka", CGFloat(160)), ("remove", "", CGFloat(44))] {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
            column.title = name
            column.width = width
            column.minWidth = id == "app" ? 120 : width
            if id != "app" { column.maxWidth = width }
            table.addTableColumn(column)
        }
        table.dataSource = self
        table.delegate = self
        scroll.documentView = table
        let add = NSButton(title: "Dodaj aplikację…", target: self, action: #selector(addApplication))
        add.bezelStyle = .rounded
        let footnote = NSTextField(wrappingLabelWithString: "Bez reguły używany jest tryb z paska menu.")
        footnote.toolTip = "Reguły mają pierwszeństwo przed trybem globalnym. Jeśli macOS nie udostępni źródła, obowiązuje tryb globalny. Brave i Chrome zachowują własne linki."
        footnote.font = .systemFont(ofSize: 11)
        footnote.textColor = .secondaryLabelColor
        empty.font = .systemFont(ofSize: 11)
        empty.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [title, explanation, scroll, empty, add, footnote])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            scroll.heightAnchor.constraint(equalToConstant: 280)
        ])
        for view in [explanation, scroll, footnote, empty] { view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
        reload()
    }
    required init?(coder: NSCoder) { fatalError() }
    func numberOfRows(in tableView: NSTableView) -> Int { rules.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let rule = rules[row]
        switch tableColumn?.identifier.rawValue {
        case "app":
            let cell = NSView()
            let image = NSImageView()
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: rule.bundleID) {
                image.image = NSWorkspace.shared.icon(forFile: url.path)
            } else {
                image.image = NSImage(systemSymbolName: "app", accessibilityDescription: nil)
            }
            image.imageScaling = .scaleProportionallyDown
            let text = NSTextField(labelWithString: rule.name)
            text.font = .systemFont(ofSize: 13, weight: .medium)
            text.lineBreakMode = .byTruncatingTail
            cell.toolTip = rule.bundleID
            for view in [image, text] { view.translatesAutoresizingMaskIntoConstraints = false; cell.addSubview(view) }
            NSLayoutConstraint.activate([
                image.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 14),
                image.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                image.widthAnchor.constraint(equalToConstant: 32),
                image.heightAnchor.constraint(equalToConstant: 32),
                text.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 12),
                text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                text.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
            return cell
        case "browser":
            let popup = NSPopUpButton()
            popup.addItems(withTitles: Browser.allCases.map(\.name))
            for (index, browser) in Browser.allCases.enumerated() {
                let icon = browser.icon.copy() as! NSImage
                icon.size = NSSize(width: 18, height: 18)
                popup.item(at: index)?.image = icon
            }
            popup.selectItem(at: Browser.allCases.firstIndex(of: rule.browser)!)
            popup.tag = row
            popup.target = self
            popup.action = #selector(changeBrowser(_:))
            popup.setAccessibilityLabel("Przeglądarka dla \(rule.name)")
            return centered(popup)
        case "remove":
            let remove = NSButton(image: NSImage(systemSymbolName: "trash", accessibilityDescription: "Usuń regułę")!, target: self, action: #selector(removeRule(_:)))
            remove.isBordered = false
            remove.contentTintColor = .secondaryLabelColor
            remove.toolTip = "Usuń regułę dla \(rule.name)"
            remove.tag = row
            remove.setAccessibilityLabel("Usuń regułę dla \(rule.name)")
            return centered(remove)
        default: return nil
        }
    }
    private func centered(_ control: NSView) -> NSView {
        let cell = NSView()
        control.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(control)
        NSLayoutConstraint.activate([
            control.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            control.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            control.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        return cell
    }
    private func reload() {
        table.reloadData()
        empty.isHidden = !rules.isEmpty
    }
    @objc private func changeBrowser(_ sender: NSPopUpButton) {
        var updated = rules
        guard updated.indices.contains(sender.tag) else { return }
        updated[sender.tag].browser = Browser.allCases[sender.indexOfSelectedItem]
        preferences.applicationRules = updated
        onChange?()
    }
    @objc private func removeRule(_ sender: NSButton) {
        var updated = rules
        guard updated.indices.contains(sender.tag) else { return }
        updated.remove(at: sender.tag)
        preferences.applicationRules = updated
        onChange?()
        reload()
    }
    @objc func addApplication() {
        guard let window else { return }
        let picker = NSOpenPanel()
        picker.title = "Wybierz aplikację źródłową"
        picker.prompt = "Dodaj regułę"
        picker.directoryURL = URL(fileURLWithPath: "/Applications")
        picker.allowedContentTypes = [.applicationBundle]
        picker.allowsMultipleSelection = false
        picker.canChooseDirectories = false
        picker.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .OK, let url = picker.url else { return }
            guard let id = Bundle(url: url)?.bundleIdentifier else {
                self.showError("Wybrana aplikacja nie ma identyfikatora pakietu.")
                return
            }
            guard id != Bundle.main.bundleIdentifier, !Browser.allCases.contains(where: { $0.bundleID == id }) else {
                self.showError("Wybierz aplikację, z której pochodzą linki, np. Slack. Chrome i Brave zachowują własne linki.")
                return
            }
            var updated = self.rules
            if let index = updated.firstIndex(where: { $0.bundleID == id }) {
                self.table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
                self.table.scrollRowToVisible(index)
                return
            }
            let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
            updated.append(ApplicationRule(bundleID: id, name: name, browser: .chrome))
            self.preferences.applicationRules = updated
            self.onChange?()
            self.reload()
            self.table.selectRowIndexes(IndexSet(integer: updated.count - 1), byExtendingSelection: false)
            self.table.scrollRowToVisible(updated.count - 1)
        }
    }
    private func showError(_ message: String) {
        guard let window else { return }
        let alert = NSAlert()
        alert.messageText = "Nie można dodać reguły"
        alert.informativeText = message
        alert.beginSheetModal(for: window)
    }
}
