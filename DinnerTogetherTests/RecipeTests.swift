import XCTest
@testable import DinnerTogether

// Tests for the "add a recipe" feature: the importer (pure functions), the
// library (persistence + menu resolution) and the store with a recipe menu.
// Runs in the Linux harness and in Xcode. No network anywhere.

private let t0 = Date(timeIntervalSince1970: 1_760_000_000)

// MARK: - Fixtures (shapes taken from real sites' markup)

/// Dotdash Meredith style (EatingWell, Allrecipes, Food & Wine): top-level
/// array, @type as an array, Person array for author, image object, yield
/// array, HowToStep list with HTML inside `text`, ISO-8601 durations.
private let eatingWellHTML = """
<!doctype html><html><head><title>You Need to Try This Whipped Frozen Apple Cider</title>
<script type="application/ld+json">
[{"@context":"http://schema.org","@type":["Recipe"],
"name":"You Need to Try This Whipped Frozen Apple Cider",
"author":[{"@type":"Person","name":"Julia Levy"}],
"publisher":{"@type":"Organization","name":"EatingWell"},
"image":{"@type":"ImageObject","url":"https://www.eatingwell.com/thmb/cider.jpg","height":1125,"width":1500},
"recipeYield":["2"],"totalTime":"PT4H10M",
"recipeIngredient":["1\\u00bd cups unsweetened apple cider, plus 3 more tablespoons as needed","1\\u00bd tablespoons pure maple syrup","1 (3-inch) cinnamon stick, plus more for garnish","1 tablespoon thinly sliced unpeeled fresh ginger","\\u00bd teaspoon whole cloves","\\u00bd teaspoon whole black peppercorns","\\u00bd teaspoon allspice berries (optional)","\\u00bd cup unsweetened canned coconut milk, well shaken and stirred"],
"recipeInstructions":[
{"@type":"HowToStep","text":"<p>Combine 1&frac12; cups cider, 1&frac12; tablespoons maple syrup, 1 cinnamon stick, 1 tablespoon sliced ginger, &frac12; teaspoon each cloves and peppercorns and &frac12; teaspoon allspice berries (if using) in a small saucepan; bring to a boil over medium heat. Remove from heat; let cool, about 1 hour. Strain and discard spices.</p>"},
{"@type":"HowToStep","text":"<p>Pour the cider mixture evenly into 12 ice cube tray wells (about 2 tablespoons each). Freeze until solid, about 3 hours.</p>"},
{"@type":"HowToStep","text":"<p>Place the frozen cider cubes and &frac12; cup coconut milk in a blender. Process until slushy, about 30 seconds. Add up to 3 tablespoons cider, 1 tablespoon at a time, to reach the desired consistency.</p>"},
{"@type":"HowToStep","text":"<p>Divide between 2 (8-ounce) chilled glasses and serve immediately, garnished with 1 cinnamon stick, if desired.</p>"}]}]
</script></head><body>…</body></html>
"""

/// WordPress Recipe Maker style: @graph wrapper, HowToSection groups,
/// prepTime + cookTime but no totalTime, yield as a plain string.
private let wprmHTML = """
<html><head>
<script type="application/ld+json" class="yoast-schema-graph">{"@context":"https://schema.org","@graph":[
{"@type":"WebPage","name":"Sheet Pan Chicken Thighs"},
{"@type":"Recipe","name":"Sheet Pan Chicken Thighs with Potatoes","author":{"@type":"Person","name":"Dana"},
"prepTime":"PT15M","cookTime":"PT45M","recipeYield":"4 servings","image":["https://example.com/chicken.jpg"],
"recipeIngredient":["6 bone-in chicken thighs","1 lb baby potatoes, halved","2 tbsp olive oil","Salt and pepper"],
"recipeInstructions":[
{"@type":"HowToSection","name":"Prep","itemListElement":[
  {"@type":"HowToStep","text":"Preheat the oven to 425°F."},
  {"@type":"HowToStep","text":"Toss the potatoes with 1 tbsp oil, salt and pepper and spread on a sheet pan."}]},
{"@type":"HowToSection","name":"Cook","itemListElement":[
  {"@type":"HowToStep","text":"Rub the thighs with the remaining oil, season, and nestle among the potatoes. Roast for 40 to 45 minutes, until the skin is crisp."},
  {"@type":"HowToStep","text":"Rest 5 minutes, then serve."}]}]}]}</script>
</head><body></body></html>
"""

/// Older blog style: instructions as one string with numbered steps inside.
private let stringInstructionsHTML = """
<script type='application/ld+json'>{"@context":"http://schema.org/","@type":"Recipe","name":"Weeknight Garlic Noodles",
"recipeIngredient":["8 oz noodles","4 cloves garlic","2 tbsp butter"],
"recipeInstructions":"1. Boil the noodles 8-10 minutes. 2. Meanwhile, melt the butter and cook the garlic 2 minutes. 3. Toss together and serve.",
"totalTime":"PT20M"}</script>
"""

private let noRecipeHTML = """
<html><head><title>Our Story</title><script type="application/ld+json">{"@type":"Organization","name":"EatingWell"}</script></head><body><p>About us.</p></body></html>
"""

private let microdataHTML = """
<html><head><title>Mom's Chili - Family Cookbook</title></head><body>
<ul><li itemprop="recipeIngredient">1 lb ground beef</li><li itemprop="recipeIngredient">1 can kidney beans</li></ul>
<ol><li itemprop="recipeInstructions">Brown the beef, about 8 minutes.</li><li itemprop="recipeInstructions">Add beans and simmer 30 minutes.</li></ol>
</body></html>
"""

private let appleNewsWrapperHTML = """
<html><head><meta charset="utf-8"><script>window.location.replace("https://www.eatingwell.com/whipped-frozen-apple-cider-11787452");</script></head><body><a href="https://apple.news/Abc">Open in News</a></body></html>
"""

private let pastedText = """
Grandma's Sunday Sauce
Serves 6
Total time: 3 hours

Ingredients
2 tbsp olive oil
1 onion, diced
4 cloves garlic
2 cans (28 oz) crushed tomatoes
1 lb Italian sausage
Salt and pepper

Directions
1. Heat the oil and brown the sausage, about 8 minutes.
2. Add the onion and garlic; cook 5 minutes.
3. Add the tomatoes and simmer, partially covered, 2 to 2½ hours, stirring occasionally.
4. Season to taste and serve over pasta.
"""

private let headerlessText = """
Quick Salad
2 cups arugula
1 pear, sliced
2 tbsp walnuts
Toss everything together with a splash of vinegar and oil and serve right away.
"""

// MARK: - Importer: pages

final class RecipeImporterPageTests: XCTestCase {

    func testEatingWellShapeParses() throws {
        let r = try RecipeImporter.parse(html: eatingWellHTML, url: URL(string: "https://www.eatingwell.com/x")!)
        XCTAssertEqual(r.title, "You Need to Try This Whipped Frozen Apple Cider")
        XCTAssertEqual(r.source.author, "Julia Levy")
        XCTAssertEqual(r.source.publisher, "EatingWell")
        XCTAssertEqual(r.imageURL?.absoluteString, "https://www.eatingwell.com/thmb/cider.jpg")
        XCTAssertEqual(r.yield, "2")
        XCTAssertEqual(r.totalMinutes, 250)
        XCTAssertEqual(r.ingredients.count, 8)
        XCTAssertEqual(r.ingredients[0], "1½ cups unsweetened apple cider, plus 3 more tablespoons as needed")
        XCTAssertEqual(r.directions.count, 4)
        XCTAssertFalse(r.directions[0].contains("<p>"), "HTML stripped")
        XCTAssertTrue(r.directions[0].hasPrefix("Combine 1½ cups cider"), "entities decoded: \(r.directions[0].prefix(30))")
    }

    func testGraphAndSectionsParse() throws {
        let r = try RecipeImporter.parse(html: wprmHTML, url: URL(string: "https://example.com/chicken")!)
        XCTAssertEqual(r.title, "Sheet Pan Chicken Thighs with Potatoes")
        XCTAssertEqual(r.totalMinutes, 60, "prep + cook when no totalTime")
        XCTAssertEqual(r.yield, "4 servings")
        XCTAssertEqual(r.sections.map { $0.name }, ["Prep", "Cook"])
        XCTAssertEqual(r.directions.count, 4)
        XCTAssertEqual(r.source.publisher, "Example", "derived from the host when the page names none")
    }

    func testStringInstructionsSplitOnNumbers() throws {
        let r = try RecipeImporter.parse(html: stringInstructionsHTML, url: nil)
        XCTAssertEqual(r.directions, ["Boil the noodles 8-10 minutes.",
                                      "Meanwhile, melt the butter and cook the garlic 2 minutes.",
                                      "Toss together and serve."])
        XCTAssertEqual(r.totalMinutes, 20)
    }

    func testNoRecipeDataThrows() {
        XCTAssertThrowsError(try RecipeImporter.parse(html: noRecipeHTML, url: nil)) { error in
            XCTAssertEqual(error as? RecipeImportError, .noRecipeData)
        }
    }

    func testMicrodataFallback() throws {
        let r = try RecipeImporter.parse(html: microdataHTML, url: URL(string: "https://family.example.org/chili")!)
        XCTAssertEqual(r.title, "Mom's Chili")
        XCTAssertEqual(r.ingredients, ["1 lb ground beef", "1 can kidney beans"])
        XCTAssertEqual(r.directions.count, 2)
    }

    func testRedirectTargetFromWrapperPage() {
        let from = URL(string: "https://apple.news/AbCdEf")!
        XCTAssertEqual(RecipeImporter.redirectTarget(inHTML: appleNewsWrapperHTML, from: from)?.absoluteString,
                       "https://www.eatingwell.com/whipped-frozen-apple-cider-11787452")
        XCTAssertNil(RecipeImporter.redirectTarget(inHTML: eatingWellHTML, from: URL(string: "https://www.eatingwell.com/x")!),
                     "an ordinary page is not a wrapper")
        let meta = "<html><head><meta http-equiv=\"refresh\" content=\"0; url=https://site.example/recipe\"></head></html>"
        XCTAssertEqual(RecipeImporter.redirectTarget(inHTML: meta, from: URL(string: "https://short.example/x")!)?.absoluteString,
                       "https://site.example/recipe")
    }

    func testISODurations() {
        XCTAssertEqual(RecipeImporter.duration("PT4H10M"), 250)
        XCTAssertEqual(RecipeImporter.duration("P0DT0H25M"), 25)
        XCTAssertEqual(RecipeImporter.duration("PT90M"), 90)
        XCTAssertEqual(RecipeImporter.duration("PT1.5H"), 90)
        XCTAssertEqual(RecipeImporter.duration("PT45S"), 1)
        XCTAssertNil(RecipeImporter.duration("PT0S"))
        XCTAssertEqual(RecipeImporter.duration("1 hr 30 min"), 90, "plain English fallback")
        XCTAssertNil(RecipeImporter.duration(nil))
    }
}

// MARK: - Importer: text, durations, attention

final class RecipeImporterTextTests: XCTestCase {

    func testPastedTextWithHeaders() throws {
        let r = try RecipeImporter.parse(text: pastedText)
        XCTAssertEqual(r.title, "Grandma's Sunday Sauce")
        XCTAssertEqual(r.yield, "6")
        XCTAssertEqual(r.totalMinutes, 180)
        XCTAssertEqual(r.ingredients.count, 6)
        XCTAssertEqual(r.directions.count, 4)
        XCTAssertEqual(r.directions[0], "Heat the oil and brown the sausage, about 8 minutes.", "numbering stripped")
    }

    func testPastedTextWithoutHeaders() throws {
        let r = try RecipeImporter.parse(text: headerlessText)
        XCTAssertEqual(r.title, "Quick Salad")
        XCTAssertEqual(r.ingredients.count, 3)
        XCTAssertEqual(r.directions.count, 1)
    }

    func testEmptyTextThrows() {
        XCTAssertThrowsError(try RecipeImporter.parse(text: "  \n\n ")) { error in
            XCTAssertEqual(error as? RecipeImportError, .emptyText)
        }
    }

    func testMinutesExtraction() {
        let cases: [(String, Int?)] = [
            ("Process until slushy, about 30 seconds.", 1),
            ("Freeze until solid, about 3 hours.", 180),
            ("Roast for 40 to 45 minutes, until the skin is crisp.", 45),
            ("Boil the noodles 8-10 minutes.", 10),
            ("simmer 2 to 2½ hours, stirring occasionally", 150),
            ("let cool, about 1 hour", 60),
            ("Bake 1 hour 15 minutes.", 75),
            ("cook 5 minutes, then simmer 20 minutes", 25),
            ("Chill overnight.", 480),
            ("Cook for a few minutes until fragrant.", 3),
            ("Bake at 350°F until golden.", nil),
            ("Add 2 cups water and 1 tablespoon salt.", nil),
            ("Rest the steak for an hour.", 60),
            ("Simmer for half an hour.", 30),
        ]
        for (text, expected) in cases {
            XCTAssertEqual(RecipeImporter.minutes(in: text), expected, text)
        }
    }

    func testHandsOffClassification() {
        XCTAssertTrue(RecipeImporter.isHandsOff("Freeze until solid, about 3 hours.", minutes: 180))
        XCTAssertTrue(RecipeImporter.isHandsOff("Roast for 40 to 45 minutes.", minutes: 45))
        XCTAssertTrue(RecipeImporter.isHandsOff("Preheat the oven to 425°F.", minutes: nil))
        XCTAssertTrue(RecipeImporter.isHandsOff("Add the tomatoes and simmer, partially covered, 2 hours, stirring occasionally.", minutes: 120))
        XCTAssertFalse(RecipeImporter.isHandsOff("Simmer, stirring constantly, 10 minutes.", minutes: 10), "constant stirring is hands-on")
        XCTAssertFalse(RecipeImporter.isHandsOff("Rest 2 minutes.", minutes: 2), "under 3 minutes is attention, not a break")
        XCTAssertFalse(RecipeImporter.isHandsOff("Whisk the eggs with the sugar.", minutes: nil))
    }

    func testStepTitles() {
        XCTAssertEqual(RecipeImporter.stepTitle(from: "Pour the cider mixture evenly into 12 ice cube tray wells (about 2 tablespoons each). Freeze until solid, about 3 hours."),
                       "Pour the cider mixture evenly into 12 ice cube tray wells…")
        XCTAssertEqual(RecipeImporter.stepTitle(from: "3. Add the tomatoes and simmer, partially covered, 2 hours."),
                       "Add the tomatoes and simmer, partially covered, 2 hours")
        XCTAssertEqual(RecipeImporter.stepTitle(from: "roast for 40 minutes, until crisp"), "Roast for 40 minutes", "doneness cue stays in the detail")
        XCTAssertEqual(RecipeImporter.stepTitle(from: "Rest 5 minutes, then serve."), "Rest 5 minutes")
    }
}

// MARK: - Importer: building the timed recipe

final class RecipeBuildTests: XCTestCase {

    func testBuildKeepsStatedTimesAndMarksGuesses() throws {
        let imported = try RecipeImporter.parse(html: eatingWellHTML, url: URL(string: "https://www.eatingwell.com/x")!)
        let recipe = RecipeImporter.build(imported, method: .link, now: t0)
        XCTAssertEqual(recipe.importMethod, .link)
        XCTAssertTrue(recipe.needsTimingReview)
        XCTAssertEqual(recipe.dishes.count, 1)
        let steps = recipe.dishes[0]
        XCTAssertEqual(steps.count, 4)
        XCTAssertEqual(steps.map { $0.minutes }, [60, 180, 1, 9], "the one guess grows to meet the stated 4 h 10 min")
        XCTAssertEqual(steps.map { $0.estimated }, [false, false, false, true])
        XCTAssertEqual(steps.map { $0.handsOn }, [false, false, true, true])
        XCTAssertEqual(steps[1].title, "Pour the cider mixture evenly into 12 ice cube tray wells…")
        XCTAssertEqual(Set(steps.map { $0.id }).count, 4, "unique ids")
        XCTAssertTrue(steps.allSatisfy { $0.id.hasPrefix("r") })
        XCTAssertEqual(recipe.directions.count, 4, "directions keep the original text")
        XCTAssertEqual(recipe.menu.id, "recipe:" + recipe.id.uuidString)
        XCTAssertEqual(recipe.menu.dishes.count, 1)
        XCTAssertEqual(recipe.plannedMinutes, 250)
    }

    func testMeanwhileThatIsCombinedBackStaysInOrder() throws {
        // "Toss together" needs the garlic butter: the engine can't express a
        // cross-dish wait, so the meanwhile step is cooked in sequence.
        let imported = try RecipeImporter.parse(html: stringInstructionsHTML, url: nil)
        let recipe = RecipeImporter.build(imported, method: .link, now: t0)
        XCTAssertEqual(recipe.dishes.count, 1)
        XCTAssertEqual(recipe.dishes[0].map { $0.title },
                       ["Boil the noodles 8-10 minutes", "Meanwhile, melt the butter and cook the garlic 2 minutes", "Toss together and serve"])
        XCTAssertFalse(recipe.dishes[0][1].dish.hasSuffix("— meanwhile"))
    }

    func testMeanwhileServedSeparatelyRunsInParallel() throws {
        let text = """
        Roast vegetables with yogurt dip
        Directions
        1. Roast the vegetables for 30 minutes.
        2. Meanwhile, stir the yogurt dip together, 5 minutes.
        3. Let the dip rest for 10 minutes.
        4. Serve the vegetables with the dip on the side.
        """
        let recipe = RecipeImporter.build(try RecipeImporter.parse(text: text), method: .text, now: t0)
        XCTAssertEqual(recipe.dishes.count, 2)
        XCTAssertEqual(recipe.dishes[1].count, 2)
    }

    func testLongFirstLineIsStillTheTitle() throws {
        let text = """
        Roasted vegetable platter with a separately served lemon sauce and herbs
        Ingredients
        4 cups vegetables
        Directions
        1. Roast for 35 minutes.
        """
        let r = try RecipeImporter.parse(text: text)
        XCTAssertEqual(r.title, "Roasted vegetable platter with a separately served lemon sauce and herbs")
        XCTAssertEqual(r.directions.count, 1)
        XCTAssertEqual(try RecipeImporter.parse(text: "Preheat the oven to 400°F and roast everything for 30 minutes.\nServe.").title,
                       "Untitled recipe", "an instruction is never taken as the title")
    }

    func testEstimatesScaleUpToStatedTotal() {
        let guess = { (id: String, m: Int, off: Bool) in
            CookingStep(id: id, dish: "D", title: id, minutes: m, detail: "", handsOn: !off, estimated: true)
        }
        let stated = CookingStep(id: "s", dish: "D", title: "s", minutes: 30, detail: "", handsOn: false, estimated: false)
        let dishes = [[guess("a", 5, false), stated, guess("b", 20, true)]]
        let scaled = RecipeImporter.scaleEstimates(dishes, toTotal: 80)
        XCTAssertEqual(scaled[0].map { $0.minutes }, [10, 30, 40], "guesses grow 2×; the stated 30 stays")
        XCTAssertEqual(RecipeImporter.scaleEstimates(dishes, toTotal: 40)[0].map { $0.minutes }, [5, 30, 20], "already past total: unchanged")
        XCTAssertEqual(RecipeImporter.scaleEstimates(dishes, toTotal: nil)[0].map { $0.minutes }, [5, 30, 20])
    }

    func testRecipeMenuPlansWithTheEngine() throws {
        let imported = try RecipeImporter.parse(html: eatingWellHTML, url: nil)
        let recipe = RecipeImporter.build(imported, method: .link, now: t0)
        var session = DinnerSession()
        session.menuID = recipe.menuID
        session.serveAt = t0.addingTimeInterval(5 * 3600)
        let plan = Scheduling.plan(menu: recipe.menu, session: session)
        XCTAssertEqual(plan.count, 4)
        XCTAssertEqual(Scheduling.checkFeasibility(menu: recipe.menu, serveAt: session.serveAt, durations: [:], now: t0), .ok)
        if case .startsInPast = Scheduling.checkFeasibility(menu: recipe.menu, serveAt: t0.addingTimeInterval(3600), durations: [:], now: t0) {} else {
            XCTFail("a 4-hour recipe cannot reach the table in an hour")
        }
    }

    func testRecipeRoundTripsThroughJSON() throws {
        let imported = try RecipeImporter.parse(text: pastedText)
        var recipe = RecipeImporter.build(imported, method: .text, now: t0)
        recipe.imageFilename = "x.jpg"; recipe.notes = "Double the garlic."
        let data = try JSONEncoder().encode(recipe)
        let back = try JSONDecoder().decode(Recipe.self, from: data)
        XCTAssertEqual(back, recipe)
    }

    func testOlderStepsWithoutEstimatedFlagDecode() throws {
        let json = #"{"id":"a1","dish":"A","title":"Prep","minutes":10,"detail":"","handsOn":true}"#
        let step = try JSONDecoder().decode(CookingStep.self, from: Data(json.utf8))
        XCTAssertNil(step.estimated)
    }
}

// MARK: - Library and store

@MainActor
final class RecipeLibraryTests: XCTestCase {
    private func tempDir() -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: "dt-recipes-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func sampleRecipe() throws -> Recipe {
        RecipeImporter.build(try RecipeImporter.parse(text: pastedText), method: .text, now: t0)
    }

    func testAddPersistsAndReloads() async throws {
        let dir = tempDir()
        let library = RecipeLibrary(directory: dir)
        XCTAssertTrue(library.isEmpty)
        let recipe = try sampleRecipe()
        library.add(recipe)
        XCTAssertNil(library.saveError)
        let reloaded = RecipeLibrary(directory: dir)
        XCTAssertEqual(reloaded.recipes, [recipe])
        XCTAssertEqual(reloaded.menu(id: recipe.menuID)?.title, "Grandma's Sunday Sauce")
        XCTAssertEqual(reloaded.menu(id: "steak")?.id, "steak", "catalog ids still resolve")
        XCTAssertNil(reloaded.menu(id: "recipe:not-a-uuid"))
        XCTAssertNil(reloaded.menu(id: "recipe:" + UUID().uuidString))
    }

    func testTimingEditsAndReview() async throws {
        let library = RecipeLibrary(directory: tempDir())
        let recipe = try sampleRecipe()
        library.add(recipe)
        let step = recipe.steps[3]
        XCTAssertEqual(step.estimated, true, "“Season to taste and serve” states no time")
        library.setStep(recipeID: recipe.id, stepID: step.id, minutes: 7)
        XCTAssertEqual(library.recipe(id: recipe.id)?.steps[3].minutes, 7)
        XCTAssertEqual(library.recipe(id: recipe.id)?.steps[3].estimated, false)
        library.setStep(recipeID: recipe.id, stepID: step.id, handsOn: false)
        XCTAssertEqual(library.recipe(id: recipe.id)?.steps[3].handsOn, false)
        XCTAssertEqual(library.recipe(id: recipe.id)?.steps[3].minutes, 7, "toggling attention keeps the minutes")
        library.markTimingReviewed(id: recipe.id)
        XCTAssertEqual(library.recipe(id: recipe.id)?.needsTimingReview, false)
        XCTAssertEqual(library.recipe(id: recipe.id)?.estimatedStepCount, 0)
    }

    func testImagesAreStoredBesideTheLibrary() async throws {
        let dir = tempDir()
        let library = RecipeLibrary(directory: dir)
        let recipe = try sampleRecipe()
        library.add(recipe)
        let name = library.saveImage(Data([0xFF, 0xD8, 0xFF, 0xE0]), for: recipe.id)
        XCTAssertEqual(name, "\(recipe.id.uuidString).jpg")
        XCTAssertNotNil(library.imageURL(for: library.recipe(id: recipe.id)!))
        library.remove(id: recipe.id)
        XCTAssertTrue(library.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appending(path: "recipe-images/\(name!)").path), "image removed with the recipe")
    }

    func testStoreResolvesRecipeMenusAndFallsBackWhenDeleted() async throws {
        let dir = tempDir()
        let library = RecipeLibrary(directory: dir)
        let recipe = try sampleRecipe()
        library.add(recipe)
        let file = dir.appending(path: "session.json")
        let store = SessionStore(fileURL: file, notifications: MockNotifications(), menuProvider: library)
        store.chooseMenu(recipe.menuID)
        XCTAssertEqual(store.menu.title, "Grandma's Sunday Sauce")
        XCTAssertFalse(store.menuIsMissing)
        XCTAssertEqual(store.plan.count, recipe.steps.count)

        // Relaunch with the same library: the recipe session survives.
        let again = SessionStore(fileURL: file, notifications: MockNotifications(), menuProvider: library)
        XCTAssertEqual(again.session.menuID, recipe.menuID)

        // Relaunch after the recipe is gone: the saved session is not loaded
        // (same rule as a catalog id that no longer exists).
        library.remove(id: recipe.id)
        let after = SessionStore(fileURL: file, notifications: MockNotifications(), menuProvider: library)
        XCTAssertEqual(after.session.menuID, DinnerSession().menuID)

        // Deleted mid-session: the store says so instead of pretending.
        XCTAssertTrue(again.menuIsMissing)
        XCTAssertEqual(again.menu.id, DinnerCatalog.menus[0].id)
    }

    func testFailedSaveRollsBackTheAdd() async throws {
        // A directory that doesn't exist: every write fails.
        let missing = URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: "dt-missing-\(UUID().uuidString)/nested", directoryHint: .isDirectory)
        let library = RecipeLibrary(directory: missing)
        XCTAssertFalse(library.add(try sampleRecipe()))
        XCTAssertTrue(library.isEmpty, "nothing shown that a relaunch would lose")
        XCTAssertNotNil(library.saveError)
    }

    func testFailedUpdateAndRemoveRollBack() async throws {
        let dir = tempDir()
        let library = RecipeLibrary(directory: dir)
        let recipe = try sampleRecipe()
        XCTAssertTrue(library.add(recipe))
        let name = library.saveImage(Data([0xFF, 0xD8]), for: recipe.id)!
        let imagePath = dir.appending(path: "recipe-images/\(name)").path
        let saved = library.recipe(id: recipe.id)!
        // Make every further write fail: move the folder away, leave a file
        // where the folder was.
        let moved = dir.deletingLastPathComponent().appending(path: "moved-\(UUID().uuidString)")
        try FileManager.default.moveItem(at: dir, to: moved)
        try Data().write(to: dir)

        XCTAssertFalse(library.setStep(recipeID: recipe.id, stepID: recipe.steps[0].id, minutes: 42))
        XCTAssertEqual(library.recipe(id: recipe.id), saved, "failed timing edit rolled back")
        XCTAssertNotNil(library.saveError)

        XCTAssertFalse(library.remove(id: recipe.id))
        XCTAssertEqual(library.recipe(id: recipe.id), saved, "failed delete rolled back")
        XCTAssertTrue(FileManager.default.fileExists(atPath: moved.appending(path: "recipe-images/\(name)").path),
                      "the photo survives a failed delete")
        _ = imagePath
    }

    func testStoreWithoutProviderIsCatalogOnly() async {
        let store = SessionStore(fileURL: tempDir().appending(path: "s.json"), notifications: MockNotifications())
        store.chooseMenu("recipe:" + UUID().uuidString)
        XCTAssertTrue(store.menuIsMissing)
        XCTAssertEqual(store.menu.id, DinnerCatalog.menus[0].id)
    }

    func testImportServiceFollowsWrapperAndFetchesImage() async throws {
        struct Fake: RecipePageFetcher {
            func fetch(_ url: URL) async throws -> (data: Data, finalURL: URL) {
                switch url.host {
                case "apple.news": return (Data(appleNewsWrapperHTML.utf8), url)
                case "www.eatingwell.com":
                    if url.path.hasSuffix(".jpg") { return (Data(repeating: 0xAB, count: 5_000), url) }
                    return (Data(eatingWellHTML.utf8), url)
                default: throw RecipeFetchError.badStatus(404)
                }
            }
        }
        let service = RecipeImportService(fetcher: Fake())
        let result = try await service.importLink(URL(string: "https://apple.news/AbCdEf")!, now: t0)
        XCTAssertEqual(result.recipe.title, "You Need to Try This Whipped Frozen Apple Cider")
        XCTAssertEqual(result.recipe.source.url?.host, "www.eatingwell.com", "source is the publisher page, not the wrapper")
        XCTAssertEqual(result.imageData?.count, 5_000)
        XCTAssertEqual(result.recipe.importMethod, .link)
    }

    func testImportServiceReportsPagesWithoutRecipeData() async {
        struct Fake: RecipePageFetcher {
            func fetch(_ url: URL) async throws -> (data: Data, finalURL: URL) { (Data(noRecipeHTML.utf8), url) }
        }
        do {
            _ = try await RecipeImportService(fetcher: Fake()).importLink(URL(string: "https://example.com/about")!)
            XCTFail("expected noRecipeData")
        } catch {
            XCTAssertEqual(error as? RecipeImportError, .noRecipeData)
        }
    }
}

// Original A2 scheduling fixtures. Not kitchen-tested recipes or public menu content.
final class A2RecipeFixtureTests: XCTestCase {
    func testFixture1() throws {
        let input = """
        Garlic mushrooms
        Yield: 2 servings
        Total time: 15 minutes
        
        Ingredients
        250 g mushrooms
        1 tablespoon olive oil
        1 garlic clove
        
        Directions
        1. Slice the mushrooms and chop the garlic for 5 minutes.
        2. Cook the mushrooms in the oil, stirring frequently, for 8 minutes.
        3. Add garlic and finish the mushrooms for 2 minutes.
        """
        let recipe = RecipeImporter.build(try RecipeImporter.parse(text: input), method: .text, id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, now: t0)
        XCTAssertEqual(recipe.title, "Garlic mushrooms")
        XCTAssertEqual(recipe.dishes.map { $0.map { $0.minutes } }, [[5, 8, 2]])
        XCTAssertEqual(recipe.estimatedStepCount, 0)
        XCTAssertTrue(recipe.needsTimingReview)
        var session = DinnerSession()
        session.menuID = recipe.menuID
        session.serveAt = t0.addingTimeInterval(Double(recipe.plannedMinutes) * 60)
        let plan = Scheduling.plan(menu: recipe.menu, session: session)
        XCTAssertEqual(plan.count, recipe.steps.count)
        for dish in recipe.dishes {
            let chain = dish.compactMap { step in plan.first { $0.id == step.id } }
            XCTAssertEqual(chain.last?.plannedEnd, session.serveAt)
            XCTAssertGreaterThanOrEqual(chain.first!.plannedStart, t0)
            for i in chain.indices.dropFirst() {
                XCTAssertEqual(chain[i - 1].plannedEnd, chain[i].plannedStart)
            }
        }
    }

    func testFixture2() throws {
        let input = """
        Lemon couscous
        Yield: 2 generous side portions
        Total time: 20 minutes
        
        Ingredients
        1 cup couscous
        1 lemon
        Water according to the couscous package
        
        Directions
        1. Measure the ingredients and prepare the lemon for 5 minutes.
        2. Bring the water to a boil and pour it over the couscous for 5 minutes.
        3. Let the couscous rest covered for 10 minutes.
        """
        let recipe = RecipeImporter.build(try RecipeImporter.parse(text: input), method: .text, id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, now: t0)
        XCTAssertEqual(recipe.title, "Lemon couscous")
        XCTAssertEqual(recipe.dishes.map { $0.map { $0.minutes } }, [[5, 5, 10]])
        XCTAssertEqual(recipe.estimatedStepCount, 0)
        XCTAssertTrue(recipe.needsTimingReview)
        var session = DinnerSession()
        session.menuID = recipe.menuID
        session.serveAt = t0.addingTimeInterval(Double(recipe.plannedMinutes) * 60)
        let plan = Scheduling.plan(menu: recipe.menu, session: session)
        XCTAssertEqual(plan.count, recipe.steps.count)
        for dish in recipe.dishes {
            let chain = dish.compactMap { step in plan.first { $0.id == step.id } }
            XCTAssertEqual(chain.last?.plannedEnd, session.serveAt)
            XCTAssertGreaterThanOrEqual(chain.first!.plannedStart, t0)
            for i in chain.indices.dropFirst() {
                XCTAssertEqual(chain[i - 1].plannedEnd, chain[i].plannedStart)
            }
        }
    }

    func testFixture3() throws {
        let input = """
        Frozen berry drink with lime and a three-hour freezer stage
        Yield: 2 tall glasses, or 4 small tasting portions
        Total time: 187 minutes
        
        Ingredients
        2 cups berry juice
        1 lime
        
        Directions
        1. Mix the juice and lime and fill an ice tray for 5 minutes.
        2. Freeze the mixture for 3 hours; check that it is solid before continuing.
        3. Blend and pour the frozen drink for 2 minutes.
        """
        let recipe = RecipeImporter.build(try RecipeImporter.parse(text: input), method: .text, id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, now: t0)
        XCTAssertEqual(recipe.title, "Frozen berry drink with lime and a three-hour freezer stage")
        XCTAssertEqual(recipe.dishes.map { $0.map { $0.minutes } }, [[5, 180, 2]])
        XCTAssertEqual(recipe.estimatedStepCount, 0)
        XCTAssertTrue(recipe.needsTimingReview)
        XCTAssertFalse(recipe.steps[1].handsOn)
        var session = DinnerSession()
        session.menuID = recipe.menuID
        session.serveAt = t0.addingTimeInterval(Double(recipe.plannedMinutes) * 60)
        let plan = Scheduling.plan(menu: recipe.menu, session: session)
        XCTAssertEqual(plan.count, recipe.steps.count)
        for dish in recipe.dishes {
            let chain = dish.compactMap { step in plan.first { $0.id == step.id } }
            XCTAssertEqual(chain.last?.plannedEnd, session.serveAt)
            XCTAssertGreaterThanOrEqual(chain.first!.plannedStart, t0)
            for i in chain.indices.dropFirst() {
                XCTAssertEqual(chain[i - 1].plannedEnd, chain[i].plannedStart)
            }
        }
        let freeze = try XCTUnwrap(plan.first { $0.minutes == 180 })
        var record = StepRecord()
        record.state = .cooking
        record.actualStart = freeze.plannedStart
        record.timerDeadline = freeze.plannedEnd
        record.confirmedMinutes = 180
        session.records[freeze.id] = record
        session.serveAt = session.serveAt.addingTimeInterval(15 * 60)
        let changed = try XCTUnwrap(Scheduling.plan(menu: recipe.menu, session: session).first { $0.id == freeze.id })
        XCTAssertEqual(changed.end, freeze.plannedEnd)
    }

    func testFixture4() throws {
        let input = """
        Vegetable platter with a separately served lemon sauce
        Yield: 4 side portions with sauce served separately
        Total time: 42 minutes
        
        Ingredients
        4 cups chopped vegetables
        2 tablespoons olive oil
        1 lemon
        2 tablespoons yogurt
        
        Directions
        1. Prepare the vegetables and tray for 5 minutes.
        2. Roast the vegetables for 35 minutes; check texture before serving.
        3. Meanwhile, whisk a separate lemon sauce for 5 minutes.
        4. Let the sauce rest for 5 minutes.
        5. Serve the vegetables on their own platter for 2 minutes, with the sauce in a separate bowl.
        """
        let recipe = RecipeImporter.build(try RecipeImporter.parse(text: input), method: .text, id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!, now: t0)
        XCTAssertEqual(recipe.title, "Vegetable platter with a separately served lemon sauce")
        XCTAssertEqual(recipe.dishes.map { $0.map { $0.minutes } }, [[5, 35, 2], [5, 5]])
        XCTAssertEqual(recipe.estimatedStepCount, 0)
        XCTAssertTrue(recipe.needsTimingReview)
        var session = DinnerSession()
        session.menuID = recipe.menuID
        session.serveAt = t0.addingTimeInterval(Double(recipe.plannedMinutes) * 60)
        let plan = Scheduling.plan(menu: recipe.menu, session: session)
        XCTAssertEqual(plan.count, recipe.steps.count)
        for dish in recipe.dishes {
            let chain = dish.compactMap { step in plan.first { $0.id == step.id } }
            XCTAssertEqual(chain.last?.plannedEnd, session.serveAt)
            XCTAssertGreaterThanOrEqual(chain.first!.plannedStart, t0)
            for i in chain.indices.dropFirst() {
                XCTAssertEqual(chain[i - 1].plannedEnd, chain[i].plannedStart)
            }
        }
    }

    func testFixture5() throws {
        let input = """
        Bean spread with an untimed step
        Yield: 2 snack portions
        
        Ingredients
        1 can beans
        1 tablespoon olive oil
        1 lemon
        
        Directions
        1. Drain the beans and prepare the lemon for 5 minutes.
        2. Warm the beans until hot.
        3. Mash and season the spread for 8-10 minutes.
        4. Finish plating for 30 seconds.
        """
        let recipe = RecipeImporter.build(try RecipeImporter.parse(text: input), method: .text, id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!, now: t0)
        XCTAssertEqual(recipe.title, "Bean spread with an untimed step")
        XCTAssertEqual(recipe.dishes.map { $0.map { $0.minutes } }, [[5, 5, 10, 1]])
        XCTAssertEqual(recipe.estimatedStepCount, 1)
        XCTAssertTrue(recipe.needsTimingReview)
        var session = DinnerSession()
        session.menuID = recipe.menuID
        session.serveAt = t0.addingTimeInterval(Double(recipe.plannedMinutes) * 60)
        let plan = Scheduling.plan(menu: recipe.menu, session: session)
        XCTAssertEqual(plan.count, recipe.steps.count)
        for dish in recipe.dishes {
            let chain = dish.compactMap { step in plan.first { $0.id == step.id } }
            XCTAssertEqual(chain.last?.plannedEnd, session.serveAt)
            XCTAssertGreaterThanOrEqual(chain.first!.plannedStart, t0)
            for i in chain.indices.dropFirst() {
                XCTAssertEqual(chain[i - 1].plannedEnd, chain[i].plannedStart)
            }
        }
    }

}

// A1-R1 finding: notes inside a HowToStep must not become cooking steps.
final class RecipeNotesTests: XCTestCase {
    func testDoAheadAndEditorNotesAreNotSteps() throws {
        let html = """
        <script type="application/ld+json">{"@type":"Recipe","name":"Cookies","recipeIngredient":["1 cup flour"],
        "recipeInstructions":[{"@type":"HowToStep","text":"Mix the dough."},
        {"@type":"HowToStep","text":"Bake until golden, 8–10 minutes. Let cool.\\nDo Ahead: Dough balls can be frozen 3 months ahead; add 1–2 minutes to the bake.\\nEditor’s note: First printed in 2019."}]}</script>
        """
        let r = try RecipeImporter.parse(html: html, url: nil)
        XCTAssertEqual(r.directions, ["Mix the dough.", "Bake until golden, 8–10 minutes. Let cool."])
        XCTAssertEqual(r.notes.count, 2)
        let recipe = RecipeImporter.build(r, method: .link)
        XCTAssertEqual(recipe.steps.count, 2)
        XCTAssertEqual(recipe.steps[1].minutes, 10, "the note’s “1–2 minutes” doesn’t leak into the bake time")
        XCTAssertTrue(recipe.notes?.hasPrefix("Do Ahead") == true)
    }

    func testPastedNotesAfterDirections() throws {
        let r = try RecipeImporter.parse(text: """
        Toast
        Directions
        1. Toast the bread, 3 minutes.
        Note: Use day-old bread.
        """)
        XCTAssertEqual(r.directions, ["Toast the bread, 3 minutes."])
        XCTAssertEqual(r.notes, ["Note: Use day-old bread."])
    }
}
