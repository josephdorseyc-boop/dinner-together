# A2-24 — one integration patch for the reviewed UI changes

October 13 morning, Denver. Companion to PR #14; no new feature scope.

## Purpose

A3 can apply the existing A2-19, A2-20, A2-21 and A2-23 proposals in one operation rather than reconstructing their order. The combined patch is **byte-for-byte equivalent** to applying those four patches sequentially to the baseline files.

Baseline: **wip/share-extension 9a08174eb7ed91c8cb8de01c4f8219e3311f1070**.

Only four app files are represented in the proposed delta: ContentView.swift, DinnerTogetherApp.swift, RecipePageStyle.swift and RecipeViews.swift. App source is not changed by this docs-only PR.

## Included changes

1. One typed destination for narrow tabs and wider sidebar, preserving recipe path and incoming-share routing (A2-19; source-reviewed by A1).
2. Large detent and wider color swatches at accessibility text sizes (A2-20; source-reviewed by A1).
3. Shorter accessibility recipe-review notice while retaining the estimate-count and missing-total cue (A2-21; source-reviewed by A1).
4. A single root appearance decision for current dark colored recipe pages, replacing the conflicting ancestor DEBUG appearance preference (A2-23; native/render verification still required).

Existing timers, persistence, recognition/parser logic, share-extension implementation, test target membership and harness are retained. The appearance proposal implements current dark-page chrome; it does not supply Joe's softer automatic photo-palette policy.

## How to use

Use **this combined patch or the four individual patches**, not both. If any of the changes already landed on the target branch, use only the remaining individual deltas or adapt after review.

Download A2-24-reviewed-ui-batch.patch from this handoff, then on A3's implementation branch:

```bash
git apply --check /path/to/A2-24-reviewed-ui-batch.patch
git apply /path/to/A2-24-reviewed-ui-batch.patch
```

The first command checks applicability only. The second applies it locally for A3 to inspect, validate and commit. Do not merge the handoff branch expecting it to change app source: it contains documentation and a patch file.

The exact source files came from 9a08174e. A later branch head must be checked again; do not force a failed application.

## Validation record

**Evidence tier: supplemental check**, isolated scratch copies:
- All four original patches passed git apply --check and were applied sequentially.
- The combined patch passed git apply --check against a fresh copy of the original files.
- Applying it produced identical bytes to the sequential result in all four files.
- Incoming AddRecipeSheet(shared:) and Dynamic Type seeding remained.
- The root contains one preferredColorScheme call and the conflicting ancestor call is removed.

No Swift compiler, Mac, native simulator or physical-device execution by A2. Source application is not runtime verification. No extra CI run dispatched and no active source branch edited.

## Owner's next validation pass

A1/A3 can use their existing flows, with focused checks for:
- Switching compact/regular or Duo pose preserves destination, recipe path and active timer deadline.
- Color picker at AX3 keeps Done usable; failed saves keep the selected color and permit recovery.
- Light system appearance on a colored detail page gives readable status/tab/sidebar chrome; Classic cream/back/other destinations restore expected appearance.
- Incoming share opens the Add sheet and routes to the saved recipe normally.
- Debug and Release compile before the next distribution build.

Run these as part of A3's next planned implementation validation. The screenshot-import content defects remain a separate S2 workstream in PR #16, owned by A3 with A1's actual OCR verification. No importer fix is claimed here.

Priorities: correct imported content and Duo behavior, then close the documented accessibility/chrome renders. Keep optional compact-copy polish proportional to finishing 1.0.
