import AppKit
import XCTest
@testable import Jot
import JotCore

final class EditorViewTests: OffscreenTestCase {
    /// Every edit goes through `apply`; nothing on that path may drop the editor to TextKit 1.
    func testMultiCaretEditStaysOnTextKit2() {
        let editor = EditorView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        editor.configurePlain()
        editor.string = "one\ntwo\nthree"
        editor.setCarets([NSRange(location: 3, length: 0), NSRange(location: 7, length: 0), NSRange(location: 13, length: 0)])
        editor.apply(MultiEdit.perSelection(editor.string, editor.selections) { Carets.replace($0, with: "!") })
        XCTAssertEqual(editor.string, "one!\ntwo!\nthree!")
        XCTAssertNotNil(editor.textLayoutManager, "EditorView fell back to TextKit 1")
    }

    func testControllerEditorIsTextKit2() {
        XCTAssertNotNil(makeController().editor.textLayoutManager)
    }
}

final class ToolbarTests: OffscreenTestCase {
    /// VoiceOver reads each toolbar button by its registry title, not its registry id.
    func testButtonsAreLabelledByCommandTitle() {
        let controller = makeController()
        let buttons = controller.toolbar.buttons
        XCTAssertFalse(buttons.isEmpty)
        for (id, button) in buttons {
            let command = controller.commands.first { $0.id == id }
            XCTAssertNotNil(command, "toolbar button \(id) has no registry command")
            XCTAssertEqual(button.accessibilityLabel(), command?.title, "toolbar button \(id)")
        }
    }
}

final class TabStripTests: OffscreenTestCase {
    /// The toolbar's narrowest layout, which sets how narrow the panel goes: squeezed to the
    /// panel's minSize, the toolbar overflows to exactly its own minimum width.
    func narrowestToolbarWidth(notes: [String]) -> CGFloat {
        let controller = makeController(notes: notes)
        let panel = controller.panel!
        panel.setContentSize(NSSize(width: panel.minSize.width, height: 300))
        panel.contentView?.layoutSubtreeIfNeeded()
        XCTAssertLessThanOrEqual(panel.frame.width, panel.minSize.width)
        return controller.toolbar.frame.width
    }

    /// Seven long labels truncate instead of holding the panel wide: the panel goes exactly as
    /// narrow as it does with seven empty tabs.
    func testLongLabelsDoNotWidenThePanel() {
        let long = String(repeating: "w", count: 140)
        let labelled = narrowestToolbarWidth(notes: Array(repeating: long, count: NoteStore.tabCount))
        XCTAssertEqual(labelled, narrowestToolbarWidth(notes: []), accuracy: 1)
    }

    /// The tab buttons are .pushOnPushOff: clicking the active one must leave it selected.
    func testClickingTheActiveTabKeepsExactlyOneSelected() {
        let controller = makeController(notes: ["a", "b"])
        let buttons = controller.toolbar.tabs.buttons
        buttons[controller.activeTab].performClick(nil)
        XCTAssertEqual(buttons.filter { $0.state == .on }.map(\.tag), [controller.activeTab])
        buttons[1].performClick(nil)
        XCTAssertEqual(controller.activeTab, 1)
        XCTAssertEqual(buttons.filter { $0.state == .on }.map(\.tag), [1])
    }
}
