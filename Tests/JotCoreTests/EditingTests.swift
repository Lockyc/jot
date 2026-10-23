import XCTest
@testable import JotCore

final class EditingTests: XCTestCase {
    func r(_ l: Int, _ n: Int) -> NSRange { NSRange(location: l, length: n) }

    func testNewlineKeepsIndent() {
        XCTAssertEqual(LineOps.newline("  ab", selection: r(4, 0)),
                       TextEdit(range: r(4, 0), replacement: "\n  ", selection: r(7, 0)))
    }
    func testNewlineKeepsTabIndent() {
        XCTAssertEqual(LineOps.newline("\tab", selection: r(3, 0)).replacement, "\n\t")
    }
    func testNewlineReplacesSelection() {
        XCTAssertEqual(LineOps.newline("  abcd", selection: r(3, 2)),
                       TextEdit(range: r(3, 2), replacement: "\n  ", selection: r(6, 0)))
    }
    func testNewlineInsideIndentCarriesOnlyWhatIsBeforeCaret() {
        XCTAssertEqual(LineOps.newline("    a", selection: r(2, 0)).replacement, "\n  ")
    }
    func testNewlinePlainLine() {
        XCTAssertEqual(LineOps.newline("ab", selection: r(2, 0)).replacement, "\n")
    }
    func testNewlineContinuesDashBullet() {
        XCTAssertEqual(LineOps.newline("  - item", selection: r(8, 0)),
                       TextEdit(range: r(8, 0), replacement: "\n  - ", selection: r(13, 0)))
    }
    func testNewlineContinuesStarBullet() {
        XCTAssertEqual(LineOps.newline("* item", selection: r(6, 0)).replacement, "\n* ")
    }
    func testNewlineSplittingBulletContinuesIt() {
        XCTAssertEqual(LineOps.newline("- ab", selection: r(3, 0)).replacement, "\n- ")
    }
    func testNewlineBeforeMarkerIsNotABullet() {
        XCTAssertEqual(LineOps.newline("  - a", selection: r(2, 0)).replacement, "\n  ")
    }
    func testNewlineNeedsSpaceAfterDash() {
        XCTAssertEqual(LineOps.newline("-5", selection: r(2, 0)).replacement, "\n")
    }
    func testNewlineOnEmptyBulletEndsTheList() {
        XCTAssertEqual(LineOps.newline("- a\n  - ", selection: r(8, 0)),
                       TextEdit(range: r(4, 4), replacement: "", selection: r(4, 0)))
    }

    func testBackspaceInIndentRemovesOneUnit() {
        XCTAssertEqual(LineOps.deleteBackward("    a", selection: r(4, 0), width: 2),
                       TextEdit(range: r(2, 2), replacement: "", selection: r(2, 0)))
    }
    func testBackspaceSnapsToIndentStop() {
        XCTAssertEqual(LineOps.deleteBackward("   a", selection: r(3, 0), width: 2)?.range, r(2, 1))
    }
    func testBackspaceAfterTextIsNative() {
        XCTAssertNil(LineOps.deleteBackward("  a ", selection: r(4, 0), width: 2))
    }
    func testBackspaceAtLineStartIsNative() {
        XCTAssertNil(LineOps.deleteBackward("a\n  b", selection: r(2, 0), width: 2))
    }
    func testBackspaceWithSelectionIsNative() {
        XCTAssertNil(LineOps.deleteBackward("    a", selection: r(2, 2), width: 2))
    }

    func testLineStartGoesToFirstCharacter() {
        XCTAssertEqual(LineOps.smartLineStart("x\n  - ab", caret: 8), 4)
    }
    func testLineStartFromFirstCharacterGoesToColumnZero() {
        XCTAssertEqual(LineOps.smartLineStart("x\n  ab", caret: 4), 2)
    }
    func testLineStartInsideIndentGoesToFirstCharacter() {
        XCTAssertEqual(LineOps.smartLineStart("    ab", caret: 1), 4)
    }
    func testLineStartOnBlankIndentedLine() {
        XCTAssertEqual(LineOps.smartLineStart("   ", caret: 3), 0)
    }

    func testDeleteLine() {
        XCTAssertEqual(LineOps.deleteLines("one\ntwo\nthree", selection: r(5, 0)),
                       TextEdit(range: r(4, 4), replacement: "", selection: r(4, 0)))
    }
    func testDeleteLastLineTakesPrecedingNewline() {
        XCTAssertEqual(LineOps.deleteLines("one\ntwo", selection: r(5, 0)),
                       TextEdit(range: r(3, 4), replacement: "", selection: r(0, 0)))
    }
    func testDeleteLinesCoveringSelection() {
        XCTAssertEqual(LineOps.deleteLines("one\ntwo\nthree", selection: r(1, 5)).range, r(0, 8))
    }
    func testDeleteOnlyLine() {
        XCTAssertEqual(LineOps.deleteLines("one", selection: r(1, 0)),
                       TextEdit(range: r(0, 3), replacement: "", selection: r(0, 0)))
    }

    func testInsertLineBelowKeepsIndentAndBullet() {
        XCTAssertEqual(LineOps.insertLineBelow("  - ab\nc", selection: r(3, 0)),
                       TextEdit(range: r(6, 0), replacement: "\n  - ", selection: r(11, 0)))
    }
    func testInsertLineBelowSelectionUsesLastLine() {
        XCTAssertEqual(LineOps.insertLineBelow("a\n  b", selection: r(0, 4)).range, r(5, 0))
    }
}
