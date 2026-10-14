import XCTest
@testable import JotCore

final class PanelPlacementTests: XCTestCase {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 875)
    let size = CGSize(width: 640, height: 480)

    func testCentresOnCursor() {
        let frame = PanelPlacement.frame(size: size, centredOn: CGPoint(x: 700, y: 400), within: screen)
        XCTAssertEqual(frame, CGRect(x: 380, y: 160, width: 640, height: 480))
    }
    func testClampsToBottomLeftCorner() {
        let frame = PanelPlacement.frame(size: size, centredOn: CGPoint(x: 5, y: 5), within: screen)
        XCTAssertEqual(frame.origin, CGPoint(x: 0, y: 0))
    }
    func testClampsToTopRightCorner() {
        let frame = PanelPlacement.frame(size: size, centredOn: CGPoint(x: 1435, y: 870), within: screen)
        XCTAssertEqual(frame.origin, CGPoint(x: 800, y: 395))
    }
    func testRespectsOffsetScreen() {
        let right = CGRect(x: 1440, y: 100, width: 1920, height: 1080)
        let frame = PanelPlacement.frame(size: size, centredOn: CGPoint(x: 1445, y: 105), within: right)
        XCTAssertEqual(frame.origin, CGPoint(x: 1440, y: 100))
    }
    func testShrinksToFitSmallScreen() {
        let small = CGRect(x: 0, y: 0, width: 500, height: 400)
        let frame = PanelPlacement.frame(size: size, centredOn: CGPoint(x: 250, y: 200), within: small)
        XCTAssertEqual(frame, small)
    }
}
