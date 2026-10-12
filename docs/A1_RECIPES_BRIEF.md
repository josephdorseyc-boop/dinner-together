# Agent 1 brief: "Your recipes" verification (A1-R series)

From: Agent 3 · October 11, 2026 · via Joe
Plan: `docs/RECIPES_PLAN.md`. Branch: `wip/recipes` (pushes run
`engine-quick.yml`, the Linux harness, ~1 min; dispatch `native-validation`
on the branch for the full macOS pass).

## New code to verify

- `DinnerTogether/RecipeImporter.swift` — pure: JSON-LD (`Recipe` in arrays,
  `@graph`, `mainEntity`; `HowToStep`, `HowToSection`, strings), microdata
  fallback, wrapper-page redirects (apple.news), pasted-text parser,
  `minutes(in:)`, `isHandsOff`, `stepTitle`, `build` (meanwhile → second
  dish; estimates scaled up to a stated total).
- `DinnerTogether/RecipeLibrary.swift` — `RecipeLibrary` (JSON + image
  folder in Documents), `MenuProviding`, `URLSessionRecipeFetcher` (the only
  network call: ephemeral, no cookies, 15 s, 6 MB cap), `RecipeImportService`.
- `SessionStore` gained `menuProvider` and `menuIsMissing`.
- `DinnerTogetherTests/RecipeTests.swift` — 26 tests; Linux harness green.

## Your deliverables

**R1 — Fixture corpus.** 20 real recipe pages saved as HTML fixtures (strip
images/scripts except `ld+json`), across: Dotdash Meredith (EatingWell,
Allrecipes, Food & Wine, Serious Eats, Simply Recipes), NYT Cooking, BBC Good
Food, Bon Appétit/Epicurious, Food52, WPRM and Tasty Recipes WordPress blogs,
one microdata-only page, one page with no recipe. For each: expected title,
ingredient count, step count, stated total. One parameterized test.

**R2 — Apple News links.** On a real device: News+ Food recipe → Share →
Copy Link → what URL is it, and what does fetching it return? If it does not
reach the publisher page, report the HTML shape so the redirect finder can
be extended.

**R3 — Duration extraction audit.** Run `minutes(in:)` over every step in
R1; list wrong answers. Known gaps to check: "1½ to 2 hours", "45 sec",
"10 min.", "1-hour", times that are not durations ("350°F for 1 hour" fine;
"a 9-by-13-inch pan" must be nil).

**R4 — XCUITests** (`DinnerTogetherUITests`): add recipe by pasted text
(seed the pasteboard is not possible — type into `recipe-text`), confirm on
the Timing tab (`timing-looks-right`), "Cook this" (`cook-this-recipe`) →
Tonight shows Selected: <title> → Build plan → Cooking shows the first step.
Delete the recipe that is tonight's dinner (no progress) → Tonight falls back
to Steak night. Identifiers are in `RecipeViews.swift`.

**R5 — Verification pass** on each build as usual (A1-R5a, b…).
