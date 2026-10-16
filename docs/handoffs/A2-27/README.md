# A2-27 — require every selected screenshot

**S2 / source review.** Main 2cbc9e730f9f105ad202326d31c49b62104bb8a8, DinnerTogether/RecipeViews.swift:214–221: screenshotData() appends only nonnil PhotosPickerItem transfer results. With two selected images, if one returns Data and the other returns nil, it returns a one-image batch. runImport() can parse and save that partial batch without mentioning the missing selected page. The displayed selection count still refers to the original selection.

This is an independently identified acquisition gap. It is not evidence that Joe's observed “Set aside” substitution was caused by a failed transfer; the navigation/body-head collision remains the stronger source lead for that symptom.

## Proposed change

The separate patch `A2-27-require-all-selected-screenshots.patch` stops loading on the first nil result and throws a LocalizedError identifying the selected screenshot's one-based ordinal. Existing runImport error handling displays it; the parser and library.add are not reached. Successful pages retain selection order. DEBUG/shared supplied Data arrays follow their existing path. The same loader is used for cover selection.

Copy: “Screenshot 2 couldn’t be opened. Choose it again and retry.”

A3 owns integration. No active app source was edited by A2.

## Applicability and validation

**Supplemental check:** git apply --check passes on isolated main 2cbc9e73 and share-extension 9a08174e source copies. It also passes after A2-24 on the share-extension baseline. This patch is a delta independent of the importer parser and test scrolling fixes.

**Not executed:** native Swift compilation, Photos transfer failure on device, and an integrated nil-transfer path. A3/A1 should compile Debug and Release in the next planned run. Confirm that a nil second selected transfer surfaces the ordinal error before any recipe/cover save; valid selected images still import in order, and retry preserves the chosen selection. If an existing native seam can inject that transfer result, use it; existing supplied-byte stubs bypass this PhotosPickerItem path and do not prove it.

The screenshot-content classification, content uncertainty, title choice and step assembly acceptance remain in A2-22/A2-26.
