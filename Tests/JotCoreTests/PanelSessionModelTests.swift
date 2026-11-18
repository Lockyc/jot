import Foundation
import PropertyBased
import Testing
@testable import JotCore

/// One user action, as the model drives it. Tabs stay within the first three so outside edits
/// and tab switches keep landing on the same notes.
enum PanelStep: CustomStringConvertible, Sendable {
    /// The global hotkey.
    case hotkey
    /// "Show jot" in the status menu.
    case statusShow
    /// The close button or the Hide command.
    case close
    /// ⌘K, or Command Palette from the status menu.
    case palette
    /// Esc in the palette.
    case escPalette
    /// A keystroke into the editor.
    case type
    /// A text command from the status menu, which runs whether or not the panel is showing.
    case command
    case select(Int)
    /// Another app rewrites the note's file; jot loses focus to it.
    case outsideEdit(Int)

    static let tabs = 0..<3
    static let all: [PanelStep] = [.hotkey, .statusShow, .close, .palette, .escPalette, .type, .type, .command]
        + tabs.map(PanelStep.select) + tabs.map(PanelStep.outsideEdit)

    var description: String {
        switch self {
        case .hotkey: "hotkey"
        case .statusShow: "statusShow"
        case .close: "close"
        case .palette: "palette"
        case .escPalette: "escPalette"
        case .type: "type"
        case .command: "command"
        case .select(let t): "select(\(t))"
        case .outsideEdit(let t): "outsideEdit(\(t))"
        }
    }
}

/// The controller, panel and editor reduced to what `PanelSession` reads and its effects change,
/// over a real `NoteStore` in a temporary folder. Effects are carried out the way
/// `JotController.carryOut` does; AppKit's own reaction (a panel ordered front becomes key) is
/// modelled too, since outside edits are picked up there.
final class PanelWorld {
    let folder: URL
    let store: NoteStore
    var visible = false, appActive = false, key = false, paletteOpen = false
    var editor: String
    var chromeRedrawn = false
    private var serial = 0
    /// Text typed or run into each note: never lost.
    var typed = Array(repeating: [String](), count: NoteStore.tabCount)
    /// Outside edits made while the note held no pending jot edit: never overwritten.
    var protected = Array(repeating: [String](), count: NoteStore.tabCount)
    /// Notes holding a jot edit not yet flushed: `NoteStore` keeps those over an outside edit.
    var pending = Array(repeating: false, count: NoteStore.tabCount)

    init() {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("jot-session-\(UUID().uuidString)")
        store = NoteStore(folder: folder, debounce: 3600)
        editor = store.text(store.state.activeTab)
    }

    deinit { try? FileManager.default.removeItem(at: folder) }

    var active: Int { store.state.activeTab }
    var session: PanelSession { PanelSession(visible: visible, appActive: appActive, paletteOpen: paletteOpen, activeTab: active) }

    func token(_ kind: String) -> String {
        serial += 1
        return "<\(kind)\(serial)>"
    }

    func disk(_ tab: Int) -> String { (try? String(contentsOf: store.noteURL(tab), encoding: .utf8)) ?? "" }

    func decide(_ rule: (PanelSession) -> [PanelSession.Effect], run: () -> Void = {}) {
        let snapshot = session
        let effects = rule(snapshot)
        if effects.contains(.orderFront) {
            #expect(effects.contains(.centre) == !snapshot.visible,
                    "show from visible: \(snapshot.visible) gave \(effects)")
        }
        for effect in effects { carryOut(effect, run: run) }
    }

    private func carryOut(_ effect: PanelSession.Effect, run: () -> Void) {
        switch effect {
        case .pickUpOutsideEdit:
            if store.reloadIfChangedOnDisk(active) { editor = store.text(active) }
        case .activateApp: appActive = true
        case .centre, .focusEditor, .rememberSelection: break
        case .orderFront:
            visible = true
            becomeKey()
        case .openPalette: paletteOpen = true
        case .closePalette: paletteOpen = false
        case .writeBack: store.setText(editor, tab: active)
        case .flush:
            try? store.flush()
            pending = pending.map { _ in false }
            expectNothingLost()
        case .orderOut:
            visible = false
            key = false
        case .hideApp: appActive = false
        case .switchTo(let tab):
            store.updateState { $0.activeTab = tab }
            store.reloadIfChangedOnDisk(tab)
            editor = store.text(tab)
            chromeRedrawn = true
        case .refreshChrome: chromeRedrawn = true
        case .runCommand: run()
        }
    }

    /// A click into a panel that is not key, or one ordered front: `windowDidBecomeKey`.
    func becomeKey() {
        guard visible, !key else { return }
        key = true
        decide { $0.becameKey() }
    }

    /// What `textDidChange` does with an edit to the editor.
    func edit(_ kind: String) {
        let t = token(kind)
        editor += t
        typed[active].append(t)
        pending[active] = true
        store.setText(editor, tab: active)
    }

    func step(_ step: PanelStep) {
        switch step {
        case .hotkey: decide { $0.toggle() }
        case .statusShow: decide { $0.show() }
        case .close:
            guard visible else { return }
            decide { $0.hide() }
        case .palette: decide({ $0.command() }, run: { self.decide { $0.openPalette() } })
        case .escPalette:
            guard paletteOpen else { return }
            becomeKey()
            paletteOpen = false
        case .type:
            guard visible else { return }
            becomeKey()
            paletteOpen = false
            edit("t")
        case .command: decide({ $0.command() }, run: { self.edit("c") })
        case .select(let tab):
            guard visible else { return }
            becomeKey()
            chromeRedrawn = false
            decide { $0.selectTab(tab) }
            #expect(active == tab, "select(\(tab)) left tab \(active) active")
            #expect(chromeRedrawn, "select(\(tab)) never redrew the tab strip")
        case .outsideEdit(let tab):
            let t = token("o")
            try? (disk(tab) + t).write(to: store.noteURL(tab), atomically: true, encoding: .utf8)
            serial += 1
            try? FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: TimeInterval(1_000_000 + serial))],
                                                   ofItemAtPath: store.noteURL(tab).path)
            if !pending[tab] { protected[tab].append(t) }
            key = false
            appActive = false
        }
        #expect(!(paletteOpen && !visible), "the palette is open on a hidden panel")
    }

    func expectNothingLost() {
        for tab in 0..<NoteStore.tabCount {
            let text = disk(tab)
            for t in typed[tab] where !text.contains(t) { Issue.record("note \(tab + 1) lost jot edit \(t): \(text)") }
            for t in protected[tab] where !text.contains(t) { Issue.record("note \(tab + 1) lost outside edit \(t): \(text)") }
        }
    }
}

/// `PanelSession` driven over generated action sequences against a real `NoteStore`. Each
/// invariant is one the history broke: the palette left open across hide/show (be1dad7), a
/// showing panel re-centred (434b2f1), clicking the active tab leaving no tab selected (cb9ada5),
/// and an outside edit overwritten by stale editor text (be1dad7).
@Suite struct PanelSessionModelTests {
    @Test func sequencesKeepEveryInvariant() async {
        let steps = Gen.element(of: PanelStep.all).array(of: 1...40).map { $0.compactMap { $0 } }
        await propertyCheck(count: 300, input: steps) { steps in
            let world = PanelWorld()
            for step in steps { world.step(step) }
            world.decide { $0.save() }
            world.expectNothingLost()
        }
    }
}
