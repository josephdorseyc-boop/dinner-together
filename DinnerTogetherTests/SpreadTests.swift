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
        XCTAssertFalse(spread(466, 678), "the Duo held upright (its first run): one page")
        XCTAssertTrue(spread(678, 466), "the Duo held like a book: the spread")
        XCTAssertFalse(spread(956, 440), "a 17 Pro Max on its side is too short for a page")
        XCTAssertFalse(spread(599, 844), "a column narrower than an SE each: one page")
        XCTAssertFalse(spread(1024, 768, phone: false), "iPad keeps its own layout (Joe: the Duo first)")
        XCTAssertFalse(spread(1366, 1024, phone: false))
        XCTAssertFalse(spread(780, 844, ax: true), "at accessibility sizes the main recipe takes the whole width")
    }

    func testDuoUprightIsOneCookbookPage() {
        func mode(_ w: Double, _ h: Double, phone: Bool = true, ax: Bool = false) -> SpreadLayout.Mode {
            SpreadLayout.mode(width: w, height: h, phoneIdiom: phone, accessibilitySize: ax)
        }
        XCTAssertEqual(mode(466, 678), .book, "the Duo upright (its first screenshots): one cookbook page with Main / Side")
        XCTAssertEqual(mode(678, 466), .spread, "the Duo turned like a book: two pages")
        XCTAssertEqual(mode(466, 678, ax: true), .book, "large text keeps the one page and its switch")
        XCTAssertEqual(mode(402, 874), .single, "an iPhone: the page as always")
        XCTAssertEqual(mode(440, 956), .single)
        XCTAssertEqual(mode(1024, 1366, phone: false), .single, "iPad keeps its layout")
    }

    func testLeftPageSettlesToTheCoverWhenItsRecipeIsGone() {
        let side = UUID(), other = UUID()
        XCTAssertEqual(SpreadLeftPage.recipe(side).settled { $0 == side }, .recipe(side), "a recipe still there stays")
        XCTAssertEqual(SpreadLeftPage.recipe(side).settled { $0 == other }, .cover, "a deleted second recipe gives way to the cover")
        XCTAssertEqual(SpreadLeftPage.cover.settled { _ in false }, .cover)
        XCTAssertEqual(SpreadLeftPage.recipe(side).secondRecipeID, side)
        XCTAssertNil(SpreadLeftPage.cover.secondRecipeID)
    }

    // MARK: Search (A2's build 20 shortlist)

    func testSearchMatchesTitleOrIngredientWhateverTheCase() {
        var r = Recipe(title: "Crème brûlée")
        r.ingredients = ["4 egg yolks", "1 vanilla bean"]
        XCTAssertTrue(r.matches(""), "a blank query matches everything")
        XCTAssertTrue(r.matches("   "))
        XCTAssertTrue(r.matches("creme"), "accents and case do not matter")
        XCTAssertTrue(r.matches("BRÛL"), "a few letters of the title")
        XCTAssertTrue(r.matches("vanilla"), "an ingredient")
        XCTAssertTrue(r.matches("Yolk"), "part of an ingredient")
        XCTAssertFalse(r.matches("chicken"))
        XCTAssertFalse(r.matches("crème chicken"), "the words are one phrase, not any-of")
    }

    // MARK: Paired dinners (Joe, October 14: two recipes on the Duo)

    func testPairedMenuIDRoundTrips() {
        let a = UUID(), b = UUID()
        let id = PairedDinner.menuID(main: a, side: b)
        XCTAssertEqual(PairedDinner.parse(id)?.main, a)
        XCTAssertEqual(PairedDinner.parse(id)?.side, b)
        XCTAssertNil(PairedDinner.parse("recipe:" + a.uuidString), "a single recipe is not a pair")
        XCTAssertNil(PairedDinner.parse(PairedDinner.prefix + a.uuidString), "half a pair is nothing")
        XCTAssertNil(PairedDinner.parse(PairedDinner.menuID(main: a, side: a)), "a recipe is not its own side")
        XCTAssertNil(PairedDinner.parse(""))
    }

    @MainActor
    func testPairedDinnerCooksBothRecipesReadyTogether() async throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("dt-pair-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let library = RecipeLibrary(directory: dir)
        func add(_ text: String) throws -> Recipe {
            let r = RecipeImporter.build(try RecipeImporter.parse(text: text), method: .text)
            XCTAssertTrue(library.add(r)); return r
        }
        let main = try add("Lemon herb chicken\nDirections\n1. Marinate the chicken for 20 minutes.\n2. Roast for 35 minutes.")
        let side = try add("Rosemary potatoes\nDirections\n1. Roast the potatoes for 40 minutes.")
        let id = PairedDinner.menuID(main: main.id, side: side.id)

        let menu = try XCTUnwrap(library.menu(id: id))
        XCTAssertEqual(menu.title, "Lemon herb chicken + Rosemary potatoes")
        XCTAssertEqual(Set(menu.steps.map(\.id)), Set(main.steps.map(\.id) + side.steps.map(\.id)), "every step of both recipes, once")
        XCTAssertEqual(library.recipe(menuID: id)?.id, main.id, "Tonight's cover and title follow the main recipe")

        let store = SessionStore(fileURL: dir.appendingPathComponent("session.json"), menuProvider: library)
        store.chooseMenu(id)
        XCTAssertTrue(store.hasDinner)
        XCTAssertFalse(store.menuIsMissing)
        let plan = store.plan
        XCTAssertEqual(plan.count, main.steps.count + side.steps.count)
        let serve = store.session.serveAt
        for recipe in [main, side] {
            let ids = Set(recipe.steps.map(\.id))
            let last = try XCTUnwrap(plan.filter { ids.contains($0.id) }.map(\.end).max())
            XCTAssertEqual(last.timeIntervalSince(serve), 0, accuracy: 1, "“\(recipe.title)” is ready at dinner time")
        }

        XCTAssertTrue(library.remove(id: side.id))
        XCTAssertNil(library.menu(id: id), "a deleted half is a missing dinner, never half a plan")
        XCTAssertTrue(store.menuIsMissing)
    }
}
