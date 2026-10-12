import Foundation

/// Illustrative menu workflows, including the original v0.1 dinners.
/// Timings are planning estimates, NOT tested recipes. `handsOn` marks steps
/// that need the cook's attention, which powers the attention warnings and the
/// "needs you vs. hands-off" distinction on the cooking screen.
enum DinnerCatalog {
    static func step(
        _ id: String, _ dish: String, _ title: String, _ minutes: Int,
        _ detail: String, handsOn: Bool = true
    ) -> CookingStep {
        CookingStep(id: id, dish: dish, title: title, minutes: minutes, detail: detail, handsOn: handsOn)
    }

    static let menus: [DinnerMenu] = [
        DinnerMenu(
            id: "steak", title: "Steak night",
            subtitle: "Steak au poivre · mash · green beans", symbol: "flame",
            dishes: [
                [
                    step("s1", "Steak", "Prep the steak & sauce ingredients", 10,
                         "Gather your preferred steak au poivre recipe. Crush pepper and measure sauce ingredients. Timing is a planning estimate; verify doneness using your recipe and a thermometer."),
                    step("s2", "Steak", "Cook the steak", 20,
                         "Use your chosen recipe and adjust this estimate to your steak's thickness and cooking method."),
                    step("s3", "Steak", "Rest steak & finish sauce", 10,
                         "Rest the steak according to your recipe. Make the pan sauce during the rest so it is ready for serving."),
                ],
                [
                    step("p1", "Mash", "Peel & cut potatoes", 10,
                         "Cut evenly so the pieces cook at a similar pace."),
                    step("p2", "Mash", "Cook potatoes until tender", 20,
                         "Check tenderness; allow more time if needed.", handsOn: false),
                    step("p3", "Mash", "Drain, mash & season", 5,
                         "Add your preferred butter or milk and season to taste."),
                ],
                [
                    step("b1", "Green beans", "Trim beans & prep garlic", 5,
                         "Wash and trim beans; chop garlic."),
                    step("b2", "Green beans", "Cook & season beans", 10,
                         "Cook using your preferred method and finish to taste."),
                ],
            ]
        ),
        DinnerMenu(
            id: "pasta", title: "A little pasta therapy",
            subtitle: "Garlic mushroom pasta · salad", symbol: "leaf",
            dishes: [
                [
                    step("m1", "Pasta", "Prep mushrooms & garlic", 10,
                         "Slice mushrooms, chop garlic, and gather pasta and sauce ingredients."),
                    step("m2", "Pasta", "Boil water & sauté mushrooms", 10,
                         "Use the pot and skillet in parallel. Water heating time varies."),
                    step("m3", "Pasta", "Cook pasta & finish sauce", 12,
                         "Follow the pasta package and your sauce recipe. Reserve pasta water before draining."),
                    step("m4", "Pasta", "Toss, season & plate", 3,
                         "Combine pasta and sauce; loosen with reserved pasta water as needed."),
                ],
                [
                    step("l1", "Salad", "Wash & chop salad", 8,
                         "Gather your favorite greens and toppings."),
                    step("l2", "Salad", "Dress & toss", 2,
                         "Dress just before serving."),
                ],
            ]
        ),
        DinnerMenu(
            id: "salmon", title: "An easy salmon evening",
            subtitle: "Salmon · rice · broccoli", symbol: "sun.max",
            dishes: [
                [
                    step("f1", "Salmon", "Preheat & prepare salmon", 10,
                         "Follow your chosen salmon recipe for oven temperature and seasoning."),
                    step("f2", "Salmon", "Cook salmon", 15,
                         "Timing varies with thickness and method. Check doneness with a thermometer and your recipe.", handsOn: false),
                    step("f3", "Salmon", "Finish & plate", 5,
                         "Add your preferred sauce or garnish just before serving."),
                ],
                [
                    step("r1", "Rice", "Measure rice & water", 5,
                         "Use the ratios on your rice package."),
                    step("r2", "Rice", "Cook rice", 20,
                         "Follow package instructions; rice varieties have different cooking times.", handsOn: false),
                    step("r3", "Rice", "Rest & fluff rice", 10,
                         "Follow the package resting instructions, then fluff.", handsOn: false),
                ],
                [
                    step("v1", "Broccoli", "Cut broccoli", 5,
                         "Cut into even florets."),
                    step("v2", "Broccoli", "Cook & season broccoli", 10,
                         "Steam or sauté until done to your preference."),
                ],
            ]
        ),
        DinnerMenu(
            id: "lemon-chicken", title: "A lemon chicken evening",
            subtitle: "Lemon chicken · couscous · zucchini", symbol: "sun.max",
            dishes: [
                [
                    step("lc-c1", "Lemon chicken", "Prepare chicken & preheat", 15,
                         "Follow your chosen lemon chicken recipe for the cut, seasoning and oven temperature. Adjust all estimates to its method."),
                    step("lc-c2", "Lemon chicken", "Roast the chicken", 25,
                         "Use a recipe with a hands-off roasting stage. Check doneness with your recipe and a thermometer; the timer is a prompt to check, not proof it is ready.", handsOn: false),
                    step("lc-c3", "Lemon chicken", "Rest & finish chicken", 10,
                         "Follow your recipe for resting, any sauce and serving. This includes active finishing; do not assume the estimate determines doneness."),
                ],
                [
                    step("lc-q1", "Couscous", "Measure couscous & heat liquid", 10,
                         "Use your couscous package and recipe for quantities, liquid temperature and heating method."),
                    step("lc-q2", "Couscous", "Let couscous absorb", 10,
                         "Choose a recipe with a covered absorption stage; match its duration and check texture when the timer ends. This estimate is not for pearl couscous.", handsOn: false),
                    step("lc-q3", "Couscous", "Fluff & season couscous", 5,
                         "Follow your recipe for fluffing and seasoning; confirm texture before serving."),
                ],
                [
                    step("lc-z1", "Zucchini", "Slice zucchini & prepare seasonings", 8,
                         "Follow your zucchini recipe for the cut size and seasonings; set its cooking estimate before starting."),
                    step("lc-z2", "Zucchini", "Sauté & season zucchini", 12,
                         "Stay with the pan and follow your recipe for heat, stirring and desired texture; extend the estimate if needed."),
                ],
            ]
        ),
        DinnerMenu(
            id: "turkey-tacos", title: "A taco kind of night",
            subtitle: "Turkey tacos · black beans · crunchy slaw", symbol: "flame",
            dishes: [
                [
                    step("tt-t1", "Turkey tacos", "Prepare filling & taco toppings", 15,
                         "Follow your turkey taco recipe for filling ingredients and toppings. Gather tortillas and allow time for its warming method."),
                    step("tt-t2", "Turkey tacos", "Cook the turkey filling", 20,
                         "Stay with the skillet; follow your recipe for stirring and heat. Verify doneness with a thermometer and the recipe, not the timer."),
                    step("tt-t3", "Turkey tacos", "Warm tortillas & assemble tacos", 5,
                         "Follow your recipe for warming tortillas and assembling. Adjust this estimate for your number of tacos and warming method."),
                ],
                [
                    step("tt-b1", "Black beans", "Prepare cooked beans & seasonings", 8,
                         "Use already-cooked or canned beans and your chosen recipe. This workflow does not include soaking or cooking dried beans."),
                    step("tt-b2", "Black beans", "Heat & season beans", 12,
                         "Follow your recipe for heating and seasoning; stay available to stir and check the beans."),
                ],
                [
                    step("tt-s1", "Crunchy slaw", "Slice slaw & mix dressing", 10,
                         "Use your slaw recipe for vegetables and dressing; keep dressing separate until the finishing step if it advises that."),
                    step("tt-s2", "Crunchy slaw", "Dress & toss slaw", 5,
                         "Follow your recipe for dressing and tossing, and check the texture before serving."),
                ],
            ]
        ),
        DinnerMenu(
            id: "tofu-bowls", title: "Crisp tofu, cozy bowls",
            subtitle: "Roasted tofu · rice · cucumber slaw", symbol: "leaf",
            dishes: [
                [
                    step("tb-t1", "Roasted tofu", "Prepare tofu & preheat", 15,
                         "Choose a vegetarian roasted tofu recipe. Use ready-to-cook firm tofu; if your recipe requires a longer pressing or marinating stage, add that time to this estimate."),
                    step("tb-t2", "Roasted tofu", "Roast tofu", 25,
                         "Use a recipe whose roasting stage does not require turning or glazing. Follow its oven temperature and check texture when the timer ends; adjust the estimate if it needs longer.", handsOn: false),
                    step("tb-t3", "Roasted tofu", "Sauce & finish tofu", 5,
                         "Follow your recipe for sauce and finishing; check texture before serving. Choose vegetarian sauce ingredients."),
                ],
                [
                    step("tb-r1", "Rice", "Measure rice & bring to a simmer", 8,
                         "Follow the rice package and recipe for quantities and heating; adjust this estimate to your hob and rice variety."),
                    step("tb-r2", "Rice", "Cook rice, covered", 20,
                         "Use a recipe with a covered absorption stage. Follow its heat and duration instructions and check the rice when the timer ends.", handsOn: false),
                    step("tb-r3", "Rice", "Rest rice, covered", 7,
                         "Follow your rice recipe or package for the resting stage; change this estimate if it specifies a different rest.", handsOn: false),
                    step("tb-r4", "Rice", "Fluff & portion rice", 3,
                         "Follow your recipe for fluffing and portioning; confirm texture before serving."),
                ],
                [
                    step("tb-s1", "Cucumber slaw", "Cut cucumber & prepare dressing", 10,
                         "Follow your vegetarian cucumber slaw recipe for vegetables and dressing; reserve any dressing it says to add at serving."),
                    step("tb-s2", "Cucumber slaw", "Dress & toss cucumber slaw", 3,
                         "Follow your recipe for tossing and serving; adjust this estimate for the amount you are making."),
                ],
            ]
        ),
        DinnerMenu(
            id: "chickpea-curry", title: "Chickpea comfort",
            subtitle: "Chickpea curry · rice · cucumber yogurt", symbol: "leaf",
            dishes: [
                [
                    step("cc-c1", "Chickpea curry", "Prepare curry ingredients", 10,
                         "Follow your vegetarian curry recipe and use already-cooked or canned chickpeas. This plan does not include cooking dried chickpeas."),
                    step("cc-c2", "Chickpea curry", "Cook the curry base", 10,
                         "Stay with the pan and follow your recipe for heat, aromatics and stirring; the estimate does not determine when the base is ready."),
                    step("cc-c3", "Chickpea curry", "Simmer the curry", 20,
                         "Follow your recipe for simmering and stirring. This stage is labeled hands-on because the curry may need attention; check texture rather than relying on the timer."),
                    step("cc-c4", "Chickpea curry", "Season & finish curry", 5,
                         "Follow your recipe for final seasoning and serving; check that the curry is ready before completing this step."),
                ],
                [
                    step("cc-r1", "Rice", "Measure rice & bring to a simmer", 8,
                         "Follow the rice package and recipe for water ratios and heating; adjust the estimate for your rice and hob."),
                    step("cc-r2", "Rice", "Cook rice, covered", 20,
                         "Use a covered absorption recipe; follow its heat and duration instructions and check texture when the timer ends.", handsOn: false),
                    step("cc-r3", "Rice", "Rest rice, covered", 7,
                         "Follow your rice recipe or package for resting; change the estimate to match it.", handsOn: false),
                    step("cc-r4", "Rice", "Fluff & portion rice", 3,
                         "Follow your recipe for fluffing and portioning; confirm texture before serving."),
                ],
                [
                    step("cc-y1", "Cucumber yogurt", "Prepare cucumber & herbs", 7,
                         "Follow your cucumber yogurt recipe for preparation and any draining stage; adjust this estimate if draining takes longer."),
                    step("cc-y2", "Cucumber yogurt", "Mix & season cucumber yogurt", 3,
                         "Follow your recipe for mixing and seasoning. Use vegetarian ingredients and keep it chilled as your recipe directs."),
                ],
            ]
        ),
        DinnerMenu(
            id: "gnocchi-greens", title: "Golden gnocchi & greens",
            subtitle: "Skillet gnocchi · lemony salad", symbol: "leaf",
            dishes: [
                [
                    step("gg-g1", "Skillet gnocchi", "Prepare gnocchi & vegetables", 10,
                         "Choose a vegetarian skillet gnocchi recipe using ready-made gnocchi suitable for its method. This estimate does not include making gnocchi from scratch."),
                    step("gg-g2", "Skillet gnocchi", "Cook gnocchi & vegetables", 20,
                         "Stay with the skillet; follow your recipe for heat, turning and texture. If your gnocchi needs separate boiling, include that work in this estimate."),
                    step("gg-g3", "Skillet gnocchi", "Finish & plate gnocchi", 5,
                         "Follow your recipe for finishing and plating; choose vegetarian toppings and check texture before marking done."),
                ],
                [
                    step("gg-s1", "Lemony salad", "Wash greens & mix dressing", 10,
                         "Follow your salad recipe for greens and lemon dressing; leave dressing separate if the recipe advises that."),
                    step("gg-s2", "Lemony salad", "Dress & toss salad", 3,
                         "Follow your recipe for dressing and tossing just before serving; adjust for the amount of salad."),
                ],
            ]
        ),
        DinnerMenu(
            id: "pork-supper", title: "A slower Sunday supper",
            subtitle: "Pork tenderloin · mash · green beans", symbol: "sun.max",
            dishes: [
                [
                    step("ps-p1", "Pork tenderloin", "Prepare tenderloin & preheat", 15,
                         "Follow a pork tenderloin recipe for preparation and oven temperature. This workflow is not for a large pork shoulder or a slow-cooked roast."),
                    step("ps-p2", "Pork tenderloin", "Roast the tenderloin", 30,
                         "Use a recipe with a hands-off roasting stage; adjust for the size and method. Verify doneness with a thermometer and your recipe before completing.", handsOn: false),
                    step("ps-p3", "Pork tenderloin", "Rest the tenderloin", 10,
                         "Follow your recipe for resting after checking doneness. The resting estimate does not replace its temperature or food-handling instructions.", handsOn: false),
                    step("ps-p4", "Pork tenderloin", "Slice & finish tenderloin", 5,
                         "Follow your recipe for slicing, sauce and serving; confirm the food is ready before marking done."),
                ],
                [
                    step("ps-m1", "Mash", "Peel & cut potatoes", 10,
                         "Follow your mash recipe for potato size and preparation; adjust the cooking estimate to the pieces you cut."),
                    step("ps-m2", "Mash", "Cook potatoes", 20,
                         "Follow your recipe for the cooking method and heat. Use a hands-off boiling stage and check tenderness when the timer ends.", handsOn: false),
                    step("ps-m3", "Mash", "Drain, mash & season", 5,
                         "Follow your recipe for draining, mashing and seasoning; confirm tenderness before serving."),
                ],
                [
                    step("ps-b1", "Green beans", "Trim beans & prepare seasonings", 7,
                         "Follow your green bean recipe for preparation and seasonings; adjust the cooking estimate for its method."),
                    step("ps-b2", "Green beans", "Cook & finish green beans", 8,
                         "Stay with the pan and follow your recipe for heat and desired texture; change the estimate if they need longer."),
                ],
            ]
        ),
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

    static func menu(id: String) -> DinnerMenu {
        menus.first { $0.id == id } ?? menus[0]
    }
}
