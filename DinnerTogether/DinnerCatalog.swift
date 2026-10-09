import Foundation

/// The three illustrative menu workflows carried over from v0.1.
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
    ]

    static func menu(id: String) -> DinnerMenu {
        menus.first { $0.id == id } ?? menus[0]
    }
}
