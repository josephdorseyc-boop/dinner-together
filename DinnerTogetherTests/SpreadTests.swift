import XCTest
@testable import DinnerTogether

/// The cookbook spread's decisions (Joe and A2, October 14): when the
/// recipe page is two pages, and what the left page settles to.
final class SpreadTests: XCTestCase {
    private func spread(_ w: Double, _ h: Double, phone: Bool = true, ax: Bool = false) -> Bool {
        SpreadLayout.showsSpread(width: w, height: h, phoneIdiom: phone, accessibilitySize: ax)
    }

    func testOnlyAWideTallPhoneWindowIsASpread() {
        XCTAssertFalse(spread(390, 844), "an iPhone upright: one page")
        XCTAssertFalse(spread(932, 430), "a Pro Max on its side is wide but not tall: one page")
        XCTAssertFalse(spread(430, 932), "a Pro Max upright: one page")
        XCTAssertTrue(spread(780, 844), "two phone-wide panels side by side: the spread")
        XCTAssertTrue(spread(600, 560), "the smallest open window that fits two readable pages")
        XCTAssertFalse(spread(599, 844), "a column narrower than an SE each: one page")
        XCTAssertFalse(spread(1024, 768, phone: false), "iPad keeps its own layout (Joe: the Duo first)")
        XCTAssertFalse(spread(1366, 1024, phone: false))
        XCTAssertFalse(spread(780, 844, ax: true), "at accessibility sizes the main recipe takes the whole width")
    }

    func testLeftPageSettlesToTheCoverWhenItsRecipeIsGone() {
        let side = UUID(), other = UUID()
        XCTAssertEqual(SpreadLeftPage.recipe(side).settled { $0 == side }, .recipe(side), "a recipe still there stays")
        XCTAssertEqual(SpreadLeftPage.recipe(side).settled { $0 == other }, .cover, "a deleted second recipe gives way to the cover")
        XCTAssertEqual(SpreadLeftPage.cover.settled { _ in false }, .cover)
        XCTAssertEqual(SpreadLeftPage.recipe(side).secondRecipeID, side)
        XCTAssertNil(SpreadLeftPage.cover.secondRecipeID)
    }
}
