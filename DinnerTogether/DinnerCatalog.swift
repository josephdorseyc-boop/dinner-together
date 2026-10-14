import Foundation

/// The one dinner the app still brings with it: Thanksgiving. Everything
/// else the cook brings in as their own recipes (Joe, October 14: "people
/// like to use their own recipes they found on the internet"). Timings are
/// planning estimates, NOT a tested recipe. `handsOn` marks steps that need
/// the cook's attention, which powers the attention warnings and the
/// "needs you vs. hands-off" distinction on the cooking screen.
enum DinnerCatalog {
    static func step(
        _ id: String, _ dish: String, _ title: String, _ minutes: Int,
        _ detail: String, handsOn: Bool = true
    ) -> CookingStep {
        CookingStep(id: id, dish: dish, title: title, minutes: minutes, detail: detail, handsOn: handsOn)
    }

    static let thanksgivingID = "thanksgiving"

    static let menus: [DinnerMenu] = [
        DinnerMenu(
            id: "thanksgiving", title: "Thanksgiving, together",
            subtitle: "Turkey · stuffing · mash · gravy · beans · rolls", symbol: "flame",
            dishes: [
                [
                    step("tg-t1", "Turkey", "Prepare turkey & preheat", 20,
                         "Choose a recipe for a fully thawed, unstuffed turkey. Thawing and advance preparation are outside this guide. Set each estimate to your recipe and bird size before building the plan."),
                    step("tg-t2", "Turkey", "Roast turkey", 180,
                         "Three hours is an editable planning placeholder, not a doneness prediction. Follow your turkey recipe, including checks or basting; verify doneness with a thermometer. Hands-off means mainly oven time, not unattended cooking.", handsOn: false),
                    step("tg-t3", "Turkey", "Rest turkey", 30,
                         "Rest only after confirming doneness. Follow your recipe's resting and food-handling instructions; adjust this estimate to match them.", handsOn: false),
                    step("tg-t4", "Turkey", "Carve & serve turkey", 10,
                         "Follow your recipe for carving and serving. Arrange help for the final sides; this guide flags attention overlaps but does not resolve them."),
                ],
                [
                    step("tg-s1", "Stuffing", "Prepare a separate stuffing dish", 20,
                         "Use a recipe for stuffing baked separately, not inside the turkey. Include any advance preparation in your estimate. Check oven capacity and temperature compatibility with the other dishes."),
                    step("tg-s2", "Stuffing", "Bake stuffing", 30,
                         "Follow your separate-dish stuffing recipe for oven temperature and doneness. The baseline puts this after the turkey roast, but edited timings may overlap; the app does not reserve the oven.", handsOn: false),
                    step("tg-s3", "Stuffing", "Rest stuffing", 5,
                         "Use this rest only if your recipe calls for it, and adjust its duration. Follow its food-handling instructions.", handsOn: false),
                    step("tg-s4", "Stuffing", "Portion & serve stuffing", 5,
                         "Follow your recipe for finishing and serving; ask a helper to handle this while the turkey is carved."),
                ],
                [
                    step("tg-m1", "Mash", "Peel & cut potatoes", 15,
                         "Follow your mash recipe for quantities and cut size. Adjust this estimate for the number of guests."),
                    step("tg-m2", "Mash", "Cook potatoes", 25,
                         "Follow your recipe for boiling and check tenderness when the timer ends. This stage is mainly hands-off, but remain available to check the pot.", handsOn: false),
                    step("tg-m3", "Mash", "Drain, mash & season", 10,
                         "Follow your mash recipe for draining, mashing and seasoning. Plan help for finishing while the turkey is carved."),
                ],
                [
                    step("tg-g1", "Gravy", "Prepare gravy ingredients", 10,
                         "Choose a stock-based gravy recipe. Gather ingredients and use turkey drippings only if your recipe allows; adjust for any extra preparation."),
                    step("tg-g2", "Gravy", "Cook & stir gravy", 15,
                         "Stay with the pan and follow your gravy recipe for heat, stirring and consistency. This is an active task."),
                    step("tg-g3", "Gravy", "Season & finish gravy", 5,
                         "Follow your recipe for finishing and serving. Ask a helper to finish this during carving if needed."),
                ],
                [
                    step("tg-b1", "Green beans", "Trim beans & prepare seasonings", 10,
                         "Choose a green bean recipe with a steaming stage; prepare the vegetables, seasonings and steamer as it directs."),
                    step("tg-b2", "Green beans", "Steam green beans", 10,
                         "Follow your recipe for steaming and check texture when the timer ends. Adjust the estimate for your quantity and equipment.", handsOn: false),
                    step("tg-b3", "Green beans", "Season & serve beans", 5,
                         "Follow your recipe for finishing and serving. Arrange help if this overlaps carving or the other sides."),
                ],
                [
                    step("tg-r1", "Rolls", "Prepare baked rolls for warming", 10,
                         "Use already-baked rolls and your chosen recipe or package warming instructions. This guide does not include dough preparation or proving. Check oven temperature and space before starting."),
                    step("tg-r2", "Rolls", "Warm rolls", 7,
                         "Follow your recipe or package for the warming method. The baseline follows the stuffing bake; adjust for oven temperature changes or use compatible separate equipment.", handsOn: false),
                    step("tg-r3", "Rolls", "Finish & serve rolls", 3,
                         "Follow your recipe for any finishing and serving. Arrange help during the final rush."),
                ],
            ]
        ),
    ]

    static var thanksgiving: DinnerMenu { menus[0] }

    static func menu(id: String) -> DinnerMenu? {
        menus.first { $0.id == id }
    }
}
