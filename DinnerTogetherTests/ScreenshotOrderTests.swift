import XCTest
@testable import DinnerTogether

// MARK: - Screenshot import ordering (A1, F1 follow-up)
//
// parse(screenshots:) keys numbered "STEP n" directions by their number, so
// those survive any selection order. Unnumbered directions have no key: they
// are kept in screenshot-selection order (PhotosPicker uses .ordered), and
// overlapping unnumbered text is not deduplicated. The supported contract
// (R9 copy) is: choose images in recipe order, then check for missing or
// repeated text after import. These tests pin that contract.

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

    func testMixedNumberedAndUnnumbered() throws {
        // Numbered steps come first (sorted), unnumbered directions append
        // after — an unnumbered tip between steps 1 and 2 lands at the end.
        let pages = [page("STEP 1", "Mix the ingredients"), page("Rest the dough"), page("STEP 2", "Bake the mixture")]
        let recipe = try RecipeImporter.parse(screenshots: pages)
        XCTAssertEqual(directions(of: recipe), ["Mix the ingredients", "Bake the mixture", "Rest the dough"],
                       "unnumbered directions append after numbered steps regardless of position")
    }
}
