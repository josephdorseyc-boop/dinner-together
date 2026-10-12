# A2 first recipe design pass

For Agent 3. Implements the first navigation and reading-surface increment from issue #4.
Baseline: main `aca699b882dc3bc8635d59b05e7dc80c0c3c7625`.

Apply `A2-12-recipes-navigation-and-reading.patch` to source. This handoff PR contains
the patch and review notes only: merging the documents does not apply the implementation.

## What changes

- Phone navigation becomes Tonight / Cooking / Recipes; iPad adds Recipes to its sidebar.
- Tonight offers Choose from Recipes instead of embedding the full collection.
- Recipes has its own collection screen and retains the existing add/import flow.
- A root-owned UUID navigation path supports the recipe stack. Explicit recipe selection
  clears that path and routes to Tonight. Browsing and timing confirmation retain their
  existing behavior; selecting a replacement still uses the existing confirmation.
- The collection provides Back to cooking when dinner has recorded progress. The global
  Cooking destination remains available from recipe detail.
- Recipe pages use an opaque, adaptive cream/sand reading gradient, dark olive in Dark Mode.
  Existing photographs fade into cream above the title; the title stays off the image.
- No-photo pages use a compact collection label, omitted at accessibility text sizes.
- Directions use scalable title3 type and more line spacing, with olive step headings.
  Original recipe text and duration wording are preserved.
- UI-test helpers enter the new collection; the existing review flow now selects the
  reviewed recipe and asserts that Tonight shows it. Method counts are unchanged.

## Source review and supplemental checks

- Patch application checked and performed in an isolated baseline copy; resulting files
  match the proposed files byte-for-byte.
- No scheduling, recipe persistence, notification or timer code is changed by this patch.
- Theme endpoint calculation: muted text on the new wash is 4.68:1 light / 7.50:1 dark;
  primary text is 11.75:1 light / 13.60:1 dark. This numerical check does not replace
  simulator review or high-contrast accessibility testing.
- No new source files or Xcode target registrations are required.
- Swift compilation, XCTest and simulator rendering have NOT been run by A2.
  CI on this handoff-only PR does not execute the proposed source changes.

## Native acceptance checks for A3

1. Compile both targets; retain the existing source-count and failure gates.
2. Run the recipe UI flows: empty library, import, timing review, Cancel, explicit choose,
   and save/delete failure. Confirm all captures now begin in the intended destination.
3. Capture Recipes and recipe detail on iPhone light/dark/default/AX3 and iPad. Review
   the Ingredients/Directions/Timing controls and the pinned primary action at AX3.
4. Switch Tonight / Cooking / Recipes during a running timer. Compare recorded start
   and deadline before/after; return to the previously opened recipe. Also check iPad
   sidebar and size-class changes, recipe scroll position and in-page section state.
   The stored navigation path alone is not evidence that every view state survives.
5. Confirm choosing a reviewed recipe returns to Tonight without automatically starting
   a step; changing an in-progress dinner still asks for confirmation.
6. Exercise the photo-width fixture, long titles, long yields and no-photo presentation.
   The larger directions should wrap without horizontal scrolling or text truncation.

## Scope boundaries

This is the first implementation increment, not completion of issue #4. Screenshot photo
cropping, automatic photo-region suggestions, step photographs, and an immersive single-step
cooking mode are not included. Existing images still work; screenshot-only imports keep the
no-photo presentation. The failed-estimate-save recovery and copy findings on PR #3 are a
separate integration item; preserve any newer A3 fixes when applying this patch.
