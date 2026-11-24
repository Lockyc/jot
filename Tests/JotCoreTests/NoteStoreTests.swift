import XCTest
@testable import JotCore

final class NoteStoreTests: XCTestCase {
    var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("jot-tests-\(UUID().uuidString)")
    }
    override func tearDownWithError() throws {
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dir.path)
        try? FileManager.default.removeItem(at: dir)
    }
    func read(_ name: String) throws -> String {
        try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)
    }

    func testFreshFolderHasSevenEmptyNotesAndDefaults() {
        let store = NoteStore(folder: dir)
        XCTAssertEqual((0..<NoteStore.tabCount).map(store.text), Array(repeating: "", count: 7))
        XCTAssertEqual(store.state, JotState())
        XCTAssertEqual(store.state.settings.hotKey, .defaultToggle)
    }
    func testRoundTripTextAndState() throws {
        let store = NoteStore(folder: dir)
        store.setText("hello", tab: 2)
        store.updateState { $0.pinned[2] = true; $0.activeTab = 2; $0.settings.fontSize = 16 }
        try store.flush()
        XCTAssertEqual(try read("3.txt"), "hello")
        let reopened = NoteStore(folder: dir)
        XCTAssertEqual(reopened.text(2), "hello")
        XCTAssertEqual(reopened.state.pinned[2], true)
        XCTAssertEqual(reopened.state.activeTab, 2)
        XCTAssertEqual(reopened.state.settings.fontSize, 16)
    }
    /// An undecodable state.json is moved aside before the defaults can be saved over it.
    func testCorruptStateIsKeptAsideAndDefaultsUsed() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("{not json".utf8).write(to: dir.appendingPathComponent("state.json"))
        let store = NoteStore(folder: dir)
        XCTAssertEqual(store.state, JotState())
        let kept = try XCTUnwrap(store.unreadableState)
        XCTAssertTrue(kept.lastPathComponent.hasPrefix("state.unreadable-"), kept.lastPathComponent)
        XCTAssertEqual(try String(contentsOf: kept, encoding: .utf8), "{not json")
        store.updateState { $0.activeTab = 3 }
        try store.flush()
        XCTAssertEqual(try String(contentsOf: kept, encoding: .utf8), "{not json")
        XCTAssertNil(NoteStore(folder: dir).unreadableState)
    }
    func testPartialStateIsNormalized() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(#"{"pinned":[true],"activeTab":99,"settings":{"indentWidth":"x"}}"#.utf8)
            .write(to: dir.appendingPathComponent("state.json"))
        let s = NoteStore(folder: dir).state
        XCTAssertEqual(s.pinned, [true, false, false, false, false, false, false])
        XCTAssertEqual(s.wrap.count, 7)
        XCTAssertEqual(s.activeTab, 6)
        XCTAssertEqual(s.settings.indentWidth, 2)
    }
    func testSetTextSavesAfterDebounce() throws {
        let store = NoteStore(folder: dir, debounce: 0.05)
        let saved = expectation(description: "saved")
        store.onSaveResult = { if $0 == nil { saved.fulfill() } }
        store.setText("hi", tab: 0)
        wait(for: [saved], timeout: 2)
        XCTAssertEqual(try read("1.txt"), "hi")
    }
    func testUnwritableFolderThrowsAndKeepsEdits() throws {
        let store = NoteStore(folder: dir)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: dir.path)
        store.setText("kept", tab: 0)
        XCTAssertThrowsError(try store.flush())
        XCTAssertEqual(store.text(0), "kept")
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dir.path)
        try store.flush()
        XCTAssertEqual(try read("1.txt"), "kept")
    }
    func testExternalEditIsReloaded() throws {
        let store = NoteStore(folder: dir)
        store.setText("mine", tab: 0)
        try store.flush()
        let url = store.noteURL(0)
        try Data("theirs".utf8).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(10)], ofItemAtPath: url.path)
        XCTAssertTrue(store.reloadIfChangedOnDisk(0))
        XCTAssertEqual(store.text(0), "theirs")
        XCTAssertFalse(store.reloadIfChangedOnDisk(0))
    }
    func testExternalEditIgnoredWhileUnsavedEditsPending() throws {
        let store = NoteStore(folder: dir)
        try store.flush()
        let url = store.noteURL(0)
        try Data("theirs".utf8).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(10)], ofItemAtPath: url.path)
        store.setText("unsaved", tab: 0)
        XCTAssertFalse(store.reloadIfChangedOnDisk(0))
        XCTAssertEqual(store.text(0), "unsaved")
    }

    func testAnOutsideEditUnderAnUnsavedOneIsKeptAsAConflictCopy() throws {
        let store = NoteStore(folder: dir)
        try store.flush()
        let url = store.noteURL(0)
        try Data("theirs".utf8).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(10)], ofItemAtPath: url.path)
        var copied: URL?
        store.onConflictCopy = { copied = $0 }
        store.setText("mine", tab: 0)
        try store.flush()
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "mine")
        let copy = try XCTUnwrap(copied)
        XCTAssertTrue(copy.lastPathComponent.hasPrefix("1.conflict-"))
        XCTAssertEqual(try String(contentsOf: copy, encoding: .utf8), "theirs")
        // A save with no outside change makes no copy.
        copied = nil
        store.setText("mine again", tab: 0)
        try store.flush()
        XCTAssertNil(copied)
    }

    /// A write that fails after the copy is retried as a write only: one copy, however many tries.
    func testAFailedWriteAfterAConflictCopyIsNotCopiedAgain() throws {
        let store = NoteStore(folder: dir)
        try store.flush()
        // A non-empty directory at the note's path: copying it works, writing over it fails.
        let url = store.noteURL(0)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        try Data("theirs".utf8).write(to: url.appendingPathComponent("keep"))
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(10)], ofItemAtPath: url.path)
        var copies = 0
        store.onConflictCopy = { _ in copies += 1 }
        store.setText("mine", tab: 0)
        XCTAssertThrowsError(try store.flush())
        XCTAssertThrowsError(try store.flush())
        XCTAssertThrowsError(try store.flush())
        XCTAssertEqual(copies, 1)
        let conflicts = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasPrefix("1.conflict-") }
        XCTAssertEqual(conflicts.count, 1)
        try FileManager.default.removeItem(at: url)
        try store.flush()
        XCTAssertEqual(try read("1.txt"), "mine")
        XCTAssertEqual(copies, 1)
    }

    func testNonUTF8NoteIsDecodedNotBlanked() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "café".data(using: .isoLatin1)!.write(to: dir.appendingPathComponent("1.txt"))
        XCTAssertEqual(NoteStore(folder: dir).text(0), "café")
    }

    func testNoteLabel() {
        XCTAssertEqual(NoteLabel.make(text: "", index: 3), "4")
        XCTAssertEqual(NoteLabel.make(text: "\n  \n  Shopping list\nmilk", index: 0), "Shopping list")
        XCTAssertEqual(NoteLabel.make(text: "A very long first line indeed", index: 0), "A very long firs…")
    }
}
