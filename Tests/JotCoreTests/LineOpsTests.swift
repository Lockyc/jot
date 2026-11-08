import XCTest
@testable import JotCore

final class LineOpsTests: XCTestCase {
    let text = "one\ntwo\nthree"
    func r(_ l: Int, _ n: Int) -> NSRange { NSRange(location: l, length: n) }

    func testIndentCaretLine() {
        XCTAssertEqual(LineOps.indent(text, selection: r(5, 0), unit: "  "),
                       TextEdit(range: r(4, 3), replacement: "  two", selection: r(7, 0)))
    }
    func testIndentSelectionSpanningLines() {
        XCTAssertEqual(LineOps.indent(text, selection: r(1, 5), unit: "  "),
                       TextEdit(range: r(0, 7), replacement: "  one\n  two", selection: r(0, 11)))
    }
    func testSelectionEndingAtLineStartExcludesThatLine() {
        XCTAssertEqual(LineOps.indent(text, selection: r(0, 4), unit: "  "),
                       TextEdit(range: r(0, 3), replacement: "  one", selection: r(0, 5)))
    }
    func testIndentSkipsEmptyLines() {
        XCTAssertEqual(LineOps.indent("a\n\nb", selection: r(0, 4), unit: "  ").replacement, "  a\n\n  b")
    }
    func testOutdentSpaces() {
        let t = "    a\n  b\nc"
        XCTAssertEqual(LineOps.outdent(t, selection: r(0, 11), width: 2).replacement, "  a\nb\nc")
    }
    func testOutdentTab() {
        XCTAssertEqual(LineOps.outdent("\ta", selection: r(1, 0), width: 2),
                       TextEdit(range: r(0, 2), replacement: "a", selection: r(0, 0)))
    }
    func testOutdentCaretClampsToLineStart() {
        XCTAssertEqual(LineOps.outdent("  a", selection: r(1, 0), width: 2).selection, r(0, 0))
    }
    func testMoveUp() {
        XCTAssertEqual(LineOps.move(text, selections: [r(5, 0)], up: true),
                       MultiEdit(splices: [Splice(range: r(0, 7), replacement: "two\none")], selections: [r(1, 0)]))
    }
    func testMoveUpFirstLineIsNil() {
        XCTAssertNil(LineOps.move(text, selections: [r(1, 0)], up: true))
    }
    func testMoveDown() {
        XCTAssertEqual(LineOps.move(text, selections: [r(5, 0)], up: false),
                       MultiEdit(splices: [Splice(range: r(4, 9), replacement: "three\ntwo")], selections: [r(11, 0)]))
    }
    func testMoveDownLastLineIsNil() {
        XCTAssertNil(LineOps.move(text, selections: [r(9, 0)], up: false))
    }
    func testMoveDownWithEmojiUsesUTF16() {
        XCTAssertEqual(LineOps.move("😀a\nb", selections: [r(0, 0)], up: false),
                       MultiEdit(splices: [Splice(range: r(0, 5), replacement: "b\n😀a")], selections: [r(2, 0)]))
    }
    func testDuplicateCaretLine() {
        XCTAssertEqual(LineOps.duplicate(text, selection: r(5, 0)),
                       TextEdit(range: r(7, 0), replacement: "\ntwo", selection: r(9, 0)))
    }
    func testDuplicateSelection() {
        XCTAssertEqual(LineOps.duplicate(text, selection: r(4, 3)),
                       TextEdit(range: r(7, 0), replacement: "two", selection: r(7, 3)))
    }
    func testSelectLineThenExtend() {
        XCTAssertEqual(LineOps.selectLine(text, selection: r(5, 0)), r(4, 4))
        XCTAssertEqual(LineOps.selectLine(text, selection: r(4, 4)), r(4, 9))
    }
    func testSelectLastLine() {
        XCTAssertEqual(LineOps.selectLine(text, selection: r(10, 0)), r(8, 5))
    }
}
