# A2 build 13 review — October 13
Baseline: wip/share-extension fa04aa07f852e792c7b1e2c827812ca9b9168716. Proposed source changes are separate patch files; this handoff branch changes documents only.

## S2 — content warnings disappear after timing confirmation
Evidence: source review. RecipeDetailView gates reviewBanner on needsTimingReview and hides it on Timing; importWarnings are only appended inside that banner. markTimingReviewed clears the flag without repairing missing source text.
A2-30 gives content warnings their own persistent, wrapping card on every tab, with accessibility identifier import-content-warning. Timing confirmation must not dismiss it. It also clarifies source-step numbering, the Remove dialog, and the 30-screenshot/Cook-mode help. Existing Remove/Cancel actions remain.

## S2 — removing a later duplicate removes the earlier direction
Evidence: source review and supplemental array-model check, not Swift execution. For directions Stir / Add salt / Stir, removing the last timed Stir currently removes the first direction.
A2-31 maps duplicate text through the original imported step ordinal. It does not assume flattened dish order equals source order. Ambiguous legacy mappings fail visibly before mutation. Two regression methods cover later-duplicate removal and parallel-dish order, persistence, and failed-save rollback.
The timing controls are already disabled while the selected dinner has progress; this is not a claim about removing a cooking step.

## Validation and ownership
Both patches pass git apply --check against an isolated fa04aa0 baseline. Native compile and XCTest remain unexecuted by A2. A3 integrates; A1 runs the two new regressions and existing persistence/parser tests and adjusts count gates if needed. Photograph the warning on Timing and after timing confirmation, including AX3. Verify Remove removes the chosen occurrence.
A3's later 9e7d5c7 title/yield/swipe changes do not resolve these two mechanisms, but overlap files: re-check applicability before integration.
A1 owns the titleKey.contains regression. Whole-word substring matching alone does not protect “Roast.” against a title of “Roast Chicken”; use source-role/context or exact title-line classification and retain the short-instruction regression.

## Remaining design decisions
Frame 5: Your recipes. Your timing. Subcaption: Bring a recipe. Check the steps. Make a plan. Use a standard-text typed-recipe capture (r15c-typed-plum, fallback r15d-typed-plum-directions), without a publisher photograph. Keep the other frames focused on whole-dinner timing. Exact filename selection must beat AX variants.
Store copy must say import/save then review the saved instructions and timing before cooking; “reviewed before saving” contradicts the current flow.
Duo: recommend outer-screen landscape for 1.0, conditional on short/wide viewport validation, not device-name assumptions. A3 owns orientation/build changes; A1 owns pose and state-continuity checks.
Palette: source policy is promising; retain pale floors/saturation limits and dark ink for the first render pass. Supplemental flat-stop calculations give muted-text ratios about 4.96, 4.83, 4.57 against A3's reported CFE5FF/D7E0F4/BFDDFF. These are not sampled renders or a guarantee about frosted material. Actual r19 standard/AX3/iPad render approval remains pending.
