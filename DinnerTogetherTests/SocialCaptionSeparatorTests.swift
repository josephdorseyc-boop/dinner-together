import XCTest
@testable import DinnerTogether

/// Regression reconstructed from Joe's screenshots of reel DdmzFTjpZLL.
/// The live Instagram caption could not be fetched; this is not a network test.
final class SocialCaptionSeparatorTests: XCTestCase {
    private let source = URL(string: "https://www.instagram.com/reel/DdmzFTjpZLL/")!
    private let ingredients = "1 lb fresh green beans • 8 oz mushrooms, sliced • 3 tbsp butter • 4 cloves garlic, minced • 1 tbsp olive oil • ½ tsp Italian seasoning • ½ tsp red pepper flakes, optional • Salt & black pepper • 1 tbsp lemon juice • Fresh parsley"
    private let directions = "1. Blanch green beans in boiling water for 3–4 minutes, then drain. 2. Heat olive oil in a skillet and sauté mushrooms until golden. 3. Add butter and garlic, cooking for 1 minute until fragrant. 4. Stir in green beans, Italian seasoning, salt, and pepper. 5. Cook for 3–5 minutes, tossing until well coated and tender. 6. Finish with lemon juice and fresh parsley."

    private func parse(_ caption: String, platform: String = "Instagram") throws -> ImportedRecipe {
        try SocialImport.recipe(from: SocialPost(platform: platform, caption: caption, author: nil,
                                                 imageURL: nil, url: source))
    }

    func testGreenBeanScreenshotBecomesTenIngredientsAndSixSteps() throws {
        let r = try parse("Garlic Butter Green Beans\nIngredients:\n\(ingredients)\nDirections:\n\(directions)\nSAVE this easy garlic butter side dish!")
        XCTAssertEqual(r.ingredients.count, 10, "\(r.ingredients)")
        XCTAssertEqual(r.ingredients[1], "8 oz mushrooms, sliced")
        XCTAssertEqual(r.ingredients[6], "½ tsp red pepper flakes, optional")
        XCTAssertEqual(r.ingredients[7], "Salt & black pepper")
        XCTAssertEqual(r.ingredients.last, "Fresh parsley")
        XCTAssertEqual(r.directions.count, 6, "\(r.directions)")
        XCTAssertEqual(r.directions.first, "Blanch green beans in boiling water for 3–4 minutes, then drain.")
        XCTAssertEqual(r.directions.last, "Finish with lemon juice and fresh parsley.")
        XCTAssertEqual(r.directions.map { RecipeImporter.minutes(in: $0) }, [4, nil, 1, nil, 5, nil])
        XCTAssertFalse(r.directions.joined().contains("SAVE"))
        XCTAssertEqual(r.source.url, source)
    }

    func testInlineHeadingsAndTrailingPromotionOnSameLine() throws {
        let r = try parse("Garlic Butter Green Beans\nIngredients: \(ingredients)\nDirections: \(directions) SAVE this easy garlic butter side dish!")
        XCTAssertEqual(r.ingredients.count, 10)
        XCTAssertEqual(r.directions.count, 6)
        XCTAssertEqual(r.directions.last, "Finish with lemon juice and fresh parsley.")
    }

    func testHeaderlessCaptionAndTikTokUseSameCleanup() throws {
        let r = try parse("Garlic Butter Green Beans\n\(ingredients)\n\(directions)\nSAVE this easy garlic butter side dish!", platform: "TikTok")
        XCTAssertEqual(r.ingredients.count, 10)
        XCTAssertEqual(r.directions.count, 6)
        XCTAssertEqual(r.source.publisher, "TikTok")
    }

    func testParenthesizedAndKeycapNumberedLists() throws {
        for method in ["1) Boil for 4 minutes. 2) Drain and serve.",
                       "1️⃣ Boil for 4 minutes. 2️⃣ Drain and serve."] {
            let r = try parse("Green Beans\nIngredients: 1 lb beans • ½ tsp salt\nSteps: \(method)")
            XCTAssertEqual(r.ingredients.count, 2)
            XCTAssertEqual(r.directions, ["Boil for 4 minutes.", "Drain and serve."])
        }
    }

    func testFractionsDecimalsCommasAndRangesStayIntact() throws {
        let r = try parse("Slow Cooked Beans\nIngredients: 1.5 lb beans, trimmed • 1 1/2 tbsp oil • ½ tsp salt\nDirections: 1. Cook at 350°F for 1.5 hours. 2. Rest for 3–5 minutes. Save this easy recipe!")
        XCTAssertEqual(r.ingredients, ["1.5 lb beans, trimmed", "1 1/2 tbsp oil", "½ tsp salt"])
        XCTAssertEqual(r.directions, ["Cook at 350°F for 1.5 hours.", "Rest for 3–5 minutes."])
        XCTAssertEqual(RecipeImporter.minutes(in: r.directions[0]), 90)
        XCTAssertEqual(SocialImport.removingCallsToAction("Bake for 1.5 hours. Save this easy recipe!"), "Bake for 1.5 hours.")
    }

    func testFoodSavingInstructionsArePreserved() throws {
        let r = try parse("Marinated Beans\nIngredients: 1 lb beans • 1 cup marinade\nDirections: 1. Cook for 4 minutes. Save this marinade for basting later. 2. Save the remaining beans in the fridge.\nSave this easy side dish!")
        XCTAssertEqual(r.directions, ["Cook for 4 minutes. Save this marinade for basting later.", "Save the remaining beans in the fridge."])
    }

    func testAmbiguousNumbersAndOrdinarySentencesAreNotSplit() {
        for line in ["Cook for 1.5 hours. Rest, then serve.",
                     "Use dish 1. Cook for 2 minutes.",
                     "1. Cook for 4 minutes. 3. Serve.",
                     "1.5 tbsp oil", "1. Cook and serve."] {
            XCTAssertEqual(SocialImport.splitNumberedCaptionSteps(line), [line])
        }
        XCTAssertEqual(SocialImport.captionLayoutLines("A cozy dinner • perfect for fall"), ["A cozy dinner • perfect for fall"])
    }

    func testNumberedStepsOnSeparateLinesStillWork() throws {
        let r = try parse("Simple Beans\nIngredients\n1 lb beans\n½ tsp salt\nDirections\n1. Boil for 4 minutes.\n2. Drain.\n3. Serve.")
        XCTAssertEqual(r.ingredients, ["1 lb beans", "½ tsp salt"])
        XCTAssertEqual(r.directions, ["Boil for 4 minutes.", "Drain.", "Serve."])
    }
}
