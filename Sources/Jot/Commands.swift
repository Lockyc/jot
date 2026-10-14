import AppKit
import Carbon.HIToolbox
import JotCore

/// Every user-invocable action. The key monitor, ⌘K palette, toolbar buttons and status menu all
/// read this one list — a shortcut or title lives here only.
struct Command {
    enum Group: String, CaseIterable {
        case note = "Note", edit = "Edit", text = "Text", tabs = "Tabs", app = "jot"
    }

    let id: String
    let title: String
    let group: Group
    var keys: [KeyCombo] = []
    /// Overrides the shortcut column when a key is handled outside the registry (Tab in the editor).
    var hint: String? = nil
    /// nil = available; otherwise the reason shown on the disabled control.
    var disabledReason: () -> String? = { nil }
    let run: () -> Void

    var shortcutDisplay: String { hint ?? keys.first?.display ?? "" }
}

extension JotController {
    func makeCommands() -> [Command] {
        appCommands()
    }

    func appCommands() -> [Command] {
        [
            Command(id: "hide", title: "Hide jot", group: .app, keys: [KeyCombo(kVK_Escape)]) { [unowned self] in self.hide() },
            Command(id: "quit", title: "Quit jot", group: .app, keys: [KeyCombo(kVK_ANSI_Q, .command)]) { NSApp.terminate(nil) },
        ]
    }
}
