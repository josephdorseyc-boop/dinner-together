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
}

