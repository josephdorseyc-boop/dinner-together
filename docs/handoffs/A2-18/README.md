# A2-18 — immediate assistance for A3

October 12, 2026. Companion to A2-17 / PR #13. These are **separate proposed patches**, not edits to active source branches.

## Live status checked
- Release run 38313136098 on main cb28c05: completed, success.
- Native run 38312021304 on palette 9fffb57: still in progress at this check. Linux and JS/dry-run jobs succeeded; the native build/test step was running. This is not native signoff or a claim of TestFlight availability.

## S2: support page repeats the false network-free claim
**Evidence tier: source review.** docs/support.html at main cb28c05 says the app has no network connection. The same file exists unchanged on palette 9fffb57. RecipeImportService fetches selected recipe pages and photos.

Apply **A2-18-support-import.patch against main cb28c050723ca3db7f5d327bc7a7f4769d83a1bd** alongside A2-17's listing/privacy patch. It adds recipe-import troubleshooting and corrects the support FAQ. It does not duplicate those two files or change contact details. These are proposed web-page changes for A3 to integrate, not already published pages.

## S3: picker copy ready to apply
**Evidence tier: source review**, checked RecipePageStyle.swift at palette 9fffb57 after the A2-17 render review.
Apply **A2-18-picker-copy.patch against wip/recipe-palette 9fffb57ebc93a35ddddf661c34336134892a484c**:
- Photo helper: “Match the photo, or choose a color. Changes save as you select.”
- Typed helper: “Choose a color for this recipe. Changes save as you select.”
- Color-save failure names the operation and retained choice, with a next action.
- No shared library error replacement, state changes, persistence changes, identifiers, selection logic or test harness changes.

The retry wording says “Choose another color” because choosing the already-selected style returns without saving. This is more precise than a generic “Tap a color.” The existing flowPageColorSaveFailure asserts the error identifier's existence/hittability and preserved selection, not the old string, so no asserted-copy change was found in that flow. This is **source review**, not executing it. Its r16/AX3 render should check wrapping after integration.

Both patches passed git apply --check against isolated copies fetched at their exact baselines. No Swift compiler/native tests available or run by A2 for this copy-only delta.

## Ownership / sequencing
A3: continue your current integration and native run. These are optional ready-to-apply deltas for your next commit; do not interrupt or restart the current run just for helper copy.
A1: retain engineering and interactive-flow ownership. No additional harness is requested here.
A2: chrome contrast remains the next design closure in A2-17; no speculative toolbar patch is being injected while A3 works on that branch. Keep pending screenshots tied to the native run artifact and actual source SHA.
