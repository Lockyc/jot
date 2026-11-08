import XCTest
@testable import JotCore

final class CaretsTests: XCTestCase {
    func r(_ l: Int, _ n: Int) -> NSRange { NSRange(location: l, length: n) }

    func testSplitIntoLinesEndsOfEachLine() {
        XCTAssertEqual(Carets.splitIntoLines("ab\ncd\nef", [r(0, 8)]), [r(2, 0), r(5, 0), r(8, 0)])
    }
    func testSplitIntoLinesStopsAtSelectionEnd() {
        XCTAssertEqual(Carets.splitIntoLines("abcd\nefgh", [r(1, 6)]), [r(4, 0), r(7, 0)])
    }
    func testSplitIntoLinesExcludesTrailingLineStart() {
        XCTAssertEqual(Carets.splitIntoLines("ab\ncd\nef", [r(0, 6)]), [r(2, 0), r(5, 0)])
    }
    func testSplitIntoLinesKeepsEmptyCarets() {
        XCTAssertEqual(Carets.splitIntoLines("ab\ncd\nef", [r(0, 0), r(3, 5)]), [r(0, 0), r(5, 0), r(8, 0)])
    }
    func testAddCaretBelowSameColumn() {
        XCTAssertEqual(Carets.addVertical("abc\ndef", [r(2, 0)], up: false), [r(2, 0), r(6, 0)])
    }
    func testAddCaretBelowClampsColumn() {
        XCTAssertEqual(Carets.addVertical("abcd\nx", [r(3, 0)], up: false), [r(3, 0), r(6, 0)])
    }
    func testAddCaretBelowExtendsFromBottommost() {
        XCTAssertEqual(Carets.addVertical("a\nb\nc", [r(0, 0), r(2, 0)], up: false), [r(0, 0), r(2, 0), r(4, 0)])
    }
    func testAddCaretBelowSnapsOutOfSurrogatePair() {
        XCTAssertEqual(Carets.addVertical("ab\n👍x", [r(1, 0)], up: false), [r(1, 0), r(3, 0)])
    }
    func testAddCaretBelowFromMultiLineSelection() {
        XCTAssertEqual(Carets.addVertical("ab\ncd\nef", [r(0, 4)], up: false), [r(0, 4), r(7, 0)])
    }
    func testAddCaretAbove() {
        XCTAssertEqual(Carets.addVertical("abc\ndef", [r(6, 0)], up: true), [r(2, 0), r(6, 0)])
    }
    func testAddCaretAboveFirstLineNoOp() {
        XCTAssertEqual(Carets.addVertical("abc\ndef", [r(1, 0)], up: true), [r(1, 0)])
    }
    func testAddCaretBelowLastLineNoOp() {
        XCTAssertEqual(Carets.addVertical("abc\ndef", [r(5, 0)], up: false), [r(5, 0)])
    }
    func testToggleAddsThenRemoves() {
        let added = Carets.toggle([r(0, 0)], at: 3)
        XCTAssertEqual(added, [r(0, 0), r(3, 0)])
        XCTAssertEqual(Carets.toggle(added, at: 3), [r(0, 0)])
    }
    func testToggleNeverRemovesLast() {
        XCTAssertEqual(Carets.toggle([r(3, 0)], at: 3), [r(3, 0)])
    }
    func testPasteDistributesMatchingLines() {
        let m = Carets.paste("a\nb", [r(1, 0), r(3, 0)], clipboard: "X\nY\n")
        XCTAssertEqual(m?.applied(to: "a\nb"), "aX\nbY")
        XCTAssertEqual(m?.selections, [r(2, 0), r(5, 0)])
    }
    func testPasteWholeWhenCountsDiffer() {
        let m = Carets.paste("a\nb", [r(1, 0), r(3, 0)], clipboard: "X\nY\nZ")
        XCTAssertEqual(m?.applied(to: "a\nb"), "aX\nY\nZ\nbX\nY\nZ")
    }
    func testPasteSingleCaretKeepsTrailingNewline() {
        XCTAssertEqual(Carets.paste("ab", [r(1, 0)], clipboard: "X\n")?.applied(to: "ab"), "aX\nb")
    }
    func testCopyJoinsNonEmpty() {
        XCTAssertEqual(Carets.copyText("abc def", [r(0, 3), r(4, 0), r(4, 3)]), "abc\ndef")
    }
    func testCopyAllEmptyIsNil() {
        XCTAssertNil(Carets.copyText("abc", [r(0, 0), r(2, 0)]))
    }
    func testDeleteBackwardComposedCharacter() {
        let t = "a👍🏽"
        let m = MultiEdit.perSelection(t, [r((t as NSString).length, 0)]) { Carets.deleteBackward(t, $0, indentWidth: 2) }
        XCTAssertEqual(m?.applied(to: t), "a")
        XCTAssertEqual(m?.selections, [r(1, 0)])
    }
    func testDeleteBackwardAtDocumentStartIsNoOp() {
        let m = MultiEdit.perSelection("abc", [r(0, 0), r(2, 0)]) { Carets.deleteBackward("abc", $0, indentWidth: 2) }
        XCTAssertEqual(m?.applied(to: "abc"), "ac")
        XCTAssertEqual(m?.selections, [r(0, 0), r(1, 0)])
    }
    func testDeleteBackwardSmartIndentAtEachCaret() {
        let t = "    a\n    b"
        let m = MultiEdit.perSelection(t, [r(4, 0), r(10, 0)]) { Carets.deleteBackward(t, $0, indentWidth: 2) }
        XCTAssertEqual(m?.applied(to: t), "  a\n  b")
    }
    func testDeleteBackwardSelection() {
        XCTAssertEqual(Carets.deleteBackward("abcd", r(1, 2), indentWidth: 2),
                       TextEdit(range: r(1, 2), replacement: "", selection: r(1, 0)))
    }
    func testDeleteForwardComposedCharacter() {
        XCTAssertEqual(Carets.deleteForward("👍🏽a", r(0, 0)),
                       TextEdit(range: r(0, 4), replacement: "", selection: r(0, 0)))
    }
    func testDeleteForwardAtEndIsNil() {
        XCTAssertNil(Carets.deleteForward("ab", r(2, 0)))
    }
    func testReplacePutsCaretAfter() {
        XCTAssertEqual(Carets.replace(r(1, 2), with: "XY"), TextEdit(range: r(1, 2), replacement: "XY", selection: r(3, 0)))
    }
}
