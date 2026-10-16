# A2-29 — reviewed UI batch for main/build12

October 13, 2026. This adapts the already-reviewed A2-19/20/21/23 intent to **main 2cbc9e730f9f105ad202326d31c49b62104bb8a8** and also applies to **wip/build12 32f8fa068475dfdf42ace582c452cd4e4e6d8693**. A2-24 targets share-extension 9a08174e instead.

## Choose one integration variant

| Actual baseline | UI batch |
|---|---|
| main 2cbc9e73 or build12 32f8fa06 | A2-29-main-ui-batch.patch |
| share-extension 9a08174e | A2-24-reviewed-ui-batch.patch |

These are alternative implementations of the same review changes. **Do not apply both**, or apply either after the corresponding individual fixes have already been integrated. Recheck against a newer tree before using it.

## What changes

- One typed destination backs compact tabs and regular sidebar selection; recipePath remains rooted in ContentView.
- Colored recipe detail controls the preferred appearance at the root; leaving detail restores DEBUG-forced/system appearance. The older root now explicitly receives RecipeLibrary, already supplied by DinnerTogetherApp. The competing DEBUG ancestor appearance preference is removed; type-size forcing is retained.
- Accessibility page-color picker uses a large detent and wider adaptive columns.
- Accessibility timing banner is shorter and retains the estimated-step count and missing-total-time cue. Default-size banner text from this baseline is unchanged.

Four app files are represented in the separate patch. The active source branches were not edited by A2. Importer and test-harness implementations remain with A3/A1.

## Evidence and limits

**Supplemental check:** git apply --check passes on isolated copies of both exact baselines above. A2 also applied it to a copied build12 tree to verify retained UI-test sheet type-size hooks and the resulting diff. The new explicit library environment dependency is present in the root, and the app already injects it.

**Source review:** these implement the same typed selection, accessibility and root-appearance policy as the earlier A1-reviewed proposals. This adaptation handles the older inline timing-banner body instead of assuming the newer reviewBannerText helper exists.

**Not executed:** native Debug/Release compilation and resulting simulator/device renders. A1/A3 should run those gates in the next planned integration run. No additional CI run was dispatched by A2.

## What still needs validation

- Resize each destination and an open recipe, checking actual size classes and route identity.
- Resize Directions/Timing, unsaved Add draft, crop and duration editor. Shared destination/path alone does not prove view-local draft/presentation continuity. S3 if reader subtab resets; S1 only if unsaved-data loss is reproduced.
- Verify status/tab/sidebar readability on current deep photo/preset pages; Classic cream, pop and Tonight/Cooking restore the expected appearance. Repeat system light/dark.
- Confirm AX3 picker options and Done are readable and the pinned cooking action remains available below the compact notice.

The forced-dark policy assumes the current deep colored palettes. A future genuinely light photo palette needs a common body/root/toolbar/text appearance policy; this patch does not supply that lighter palette.
