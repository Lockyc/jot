import AppKit
import XCTest
@testable import Jot
import JotCore

/// Base for every AppKit test: views and the controller are built and never shown. tearDown fails
/// the test if any window came on screen or the test process became the active app, so no test
/// can take the operator's focus unnoticed.
class OffscreenTestCase: XCTestCase {
    private var folders: [URL] = []

    override func setUp() {
        super.setUp()
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
    }

    override func tearDown() {
        let visible = NSApp.windows.filter(\.isVisible).map { $0.title.isEmpty ? String(describing: type(of: $0)) : $0.title }
        XCTAssertEqual(visible, [], "a test put a window on screen")
        XCTAssertFalse(NSApp.isActive, "a test activated the app")
        for folder in folders { try? FileManager.default.removeItem(at: folder) }
        folders = []
        super.tearDown()
    }

    /// A controller over a fresh notes folder, built off-screen; `notes` seeds the tab files.
    func makeController(notes: [String] = []) -> JotController {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("jot-tests-\(UUID().uuidString)")
        folders.append(folder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (i, text) in notes.enumerated() {
            try? text.write(to: folder.appendingPathComponent("\(i + 1).txt"), atomically: true, encoding: .utf8)
        }
        let controller = JotController(store: NoteStore(folder: folder))
        controller.build()
        return controller
    }
}
