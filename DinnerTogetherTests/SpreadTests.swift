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
        XCTAssertTrue(spread(820, 844), "two phone-wide panels side by side: the spread")
        XCTAssertTrue(spread(800, 560), "the smallest open window that fits two readable pages")
        XCTAssertFalse(spread(799, 560), "just short of two comfortable pages: one page")
        XCTAssertFalse(spread(466, 678), "the Duo's cover display, folded: one page")
        XCTAssertFalse(spread(678, 466), "the cover display sideways: still one page (Joe, October 15)")
        XCTAssertTrue(spread(951, 669), "the Duo opened (inner display, as reported): the spread")
        XCTAssertFalse(spread(669, 951), "the Duo opened and held upright: one page")
        XCTAssertFalse(spread(956, 440), "a 17 Pro Max on its side is too short for a page")
        XCTAssertFalse(spread(599, 844), "a column narrower than an SE each: one page")
        XCTAssertFalse(spread(1024, 768, phone: false), "iPad keeps its own layout (Joe: the Duo first)")
        XCTAssertFalse(spread(1366, 1024, phone: false))
        XCTAssertFalse(spread(820, 844, ax: true), "at accessibility sizes the main recipe takes the whole width")
    }

    func testDuoUprightIsOneCookbookPage() {
        func mode(_ w: Double, _ h: Double, phone: Bool = true, ax: Bool = false) -> SpreadLayout.Mode {
            SpreadLayout.mode(width: w, height: h, phoneIdiom: phone, accessibilitySize: ax)
        }
        XCTAssertEqual(mode(466, 678), .single, "the folded Duo's cover mirrors the iPhone: the photo-first page (Joe, 12:12 PM)")
        XCTAssertEqual(mode(678, 466), .single, "the cover sideways: still the iPhone page, never a split")
        XCTAssertEqual(mode(951, 669), .spread, "the Duo opened: two pages")
        XCTAssertEqual(mode(669, 951), .book, "the Duo opened, held upright: one page with Main / Side (mockup 04)")
        XCTAssertEqual(mode(951, 669, ax: true), .book, "large text on the opened Duo: one page")
        XCTAssertEqual(mode(669, 951, ax: true), .book, "large text on the opened Duo upright keeps the one page and its switch")
        XCTAssertEqual(mode(466, 678, ax: true), .single, "large text on the cover: the iPhone page")
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

    // MARK: Whole meals (Joe, October 14–15: one to four recipes, ready
    // together, on every device — build 21)

    func testWholeMealIDsRoundTripAndKeepBuild20Pairs() throws {
        let a = UUID(), b = UUID(), c = UUID(), d = UUID(), e = UUID()
        XCTAssertEqual(WholeMeal.menuID([a]), "recipe:" + a.uuidString, "one recipe is the recipe's own id")
        XCTAssertEqual(WholeMeal.menuID([a, b]), PairedDinner.menuID(main: a, side: b), "two stay a build 20 pair")
        let three = try XCTUnwrap(WholeMeal.menuID([a, b, c]))
        XCTAssertTrue(three.hasPrefix(WholeMeal.prefix))
        XCTAssertEqual(WholeMeal.recipeIDs(three), [a, b, c], "main first, the rest in order")
        XCTAssertEqual(WholeMeal.recipeIDs(WholeMeal.menuID([a, b, c, d])!), [a, b, c, d])
        XCTAssertEqual(WholeMeal.recipeIDs(PairedDinner.menuID(main: a, side: b)), [a, b], "a saved pair reads as a two-dish meal")
        XCTAssertEqual(WholeMeal.recipeIDs("recipe:" + a.uuidString), [a])
        XCTAssertNil(WholeMeal.menuID([a, b, c, d, e]), "four recipes at most")
        XCTAssertNil(WholeMeal.menuID([a, b, a]), "a recipe once")
        XCTAssertNil(WholeMeal.menuID([]))
        XCTAssertNil(WholeMeal.recipeIDs(WholeMeal.prefix + a.uuidString), "a meal of one is a recipe id, not a meal")
        XCTAssertNil(WholeMeal.recipeIDs(WholeMeal.prefix + [a, b, a].map(\.uuidString).joined(separator: "+")))
        XCTAssertNil(WholeMeal.recipeIDs(WholeMeal.prefix + [a, b, c, d, e].map(\.uuidString).joined(separator: "+")))
        XCTAssertNil(WholeMeal.recipeIDs(WholeMeal.prefix + a.uuidString + "+not-a-uuid"))
        XCTAssertNil(WholeMeal.recipeIDs("thanksgiving"), "a catalog dinner is not a whole meal")
        XCTAssertFalse(WholeMeal.isWholeMeal("recipe:" + a.uuidString))
        XCTAssertTrue(WholeMeal.isWholeMeal(three))
    }

    func testAddingAndRemovingDishesKeepsTheMainFirst() throws {
        let a = UUID(), b = UUID(), c = UUID(), d = UUID(), e = UUID()
        let one = "recipe:" + a.uuidString
        let two = try XCTUnwrap(WholeMeal.adding(b, to: one))
        XCTAssertEqual(WholeMeal.recipeIDs(two), [a, b])
        let four = try XCTUnwrap(WholeMeal.adding(d, to: WholeMeal.adding(c, to: two)!))
        XCTAssertEqual(WholeMeal.recipeIDs(four), [a, b, c, d])
        XCTAssertNil(WholeMeal.adding(e, to: four), "a fifth dish doesn't fit")
        XCTAssertNil(WholeMeal.adding(b, to: four), "a dish already there")
        XCTAssertEqual(WholeMeal.recipeIDs(WholeMeal.removing(c, from: four)!), [a, b, d])
        XCTAssertEqual(WholeMeal.removing(b, from: two), one, "back to the main alone")
        XCTAssertNil(WholeMeal.removing(a, from: two), "the main isn't removed this way")
        XCTAssertNil(WholeMeal.removing(e, from: two))
        XCTAssertNil(WholeMeal.removing(a, from: one))
    }

    @MainActor
    func testFourRecipeDinnerIsReadyTogether() async throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("dt-meal-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let library = RecipeLibrary(directory: dir)
        func add(_ text: String) throws -> Recipe {
            let r = RecipeImporter.build(try RecipeImporter.parse(text: text), method: .text)
            XCTAssertTrue(library.add(r)); return r
        }
        // ("Roast chicken" alone reads as a direction to the text importer,
        // which is its own question; the dinner is what's under test.)
        let chicken = try add("Sunday herb chicken\nDirections\n1. Season the chicken.\n2. Roast for 60 minutes.\n3. Rest for 10 minutes.")
        let potatoes = try add("Mashed potatoes\nDirections\n1. Boil the potatoes for 20 minutes.\n2. Mash with butter.")
        let beans = try add("Green beans\nDirections\n1. Steam the beans for 6 minutes.")
        let gravy = try add("Pan gravy\nDirections\n1. Simmer the drippings for 8 minutes.")
        let recipes = [chicken, potatoes, beans, gravy]
        let id = try XCTUnwrap(WholeMeal.menuID(recipes.map(\.id)))

        let menu = try XCTUnwrap(library.menu(id: id))
        XCTAssertEqual(menu.title, "Sunday herb chicken + Mashed potatoes + Green beans + Pan gravy")
        XCTAssertTrue(menu.subtitle.hasPrefix("Four recipes, ready together"), menu.subtitle)
        XCTAssertEqual(Set(menu.steps.map(\.id)), Set(recipes.flatMap { $0.steps.map(\.id) }), "every step of every recipe, once")
        XCTAssertEqual(library.recipe(menuID: id)?.id, chicken.id, "Tonight follows the main")

        let store = SessionStore(fileURL: dir.appendingPathComponent("session.json"), menuProvider: library)
        store.chooseMenu(id)
        XCTAssertTrue(store.hasDinner)
        XCTAssertFalse(store.menuIsMissing)
        let serve = store.session.serveAt
        for recipe in recipes {
            let ids = Set(recipe.steps.map(\.id))
            let last = try XCTUnwrap(store.plan.filter { ids.contains($0.id) }.map(\.end).max())
            XCTAssertEqual(last.timeIntervalSince(serve), 0, accuracy: 1, "“\(recipe.title)” is ready at dinner time")
        }

        XCTAssertTrue(library.remove(id: beans.id))
        XCTAssertNil(library.menu(id: id), "a deleted dish is a missing dinner, never part of a plan")
        XCTAssertTrue(store.menuIsMissing)
    }

    @MainActor
    func testChangingDishesKeepsTheDinnerTimeAndADeletedSideLeavesTheRest() async throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("dt-dishes-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let library = RecipeLibrary(directory: dir)
        func add(_ text: String) throws -> Recipe {
            let r = RecipeImporter.build(try RecipeImporter.parse(text: text), method: .text)
            XCTAssertTrue(library.add(r)); return r
        }
        let chicken = try add("Sunday herb chicken\nDirections\n1. Roast for 60 minutes.")
        let potatoes = try add("Mashed potatoes\nDirections\n1. Boil the potatoes for 20 minutes.")
        let beans = try add("Green beans\nDirections\n1. Steam the beans for 6 minutes.")
        let store = SessionStore(fileURL: dir.appendingPathComponent("session.json"), menuProvider: library)
        let now = Date()
        store.chooseMenu(chicken.menuID, now: now)
        let dinnerTime = now.addingTimeInterval(3 * 3600)
        store.setServeAt(dinnerTime)
        XCTAssertTrue(store.isTonightsDish(chicken.id))
        XCTAssertFalse(store.isTonightsDish(potatoes.id))

        // Adding a dish keeps the time the cook set.
        store.changeDishes(to: WholeMeal.adding(potatoes.id, to: store.session.menuID)!, now: now)
        XCTAssertEqual(WholeMeal.recipeIDs(store.session.menuID), [chicken.id, potatoes.id])
        XCTAssertEqual(store.session.serveAt, dinnerTime, "the dinner time stays")
        XCTAssertTrue(store.isTonightsDish(potatoes.id))
        store.changeDishes(to: WholeMeal.adding(beans.id, to: store.session.menuID)!, now: now)
        XCTAssertEqual(WholeMeal.recipeIDs(store.session.menuID)?.count, 3)

        // A dish that can't make the time moves dinner to the earliest it can.
        let soon = now.addingTimeInterval(10 * 60)
        store.setServeAt(soon)
        let roast = try add("Slow roast\nDirections\n1. Roast for 4 hours.")
        store.changeDishes(to: WholeMeal.adding(roast.id, to: store.session.menuID)!, now: now)
        XCTAssertGreaterThan(store.session.serveAt, soon, "dinner moved later for the four-hour roast")
        XCTAssertFalse(store.menuIsMissing)

        // Deleting a side leaves the rest; deleting the main clears dinner.
        XCTAssertTrue(library.remove(id: beans.id))
        store.dishDeleted(beans.id)
        XCTAssertEqual(WholeMeal.recipeIDs(store.session.menuID), [chicken.id, potatoes.id, roast.id])
        XCTAssertFalse(store.menuIsMissing)
        XCTAssertTrue(library.remove(id: chicken.id))
        store.dishDeleted(chicken.id)
        XCTAssertFalse(store.hasDinner, "the main gone is no dinner")
    }
}
