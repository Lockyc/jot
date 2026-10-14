import XCTest
@testable import JotCore

final class GutterTests: XCTestCase {
    func testStripsBoxGutterAndDedents() {
        let input = "  │ func greet() {\n  │     print(\"hi\")\n  │ }"
        XCTAssertEqual(TextActions.stripQuoteGutter(input), "func greet() {\n    print(\"hi\")\n}")
    }
    func testBareGutterLinesBecomeEmptyAndTrailingNewlineKept() {
        XCTAssertEqual(TextActions.stripQuoteGutter("  │ a\n  │\n  │ b\n"), "a\n\nb\n")
    }
    func testMarkdownTableInsideBoxGutterKeepsItsPipes() {
        XCTAssertEqual(TextActions.stripQuoteGutter("│ | a | b |\n│ |---|---|\n"), "| a | b |\n|---|---|\n")
    }
    func testAsciiPipeGutterWhenNoBoxMarkers() {
        XCTAssertEqual(TextActions.stripQuoteGutter("| one\n| two"), "one\ntwo")
    }
    func testChevronQuote() {
        XCTAssertEqual(TextActions.stripQuoteGutter("> a\n> b"), "a\nb")
    }
    func testOtherBoxMarkers() {
        XCTAssertEqual(TextActions.stripQuoteGutter("▎ a\n┃ b\n⎿  c"), "a\nb\n c")
    }
    func testLinesWithoutMarkerAreKeptThenDedented() {
        XCTAssertEqual(TextActions.stripQuoteGutter("  │ a\n    b"), "a\n    b")
    }
    func testCRLFInput() {
        XCTAssertEqual(TextActions.stripQuoteGutter("│ a\r\n│ b\r\n"), "a\nb\n")
    }

    func testDedentRemovesCommonIndent() {
        XCTAssertEqual(TextActions.dedent("    a\n      b\n    c"), "a\n  b\nc")
    }
    func testDedentIgnoresBlankLinesForThePrefix() {
        XCTAssertEqual(TextActions.dedent("    a\n\n    b\n"), "a\n\nb\n")
    }
    func testDedentEmptiesWhitespaceOnlyLines() {
        XCTAssertEqual(TextActions.dedent("    a\n  \n    b"), "a\n\nb")
    }
    func testDedentNoCommonIndentUnchanged() {
        XCTAssertEqual(TextActions.dedent("a\n  b"), "a\n  b")
    }
    func testDedentTabs() {
        XCTAssertEqual(TextActions.dedent("\ta\n\tb"), "a\nb")
    }
}
