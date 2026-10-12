import XCTest
@testable import DinnerTogether

// MARK: - Screenshot import ordering (A1, F1 follow-up)
//
// parse(screenshots:) keys numbered "STEP n" directions by their number, so
// those survive any selection order. Unnumbered directions have no key: they
// are kept in screenshot-selection order (PhotosPicker uses .ordered), and
// overlapping unnumbered text is not deduplicated. The supported contract
// (R9 copy) is: choose images in recipe order, then check for missing or
// repeated text after import. Mixed numbered/unnumbered imports keep their
// visible order: an unnumbered direction is anchored after the numbered step
// it followed (A2-10). These tests pin that contract.

final class ScreenshotOrderTests: XCTestCase {
    private func page(_ texts: String...) -> [OCRLine] {
        texts.enumerated().map { OCRLine(text: $0.element, top: 0.1 + Double($0.offset) * 0.05) }
    }

    private func directions(of recipe: ImportedRecipe) -> [String] {
        recipe.sections.flatMap { $0.steps }
    }

    func testUnnumberedDirectionsFollowSelectionOrder() throws {
        // Agent 2's repro: two unnumbered Directions screenshots, provided in
        // reverse selection order. The importer cannot recover recipe order
        // from content alone, so it preserves selection order.
        let bakeFirst = [page("Bake the mixture"), page("Mix the ingredients")]
        let recipe = try RecipeImporter.parse(screenshots: bakeFirst)
        XCTAssertEqual(directions(of: recipe), ["Bake the mixture", "Mix the ingredients"],
                       "unnumbered directions follow selection order; choose images in recipe order")
    }

    func testUnnumberedDirectionsInRecipeOrder() throws {
        let inOrder = [page("Mix the ingredients"), page("Bake the mixture")]
        let recipe = try RecipeImporter.parse(screenshots: inOrder)
        XCTAssertEqual(directions(of: recipe), ["Mix the ingredients", "Bake the mixture"])
    }

    func testNumberedStepsSurviveAnySelectionOrder() throws {
        let reversed = [page("STEP 2", "Bake the mixture"), page("STEP 1", "Mix the ingredients")]
        let recipe = try RecipeImporter.parse(screenshots: reversed)
        XCTAssertEqual(directions(of: recipe), ["Mix the ingredients", "Bake the mixture"],
                       "numbered steps are keyed by number, not selection order")
    }

    func testOverlappingUnnumberedTextDuplicates() throws {
        // Overlapping screenshots of the same unnumbered direction are not
        // collapsed (ingredients dedupe; loose directions do not). The import
        // UI must keep telling the cook to check for repeated text.
        let overlapping = [page("Mix the ingredients"), page("Mix the ingredients", "Bake the mixture")]
        let recipe = try RecipeImporter.parse(screenshots: overlapping)
        XCTAssertEqual(directions(of: recipe).filter { $0 == "Mix the ingredients" }.count, 2,
                       "overlapping unnumbered text currently duplicates; copy must say to check")
    }

    func testMixedNumberedAndUnnumberedKeepsVisibleOrder() throws {
        // A2-10's fixture: an unnumbered direction between STEP 1 and STEP 2
        // must stay between them — never be pushed after the last numbered step.
        let pages = [page("STEP 1", "Mix the ingredients"), page("Rest the dough"), page("STEP 2", "Bake the mixture")]
        let recipe = try RecipeImporter.parse(screenshots: pages)
        XCTAssertEqual(directions(of: recipe), ["Mix the ingredients", "Rest the dough", "Bake the mixture"],
                       "unnumbered directions are anchored after the numbered step they followed")
    }

    func testUnnumberedBeforeAnyNumberedStepComesFirst() throws {
        let pages = [page("Preheat the oven"), page("STEP 1", "Mix the ingredients"), page("STEP 2", "Bake the mixture")]
        let recipe = try RecipeImporter.parse(screenshots: pages)
        XCTAssertEqual(directions(of: recipe), ["Preheat the oven", "Mix the ingredients", "Bake the mixture"])
    }

    func testNumberedStepContinuationJoinsItsStep() throws {
        // A2-10: text above a STEP n marker on the same screenshot is the end
        // of step n−1, not a separate direction.
        let pages = [page("STEP 1", "Mix the ingredients"),
                     page("Rest the dough", "STEP 2", "Bake the mixture")]
        let recipe = try RecipeImporter.parse(screenshots: pages)
        let steps = directions(of: recipe)
        XCTAssertEqual(steps.count, 2)
        XCTAssertTrue(steps[0].contains("Mix the ingredients") && steps[0].contains("Rest the dough"), steps[0])
        XCTAssertEqual(steps[1], "Bake the mixture")
    }

    func testEmptyFirstNumberedHeadingKeepsLaterText() throws {
        let pages = [page("STEP 1"), page("STEP 2", "Bake the mixture")]
        let recipe = try RecipeImporter.parse(screenshots: pages)
        XCTAssertEqual(directions(of: recipe), ["Bake the mixture"],
                       "an empty heading must not index beyond the recognized steps")
    }

    func testEmptyMiddleNumberedHeadingKeepsLaterText() throws {
        let pages = [page("STEP 1", "Mix the ingredients"), page("STEP 2"),
                     page("STEP 3", "Bake the mixture")]
        let recipe = try RecipeImporter.parse(screenshots: pages)
        XCTAssertEqual(directions(of: recipe), ["Mix the ingredients", "Bake the mixture"])
    }

    func testEmptyLastNumberedHeadingKeepsEarlierText() throws {
        let pages = [page("STEP 1", "Mix the ingredients"), page("STEP 2")]
        let recipe = try RecipeImporter.parse(screenshots: pages)
        XCTAssertEqual(directions(of: recipe), ["Mix the ingredients"])
    }

    func testLooseDirectionsAfterEmptyHeadingKeepTheirAnchor() throws {
        let pages = [page("STEP 1", "Mix the ingredients"), page("STEP 2"),
                     page("Rest the dough"), page("STEP 3", "Bake the mixture")]
        let recipe = try RecipeImporter.parse(screenshots: pages)
        XCTAssertEqual(directions(of: recipe),
                       ["Mix the ingredients", "Rest the dough", "Bake the mixture"],
                       "loose directions after an empty heading stay before the following step")
    }

    func testOnlyEmptyNumberedHeadingsHaveNoRecipeData() {
        XCTAssertThrowsError(try RecipeImporter.parse(screenshots: [page("STEP 1"), page("STEP 2")])) { error in
            XCTAssertEqual(error as? RecipeImportError, .noTextInScreenshots,
                           "empty headings cannot manufacture a recipe or crash the import")
        }
    }

}
