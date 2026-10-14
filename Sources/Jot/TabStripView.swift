import AppKit
import JotCore

final class TabStripView: NSStackView, NSMenuDelegate {
    var onSelect: ((Int) -> Void)?
    var populateMenu: ((Int, NSMenu) -> Void)?
    private var buttons: [NSButton] = []

    init() {
        super.init(frame: .zero)
        orientation = .horizontal
        spacing = 4
        for i in 0..<NoteStore.tabCount {
            let b = NSButton(title: "\(i + 1)", target: self, action: #selector(clicked(_:)))
            b.tag = i
            b.bezelStyle = .recessed
            b.setButtonType(.pushOnPushOff)
            b.lineBreakMode = .byTruncatingTail
            b.imagePosition = .imageLeading
            b.toolTip = "⌘\(i + 1)"
            b.widthAnchor.constraint(lessThanOrEqualToConstant: 140).isActive = true
            let menu = NSMenu()
            menu.delegate = self
            b.menu = menu
            addArrangedSubview(b)
            buttons.append(b)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    @objc private func clicked(_ sender: NSButton) { onSelect?(sender.tag) }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let i = buttons.firstIndex(where: { $0.menu === menu }) else { return }
        menu.removeAllItems()
        populateMenu?(i, menu)
    }

    func update(labels: [String], empty: [Bool], pinned: [Bool], active: Int) {
        for (i, b) in buttons.enumerated() {
            b.title = labels[i]
            b.state = i == active ? .on : .off
            b.alphaValue = empty[i] && i != active ? 0.45 : 1
            b.image = pinned[i] ? NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "Pinned") : nil
        }
    }
}
