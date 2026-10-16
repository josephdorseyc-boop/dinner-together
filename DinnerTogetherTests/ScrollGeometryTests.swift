import XCTest
@testable import DinnerTogether

/// Unit tests for ScrollGeometry's small-window mode (A1, #15).
/// Pure geometry — runs on Linux, no simulator needed.
final class ScrollGeometryTests: XCTestCase {
    func testIsTopInZone() {
        let zoneTop: CGFloat = 60, zoneBottom: CGFloat = 405.7
        XCTAssertTrue(ScrollGeometry.isTopInZone(
            frame: CGRect(x: 23.5, y: 280.3, width: 335, height: 285),
            zoneTop: zoneTop, zoneBottom: zoneBottom))
        XCTAssertFalse(ScrollGeometry.isTopInZone(
            frame: CGRect(x: 23.5, y: 20, width: 335, height: 285),
            zoneTop: zoneTop, zoneBottom: zoneBottom))
        XCTAssertFalse(ScrollGeometry.isTopInZone(
            frame: CGRect(x: 23.5, y: 370, width: 335, height: 285),
            zoneTop: zoneTop, zoneBottom: zoneBottom))
        XCTAssertTrue(ScrollGeometry.isTopInZone(
            frame: CGRect(x: 23.5, y: 361.7, width: 335, height: 285),
            zoneTop: zoneTop, zoneBottom: zoneBottom))
    }

    func testIsSmallWindowTrigger() {
        XCTAssertTrue(ScrollGeometry.isSmallWindow(width: 466, height: 678))
        XCTAssertTrue(ScrollGeometry.isSmallWindow(width: 678, height: 466))
        XCTAssertFalse(ScrollGeometry.isSmallWindow(width: 393, height: 852))
        XCTAssertFalse(ScrollGeometry.isSmallWindow(width: 375, height: 667))
        XCTAssertFalse(ScrollGeometry.isSmallWindow(width: 820, height: 1180))
        XCTAssertFalse(ScrollGeometry.isSmallWindow(width: 951, height: 669))
        // The CI iPhone 17 Pro and a Pro Max: tall, not small windows (A3).
        XCTAssertFalse(ScrollGeometry.isSmallWindow(width: 402, height: 874))
        XCTAssertFalse(ScrollGeometry.isSmallWindow(width: 440, height: 956))
        XCTAssertFalse(ScrollGeometry.isSmallWindow(width: 874, height: 402), "an iPhone on its side")
        XCTAssertFalse(ScrollGeometry.isSmallWindow(width: 0, height: 0), "no window yet")
    }
}
