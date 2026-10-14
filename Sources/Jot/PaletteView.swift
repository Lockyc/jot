import AppKit
import Carbon.HIToolbox
import JotCore

/// The ⌘K command list, drawn inside the panel so the panel stays the key window.
final class PaletteView: NSVisualEffectView, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    var onClose: (() -> Void)?
    private let commands: () -> [Command]
    private let perform: (Command) -> Void
    private let field = NSSearchField()
    private let table = NSTableView()
    private var rows: [Command] = []

    var isOpen: Bool { !isHidden }

    init(commands: @escaping () -> [Command], perform: @escaping (Command) -> Void) {
        self.commands = commands
        self.perform = perform
        super.init(frame: .zero)
        material = .popover
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 10
        isHidden = true

        field.placeholderString = "Run a command…"
        field.delegate = self
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("c"))
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        table.headerView = nil
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.action = #selector(clickedRow)
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false

        let stack = NSStackView(views: [field, scroll])
        stack.orientation = .vertical
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func open() {
        isHidden = false
        field.stringValue = ""
        refilter()
        window?.makeFirstResponder(field)
    }

    func close() {
        isHidden = true
        onClose?()
    }

    func handleKey(_ combo: KeyCombo) -> Bool {
        switch (Int(combo.keyCode), combo.modifiers) {
        case (kVK_Escape, []): close()
        case (kVK_ANSI_K, [.command]): close()
        case (kVK_DownArrow, []): move(1)
        case (kVK_UpArrow, []): move(-1)
        case (kVK_Return, []): runSelected()
        default: return false
        }
        return true
    }

    func controlTextDidChange(_ obj: Notification) { refilter() }

    private func refilter() {
        rows = Fuzzy.rank(commands(), query: field.stringValue) { "\($0.group.rawValue) \($0.title)" }
        table.reloadData()
        if !rows.isEmpty { table.selectRowIndexes([0], byExtendingSelection: false) }
    }

    private func move(_ delta: Int) {
        guard !rows.isEmpty else { return }
        let next = min(max(table.selectedRow + delta, 0), rows.count - 1)
        table.selectRowIndexes([next], byExtendingSelection: false)
        table.scrollRowToVisible(next)
    }

    @objc private func clickedRow() { runSelected() }

    private func runSelected() {
        guard rows.indices.contains(table.selectedRow) else { return }
        let command = rows[table.selectedRow]
        close()
        perform(command)
    }

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let command = rows[row]
        let reason = command.disabledReason()
        let title = NSTextField(labelWithString: command.title)
        let keys = NSTextField(labelWithString: command.shortcutDisplay)
        keys.textColor = .secondaryLabelColor
        title.textColor = reason == nil ? .labelColor : .tertiaryLabelColor
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let cell = NSStackView(views: [title, spacer, keys])
        cell.toolTip = reason
        return cell
    }
}
