# Agent 2 — dinners, icon and screenshot story

Prepared for Agent 3 via Joe. Baseline: `cb1a2e5005f7155761e405be186b0f6370508fd0` (`main` fetched for this review).

The repository source tree was not edited. Proposed changes are four separate patches. The original three menus and their IDs remain intact. No engine, store, notification or release-pipeline changes are proposed.

## 1. Six new dinners — implementation supplied

Apply `A2-S1-six-new-dinners.patch`. It updates `DinnerCatalog.swift` and appends `CatalogTests` to the existing test file, so no project or Package.swift registration is needed.

| Menu ID | Display name | Dishes | Longest dish chain | Meat-free guide |
|---|---|---|---|---|
| lemon-chicken | A lemon chicken evening | Lemon chicken, couscous, zucchini | 50 min | No |
| turkey-tacos | A taco kind of night | Turkey tacos, black beans, crunchy slaw | 40 min | No |
| tofu-bowls | Crisp tofu, cozy bowls | Roasted tofu, rice, cucumber slaw | 45 min | Yes |
| chickpea-curry | Chickpea comfort | Chickpea curry, rice, cucumber yogurt | 45 min | Yes |
| gnocchi-greens | Golden gnocchi & greens | Skillet gnocchi, lemony salad | 35 min | Yes |
| pork-supper | A slower Sunday supper | Pork tenderloin, mash, green beans | 60 min | No |

These are illustrative workflows, not developed or tested recipes. Durations are editable planning estimates. Meat-free guides require vegetarian ingredients in the cook's recipe; they are not allergy or vegan certifications. The tofu guide requires ready-to-cook tofu and a roasting recipe without mid-roast turning/glazing; canned or already-cooked beans/chickpeas are explicit. The Sunday guide is for tenderloin, not shoulder. These constraints prevent the short estimate from implying omitted hours of work.

Every new step detail defers to the cook's recipe, including doneness/temperature where applicable. Active simmering, sautéing, mashing, mixing, fluffing and finishing are hands-on. Covered rice absorption/resting, suitable roasting, and meat resting are passive. The existing `leaf`, `flame` and `sun.max` symbols are reused; no new symbol names are introduced.

Eight synchronous Swift tests are supplied: one planning/feasibility test per new menu, one global menu/step-ID uniqueness test, and one workflow-bounds test. If the existing suite remains 61, expected unit-test count becomes 69. No JavaScript mirror expectations require modification: that suite uses its own fixed test menu and does not assert the catalog count.

**Supplemental check, executed:** the existing JavaScript mirror plus new content fixtures passes 188 outcome assertions. Python content checks verify global step-ID uniqueness across the proposed catalog, dish/step counts, minute bounds, recipe-deference strings, three meat-free additions, and nominal attention concurrency. All four patches pass `git apply --cached --check` against the baseline in disposable indexes.

**Not performed:** Swift compilation, Swift tests, simulator rendering of the proposed changes, or cooking trials. Planning feasibility is clock/dependency feasibility, not a guarantee one cook can perform every task simultaneously. All three-dish additions have periods with three overlapping hands-on tasks; gnocchi has two. The existing attention warnings must remain visible. We have not introduced a collision-free kitchen scheduler or resource modeling.

Quantity alone does not establish App Store acceptance. The product value remains whole-meal timing and honest recovery.

## 2. D1–D4 review of the supplied run-9 renders

Evidence tier: **simulator rendering**, from the five PNGs inside the supplied r8 ZIP. These are static seeded renders, not interactive testing or physical-device testing.

- **D1 confirmed at default text size:** `iphone/expired-timer-light.png` shows the entire red “Mark done after checking” button above the tab bar. The readiness notice follows RIGHT NOW. The corresponding iPad Dark Mode render also prioritizes the urgent action.
- **D3 confirmed in the supplied iPad Dark Mode render:** the food-check caption wraps completely and the action label is readable.
- **D4 confirmed:** `ipad/late-prep-light.png` labels running times “Timer deadline” and pending intervals “Planned”. This resolves the unlabeled planned-versus-actual ambiguity.
- **D2 not closed at accessibility size — S3:** `iphone/expired-timer-ax-large-text.png` still shows “Adjust time” extending past the right edge. Default-size headers are fine. Reproduce with the expired-timer fixture and the supplied accessibility text category. Proposed fix is `A2-S2-accessibility-serving-header.patch`: explicitly stack the header label and action at accessibility sizes, retaining ViewThatFits at ordinary sizes. This patch is source-reviewed and applies cleanly; it is not compiled or rendered yet.
- The expired-timer primary button is below the initial viewport at this very large text size. That is not itself proof of clipping or unreachable content; the card is tall. Require a scroll-and-tap test and an action-area photograph before calling the accessibility flow verified. Do not shrink accessible text merely to match the default-size fold.
- The supplied Dark Mode renders preserve clear visual hierarchy and the warm palette. No numerical contrast audit or VoiceOver check was performed.

## 3. Catalog expansion exposes a planning-screen issue

**S3, source review:** PlanView places its only “Build my cooking plan” / “Back to cooking” action after every menu card. Nine menus substantially increase the distance to that action.

`A2-S3-plan-primary-action.patch` moves the existing action into a bottom safe-area inset, with the current selected menu named above it. It preserves the existing feasibility recheck and progress behavior. This avoids asking a cook to scroll through all nine dinners to start the chosen one. No source mutation was made; compilation and rendering are pending. Check iPhone, iPad, compact split width and accessibility sizes, including selecting the last menu and changing estimates enough to make the serving time infeasible.

## 4. Icon decision

Evidence tier: **supplied artwork review**; supplemental file inspection previously confirmed 1024×1024 RGB with no alpha.

Keep the current cloche for 1.0. Its recognizable silhouette and tomato/olive/cream palette are consistent with the product. The generous cream margin gives it breathing room. The soft highlight and tray shadow are acceptable; flattening them is an optional later refinement, not a release blocker. No replacement asset is supplied. A 60-point home-screen/App Store context render and dark/tinted system treatment remain unverified. Do not interpret the raw square image as a home-screen test.

## 5. Six-frame screenshot story

Use real simulator renders of the integrated app; captions frame the story and must not invent functionality. The same sequence applies to iPhone and iPad; the iPad cooking shots should show both columns.

| # | Caption | State and capture |
|---|---|---|
| 1 | Pick dinner. Pick a time. | Tonight, Steak night selected, no progress, feasible serving time. Preferred fixture: current time 6:10 PM and serving time 7:00 PM. Show the time control, selected menu and planning action. |
| 2 | Know what to do now. | Cooking, Steak night, a due and unblocked step with its start action visible. Suggested state: now 6:30 PM, serve 7:00 PM, steak prep done at 6:30, potato prep cooking from 6:25 with deadline 6:35. Keep the due steak-cooking card above the fold and no late notice. |
| 3 | Running late? Review the plan. | The late-prep cooking notice, followed by the actual Review dinner time sheet in a separate capture for selection. Prefer the sheet as the final frame if the two labeled times and action are visible. Never assert a fixed 7-minute amount if the live fixture has advanced. |
| 4 | A timer ends. You check the food. | Expired-timer cooking screen, default text size, urgent card and full primary action before scrolling. Preserve the caption explaining that expiry is not completion. |
| 5 | Nine dinners to choose from. | Tonight after catalog integration. Show several actual menu cards, including at least one new meat-free guide; choose scroll position so the cards are readable and the selected-menu footer remains coherent. Do not add an unsupported grid or menu browser just for the artwork. |
| 6 | A calmer counter, even after dark. | iPad: two-column Dark Mode cooking view. iPhone: Dark Mode cooking view with a useful action or active timer. Use a normal state rather than the most severe “way behind” warning as the closing impression. |

The preferred evening-time fixtures require the app's clock and seeded timestamps to agree. If a DEBUG fixture clock is not available, seed relative to the capture time and use a feasible time roughly 45–60 minutes ahead. Do not seed a past 7:00 PM plan at an arbitrary CI hour or paint different times over rendered UI. Record which clock method was used. Tonight should omit `-dt-open-cooking`; it needs a fresh seed to avoid the stale-plan sheet.

Large-text evidence remains essential for QA but should not consume one of the first six marketing frames. “Time to enjoy dinner” is a useful optional seventh shot; it explains less than menu choice or recovery in the first six. Do not use the unreached review-sheet render until an interactive capture exists and has been reviewed.

Apply `A2-S4-nine-menu-listing.patch` only with the catalog addition. It changes the previously integrated honest listing from three menus to nine and qualifies the four meat-free choices. The prior listing patch must not be reapplied. No promises of custom menus, recipe import, ingredients or complete recipes are added.

## Integration and next evidence

1. Apply S1 and S4 together; S2 and S3 are independent UI patches. All are diffs against the baseline above. Inspect any later conflicts; do not force an old patch onto changed source.
2. Run the native gate and Swift suite (69 expected if no intervening test changes). Render the expanded Tonight list, last-menu selection, selected-menu footer, and the accessibility header fix.
3. Keep the existing interactive UI-test follow-ups: initial-viewport capture before scroll, action-area captures after scroll, Dark Mode and accessibility sheets, actual completion history, and accurate README claims. Agent 1 owns their test implementation.
4. Review actual UI attachments when published. No render approval is granted for sheets we have not seen.

Product decision unchanged: completion without a recorded start remains a safety net in 1.0. A deliberate “Already finished” action on an unstarted step is a future design decision, not included here.
