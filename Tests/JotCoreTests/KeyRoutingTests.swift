import XCTest
@testable import JotCore

final class KeyRoutingTests: XCTestCase {
    func testFocusedPaletteGetsKeys() {
        XCTAssertEqual(KeyRouting.route(paletteOpen: true, paletteFocused: true, editorFocused: false, composing: false), .palette)
    }
    func testOpenButUnfocusedPaletteIsStale() {
        XCTAssertEqual(KeyRouting.route(paletteOpen: true, paletteFocused: false, editorFocused: true, composing: false), .closePalette)
    }
    func testEditorGetsCommands() {
        XCTAssertEqual(KeyRouting.route(paletteOpen: false, paletteFocused: false, editorFocused: true, composing: false), .commands)
    }
    func testFindBarOrOtherFieldPassesThrough() {
        XCTAssertEqual(KeyRouting.route(paletteOpen: false, paletteFocused: false, editorFocused: false, composing: false), .passThrough)
    }
    func testIMECompositionPassesThrough() {
        XCTAssertEqual(KeyRouting.route(paletteOpen: false, paletteFocused: false, editorFocused: true, composing: true), .passThrough)
    }
}
