# UI proposal audit — A2-23 / A2-24

October 13, 2026. Read-only investigator audit, consolidated by A2; no source branch edits or CI dispatch.

## Result

No obvious new API or actor-isolation compile defect was found in A2-23/A2-24 by source inspection. This is not compilation or native execution. The proposals are coherent for the current deep colored-page policy, and preserve the share inbox sheet at the ContentView presentation root.

Exact source fetched: `wip/share-extension 9a08174e` and `wip/build12 32f8fa06`. A2-24 is still a proposal; its presence in the docs handoff is not evidence that it is integrated.

## Findings and integration constraints

### Baseline mismatch — do not force application to build12

**Evidence tier: supplemental check.** `git apply --check` against isolated exact source files passes at `9a08174e`. It fails at `32f8fa06` in ContentView.swift and RecipeViews.swift. Integrate on the stated share-extension baseline, or adapt the remaining deltas after review. Source reading of `32f8fa06` confirms it still has separate compact tab and regular sidebar selection and lacks the newer incoming-share root sheet.

### Resize continuity — top-level selection is covered; child presentation state is not

**Evidence tier: source review / framework-lifetime inference, not an executed Duo repro.** A2-24 uses one typed Destination and a root recipePath, correcting the known top-level selection divergence. SessionStore, RecipeLibrary and TimerCenter remain App-owned StateObjects; the patch changes none of their data or timer deadlines.

RecipeDetailView still owns local state for Ingredients/Directions/Timing, duration editing, page color and recipe-time sheets. YourRecipesSection still owns the Add recipe presentation; AddRecipeSheet owns unsaved typed text, screenshot and crop draft state. These are below the separate compact/regular subtrees, so rebuilding the layout may reset the sub-tab or dismiss a local sheet. A2-24 does not promise to preserve those states.

Severity if reproduced: S3 for a reset reader tab; S1 for lost unsaved draft/edit data. Verify first; do not report source risk as observed data loss. The incoming-share sheet is already outside the layout branch and is preserved in the source delta.

Smallest adjustment if failure is reproduced: lift the affected presentation and draft state into the surviving ContentView or a shared presentation model. Do not repair it by adding independent compact/regular copies.

### Lighter photo palettes require one coherent appearance policy

**Evidence tier: source review.** A2-23 forces root `.dark` whenever a recipe has a nonnil palette. RecipeDetailView likewise selects dark body text/chrome for every nonnil palette. This is correct for the current luminance-limited deep palettes and does not implement Joe's requested softer blue/lavender page.

If A3 introduces truly light backgrounds, derive body colors, root preferred appearance, toolbar scheme and foreground accents from a common palette appearance field together. Changing only root `.dark` or only the stops would leave the other layers mismatched. No immediate adjustment is needed while all palettes remain deep.

### Appearance restoration is source-consistent but needs real renders

**Evidence tier: source review.** Root preference returns to the DEBUG forced appearance, or nil in Release, whenever destination is not Recipes, recipePath is empty, the recipe is absent, or Classic cream resolves to no palette. The conflicting DEBUG ancestor preference is removed; forced Dynamic Type remains. Theme supplies dark adaptive colors for the sidebar/tab surface and tint. This is a plausible correction, not visual signoff.

**Evidence tier: simulator rendering, pre-patch run 38341383318 / source 50e74dd7.** Inspected original r14a iPhone, r14c AX3 iPhone and r14c AX3 iPad: black status text over the dark page remains visible in that older build; white selected-tab text is on pale glass. The AX picker opens at medium height; iPad labels split Tomato/Saffron across narrow columns. These images do not show A2-24 executed.

A2-20's larger accessibility detent and 160-point adaptive columns directly address the observed picker composition. The sheet retains a ScrollView, Done toolbar action and existing save/rollback behavior. Its grid may still need scrolling; the patch never guarantees all choices fit at once.

## Required evidence on A3/A1's next planned native run

1. Debug and Release compile the actual integrated tree. Do not use patch applicability as compile proof.
2. Directly select Tonight, Cooking and Recipes in each layout, then switch to the other layout and back. Record actual horizontal size class; closed/open Duo poses selecting compact/regular are an expectation, not proof until executed.
3. Open a recipe in Directions, then Timing, and resize. Verify recipe identity and reader tab. With a live cook, verify timer deadline/run identity.
4. Type an unsaved Add recipe draft, open screenshot crop, and open a duration editor; resize in each case. Verify draft/presentation continuity and cancellation. Incoming-share routing should also work after resizing.
5. System light → colored photo/Plum/Tomato detail, top and scrolled captures → Classic cream, pop to collection and switch Tonight/Cooking. Verify readable status/tab/sidebar chrome and light restoration. Repeat system dark.
6. AX3 photo/typed picker and failed-save state: Done remains available, error readable, selected option stays correct, options scroll and retry succeeds. Photograph actual instructions below the shortened notice with the pinned cooking action visible.

No app source changes or new patch supplied by this audit. Avoid overlapping A3's integration and A1's native harness work.
