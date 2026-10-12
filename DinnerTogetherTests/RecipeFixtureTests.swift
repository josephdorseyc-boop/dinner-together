import XCTest
@testable import DinnerTogether

// MARK: - Real-page fixture corpus (A1-R1)
//
// HTML saved from live recipe pages, stripped of images and scripts except
// ld+json. Manifest with source URLs and verified counts:
// DinnerTogetherTests/Fixtures/manifest.json
//
// To add a page: drop the stripped HTML in Fixtures/, add its row to
// `realPages` below and to manifest.json. Dotdash Meredith sites
// (EatingWell, Allrecipes, Food & Wine, Serious Eats, Simply Recipes)
// block datacenter IPs (HTTP 402); Food52 rate-limited (429) — retry later.

final class RecipeFixtureTests: XCTestCase {
    private var fixturesURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
    }

    private func html(_ file: String) throws -> String {
        try String(contentsOf: fixturesURL.appendingPathComponent(file), encoding: .utf8)
    }

    func testRealPages() throws {
        // file, expected title, ingredients, steps, totalMinutes
        let realPages: [(String, String, Int, Int, Int?)] = [
            // PT21H30M stated by the publisher: preserved as metadata. Step
            // durations are capped separately for scheduling; the stated
            // total is not.
            ("nyt-no-knead-bread.html", "No-Knead Bread", 4, 4, 1290),
            ("bbcgoodfood-classic-lasagne.html", "Easy classic lasagne", 15, 5, 75),
            // totalTime is the raw string "40 minutes", not ISO 8601.
            // The curly apostrophe is the source's own; the importer does
            // not normalize it.
            ("bonappetit-bas-best-chocolate-chip-cookies.html", "BA’s Best Chocolate Chip Cookies", 10, 4, 40),
            // No totalTime; the importer falls back to prep + cook (5 + 3).
            // WPRM emits 10 HowToSteps, including tip/note steps.
            ("recipetineats-hollandaise-sauce.html", "Hollandaise sauce", 6, 10, 8),
            ("pinchofyum-pastina-soup.html", "Pastina Soup (Italian Penicillin)", 9, 6, 45),
        ]
        for (file, title, ingredients, steps, totalMinutes) in realPages {
            let imported = try RecipeImporter.parse(html: try html(file), url: nil)
            XCTAssertEqual(imported.title, title, file)
            XCTAssertEqual(imported.ingredients.count, ingredients, file)
            XCTAssertEqual(imported.directions.count, steps, file)
            XCTAssertEqual(imported.totalMinutes, totalMinutes, file)
        }
    }

    func testMicrodataWithoutInstructionsThrows() throws {
        // Smitten Kitchen (Jetpack markup): recipeIngredient microdata but no
        // recipeInstructions — a real coverage gap, documented here. When the
        // importer learns this pattern, update this expectation.
        XCTAssertThrowsError(
            try RecipeImporter.parse(
                html: try html("smittenkitchen-double-chocolate-banana-bread.html"), url: nil)
        ) { error in
            XCTAssertEqual(error as? RecipeImportError, .noRecipeData)
        }
    }

    func testPageWithoutRecipeThrows() throws {
        XCTAssertThrowsError(
            try RecipeImporter.parse(
                html: try html("negative-wikipedia-banana-bread.html"), url: nil)
        ) { error in
            XCTAssertEqual(error as? RecipeImportError, .noRecipeData)
        }
    }
}
