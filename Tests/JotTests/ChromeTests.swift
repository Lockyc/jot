import AppKit
import XCTest
@testable import Jot
import JotCore

final class QuitTests: OffscreenTestCase {
    /// An unwritable notes folder makes the quit-time save fail, so the quit is refused; a
    /// writable one lets it through.
    func testAFailedSaveRefusesTheQuit() throws {
        let controller = makeController(notes: ["one"])
        controller.editor.string = "edited"
        XCTAssertTrue(controller.saveForQuit())
        let folder = controller.store.folder
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: folder.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path) }
        controller.editor.string = "edited again"
        XCTAssertFalse(controller.saveForQuit())
    }
}

final class BannerTests: OffscreenTestCase {
    /// The save that makes a conflict copy succeeds, and that success must not clear the notice.
    func testAConflictCopyIsNamedAfterTheSaveSucceeds() throws {
        let controller = makeController(notes: ["one"])
        let url = controller.store.noteURL(0)
        try Data("theirs".utf8).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(10)], ofItemAtPath: url.path)
        controller.store.setText("mine", tab: 0)
        controller.store.flushReportingResult()
        XCTAssertFalse(controller.banner.isHidden)
        XCTAssertTrue(controller.banner.stringValue.contains("1.conflict-"), controller.banner.stringValue)
        // It stays through later successful saves, and goes with the next tab switch.
        controller.store.setText("mine again", tab: 0)
        controller.store.flushReportingResult()
        XCTAssertFalse(controller.banner.isHidden)
        controller.selectTab(1)
        XCTAssertTrue(controller.banner.isHidden)
    }

    /// A save error shows over a conflict notice, and the notice comes back once saving recovers.
    func testASaveErrorOutranksTheNoticeAndClearsAlone() throws {
        let controller = makeController(notes: ["one"])
        let url = controller.store.noteURL(0)
        try Data("theirs".utf8).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(10)], ofItemAtPath: url.path)
        controller.store.setText("mine", tab: 0)
        controller.store.flushReportingResult()
        let notice = controller.banner.stringValue
        let folder = controller.store.folder
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: folder.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path) }
        controller.store.setText("mine again", tab: 0)
        controller.store.flushReportingResult()
        XCTAssertTrue(controller.banner.stringValue.contains("Can't save"), controller.banner.stringValue)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path)
        controller.store.flushReportingResult()
        XCTAssertEqual(controller.banner.stringValue, notice)
    }
}

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
