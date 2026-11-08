import XCTest
@testable import JotCore

final class LineOpsTests: XCTestCase {
    let text = "one\ntwo\nthree"
    func r(_ l: Int, _ n: Int) -> NSRange { NSRange(location: l, length: n) }

    func check(_ m: MultiEdit?, on t: String, _ expected: String, _ sels: [NSRange]? = nil,
               file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(m?.applied(to: t), expected, file: file, line: line)
        if let sels { XCTAssertEqual(m?.selections, sels, file: file, line: line) }
    }

    func testIndentCaretLine() {
        check(LineOps.indent(text, selections: [r(5, 0)], unit: "  "), on: text, "one\n  two\nthree", [r(7, 0)])
    }
    func testIndentSelectionSpanningLines() {
        check(LineOps.indent(text, selections: [r(1, 5)], unit: "  "), on: text, "  one\n  two\nthree", [r(0, 11)])
    }
    func testSelectionEndingAtLineStartExcludesThatLine() {
        check(LineOps.indent(text, selections: [r(0, 4)], unit: "  "), on: text, "  one\ntwo\nthree", [r(0, 5)])
    }
    func testIndentSkipsEmptyLines() {
        check(LineOps.indent("a\n\nb", selections: [r(0, 4)], unit: "  "), on: "a\n\nb", "  a\n\n  b")
    }
    func testIndentTwoCaretsOneLineKeepsBoth() {
        check(LineOps.indent("abc", selections: [r(1, 0), r(2, 0)], unit: "  "), on: "abc", "  abc", [r(3, 0), r(4, 0)])
    }
    func testIndentCaretsOnSeparateLines() {
        check(LineOps.indent("a\nb\nc", selections: [r(1, 0), r(3, 0), r(5, 0)], unit: "  "), on: "a\nb\nc",
              "  a\n  b\n  c", [r(3, 0), r(7, 0), r(11, 0)])
    }
    func testOutdentSpaces() {
        let t = "    a\n  b\nc"
        check(LineOps.outdent(t, selections: [r(0, 11)], width: 2), on: t, "  a\nb\nc", [r(0, 7)])
    }
    func testOutdentTab() {
        check(LineOps.outdent("\ta", selections: [r(1, 0)], width: 2), on: "\ta", "a", [r(0, 0)])
    }
    func testOutdentCaretClampsToLineStart() {
        check(LineOps.outdent("  a", selections: [r(1, 0)], width: 2), on: "  a", "a", [r(0, 0)])
    }
    func testOutdentCaretsOnSeparateLines() {
        check(LineOps.outdent("  a\n  b", selections: [r(3, 0), r(7, 0)], width: 2), on: "  a\n  b", "a\nb", [r(1, 0), r(3, 0)])
    }
    func testDeleteLinesLastTwoCaretsAtColumnZero() {
        check(LineOps.deleteLines("a\nb\nc", selections: [r(2, 0), r(4, 0)]), on: "a\nb\nc", "a", [r(0, 0)])
    }
    func testDeleteLinesAdjacentCaretsCollapse() {
        check(LineOps.deleteLines("a\nb\nc", selections: [r(0, 0), r(2, 0)]), on: "a\nb\nc", "c", [r(0, 0)])
    }
    func testDeleteLinesSeparateBlocks() {
        check(LineOps.deleteLines("a\nb\nc", selections: [r(0, 0), r(4, 0)]), on: "a\nb\nc", "b", [r(0, 0)])
    }
    func testDuplicateTwoCaretsOneLineOnce() {
        check(LineOps.duplicate("abc\nd", selections: [r(1, 0), r(2, 0)]), on: "abc\nd", "abc\nabc\nd", [r(5, 0), r(6, 0)])
    }
    func testDuplicateAdjacentCaretLines() {
        check(LineOps.duplicate("a\nb", selections: [r(0, 0), r(2, 0)]), on: "a\nb", "a\na\nb\nb", [r(2, 0), r(6, 0)])
    }
    func testDuplicateSelectionsLeaveCaretsAlone() {
        check(LineOps.duplicate("ab cd", selections: [r(0, 2), r(4, 0)]), on: "ab cd", "abab cd", [r(2, 2), r(6, 0)])
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
