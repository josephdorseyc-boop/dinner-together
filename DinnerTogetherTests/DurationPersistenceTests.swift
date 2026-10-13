import XCTest
@testable import DinnerTogether

// MARK: - Duration persistence and failure rollback (A1 verification batch)
//
// Against main d0c28d4553c4b25b2f3ac930fdada1d70f252039.
// The 180/181-minute values come from Agent 2's capture contract
// (re-capture the duration editor at 180 and 181 minutes).

@MainActor
final class DurationPersistenceTests: XCTestCase {
    private func tempDir() -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: "dt-dur-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// A saved recipe whose first step is exactly 180 minutes.
    private func recipeAt180(in library: RecipeLibrary) throws -> Recipe {
        let recipe = try RecipeImporter.build(
            try RecipeImporter.parse(text: "Frozen Berry Drink\n\nIngredients\n- berries\n\nDirections\nFreeze the mixture.\nServe cold."),
            method: .text, now: Date())
        XCTAssertTrue(library.add(recipe))
        let stepID = recipe.steps[0].id
        XCTAssertTrue(library.setStep(recipeID: recipe.id, stepID: stepID, minutes: 180))
        return library.recipe(id: recipe.id)!
    }

    func testDurationEditPersistsAcrossRelaunch() async throws {
        let dir = tempDir()
        let library = RecipeLibrary(directory: dir)
        let recipe = try recipeAt180(in: library)
        let stepID = recipe.steps[0].id
        XCTAssertEqual(recipe.steps[0].minutes, 180)

        // The editor's Save path: onSave -> setStep -> update -> save to disk.
        XCTAssertTrue(library.setStep(recipeID: recipe.id, stepID: stepID, minutes: 181))
        XCTAssertEqual(library.recipe(id: recipe.id)?.steps[0].minutes, 181)

        // Relaunch: a fresh library over the same directory.
        let reloaded = RecipeLibrary(directory: dir)
        XCTAssertEqual(reloaded.recipe(id: recipe.id)?.steps[0].minutes, 181,
                       "saving 181 minutes persists after relaunch")
    }

    func testFailedConfirmationRollsBack() async throws {
        let dir = tempDir()
        let library = RecipeLibrary(directory: dir)
        let recipe = try recipeAt180(in: library)
        let saved = library.recipe(id: recipe.id)!

        // Make every further write fail: move the folder away, leave a file
        // where the folder was.
        let moved = dir.deletingLastPathComponent().appending(path: "moved-\(UUID().uuidString)")
        try FileManager.default.moveItem(at: dir, to: moved)
        try Data().write(to: dir)

        XCTAssertFalse(library.markTimingReviewed(id: recipe.id))
        XCTAssertEqual(library.recipe(id: recipe.id), saved, "failed confirmation keeps the saved recipe")
        XCTAssertTrue(library.recipe(id: recipe.id)?.needsTimingReview ?? false,
                      "the review requirement survives a failed confirmation")
        XCTAssertNotNil(library.saveError, "visible feedback for the failed save")
    }

    func testFailedDeletePreservesRecipeAndPhoto() async throws {
        let dir = tempDir()
        let library = RecipeLibrary(directory: dir)
        let recipe = try recipeAt180(in: library)
        let name = library.saveImage(Data([0xFF, 0xD8]), for: recipe.id)!
        let saved = library.recipe(id: recipe.id)!

        // Block only the JSON destination. The original image stays reachable,
        // so deleting it before a failed save would genuinely fail this test.
        let image = dir.appending(path: "recipe-images/\(name)")
        XCTAssertTrue(FileManager.default.fileExists(atPath: image.path))
        let json = dir.appending(path: "dinner-together-recipes-v1.json")
        try FileManager.default.removeItem(at: json)
        try FileManager.default.createDirectory(at: json, withIntermediateDirectories: false)

        XCTAssertFalse(library.remove(id: recipe.id))
        XCTAssertEqual(library.recipe(id: recipe.id), saved, "failed delete keeps the recipe")
        XCTAssertTrue(FileManager.default.fileExists(atPath: image.path),
                      "the photo survives a failed delete")
    }

    /// The recipe's own total time, entered by hand when the import found
    /// none (Joe, build 11): persists, clamps, clears, and never touches the
    /// step estimates; a failed save rolls back.
    func testRecipeTimeEntryPersistsAndRollsBack() async throws {
        let dir = tempDir()
        let library = RecipeLibrary(directory: dir)
        let recipe = try recipeAt180(in: library)
        XCTAssertNil(recipe.totalMinutes, "the text had no total time")

        XCTAssertTrue(library.setTotalMinutes(recipeID: recipe.id, minutes: 45))
        XCTAssertEqual(library.recipe(id: recipe.id)?.totalMinutes, 45)
        XCTAssertEqual(library.recipe(id: recipe.id)?.steps[0].minutes, 180, "the step estimate is untouched")
        XCTAssertEqual(RecipeLibrary(directory: dir).recipe(id: recipe.id)?.totalMinutes, 45, "persists after relaunch")

        XCTAssertTrue(library.setTotalMinutes(recipeID: recipe.id, minutes: 0))
        XCTAssertEqual(library.recipe(id: recipe.id)?.totalMinutes, 1, "clamped to at least a minute")
        XCTAssertTrue(library.setTotalMinutes(recipeID: recipe.id, minutes: nil))
        XCTAssertNil(library.recipe(id: recipe.id)?.totalMinutes, "cleared")

        library.simulateSaveFailure = true
        XCTAssertFalse(library.setTotalMinutes(recipeID: recipe.id, minutes: 90))
        XCTAssertNil(library.recipe(id: recipe.id)?.totalMinutes, "a failed save changes nothing in memory")
        XCTAssertNotNil(library.saveError)
        XCTAssertFalse(library.setTotalMinutes(recipeID: UUID(), minutes: 10), "unknown recipe")
    }

    /// A2 S2 (build 11): text the import mistook for a step leaves the plan
    /// and the directions together; a second removal still finds its line.
    func testRemovingAStepLeavesDirectionsAndPlanTogether() async throws {
        let dir = tempDir()
        let library = RecipeLibrary(directory: dir)
        let recipe = try RecipeImporter.build(
            try RecipeImporter.parse(text: "Meringue Twists\n\nIngredients\n- 4 egg whites\n\nDirections\nSTEP 1\nMeringue Twists Meringue Twists\nSTEP 2\nToday News+ Audio Following Search\nSTEP 3\nPreheat the oven to 200°F.\nSTEP 4\nSet aside."),
            method: .photo, now: Date())
        XCTAssertTrue(library.add(recipe))
        XCTAssertEqual(recipe.directions.count, 4)
        XCTAssertEqual(recipe.steps.count, 4)

        XCTAssertTrue(library.removeStep(recipeID: recipe.id, stepID: recipe.steps[1].id))
        var saved = library.recipe(id: recipe.id)!
        XCTAssertEqual(saved.steps.map { $0.detail }, ["Meringue Twists Meringue Twists", "Preheat the oven to 200°F.", "Set aside."])
        XCTAssertEqual(saved.directions.count, 3)
        XCTAssertFalse(saved.directions.contains { $0.contains("Following Search") }, "\(saved.directions)")

        XCTAssertTrue(library.removeStep(recipeID: recipe.id, stepID: saved.steps[0].id), "the first step, after one removal, is still found by its text")
        saved = library.recipe(id: recipe.id)!
        XCTAssertEqual(saved.steps.map { $0.detail }, ["Preheat the oven to 200°F.", "Set aside."])
        XCTAssertEqual(saved.directions.map { RecipeImporter.stripStepPrefix($0) }, ["Preheat the oven to 200°F.", "Set aside."])
        XCTAssertEqual(RecipeLibrary(directory: dir).recipe(id: recipe.id)?.steps.count, 2, "persists after relaunch")

        library.simulateSaveFailure = true
        XCTAssertFalse(library.removeStep(recipeID: recipe.id, stepID: saved.steps[0].id))
        XCTAssertEqual(library.recipe(id: recipe.id)?.steps.count, 2, "a failed save changes nothing in memory")
        XCTAssertFalse(library.removeStep(recipeID: recipe.id, stepID: "nope"), "unknown step")
    }

    func testRemovingLaterDuplicatePreservesSourceDirectionOrder() async throws {
        let library = RecipeLibrary(directory: tempDir())
        var imported = ImportedRecipe(title: "Double stir")
        imported.sections = [ImportedSection(name: nil, steps: ["Stir.", "Add salt.", "Stir."])]
        let recipe = RecipeImporter.build(imported, method: .text)
        XCTAssertTrue(library.add(recipe))

        XCTAssertTrue(library.removeStep(recipeID: recipe.id, stepID: recipe.steps[2].id))
        let saved = try XCTUnwrap(library.recipe(id: recipe.id))
        XCTAssertEqual(saved.directions, ["Stir.", "Add salt."])
        XCTAssertEqual(saved.steps.map { $0.detail }, ["Stir.", "Add salt."])
    }

    func testRemovingDuplicateFromParallelDishKeepsSourceOccurrence() async throws {
        let directory = tempDir()
        let library = RecipeLibrary(directory: directory)
        var imported = ImportedRecipe(title: "Parallel stir")
        imported.sections = [ImportedSection(name: nil, steps: ["Stir.", "Chop herbs.", "Stir.", "Plate.", "Stir."])]
        var recipe = RecipeImporter.build(imported, method: .text)
        let steps = recipe.steps
        // Dish order differs from source order, as it can with meanwhile work.
        recipe.dishes = [[steps[0], steps[3], steps[4]], [steps[1], steps[2]]]
        XCTAssertTrue(library.add(recipe))
        XCTAssertTrue(library.removeStep(recipeID: recipe.id, stepID: steps[2].id))
        let saved = try XCTUnwrap(library.recipe(id: recipe.id))
        XCTAssertEqual(saved.directions, ["Stir.", "Chop herbs.", "Plate.", "Stir."])
        XCTAssertEqual(RecipeLibrary(directory: directory).recipe(id: recipe.id)?.directions, saved.directions)

        library.simulateSaveFailure = true
        XCTAssertFalse(library.removeStep(recipeID: recipe.id, stepID: steps[4].id))
        XCTAssertEqual(library.recipe(id: recipe.id), saved, "failed removal restores the whole recipe")
    }

    /// Swipe → Edit (Joe, build 12): the title and yield change, the steps'
    /// dish labels follow, a blank title is refused, a failed save changes
    /// nothing.
    func testRenamingARecipe() async throws {
        let dir = tempDir()
        let library = RecipeLibrary(directory: dir)
        let junk = "10:08 1 ••ll 5GW Whipped Frozen Apple Cider"
        var imported = ImportedRecipe(title: junk)
        imported.ingredients = ["2 cups cider"]
        imported.sections = [ImportedSection(name: nil, steps: ["Freeze for 3 hours.", "Blend until slushy, about 30 seconds."])]
        let recipe = RecipeImporter.build(imported, method: .photo, now: Date())
        XCTAssertTrue(library.add(recipe))
        let oldLabel = recipe.steps[0].dish
        XCTAssertTrue(junk.hasPrefix(oldLabel.replacingOccurrences(of: "…", with: "")), oldLabel)

        XCTAssertTrue(library.rename(recipeID: recipe.id, title: "  Whipped Frozen Apple Cider ", yield: "2 glasses"))
        let saved = try XCTUnwrap(RecipeLibrary(directory: dir).recipe(id: recipe.id))
        XCTAssertEqual(saved.title, "Whipped Frozen Apple Cider")
        XCTAssertEqual(saved.yield, "2 glasses")
        XCTAssertEqual(Set(saved.steps.map(\.dish)), ["Whipped Frozen Apple Cider"], "the cooking screen's dish label follows")
        XCTAssertEqual(saved.steps.map(\.minutes), recipe.steps.map(\.minutes), "timing untouched")
        XCTAssertEqual(saved.menu.title, "Whipped Frozen Apple Cider")

        XCTAssertFalse(library.rename(recipeID: recipe.id, title: "   ", yield: nil), "a recipe needs a title")
        XCTAssertTrue(library.rename(recipeID: recipe.id, title: "Cider slush", yield: " "))
        XCTAssertNil(library.recipe(id: recipe.id)?.yield, "a blank yield clears it")

        library.simulateSaveFailure = true
        XCTAssertFalse(library.rename(recipeID: recipe.id, title: "Something else", yield: nil))
        XCTAssertEqual(library.recipe(id: recipe.id)?.title, "Cider slush", "a failed save changes nothing in memory")
        XCTAssertFalse(library.rename(recipeID: UUID(), title: "x", yield: nil), "unknown recipe")
    }

    func testImportWarningsSurviveARelaunch() async throws {
        let dir = tempDir()
        let library = RecipeLibrary(directory: dir)
        var imported = try RecipeImporter.parse(text: "Soup\n\nIngredients\n- 1 onion\n\nDirections\nSimmer for 20 minutes.")
        imported.warnings = ["Step 2 wasn’t found in the screenshots."]
        let recipe = RecipeImporter.build(imported, method: .photo, now: Date())
        XCTAssertTrue(library.add(recipe))
        XCTAssertEqual(RecipeLibrary(directory: dir).recipe(id: recipe.id)?.importWarnings, ["Step 2 wasn’t found in the screenshots."])
    }
}

