import XCTest
@testable import JotCore

final class MultiEditTests: XCTestCase {
    func r(_ l: Int, _ n: Int) -> NSRange { NSRange(location: l, length: n) }
    func insert(_ s: String) -> (NSRange) -> TextEdit? {
        { sel in TextEdit(range: sel, replacement: s, selection: NSRange(location: sel.location + (s as NSString).length, length: 0)) }
    }
    func outcome(_ text: String, _ m: MultiEdit?) -> (String, [NSRange])? {
        m.map { ($0.applied(to: text), $0.selections) }
    }

    func testSingleSelectionMatchesTextEdit() {
        let o = outcome("  ab", MultiEdit.perSelection("  ab", [r(4, 0)]) { LineOps.newline("  ab", selection: $0) })
        XCTAssertEqual(o?.0, "  ab\n  ")
        XCTAssertEqual(o?.1, [r(7, 0)])
    }
    func testInsertAtThreeCaretsShiftsLaterOnes() {
        let o = outcome("a\nb\nc", MultiEdit.perSelection("a\nb\nc", [r(1, 0), r(3, 0), r(5, 0)], insert("!")))
        XCTAssertEqual(o?.0, "a!\nb!\nc!")
        XCTAssertEqual(o?.1, [r(2, 0), r(5, 0), r(8, 0)])
    }
    func testNilOpLeavesSelectionInPlace() {
        let o = outcome("abc", MultiEdit.perSelection("abc", [r(0, 0), r(3, 0)]) { $0.location == 0 ? nil : self.insert("!")($0) })
        XCTAssertEqual(o?.0, "abc!")
        XCTAssertEqual(o?.1, [r(0, 0), r(4, 0)])
    }
    func testNilEverywhereIsNil() {
        XCTAssertNil(MultiEdit.perSelection("abc", [r(0, 0), r(1, 0)]) { _ in nil })
    }
    func testOverlappingEditsMerge() {
        let op: (NSRange) -> TextEdit? = { s in
            let start = max(0, s.location - 2)
            return TextEdit(range: NSRange(location: start, length: NSMaxRange(s) - start), replacement: "",
                            selection: NSRange(location: start, length: 0))
        }
        let m = MultiEdit.perSelection("abcdef", [r(2, 0), r(3, 0)], op)
        XCTAssertEqual(outcome("abcdef", m)?.0, "def")
        XCTAssertEqual(m?.selections, [r(0, 0)])
        XCTAssertEqual(m?.splices.count, 1)
    }
    func testIndentCaretsOnSeparateLines() {
        let t = "a\nb\nc"
        let o = outcome(t, MultiEdit.perSelection(t, [r(1, 0), r(3, 0), r(5, 0)]) { LineOps.indent(t, selection: $0, unit: "  ") })
        XCTAssertEqual(o?.0, "  a\n  b\n  c")
        XCTAssertEqual(o?.1, [r(3, 0), r(7, 0), r(11, 0)])
    }
    func testTwoCaretsOnOneLineIndentOnce() {
        let o = outcome("abc", MultiEdit.perSelection("abc", [r(1, 0), r(2, 0)]) { LineOps.indent("abc", selection: $0, unit: "  ") })
        XCTAssertEqual(o?.0, "  abc")
        XCTAssertEqual(o?.1.count, 1)
    }
    func testDeleteLinesAdjacentCaretsCollapse() {
        let t = "a\nb\nc"
        let o = outcome(t, MultiEdit.perSelection(t, [r(0, 0), r(2, 0)]) { LineOps.deleteLines(t, selection: $0) })
        XCTAssertEqual(o?.0, "c")
        XCTAssertEqual(o?.1, [r(0, 0)])
    }
    func testDeleteLinesLastLine() {
        let t = "a\nb\nc"
        let o = outcome(t, MultiEdit.perSelection(t, [r(0, 0), r(4, 0)]) { LineOps.deleteLines(t, selection: $0) })
        XCTAssertEqual(o?.0, "b")
        XCTAssertEqual(o?.1, [r(0, 0)])
    }
    func testInsertLineBelowLastLine() {
        let t = "- a\n- b"
        let o = outcome(t, MultiEdit.perSelection(t, [r(1, 0), r(5, 0)]) { LineOps.insertLineBelow(t, selection: $0) })
        XCTAssertEqual(o?.0, "- a\n- \n- b\n- ")
        XCTAssertEqual(o?.1, [r(6, 0), r(13, 0)])
    }
    func testMoveUpBlockCarriesCarets() {
        let o = outcome("x\na\nb", LineOps.move("x\na\nb", selections: [r(2, 0), r(4, 0)], up: true))
        XCTAssertEqual(o?.0, "a\nb\nx")
        XCTAssertEqual(o?.1, [r(0, 0), r(2, 0)])
    }
    func testMoveUpTwoBlocks() {
        let o = outcome("x\na\ny\nb", LineOps.move("x\na\ny\nb", selections: [r(2, 0), r(6, 0)], up: true))
        XCTAssertEqual(o?.0, "a\nx\nb\ny")
        XCTAssertEqual(o?.1, [r(0, 0), r(4, 0)])
    }
    func testMoveDownBlockCarriesCarets() {
        let o = outcome("a\nb\nx", LineOps.move("a\nb\nx", selections: [r(0, 0), r(2, 0)], up: false))
        XCTAssertEqual(o?.0, "x\na\nb")
        XCTAssertEqual(o?.1, [r(2, 0), r(4, 0)])
    }
    func testMoveUpAtTopIsNil() {
        XCTAssertNil(LineOps.move("a\nb\nc", selections: [r(0, 0), r(4, 0)], up: true))
    }
    func testMoveDownLastLineIsNil() {
        XCTAssertNil(LineOps.move("a\nb\nc", selections: [r(0, 0), r(4, 0)], up: false))
    }
    func testNormalizeDedupesAndAbsorbs() {
        XCTAssertEqual(MultiEdit.normalize([r(5, 0), r(1, 0), r(5, 0), r(2, 3), r(3, 0)]), [r(1, 0), r(2, 3), r(5, 0)])
    }
    func testNormalizeMergesOverlapping() {
        XCTAssertEqual(MultiEdit.normalize([r(0, 3), r(2, 3)]), [r(0, 5)])
    }
    func testAppliedRoundTrip() {
        let m = MultiEdit(splices: [Splice(range: r(0, 1), replacement: "AA"), Splice(range: r(2, 0), replacement: "-"),
                                    Splice(range: r(4, 2), replacement: "")], selections: [])
        let s = NSMutableString(string: "abcdef")
        for sp in m.splices.reversed() { s.replaceCharacters(in: sp.range, with: sp.replacement) }
        XCTAssertEqual(m.applied(to: "abcdef"), s as String)
        XCTAssertEqual(m.applied(to: "abcdef"), "AAb-cd")
    }
}
