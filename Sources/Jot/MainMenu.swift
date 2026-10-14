import AppKit

/// Standard Edit-menu equivalents (⌘Z/⌘C/⌘V/⌘F…) that NSTextView expects; jot's own commands are
/// not here — they live in the command registry.
enum MainMenu {
    static func build() -> NSMenu {
        let main = NSMenu()
        let appItem = NSMenuItem()
        appItem.submenu = NSMenu()
        main.addItem(appItem)

        let editItem = NSMenuItem()
        main.addItem(editItem)
        let edit = NSMenu(title: "Edit")
        editItem.submenu = edit
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
            .keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Find…", action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "f")
            .tag = Int(NSFindPanelAction.showFindPanel.rawValue)
        edit.addItem(withTitle: "Find Next", action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "g")
            .tag = Int(NSFindPanelAction.next.rawValue)
        return main
    }
}
