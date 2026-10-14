import XCTest
@testable import JotCore

final class TextActionsTests: XCTestCase {
    func testTrimTrailingWhitespace() {
        XCTAssertEqual(TextActions.trimTrailingWhitespace("a  \nb\t\n"), "a\nb\n")
    }
    func testSortAscendingKeepsTrailingNewline() {
        XCTAssertEqual(TextActions.sortLines("b\na\nc\n", descending: false), "a\nb\nc\n")
    }
    func testSortDescending() {
        XCTAssertEqual(TextActions.sortLines("b\na\nc", descending: true), "c\nb\na")
    }
    func testSortIsNumberAware() {
        XCTAssertEqual(TextActions.sortLines("item10\nitem2", descending: false), "item2\nitem10")
    }
    func testRemoveDuplicateLinesKeepsFirst() {
        XCTAssertEqual(TextActions.removeDuplicateLines("a\nb\na\nc\nb"), "a\nb\nc")
    }
    func testRemoveBlankLines() {
        XCTAssertEqual(TextActions.removeBlankLines("a\n\n  \nb\n"), "a\nb\n")
    }
    func testJoinLines() {
        XCTAssertEqual(TextActions.joinLines("  a\nb  \n\nc\n"), "a b c\n")
    }
    func testSplitOnDelimiterTrimsPieces() {
        XCTAssertEqual(TextActions.split("a, b,c", on: ","), "a\nb\nc")
    }
    func testSplitOnEmptyDelimiterIsNoOp() {
        XCTAssertEqual(TextActions.split("a,b", on: ""), "a,b")
    }
    func testCase() {
        XCTAssertEqual(TextActions.uppercase("Hello"), "HELLO")
        XCTAssertEqual(TextActions.lowercase("Hello"), "hello")
        XCTAssertEqual(TextActions.titleCase("hello wORLD"), "Hello World")
    }
    func testNumberLinesSkipsBlank() {
        XCTAssertEqual(TextActions.numberLines("a\n\nb\n"), "1. a\n\n2. b\n")
    }
    func testEmptyInputStaysEmpty() {
        for f in [TextActions.trimTrailingWhitespace, TextActions.removeDuplicateLines,
                  TextActions.removeBlankLines, TextActions.joinLines, TextActions.numberLines] {
            XCTAssertEqual(f(""), "")
        }
        XCTAssertEqual(TextActions.sortLines("", descending: false), "")
    }
}
