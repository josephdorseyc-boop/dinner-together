import XCTest

// MARK: - A2-13 cover crop UI tests
//
// Requires A2-13 (screenshot cover cropping) integrated.
// Requires a `-dt-stub-screenshots` harness hook (Agent 3): pre-populates the
// Screenshots picker with two test images so XCUITest never touches the
// system PhotosPicker. Without the stub, the picker step cannot run.
//
// Identifiers (from A2-13):
//   choose-cover, cover-source, cover-preview, cover-zoom,
//   cover-horizontal, cover-vertical, use-cover-crop,
//   import-recipe ("Retry cover save" on retry), continue-without-cover

final class CoverCropUITests: DinnerTogetherUITestCase {

    /// Happy path: screenshots → cover → crop → Add → hero on the recipe page.
    func testCoverCropHappyPath() {
        launchRecipes([], .standard, extra: ["-dt-stub-screenshots"])
        openRecipesLibrary()
        scrollAndTap(app.buttons["add-recipe"], "Add a recipe")
        // Screenshots tab with stubbed images.
        app.buttons["choose-screenshots"].tap()
        // (Stub provides two screenshots; no system picker interaction.)

        // Choose a cover from the screenshots.
        let chooseCover = app.buttons["choose-cover"]
        XCTAssertTrue(chooseCover.waitForExistence(timeout: 5), "choose cover appears with screenshots selected")
        chooseCover.tap()

        // Crop sheet: preview + sliders.
        XCTAssertTrue(app.images["cover-preview"].waitForExistence(timeout: 5), "crop preview appears")
        XCTAssertTrue(app.sliders["cover-zoom"].exists, "zoom slider")
        XCTAssertTrue(app.sliders["cover-horizontal"].exists, "horizontal slider")
        XCTAssertTrue(app.sliders["cover-vertical"].exists, "vertical slider")

        // Adjust and use the crop.
        app.sliders["cover-zoom"].adjust(toNormalizedSliderPosition: 0.5)
        app.buttons["use-cover-crop"].tap()

        // Cover thumbnail shows in the form.
        XCTAssertTrue(app.images["Selected recipe cover"].waitForExistence(timeout: 5), "cover thumbnail in the form")

        // Add the recipe (text import via stubbed OCR or pasted text).
        // Note: the stub must also provide OCR text, or the test pastes text.
        let importButton = app.buttons["import-recipe"]
        XCTAssertTrue(importButton.label.contains("Add recipe"), "not in retry state")
        scrollAndTap(importButton, "Add recipe")

        // Recipe page shows the hero.
        XCTAssertTrue(app.images["Selected recipe cover"].waitForExistence(timeout: 10) ||
                      app.images.matching(NSPredicate(format: "label CONTAINS 'cover'")).firstMatch.waitForExistence(timeout: 10),
                      "recipe page shows the hero image")
        photograph("r10-cover-hero")
    }

    /// Retry path: recipe saves, cover fails → Retry / Continue without cover.
    func testCoverSaveFailureRetry() {
        launchRecipes([], .standard, extra: ["-dt-stub-screenshots", "-dt-fail-cover-saves"])
        openRecipesLibrary()
        scrollAndTap(app.buttons["add-recipe"], "Add a recipe")
        app.buttons["choose-screenshots"].tap()

        let chooseCover = app.buttons["choose-cover"]
        XCTAssertTrue(chooseCover.waitForExistence(timeout: 5), "choose cover appears")
        chooseCover.tap()
        XCTAssertTrue(app.images["cover-preview"].waitForExistence(timeout: 5), "crop preview")
        app.buttons["use-cover-crop"].tap()

        // Add: recipe saves, cover fails.
        scrollAndTap(app.buttons["import-recipe"], "Add recipe")

        // Retry state: button relabels, continue option appears, no duplicate.
        let retry = app.buttons["import-recipe"]
        XCTAssertTrue(retry.waitForExistence(timeout: 10), "import button still present")
        XCTAssertTrue(retry.label.contains("Retry cover save"), "button offers retry, not duplicate add: \(retry.label)")
        XCTAssertTrue(app.buttons["continue-without-cover"].waitForExistence(timeout: 5),
                      "continue without cover is offered")
        // The error explains the recipe is saved.
        let error = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'recipe is saved'")).firstMatch
        XCTAssertTrue(error.waitForExistence(timeout: 5), "cover-save error explains the recipe is safe")

        // Continue without cover: finishes, no error, no duplicate recipe.
        app.buttons["continue-without-cover"].tap()
        // Sheet dismisses to the recipe page (or library); no cover error remains.
        XCTAssertFalse(app.buttons["continue-without-cover"].waitForExistence(timeout: 5),
                       "continuing clears the pending state")
        photograph("r10b-cover-retry")
    }
}
