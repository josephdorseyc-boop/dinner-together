import XCTest
@testable import DinnerTogether

// Joe's build-11 import (October 13): Southern Living's "Lavender-Ginger
// Meringue Twists" from Apple News+ Food in Cook mode — one screenshot per
// step. Each page shows the tabs, a small "Step n" navigation label with the
// recipe title under it, the big "STEP n" with the step, and the next step
// dimmed below. The cover has Cook/Save/Share, "Read the Story" and a story
// teaser but no Total Time or Yield labels. What arrived in build 11: the
// title "0001 -" (read off the cover photo), the title twice as step 1, the
// teaser as step 2, "Today News+ Audio Following Search" as step 3, and the
// title in place of "Set aside." (A2-22 expected prefix, A2-26 trace, A1's
// source trace on PR #16). Three pages never reached the parser: the photo
// picker stopped at 12.

private func L(_ text: String, _ top: Double, _ left: Double = 0.06, h: Double = 0.016) -> OCRLine {
    OCRLine(text: text, top: top, left: left, height: h)
}

private let meringueTitle = "Lavender-Ginger Meringue Twists"

/// The status bar, the Ingredients/Directions tab row, the close button.
private func cookChrome() -> [OCRLine] {
    [L("11:26", 0.030, 0.10, h: 0.015), L("42", 0.030, 0.90, h: 0.012),
     L("Ingredients", 0.082, 0.28, h: 0.016), L("Directions", 0.082, 0.50, h: 0.016), L("X", 0.082, 0.92, h: 0.016)]
}

/// One Cook-mode page: step `n` in big type, the next step dimmed and cut
/// off at the bottom of the screen. The first step has no "Step 1" label.
private func cookPage(_ n: Int, _ active: [String], next: (Int, [String])? = nil, trailing: [OCRLine] = []) -> [OCRLine] {
    var lines = cookChrome()
    if n > 1 { lines.append(L("Step \(n)", 0.131, 0.42, h: 0.016)) }
    lines.append(L(meringueTitle, 0.154, 0.30, h: 0.013))
    lines.append(L("STEP \(n)", 0.210, h: 0.018))
    var y = 0.260
    for line in active { lines.append(L(line, y, h: 0.035)); y += 0.051 }
    if let (m, dimmed) = next {
        y += 0.12
        lines.append(L("STEP \(m)", y, h: 0.018)); y += 0.05
        for line in dimmed where y < 0.98 { lines.append(L(line, y, h: 0.035)); y += 0.051 }
    }
    return lines + trailing
}

private let meringueCover: [OCRLine] = [
    L("11:25", 0.030, 0.10, h: 0.015), L("42", 0.030, 0.90, h: 0.012),
    L("0001 -", 0.300, 0.40, h: 0.050),                       // the photo's swirls, read as a number
    L("Lavender-Ginger", 0.511, h: 0.030), L("Meringue Twists", 0.550, h: 0.030),
    L("Southern Living · Paige Grandjean", 0.582),
    L("Cook", 0.677, 0.16), L("Save", 0.677, 0.46), L("Share", 0.677, 0.76),
    L("Read the Story", 0.727, 0.21), L(meringueTitle, 0.750, 0.21),
    L("An ultra-creative use for meringue, these", 0.810), L("sophisticated confections will be the show-", 0.835),
    L("stopper on your dessert table.", 0.859),
    L("Today", 0.955, 0.16, h: 0.012), L("News+", 0.955, 0.33, h: 0.012), L("Audio", 0.955, 0.49, h: 0.012),
    L("Following", 0.955, 0.66, h: 0.012), L("Search", 0.955, 0.83, h: 0.012),
]

/// The Recipes-view ingredients page: the cover's text bleeds through the
/// glass at the top; the first step sits under the floating News button.
private let meringueIngredients: [OCRLine] = [
    L("Cook", 0.003, 0.16), L("Save", 0.003, 0.46), L("Share", 0.003, 0.76),
    L("11:25", 0.030, 0.10, h: 0.015), L("42", 0.030, 0.90, h: 0.012),
    L("Read the Story", 0.050, 0.21), L(meringueTitle, 0.074, 0.21), L("Meringue Twists", 0.095, 0.40),
    L("An ultra-creative use for meringue, these", 0.135), L("sophisticated confections will be the show-", 0.158),
    L("stopper on your dessert table.", 0.182),
    L("Ingredients", 0.279, h: 0.022),
    L("Basic Meringue , divided", 0.346),
    L(".5 teaspoon finely grated fresh ginger", 0.420),
    L(".25 teaspoon lavender extract (such", 0.494), L("as Angel Bake)", 0.520),
    L("Food coloring gel (such as Wilton", 0.594), L("Violet and Royal Blue)", 0.620),
    L("Add to Grocery List", 0.695, 0.30), L("in Reminders", 0.721, 0.30),
    L("Directions", 0.838, h: 0.022),
    L("STEP 1", 0.874, h: 0.014),
    L("Preheat oven to 200°F with rack in lower", 0.908),
    L("third position.", 0.938),
    L("STEP 2", 0.988, h: 0.014),
]

private let meringueSteps: [[String]] = [
    ["Preheat oven to 200°F", "with rack in lower third", "position."],
    ["Spread about ⅛", "teaspoon of the Basic", "Meringue into each", "corner of 2 unrimmed", "baking sheets; line each",
     "baking sheet with", "parchment paper, and", "press into meringue to", "hold parchment paper", "in place."],
    ["Set aside."],
    ["Gently stir ginger and", "lavender extract into", "remaining Basic", "Meringue in mixing", "bowl using a rubber",
     "spatula until evenly", "incorporated."],
    ["Transfer one-fourth of", "the meringue mixture", "(about 1 cup) to a", "medium bowl, and stir in", "a very small amount of",
     "violet food coloring", "gel."],
    ["Repeat process with", "one-fourth of the", "meringue mixture and", "royal blue food coloring", "in a separate bowl.",
     "Leave remaining", "meringue mixture", "undyed."],
    ["Transfer about half of", "each meringue mixture", "to 3 separate large", "piping bags with a ½-", "inch hole cut in the", "corner."],
    ["Place all 3 piping bags", "inside 1 large (about 18-", "inch) piping bag fitted", "with a ⅓-inch open star", "tip."],
    ["Pipe into 5-inch-long,", "about 2-inch-wide,", "zigzag patterns on", "prepared baking sheets,", "allowing the 3 colors to",
     "swirl together as you", "pipe."],
    ["Alternatively, if desired,", "arrange 14 (6-inch)", "lollipop sticks on", "prepared baking sheets,", "and pipe zigzag",
     "patterns onto sticks,", "leaving 3 inches of", "each stick uncovered as", "a handle."],
    ["Refill piping bags with", "remaining meringue", "mixtures as needed, and", "space meringue twists", "at least 1 inch apart on",
     "prepared baking sheets.", "You should have 14", "meringue twists total."],
    ["Bake meringues in", "preheated oven until dry", "and no longer sticky,", "© 1 ½ to 2 ½ hours .", "Turn oven off, and let",
     "meringues cool", "completely in oven until", "crisp, at least", "© 2 hours or up to", "© 12 hours ."],
    ["Meringues can be", "stored in an airtight", "container at room", "temperature up to 1", "week."],
]

private let meringueExpected: [String] = [
    "Preheat oven to 200°F with rack in lower third position.",
    "Spread about ⅛ teaspoon of the Basic Meringue into each corner of 2 unrimmed baking sheets; line each baking sheet with parchment paper, and press into meringue to hold parchment paper in place.",
    "Set aside.",
    "Gently stir ginger and lavender extract into remaining Basic Meringue in mixing bowl using a rubber spatula until evenly incorporated.",
    "Transfer one-fourth of the meringue mixture (about 1 cup) to a medium bowl, and stir in a very small amount of violet food coloring gel.",
    "Repeat process with one-fourth of the meringue mixture and royal blue food coloring in a separate bowl. Leave remaining meringue mixture undyed.",
    "Transfer about half of each meringue mixture to 3 separate large piping bags with a ½-inch hole cut in the corner.",
    "Place all 3 piping bags inside 1 large (about 18-inch) piping bag fitted with a ⅓-inch open star tip.",
    "Pipe into 5-inch-long, about 2-inch-wide, zigzag patterns on prepared baking sheets, allowing the 3 colors to swirl together as you pipe.",
    "Alternatively, if desired, arrange 14 (6-inch) lollipop sticks on prepared baking sheets, and pipe zigzag patterns onto sticks, leaving 3 inches of each stick uncovered as a handle.",
    "Refill piping bags with remaining meringue mixtures as needed, and space meringue twists at least 1 inch apart on prepared baking sheets. You should have 14 meringue twists total.",
    "Bake meringues in preheated oven until dry and no longer sticky, 1 ½ to 2 ½ hours. Turn oven off, and let meringues cool completely in oven until crisp, at least 2 hours or up to 12 hours.",
    "Meringues can be stored in an airtight container at room temperature up to 1 week.",
]

/// Cook-mode page for step n (1-based), with the next step dimmed below it;
/// the last page carries the "Mark as Cooked" button instead.
private func meringuePage(_ n: Int) -> [OCRLine] {
    let i = n - 1
    if n == meringueSteps.count {
        return cookPage(n, meringueSteps[i], trailing: [L("Mark as Cooked", 0.910, 0.35)])
    }
    return cookPage(n, meringueSteps[i], next: (n + 1, meringueSteps[i + 1]))
}

final class CookModeScreenshotTests: XCTestCase {

    func testJoesMeringueCookModeScreenshotsImportCleanly() throws {
        var pages = [meringueCover, meringueIngredients]
        pages += (1...meringueSteps.count).map(meringuePage)
        let r = try RecipeImporter.parse(screenshots: pages)
        XCTAssertEqual(r.title, meringueTitle, "the title repeated under the tabs on every Cook-mode page, not the photo's '0001 -'")
        XCTAssertEqual(r.source.publisher, "Southern Living")
        XCTAssertEqual(r.source.author, "Paige Grandjean")
        XCTAssertNil(r.totalMinutes, "Southern Living states no total time")
        XCTAssertEqual(r.ingredients, ["Basic Meringue, divided", ".5 teaspoon finely grated fresh ginger",
                                       ".25 teaspoon lavender extract (such as Angel Bake)",
                                       "Food coloring gel (such as Wilton Violet and Royal Blue)"])
        XCTAssertEqual(r.directions.count, meringueExpected.count, r.directions.joined(separator: "\n"))
        for (got, want) in zip(r.directions, meringueExpected) { XCTAssertEqual(got, want) }
        XCTAssertEqual(r.warnings, [], "a complete set of pages raises nothing")
        let all = r.directions.joined(separator: " ")
        for junk in ["0001", "Today", "Following", "Search", "ultra-creative", "Read the Story", "Mark as Cooked", "Step 3"] {
            XCTAssertFalse(all.contains(junk), "\(junk) is not a direction")
        }
        XCTAssertEqual(all.components(separatedBy: meringueTitle).count - 1, 0, "the title never appears as a step")
    }

    func testShortStepBesideItsHeaderSurvives() throws {
        // A2-26's fixture: the cover (with the photo read as "0001 -") and
        // the Step 3 page alone. The step is "Set aside.", never the title.
        let r = try RecipeImporter.parse(screenshots: [meringueCover, meringuePage(3)])
        XCTAssertEqual(r.title, meringueTitle)
        XCTAssertEqual(r.directions.first, "Set aside.")
        XCTAssertTrue(r.warnings.contains { $0.contains("Steps 1, 2 weren’t found") }, "\(r.warnings)")
    }

    func testSelectionOrderDoesNotMatter() throws {
        var pages = (1...meringueSteps.count).map(meringuePage).reversed() + [meringueIngredients, meringueCover]
        pages.swapAt(2, 9)
        let r = try RecipeImporter.parse(screenshots: Array(pages))
        XCTAssertEqual(r.title, meringueTitle)
        XCTAssertEqual(r.directions, meringueExpected)
        XCTAssertEqual(r.warnings, [])
    }

    func testMissingPagesAreToldNotRenumbered() throws {
        // Pages for steps 1, 2 and 5 only (the picker's old limit of 12 cut
        // Joe's last three pages). Step 3 is complete in the dimmed copy on
        // the step-2 page; step 4 was never seen, and the import says so
        // instead of closing the gap.
        let r = try RecipeImporter.parse(screenshots: [meringueCover, meringuePage(1), meringuePage(2), meringuePage(5)])
        XCTAssertEqual(r.directions.map { String($0.prefix(12)) }, ["Preheat oven", "Spread about", "Set aside.", "Transfer one", "Repeat proce"])
        XCTAssertTrue(r.warnings.contains("Step 4 wasn’t found in the screenshots."), "\(r.warnings)")
        XCTAssertTrue(r.warnings.contains("The last step may be cut off — check it against your recipe."),
                      "the dimmed, cut-off copy of step 6 is the last text: \(r.warnings)")
        let recipe = RecipeImporter.build(r, method: .photo)
        XCTAssertEqual(recipe.importWarnings, r.warnings, "the warnings reach the saved recipe")
    }

    func testUnreadableLinesAreCounted() throws {
        var page = meringuePage(4)
        page.append(L("απο the bowl πλοαγυ ou am", 0.70, h: 0.035))
        let r = try RecipeImporter.parse(screenshots: [meringueCover, meringuePage(1), meringuePage(2), meringuePage(3), page])
        XCTAssertEqual(r.directions[3], meringueExpected[3])
        XCTAssertTrue(r.warnings.contains("One line couldn’t be read clearly and was left out."), "\(r.warnings)")
    }

    func testCoverWithoutTimeLabelsIsACover() throws {
        let r = try RecipeImporter.parse(screenshots: [meringueCover, meringueIngredients])
        XCTAssertEqual(r.title, meringueTitle)
        XCTAssertEqual(r.directions, ["Preheat oven to 200°F with rack in lower third position."],
                       "the cover's teaser and buttons are not steps; the empty STEP 2 heading is told, not scheduled")
        XCTAssertEqual(r.warnings, ["Step 2 wasn’t found in the screenshots."])
    }

    func testSplitNewsTabRowIsChromeButASentenceIsNot() throws {
        let page = cookPage(2, meringueSteps[1]) + [
            L("Today", 0.955, 0.16, h: 0.012), L("News+", 0.955, 0.33, h: 0.012), L("Audio", 0.955, 0.49, h: 0.012),
            L("Following", 0.955, 0.66, h: 0.012), L("Search", 0.955, 0.83, h: 0.012),
        ]
        let r = try RecipeImporter.parse(screenshots: [meringuePage(1), page])
        XCTAssertEqual(r.directions, Array(meringueExpected.prefix(2)))
        let bare = [L("Ingredients", 0.08, h: 0.022), L("2 eggs", 0.14), L("Directions", 0.20, h: 0.022),
                    L("Search the pantry for more flour.", 0.26), L("Notes", 0.32, 0.10), L("Tips", 0.32, 0.60)]
        let plain = try RecipeImporter.parse(screenshots: [bare])
        XCTAssertEqual(plain.directions, ["Search the pantry for more flour."], "one tab word in a sentence is a sentence; a row of two is a tab bar")
    }

    func testTallMarksWithoutLettersAreNotATitle() throws {
        let page = [L("0001 -", 0.10, h: 0.05), L("Lemon Posset", 0.20, h: 0.04), L("1 cup cream", 0.30), L("1 lemon", 0.34),
                    L("½ cup sugar", 0.38), L("Heat the cream and stir in the lemon juice.", 0.44)]
        XCTAssertEqual(try RecipeImporter.parse(screenshots: [page]).title, "Lemon Posset")
        let junkOnly = [L("0001 -", 0.10, h: 0.05), L("1 cup cream", 0.30), L("1 lemon", 0.34),
                        L("Heat the cream and stir in the lemon juice.", 0.40)]
        XCTAssertEqual(try RecipeImporter.parse(screenshots: [junkOnly]).title, "Untitled recipe")
    }

    func testOneCookModePageStillNamesTheRecipe() throws {
        // One page, nothing repeated: the heading directly under the tabs
        // with "STEP 4" after it is the recipe's name; the big step text is
        // never promoted to a title.
        let r = try RecipeImporter.parse(screenshots: [meringuePage(4)])
        XCTAssertEqual(r.title, meringueTitle)
        XCTAssertEqual(r.directions.first, meringueExpected[3])
        let noHeading = meringuePage(4).filter { $0.text != meringueTitle }
        XCTAssertEqual(try RecipeImporter.parse(screenshots: [noHeading]).title, "Untitled recipe",
                       "without the heading, the tall step text under STEP 4 is still not a title")
    }

    func testHyphensAfterNumbersSurviveTheWrap() {
        XCTAssertEqual(RecipeImporter.joinLines(["piping bags with a ½-", "inch hole cut in the"]), "piping bags with a ½-inch hole cut in the")
        XCTAssertEqual(RecipeImporter.joinLines(["1 large (about 18-", "inch) piping bag"]), "1 large (about 18-inch) piping bag")
        XCTAssertEqual(RecipeImporter.joinLines(["will be the show-", "stopper on your table."]), "will be the showstopper on your table.")
        XCTAssertEqual(RecipeImporter.joinLines(["pour the mixture -", "slowly"]), "pour the mixture - slowly")
    }
}
