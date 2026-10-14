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
        noteCommands() + editCommands() + textCommands() + tabCommands() + appCommands()
    }

    func noteCommands() -> [Command] {
        let pinnedReason: () -> String? = { [unowned self] in self.store.state.pinned[self.activeTab] ? "Unpin to clear" : nil }
        return [
            Command(id: "clear", title: "Clear Note", group: .note, keys: [KeyCombo(kVK_Delete, .command)],
                    disabledReason: pinnedReason) { [unowned self] in self.editor.clearAll() },
            Command(id: "copyClear", title: "Copy & Clear Note", group: .note, keys: [KeyCombo(kVK_ANSI_C, [.command, .shift])],
                    disabledReason: pinnedReason) { [unowned self] in
                guard !self.editor.string.isEmpty else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(self.editor.string, forType: .string)
                self.editor.clearAll()
            },
            Command(id: "pin", title: "Pin / Unpin Tab", group: .note, keys: [KeyCombo(kVK_ANSI_P, .command)]) { [unowned self] in
                self.togglePin(self.activeTab)
            },
        ]
    }

    func tabCommands() -> [Command] {
        let digits = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7]
        return (0..<NoteStore.tabCount).map { i in
            Command(id: "tab\(i + 1)", title: "Go to Tab \(i + 1)", group: .tabs, keys: [KeyCombo(digits[i], .command)]) { [unowned self] in
                self.selectTab(i)
            }
        }
    }

    func editCommands() -> [Command] {
        [
            Command(id: "indent", title: "Indent Lines", group: .edit, keys: [KeyCombo(kVK_ANSI_RightBracket, .command)],
                    hint: "⇥ / ⌘]") { [unowned self] in self.editor.indentLines() },
            Command(id: "outdent", title: "Outdent Lines", group: .edit, keys: [KeyCombo(kVK_ANSI_LeftBracket, .command)],
                    hint: "⇧⇥ / ⌘[") { [unowned self] in self.editor.outdentLines() },
            Command(id: "moveUp", title: "Move Line Up", group: .edit, keys: [KeyCombo(kVK_UpArrow, .option)]) { [unowned self] in self.editor.moveLines(up: true) },
            Command(id: "moveDown", title: "Move Line Down", group: .edit, keys: [KeyCombo(kVK_DownArrow, .option)]) { [unowned self] in self.editor.moveLines(up: false) },
            Command(id: "duplicate", title: "Duplicate Line / Selection", group: .edit, keys: [KeyCombo(kVK_ANSI_D, .command)]) { [unowned self] in self.editor.duplicateLines() },
            Command(id: "selectLine", title: "Select Line", group: .edit, keys: [KeyCombo(kVK_ANSI_L, .command)]) { [unowned self] in self.editor.selectLines() },
            Command(id: "wrap", title: "Toggle Word Wrap", group: .edit, keys: [KeyCombo(kVK_ANSI_Z, .option)]) { [unowned self] in self.toggleWrap() },
            Command(id: "pasteStripped", title: "Paste Without Quote Gutter", group: .edit, keys: [KeyCombo(kVK_ANSI_V, [.command, .option])]) { [unowned self] in self.editor.pasteStrippingGutter() },
        ]
    }

    func textCommands() -> [Command] {
        func action(_ id: String, _ title: String, keys: [KeyCombo] = [], _ f: @escaping (String) -> String) -> Command {
            Command(id: id, title: title, group: .text, keys: keys) { [unowned self] in self.editor.transform(f) }
        }
        return [
            action("stripGutter", "Strip Quote Gutter", keys: [KeyCombo(kVK_ANSI_V, [.command, .shift])], TextActions.stripQuoteGutter),
            action("dedent", "Dedent", TextActions.dedent),
            action("trimTrailing", "Trim Trailing Whitespace", TextActions.trimTrailingWhitespace),
            action("sortAsc", "Sort Lines A→Z") { TextActions.sortLines($0, descending: false) },
            action("sortDesc", "Sort Lines Z→A") { TextActions.sortLines($0, descending: true) },
            action("dedupe", "Remove Duplicate Lines", TextActions.removeDuplicateLines),
            action("removeBlank", "Remove Blank Lines", TextActions.removeBlankLines),
            action("join", "Join Lines", TextActions.joinLines),
            Command(id: "split", title: "Split on Delimiter…", group: .text) { [unowned self] in self.promptSplit() },
            action("upper", "UPPERCASE", TextActions.uppercase),
            action("lower", "lowercase", TextActions.lowercase),
            action("title", "Title Case", TextActions.titleCase),
            action("number", "Number Lines", TextActions.numberLines),
        ]
    }

    func appCommands() -> [Command] {
        [
            Command(id: "hide", title: "Hide jot", group: .app, keys: [KeyCombo(kVK_Escape)]) { [unowned self] in self.hide() },
            Command(id: "quit", title: "Quit jot", group: .app, keys: [KeyCombo(kVK_ANSI_Q, .command)]) { NSApp.terminate(nil) },
        ]
    }
}
