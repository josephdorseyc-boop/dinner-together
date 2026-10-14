import XCTest
@testable import DinnerTogether

// Screenshot import. The pages below transcribe Joe's five Apple News+ Food
// screenshots of "You Need to Try This Whipped Frozen Apple Cider"
// (October 11, 2026) the way on-device text recognition reports them: one
// line of text with its position as a fraction of the screen. The quirks are
// the real ones — the timer chip reads as "©", a step is cut across two
// screenshots, the floating buttons garble a line, tabs repeat on every page.

private let t0 = Date(timeIntervalSince1970: 1_760_000_000)

private func L(_ text: String, _ top: Double, _ left: Double = 0.06, h: Double = 0.016) -> OCRLine {
    OCRLine(text: text, top: top, left: left, height: h)
}

/// Status bar, navigation title and tab bar, as on every scrolled page.
private func chrome() -> [OCRLine] {
    [L("6:09", 0.020, 0.10, h: 0.015), L("77", 0.022, 0.87, h: 0.012),
     L("You Need to Try This Whipped", 0.058, 0.20, h: 0.020), L("Frozen Apple Cider", 0.085, 0.31, h: 0.020),
     L("Ingredients", 0.138, 0.07), L("Directions", 0.138, 0.35), L("Nutrition", 0.138, 0.60), L("More", 0.138, 0.83)]
}

/// Screenshot 1: STEP 3 in full, then the serving paragraph below its photo.
private let pageStep3 = chrome() + [
    L("STEP 3", 0.222, h: 0.015),
    L("Place the frozen cider cubes and ½ cup", 0.255, h: 0.018),
    L("coconut milk in a blender. Process until", 0.284, h: 0.018),
    L("slushy, about © 30 seconds . Add up to", 0.313, h: 0.018),
    L("3 tablespoons cider, 1 tablespoon at a time,", 0.342, h: 0.018),
    L("to reach the desired consistency.", 0.370, h: 0.018),
    L("Divide between 2 (8-ounce) chilled glasses", 0.812, h: 0.018),
    L("and serve immediately, garnished with 1", 0.841, h: 0.018),
    L("cinnamon stick, if desired.", 0.869, h: 0.018),
    L("Start Cooking", 0.956, 0.40, h: 0.018),
]

/// Screenshot 2: the end of STEP 1 at the top, STEP 2, and STEP 3 cut off by
/// the floating buttons.
private let pageStep2 = chrome() + [
    L("cool, about © 1 hour . Strain and discard", 0.170, h: 0.018),
    L("spices.", 0.198, h: 0.018),
    L("STEP 2", 0.250, h: 0.015),
    L("Pour the cider mixture evenly into 12 ice", 0.284, h: 0.018),
    L("cube tray wells (about 2 tablespoons each).", 0.313, h: 0.018),
    L("Freeze until solid, about © 3 hours .", 0.341, h: 0.018),
    L("STEP 3", 0.784, h: 0.015),
    L("Place the frozen cider cubes and ½ cup", 0.817, h: 0.018),
    L("coconut milk in a blender. Process until", 0.846, h: 0.018),
    L("slushy, about © 30 seconds . Add up to", 0.874, h: 0.018),
    L("3 t lespoons cider, 1 tablespoon at a ti", 0.903, h: 0.018),
    L("h the desired consistency.", 0.931, 0.25, h: 0.018),
]

/// Screenshot 3: the end of the ingredients card and the start of Directions.
private let pageStep1 = chrome() + [
    L("Add to Grocery List", 0.195, 0.25, h: 0.018), L("in Reminders", 0.222, 0.25, h: 0.018),
    L("Recipe units are from the publisher.", 0.287, 0.10),
    L("Customize Units", 0.310, 0.10),
    L("Directions", 0.405, h: 0.022),
    L("Total Time: 4 hr 10 min", 0.433, h: 0.015),
    L("STEP 1", 0.466, h: 0.015),
    L("Combine 1½ cups cider, 1½ tablespoons", 0.500, h: 0.018),
    L("maple syrup, 1 cinnamon stick, 1 tablespoon", 0.529, h: 0.018),
    L("sliced ginger, ½ teaspoon each cloves and", 0.557, h: 0.018),
    L("peppercorns and ½ teaspoon allspice", 0.586, h: 0.018),
    L("berries (if using) in a small saucepan; bring", 0.614, h: 0.018),
    L("to a boil over medium heat.", 0.643, h: 0.018),
]

/// Screenshot 4: the ingredient cards. Wrapped lines sit close together;
/// cards are separated by a gap. The last card is half hidden.
private let pageIngredients = chrome() + [
    L("Ingredients", 0.213, h: 0.022), L("Scale", 0.215, 0.81),
    L("Yield: 2", 0.240, h: 0.015),
    L("1½ cups unsweetened apple cider,", 0.302), L("plus 3 more tablespoons as needed", 0.328),
    L("1½ tablespoons pure maple syrup", 0.402),
    L("1 (3-inch) cinnamon stick, plus more", 0.476), L("for garnish", 0.502),
    L("1 tablespoon thinly sliced unpeeled", 0.576), L("fresh ginger", 0.602),
    L("½ teaspoon whole cloves", 0.676),
    L("½ teaspoon whole black peppercorns", 0.750),
    L("½ teaspoon allspice berries (optional)", 0.824),
    L("½ cup unsweetened canned coconut", 0.898), L("well shaken and stirred", 0.924, 0.20),
    L("Add to Grocery I ist", 0.980, 0.25),
]

/// Screenshot 5: the title page.
private let pageTitle: [OCRLine] = [
    L("6:09", 0.020, 0.10, h: 0.015), L("77", 0.022, 0.87, h: 0.012),
    L("You Need to Try This", 0.345, h: 0.033), L("Whipped Frozen", 0.390, h: 0.033), L("Apple Cider", 0.435, h: 0.033),
    L("EatingWell • Julia Levy", 0.480),
    L("Total Time", 0.531, 0.06), L("Yield", 0.531, 0.43),
    L("4 hr 10 min", 0.556, 0.06, h: 0.020), L("2", 0.556, 0.43, h: 0.020),
    L("Cook", 0.652, 0.16), L("Save", 0.652, 0.46), L("Share", 0.652, 0.76),
    L("Read the Story", 0.708, 0.21), L("Whipped Frozen Apple Cider", 0.730, 0.21),
    L("Who says slushies are only for summer?", 0.790),
    L("Ingredients", 0.885, h: 0.022), L("Scale", 0.890, 0.81),
    L("1½ cups unsweetened apple cider,", 0.978),
]

private let expectedIngredients = [
    "1½ cups unsweetened apple cider, plus 3 more tablespoons as needed",
    "1½ tablespoons pure maple syrup",
    "1 (3-inch) cinnamon stick, plus more for garnish",
    "1 tablespoon thinly sliced unpeeled fresh ginger",
    "½ teaspoon whole cloves",
    "½ teaspoon whole black peppercorns",
    "½ teaspoon allspice berries (optional)",
    "½ cup unsweetened canned coconut well shaken and stirred",
]

final class RecipeScreenshotTests: XCTestCase {

    func testJoesFiveAppleNewsScreenshots() throws {
        let r = try RecipeImporter.parse(screenshots: [pageStep3, pageStep2, pageStep1, pageIngredients, pageTitle])
        XCTAssertEqual(r.title, "You Need to Try This Whipped Frozen Apple Cider")
        XCTAssertEqual(r.source.publisher, "EatingWell")
        XCTAssertEqual(r.source.author, "Julia Levy")
        XCTAssertEqual(r.totalMinutes, 250)
        XCTAssertEqual(r.yield, "2")
        XCTAssertEqual(r.ingredients, expectedIngredients)
        XCTAssertEqual(r.directions.count, 3)
        XCTAssertTrue(r.directions[0].hasPrefix("Combine 1½ cups cider"), r.directions[0])
        XCTAssertTrue(r.directions[0].hasSuffix("cool, about 1 hour. Strain and discard spices."),
                      "the end of step 1 came from another screenshot: \(r.directions[0])")
        XCTAssertEqual(r.directions[1], "Pour the cider mixture evenly into 12 ice cube tray wells (about 2 tablespoons each). Freeze until solid, about 3 hours.")
        XCTAssertEqual(r.directions[2], "Place the frozen cider cubes and ½ cup coconut milk in a blender. Process until slushy, about 30 seconds. Add up to 3 tablespoons cider, 1 tablespoon at a time, to reach the desired consistency. Divide between 2 (8-ounce) chilled glasses and serve immediately, garnished with 1 cinnamon stick, if desired.",
                       "the complete copy of step 3 wins over the garbled one")
        XCTAssertFalse(r.directions.joined().contains("©"))
    }

    func testOrderOfScreenshotsDoesNotMatter() throws {
        let a = try RecipeImporter.parse(screenshots: [pageStep3, pageStep2, pageStep1, pageIngredients, pageTitle])
        let b = try RecipeImporter.parse(screenshots: [pageTitle, pageIngredients, pageStep1, pageStep2, pageStep3])
        XCTAssertEqual(a.title, b.title)
        XCTAssertEqual(a.ingredients, b.ingredients)
        XCTAssertEqual(a.directions, b.directions)
        XCTAssertEqual(a.totalMinutes, b.totalMinutes)
    }

    func testScreenshotRecipePlansLikeTheLinkVersion() throws {
        let imported = try RecipeImporter.parse(screenshots: [pageTitle, pageIngredients, pageStep1, pageStep2, pageStep3])
        let recipe = RecipeImporter.build(imported, method: .photo, now: t0)
        XCTAssertEqual(recipe.importMethod, .photo)
        XCTAssertEqual(recipe.steps.map { $0.minutes }, [60, 180, 1])
        XCTAssertEqual(recipe.steps.map { $0.handsOn }, [false, false, true], "cooling and freezing are waiting; blending is not")
        XCTAssertEqual(recipe.estimatedStepCount, 0)
        XCTAssertTrue(recipe.needsTimingReview, "review is still required before cooking")
    }

    func testOnlySomeScreenshots() throws {
        // Just the ingredients screenshot: the title comes from the
        // navigation bar above the tabs.
        let r = try RecipeImporter.parse(screenshots: [pageIngredients])
        XCTAssertEqual(r.title, "You Need to Try This Whipped Frozen Apple Cider")
        XCTAssertEqual(r.ingredients, expectedIngredients)
        XCTAssertEqual(r.yield, "2")
        XCTAssertTrue(r.directions.isEmpty)
    }

    func testTitleFromTallestTextWhenNoRepeatedHeader() throws {
        let r = try RecipeImporter.parse(screenshots: [pageTitle, pageStep1.filter { $0.top > 0.16 }])
        XCTAssertEqual(r.title, "You Need to Try This Whipped Frozen Apple Cider")
        XCTAssertEqual(r.directions.count, 1)
    }

    func testCookbookPhotoWithoutLabels() throws {
        // A photographed card: no tabs, no STEP labels. Paragraph gaps split
        // the method; quantities mark ingredients.
        let page: [OCRLine] = [
            L("Weeknight Lentil Soup", 0.08, h: 0.035),
            L("2 tbsp olive oil", 0.16), L("1 onion, chopped", 0.185), L("1 cup red lentils", 0.21),
            L("Heat the oil and soften the onion,", 0.30), L("about 8 minutes.", 0.325),
            L("Add the lentils and 4 cups water and", 0.39), L("simmer for 25 minutes.", 0.415),
        ]
        let r = try RecipeImporter.parse(screenshots: [page])
        XCTAssertEqual(r.title, "Weeknight Lentil Soup")
        XCTAssertEqual(r.ingredients, ["2 tbsp olive oil", "1 onion, chopped", "1 cup red lentils"])
        XCTAssertEqual(r.directions, ["Heat the oil and soften the onion, about 8 minutes.",
                                      "Add the lentils and 4 cups water and simmer for 25 minutes."])
    }

    func testNoTextThrows() {
        XCTAssertThrowsError(try RecipeImporter.parse(screenshots: [[], [L("6:09", 0.02)]])) { error in
            XCTAssertEqual(error as? RecipeImportError, .noTextInScreenshots)
        }
    }

    func testCleanOCRAndOverlapMerge() {
        XCTAssertEqual(RecipeImporter.cleanOCR(L("slushy, about © 30 seconds . Add", 0)).text, "slushy, about 30 seconds. Add")
        XCTAssertEqual(RecipeImporter.cleanOCR(L("Freeze until solid, about (3 hours).", 0)).text, "Freeze until solid, about 3 hours.")
        XCTAssertEqual(RecipeImporter.cleanOCR(L("arrange 14(6-inch) lollipop sticks", 0)).text, "arrange 14 (6-inch) lollipop sticks",
                       "a dropped space before a parenthesized size (Joe's meringue import, 1.0 (17))")
        XCTAssertEqual(RecipeImporter.cleanOCR(L("Serves 4(see note)", 0)).text, "Serves 4(see note)", "only before a digit")
        XCTAssertEqual(RecipeImporter.mergeOverlapping("bring to a boil over medium heat. Remove from", "Remove from heat; let cool."),
                       "bring to a boil over medium heat. Remove from heat; let cool.")
        XCTAssertEqual(RecipeImporter.joinLines(["Pre-", "heat the oven"]), "Preheat the oven")
    }
}

// MARK: - Apple News links

final class AppleNewsLinkTests: XCTestCase {
    /// What https://apple.news/KHuRjSBKDOACcBIjqE6y9tg returned on October 11, 2026.
    private let placeholder = """
    <html><head><title>Whipped Frozen Apple Cider</title>
    <meta property="og:title" content="Whipped Frozen Apple Cider — EatingWell">
    </head><body><p>This content is only available in Apple News.</p>
    <a href="https://www.apple.com/legal/privacy/">Privacy Policy</a></body></html>
    """

    func testPlaceholderIsRecognizedWithItsTitle() {
        XCTAssertTrue(RecipeImporter.isAppleNewsPlaceholder(url: URL(string: "https://apple.news/KHuR")!, html: placeholder))
        XCTAssertEqual(RecipeImporter.placeholderTitle(placeholder), "Whipped Frozen Apple Cider")
        XCTAssertNil(RecipeImporter.redirectTarget(inHTML: placeholder, from: URL(string: "https://apple.news/KHuR")!))
    }

    func testImportingTheLinkExplainsWhatToDo() async {
        struct Fake: RecipePageFetcher {
            let html: String
            func fetch(_ url: URL) async throws -> (data: Data, finalURL: URL) { (Data(html.utf8), url) }
        }
        do {
            _ = try await RecipeImportService(fetcher: Fake(html: placeholder))
                .importLink(URL(string: "https://apple.news/KHuRjSBKDOACcBIjqE6y9tg")!)
            XCTFail("an Apple News placeholder has no recipe")
        } catch {
            XCTAssertEqual(error as? RecipeImportError, .appleNewsOnly(title: "Whipped Frozen Apple Cider"))
            XCTAssertTrue((error as? LocalizedError)?.errorDescription?.contains("screenshots") == true)
        }
    }
}

// What Joe's iPhone actually returned for screenshot 2 (build 8, October 12):
// the line under News's blurred top bar came back half Cyrillic, and the
// timer chip's icon came back as a bullet.
final class DeviceOCRRegressionTests: XCTestCase {
    private func L(_ text: String, _ top: Double, h: Double = 0.016) -> OCRLine { OCRLine(text: text, top: top, height: h) }

    private var deviceStep2: [OCRLine] {
        [L("cool, about плоагу. ou am апа ascdra", 0.170, h: 0.018), L("spices.", 0.198, h: 0.018),
         L("STEP 2", 0.250, h: 0.015),
         L("Pour the cider mixture evenly into 12 ice", 0.284, h: 0.018),
         L("cube tray wells (about 2 tablespoons each).", 0.313, h: 0.018),
         L("Freeze until solid, about 3 hours.", 0.341, h: 0.018),
         L("STEP 3", 0.784, h: 0.015),
         L("Place the frozen cider cubes and ½ cup", 0.817, h: 0.018),
         L("coconut milk in a blender. Process until", 0.846, h: 0.018),
         L("slushy, about • 30 seconds. Add up to", 0.874, h: 0.018)]
    }
    private var deviceStep1: [OCRLine] {
        [L("Directions", 0.405, h: 0.022), L("STEP 1", 0.466, h: 0.015),
         L("Combine 1½ cups cider, 1½ tablespoons", 0.500, h: 0.018),
         L("maple syrup, 1 cinnamon stick, 1 tablespoon", 0.529, h: 0.018),
         L("to a boil over medium heat.", 0.557, h: 0.018)]
    }

    func testBlurredCyrillicTailIsDroppedNotScheduled() throws {
        let r = try RecipeImporter.parse(screenshots: [deviceStep1, deviceStep2])
        XCTAssertEqual(r.directions.count, 3)
        XCTAssertFalse(r.directions[0].contains("плоагу") || r.directions[0].contains("ascdra"), r.directions[0])
        XCTAssertFalse(r.directions[0].hasSuffix("spices."), "the whole unreliable tail goes, not half of it")
        XCTAssertTrue(r.directions[0].hasSuffix("medium heat."), r.directions[0])
        let recipe = RecipeImporter.build(r, method: .photo)
        XCTAssertEqual(recipe.steps[0].estimated, true, "with the time unreadable, step 1 stays an honest estimate")
    }

    func testTimerIconBulletBeforeANumberIsRemoved() throws {
        let r = try RecipeImporter.parse(screenshots: [deviceStep1, deviceStep2])
        XCTAssertTrue(r.directions[2].contains("about 30 seconds"), r.directions[2])
        XCTAssertEqual(RecipeImporter.cleanOCR(L("EatingWell • Julia Levy", 0)).text, "EatingWell • Julia Levy", "a byline separator stays")
    }

    func testCyrillicRecipeIsNotFlagged() {
        let page = [L("Борщ", 0.1, h: 0.03), L("Ингредиенты", 0.2), L("2 свёклы", 0.25), L("Способ приготовления", 0.3), L("Варите 40 минут.", 0.35)]
        XCTAssertTrue(RecipeImporter.markUnreliable([page])[0].allSatisfy { !$0.unreliable }, "a page written in Cyrillic is not ‘mixed’")
    }
}

// MARK: - Joe's five screenshots of the same recipe from News's Recipes view
// (October 12, build 1.0 (10)): the cover with Cook · Saved · Share and the
// story teaser bleeding through the tab bar, the ingredient cards, and three
// Directions pages where STEP 1 is split by a photo, the "STEP 2" label sits
// under the floating News button, and the "Ingredients Directions" tabs read
// as one line. What arrived: "Saved" and the teaser as steps 1 and 2, step 1
// ending with the start of step 2, "Ingredients Directions" glued to step 2.

private func recipesViewChrome(tabsJoined: Bool = false) -> [OCRLine] {
    var lines = [L("4:07", 0.020, 0.10, h: 0.015), L("73", 0.022, 0.87, h: 0.012),
                 L("Whipped Frozen Apple Cider", 0.075, 0.21, h: 0.020)]
    if tabsJoined {
        lines += [L("Ingredients Directions", 0.138, 0.07), L("Nutrition", 0.138, 0.60), L("More", 0.138, 0.83)]
    } else {
        lines += [L("Ingredients", 0.138, 0.07), L("Directions", 0.138, 0.35), L("Nutrition", 0.138, 0.60), L("More", 0.138, 0.83)]
    }
    return lines
}

private let rvCover: [OCRLine] = [
    L("4:06", 0.020, 0.10, h: 0.015), L("73", 0.022, 0.87, h: 0.012),
    L("Whipped Frozen", 0.500, h: 0.040), L("Apple Cider", 0.545, h: 0.040),
    L("EatingWell • Julia Levy", 0.595),
    L("Total Time", 0.645, 0.06), L("Yield", 0.645, 0.43),
    L("4 hr 10 min", 0.670, 0.06, h: 0.020), L("2", 0.670, 0.43, h: 0.020),
    L("Cook", 0.770, 0.16), L("Saved", 0.770, 0.46), L("Share", 0.770, 0.76),
    L("Read the Story", 0.835, 0.21), L("Whipped Frozen Apple Cider", 0.855, 0.21),
    L("ect m it warn nd colo Up Following Search", 0.945),
    L("retreshing enough for any time you want a... MoRE", 0.975),
]

private let rvIngredients = recipesViewChrome() + [
    L("Ingredients", 0.195, h: 0.022), L("Scale", 0.200, 0.81),
    L("Yield: 2", 0.222, h: 0.015),
    L("1½ cups unsweetened apple cider,", 0.285), L("plus 3 more tablespoons as needed", 0.311),
    L("1½ tablespoons pure maple syrup", 0.385),
    L("1 (3-inch) cinnamon stick, plus more", 0.459), L("for garnish", 0.485),
    L("1 tablespoon thinly sliced unpeeled", 0.559), L("fresh ginger", 0.585),
    L("½ teaspoon whole cloves", 0.659),
    L("½ teaspoon whole black peppercorns", 0.733),
    L("½ teaspoon allspice berries (optional)", 0.807),
    L("½ cup unsweetened canned coconut", 0.881), L("milk, well shaken and stirred", 0.907),
    L("Add to Grocery List", 0.980, 0.25),
]

/// STEP 1 is split by a photo; the "STEP 2" label at the very bottom is
/// under the floating News button, so only its first line survives.
private let rvStep1 = recipesViewChrome() + [
    L("STEP 1", 0.195, h: 0.015),
    L("Combine 1½ cups cider, 1½ tablespoons", 0.230, h: 0.018),
    L("maple syrup, 1 cinnamon stick, 1 tablespoon", 0.258, h: 0.018),
    L("sliced ginger, ½ teaspoon each cloves and", 0.287, h: 0.018),
    L("peppercorns and ½ teaspoon allspice", 0.315, h: 0.018),
    L("berries (if using) in a small saucepan; bring", 0.344, h: 0.018),
    L("to a boil over medium heat.", 0.372, h: 0.018),
    L("Remove from heat; let steep at room", 0.815, h: 0.018),
    L("temperature, stirring once or twice, until", 0.843, h: 0.018),
    L("cool, about © 1 hour . Strain and discard", 0.871, h: 0.018),
    L("spices.", 0.900, h: 0.018),
    L("S", 0.955, 0.06, h: 0.015),
    L("Pour the cider mixture evenly into 12 ice", 0.985, h: 0.018),
]

private let rvStep2 = recipesViewChrome() + [
    L("STEP 2", 0.205, h: 0.015),
    L("Pour the cider mixture evenly into 12 ice", 0.240, h: 0.018),
    L("cube tray wells (about 2 tablespoons each).", 0.268, h: 0.018),
    L("Freeze until solid, about © 3 hours .", 0.297, h: 0.018),
    L("STEP 3", 0.740, h: 0.015),
    L("Place the frozen cider cubes and ½ cup", 0.775, h: 0.018),
    L("coconut milk in a blender. Process until", 0.803, h: 0.018),
    L("slushy, about © 30 seconds . Add up to", 0.832, h: 0.018),
    L("3 tablespoons cider, 1 tablespoon at a time,", 0.860, h: 0.018),
    L("to reach the desired consistency.", 0.888, h: 0.018),
]

private let rvStep3 = recipesViewChrome(tabsJoined: true) + [
    L("STEP 3", 0.205, h: 0.015),
    L("Place the frozen cider cubes and ½ cup", 0.240, h: 0.018),
    L("coconut milk in a blender. Process until", 0.268, h: 0.018),
    L("slushy, about © 30 seconds . Add up to", 0.297, h: 0.018),
    L("3 tablespoons cider, 1 tablespoon at a time,", 0.325, h: 0.018),
    L("to reach the desired consistency.", 0.354, h: 0.018),
    L("Divide between 2 (8-ounce) chilled glasses", 0.800, h: 0.018),
    L("and serve immediately, garnished with 1", 0.830, h: 0.018),
    L("cinnamon stick, if desired.", 0.858, h: 0.018),
    L("Start Cooking", 0.945, 0.40, h: 0.018),
]

final class RecipesViewScreenshotTests: XCTestCase {

    func testJoesRecipesViewScreenshotsImportCleanly() throws {
        let r = try RecipeImporter.parse(screenshots: [rvCover, rvIngredients, rvStep1, rvStep2, rvStep3])
        XCTAssertEqual(r.title, "Whipped Frozen Apple Cider")
        XCTAssertEqual(r.source.publisher, "EatingWell")
        XCTAssertEqual(r.source.author, "Julia Levy")
        XCTAssertEqual(r.totalMinutes, 250)
        XCTAssertEqual(r.yield, "2")
        XCTAssertEqual(r.ingredients.count, 8, r.ingredients.joined(separator: " | "))
        XCTAssertEqual(r.ingredients.last, "½ cup unsweetened canned coconut milk, well shaken and stirred")
        XCTAssertEqual(r.directions.count, 3, "no cover-page text as steps: \(r.directions)")
        XCTAssertEqual(r.directions[0], "Combine 1½ cups cider, 1½ tablespoons maple syrup, 1 cinnamon stick, 1 tablespoon sliced ginger, ½ teaspoon each cloves and peppercorns and ½ teaspoon allspice berries (if using) in a small saucepan; bring to a boil over medium heat. Remove from heat; let steep at room temperature, stirring once or twice, until cool, about 1 hour. Strain and discard spices.",
                       "step 1 is whole across its photo and does not end with the start of step 2")
        XCTAssertEqual(r.directions[1], "Pour the cider mixture evenly into 12 ice cube tray wells (about 2 tablespoons each). Freeze until solid, about 3 hours.",
                       "the tab row read as one line is not part of step 2")
        XCTAssertEqual(r.directions[2], "Place the frozen cider cubes and ½ cup coconut milk in a blender. Process until slushy, about 30 seconds. Add up to 3 tablespoons cider, 1 tablespoon at a time, to reach the desired consistency. Divide between 2 (8-ounce) chilled glasses and serve immediately, garnished with 1 cinnamon stick, if desired.")
        let all = r.directions.joined(separator: " ")
        for junk in ["Saved", "Following", "Search", "MoRE", "Ingredients Directions", "Read the Story"] {
            XCTAssertFalse(all.contains(junk), "\(junk) is app chrome, not a direction")
        }
    }

    func testCoverPageAloneStillGivesTheSummary() throws {
        // Only the cover: metadata but no directions and no ingredients → the
        // import says so instead of inventing steps from the buttons.
        XCTAssertThrowsError(try RecipeImporter.parse(screenshots: [rvCover]))
        let r = try RecipeImporter.parse(screenshots: [rvCover, rvIngredients])
        XCTAssertEqual(r.totalMinutes, 250)
        XCTAssertEqual(r.yield, "2")
        XCTAssertTrue(r.directions.isEmpty, "\(r.directions)")
    }

    func testCookbookPageWithServesLineIsNotACover() throws {
        // A bare cookbook photo says "Serves 4" and has no app buttons: its
        // text is still sorted into ingredients and directions.
        let page = [L("Serves 4", 0.10), L("2 eggs", 0.16), L("1 cup flour", 0.19),
                    L("Whisk the eggs into the flour and rest the batter for 20 minutes.", 0.30)]
        let r = try RecipeImporter.parse(screenshots: [page])
        XCTAssertEqual(r.ingredients, ["2 eggs", "1 cup flour"])
        XCTAssertEqual(r.directions, ["Whisk the eggs into the flour and rest the batter for 20 minutes."])
    }

    /// Joe's build-12 import of the same recipe: the status bar came back as
    /// one line — clock, location arrow, signal bars, "5GW" — and opened the
    /// title ("10:08 1 ••ll 5GW Whipped Frozen Apple Cider"); and "Yield"
    /// read a hair above "Total Time", so the time landed under Yield and
    /// Recipe time said "Not stated".
    func testMergedStatusBarAndShiftedLabels() throws {
        func merged(_ page: [OCRLine]) -> [OCRLine] {
            page.filter { $0.top > 0.03 } + [L("10:08 1 ••ll 5GW", 0.020, 0.08, h: 0.016), L("63", 0.022, 0.88, h: 0.012)]
        }
        var cover = merged(rvCover)
        cover = cover.map { line in
            var l = line
            if l.text == "Yield" { l.top = 0.637 }          // 0.008 above "Total Time"
            if l.text == "2" { l.top = 0.663 }
            return l
        }
        let pages = [cover, merged(rvIngredients), merged(rvStep1), merged(rvStep2), merged(rvStep3)]
        let r = try RecipeImporter.parse(screenshots: pages)
        XCTAssertEqual(r.title, "Whipped Frozen Apple Cider", "no status bar in the title")
        XCTAssertEqual(r.totalMinutes, 250, "4 hr 10 min is the recipe time")
        XCTAssertEqual(r.yield, "2")
        XCTAssertEqual(r.directions.count, 3, "\(r.directions)")
        XCTAssertFalse(r.directions.joined(separator: " ").contains("5GW"), "\(r.directions)")
    }

    func testStatusBarRules() {
        for w in ["10:08", "9:41", "9.41", "10:08↗"] { XCTAssertTrue(RecipeImporter.isClockWord(w), w) }
        for w in ["1008", "10:8", "100:08", "10:08:30", "5GW", "3/4", "10:08abc"] { XCTAssertFalse(RecipeImporter.isClockWord(w), w) }
        let page = [L("10:08 1 ••ll 5GW", 0.020, 0.08), L("63", 0.022, 0.88), L("Whipped Frozen Apple Cider", 0.075, 0.21)]
        XCTAssertEqual(RecipeImporter.dropStatusBar(page).map(\.text), ["Whipped Frozen Apple Cider"])
        let ipad = [L("10:08 Tue Oct 13", 0.012, 0.03), L("100%", 0.012, 0.92), L("Soup", 0.06)]
        XCTAssertEqual(RecipeImporter.dropStatusBar(ipad).map(\.text), ["Soup"], "iPad: clock and date")
        let photo = [L("Bake at 350 until golden, about 10:00 on the timer", 0.02), L("2 eggs", 0.10)]
        XCTAssertEqual(RecipeImporter.dropStatusBar(photo).count, 2, "a sentence with a time in it is not a status bar")
        let lower = [L("Rest the dough until 10:30.", 0.30)]
        XCTAssertEqual(RecipeImporter.dropStatusBar(lower).count, 1, "only at the top edge")
    }

    func testDurationUnderYieldIsTheTime() throws {
        var r = ImportedRecipe(title: "x")
        RecipeImporter.assignMetadata("yield", "4 hr 10 min", to: &r)
        XCTAssertEqual(r.totalMinutes, 250); XCTAssertNil(r.yield)
        RecipeImporter.assignMetadata("yield", "12 muffins", to: &r)
        XCTAssertEqual(r.yield, "12 muffins")
        let inline = try RecipeImporter.parse(screenshots: [[L("Soup", 0.05, h: 0.04), L("Yield: 45 minutes", 0.12), L("1 onion", 0.2),
                                                             L("Simmer the onion in stock.", 0.3)]])
        XCTAssertEqual(inline.totalMinutes, 45)
        XCTAssertNil(inline.yield)
    }

    func testOverlapTrimAndChromeRows() {
        XCTAssertEqual(RecipeImporter.trimOverlap("Strain and discard spices. Pour the cider mixture evenly into 12 ice",
                                                  next: "Pour the cider mixture evenly into 12 ice cube tray wells."),
                       "Strain and discard spices.")
        XCTAssertEqual(RecipeImporter.trimOverlap("Set aside. Add the onions", next: "Add the garlic and cook"), "Set aside. Add the onions",
                       "two shared words are not an overlap")
        XCTAssertEqual(RecipeImporter.trimOverlap("Pour the cider", next: "Pour the cider mixture"), "Pour the cider",
                       "a step that is nothing but the overlap keeps its text")
        for line in ["Ingredients Directions", "Nutrition More", "Today News+ Audio Following Search", "Saved", "cook saved share",
                     "ect m it warn nd colo Up Following Search"] {
            XCTAssertTrue(RecipeImporter.isChrome(RecipeImporter.normalizedKey(line)), line)
        }
        for line in ["Combine the ingredients", "Search for the ripest tomatoes", "More flour if needed"] {
            XCTAssertFalse(RecipeImporter.isChrome(RecipeImporter.normalizedKey(line)), line)
        }
    }
}

