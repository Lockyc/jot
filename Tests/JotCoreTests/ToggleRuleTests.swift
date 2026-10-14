import XCTest
@testable import JotCore

final class ToggleRuleTests: XCTestCase {
    func testVisibleAndActiveHides() {
        XCTAssertEqual(ToggleRule.action(panelVisible: true, appActive: true), .hide)
    }
    func testVisibleButInactiveShows() {
        XCTAssertEqual(ToggleRule.action(panelVisible: true, appActive: false), .show)
    }
    func testHiddenShows() {
        XCTAssertEqual(ToggleRule.action(panelVisible: false, appActive: true), .show)
        XCTAssertEqual(ToggleRule.action(panelVisible: false, appActive: false), .show)
    }
}
