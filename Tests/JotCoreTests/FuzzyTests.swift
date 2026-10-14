import XCTest
@testable import JotCore

final class FuzzyTests: XCTestCase {
    func testSubsequenceMatches() {
        XCTAssertNotNil(Fuzzy.score("sqg", "Strip Quote Gutter"))
    }
    func testNonMatchIsNil() {
        XCTAssertNil(Fuzzy.score("xyz", "Strip Quote Gutter"))
    }
    func testEmptyQueryMatchesEverything() {
        XCTAssertEqual(Fuzzy.score("", "anything"), 0)
    }
    func testContiguousBeatsScattered() {
        XCTAssertGreaterThan(Fuzzy.score("sort", "Sort Lines")!, Fuzzy.score("sort", "Strip Quote Gutter Rt") ?? -1)
    }
    func testRankOrdersByScoreThenOriginalOrder() {
        let items = ["Remove Blank Lines", "Sort Lines A→Z", "Sort Lines Z→A"]
        XCTAssertEqual(Fuzzy.rank(items, query: "sort", key: { $0 }), ["Sort Lines A→Z", "Sort Lines Z→A"])
    }
}
