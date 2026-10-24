import XCTest
@testable import JotCore

final class UnwrapTests: XCTestCase {
    /// Lays markdown out the way Claude Code prints a reply: a two-column margin (`⏺ ` on the
    /// first line), greedy word wrap at `width`, list continuations aligned under the item text.
    func claudeWrap(_ source: String, width: Int) -> String {
        var out: [String] = []
        for (i, line) in source.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let margin = i == 0 ? "⏺ " : "  "
            guard !line.isEmpty else { out.append(""); continue }
            let hang = String(repeating: " ", count: 2 + (LineOps.listMarker(line)?.current.count ?? 0))
            var current = margin
            var started = false
            for word in line.split(separator: " ") {
                if started && current.count + 1 + word.count > width {
                    out.append(current)
                    current = hang + word
                } else {
                    current += (started ? " " : "") + word
                }
                started = true
            }
            out.append(current)
        }
        return out.joined(separator: "\n")
    }

    let paragraph = "What it's worth: if 2027 sells the same quantities as 2025, these prices bring in about $3,000 more in food takings ($11,470 against $8,495). No extra people or stock are needed."

    func testRejoinsAWrappedParagraph() {
        XCTAssertEqual(TextActions.unwrap(claudeWrap(paragraph, width: 40)), paragraph)
    }
    func testSelectionThatCutTheFirstLineMargin() {
        let wrapped = String(claudeWrap(paragraph, width: 40).dropFirst(2))
        XCTAssertEqual(TextActions.unwrap(wrapped), paragraph)
    }
    func testCopiedFromClaudeCode() {
        let copied = """
            What it's worth: if 2027 sells the same quantities as 2025, these prices bring in about $3,000 more in food takings ($11,470
              against $8,495). No extra people or stock are needed. Even if sales drop 10% because of the higher prices, the stall still comes out
              ahead.
            """
        XCTAssertEqual(TextActions.unwrap(copied), "What it's worth: if 2027 sells the same quantities as 2025, these prices bring in about $3,000 more in food takings ($11,470 against $8,495). No extra people or stock are needed. Even if sales drop 10% because of the higher prices, the stall still comes out ahead.")
    }
    func testParagraphsStaySeparate() {
        let source = paragraph + "\n\n" + paragraph
        XCTAssertEqual(TextActions.unwrap(claudeWrap(source, width: 50)), source)
    }
    func testListItemsStaySeparateAndRejoinTheirOwnWraps() {
        let source = "Options:\n- " + paragraph + "\n- short\n1. " + paragraph + "\n2. also short"
        XCTAssertEqual(TextActions.unwrap(claudeWrap(source, width: 45)), source)
    }
    func testShortLinesAreNotJoined() {
        XCTAssertEqual(TextActions.unwrap("  let a = 1\n  let b = 2\n  print(a + b)"), "let a = 1\nlet b = 2\nprint(a + b)")
    }
    func testFencedCodeIsLeftAlone() {
        let long = Array(repeating: "word", count: 8).joined(separator: " ")
        let input = "```\n" + long + "\nend\n```"
        XCTAssertEqual(TextActions.unwrap(input), input)
    }
    func testBoxDrawnTableRowsAreNotJoined() {
        let input = "┌─────┬─────┐\n│ a   │ b   │\n└─────┴─────┘"
        XCTAssertEqual(TextActions.unwrap(input), input)
    }
    func testTrailingNewlineKeptAndTrailingSpacesDropped() {
        let wrapped = claudeWrap(paragraph, width: 40).replacingOccurrences(of: "\n", with: "  \n") + "\n"
        XCTAssertEqual(TextActions.unwrap(wrapped), paragraph + "\n")
    }
}
