import AppKit

/// Tab strip plus note buttons. Each button runs a registry command by id, so titles, shortcuts and
/// availability come from the registry.
final class ToolbarView: NSStackView {
    let tabs = TabStripView()
    private var buttons: [String: NSButton] = [:]
    private let lookup: (String) -> Command?
    private let run: (String) -> Void

    init(lookup: @escaping (String) -> Command?, run: @escaping (String) -> Void) {
        self.lookup = lookup
        self.run = run
        super.init(frame: .zero)
        orientation = .horizontal
        spacing = 6
        edgeInsets = NSEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
        addArrangedSubview(tabs)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        addArrangedSubview(spacer)
        for (id, symbol) in [("wrap", "text.word.spacing"), ("copyClear", "doc.on.clipboard"),
                             ("clear", "trash"), ("palette", "command")] {
            let b = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: id)!,
                             target: self, action: #selector(clicked(_:)))
            b.identifier = NSUserInterfaceItemIdentifier(id)
            b.isBordered = false
            buttons[id] = b
            addArrangedSubview(b)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    @objc private func clicked(_ sender: NSButton) {
        if let id = sender.identifier?.rawValue { run(id) }
    }

    func update(wraps: Bool) {
        for (id, b) in buttons {
            guard let command = lookup(id) else { b.isEnabled = false; continue }
            let reason = command.disabledReason()
            b.isEnabled = reason == nil
            b.toolTip = reason ?? "\(command.title)  \(command.shortcutDisplay)"
            if id == "wrap" { b.contentTintColor = wraps ? .controlAccentColor : nil }
        }
    }
}
