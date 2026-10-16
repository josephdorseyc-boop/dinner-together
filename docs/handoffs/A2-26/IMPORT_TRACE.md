# Import failure trace — source and supplemental checks

Baseline: main `e0706fdb` and `wip/share-extension` `9a08174e`. The screenshot-parser implementation is identical in both; their only RecipeImporter diff is three added social-import errors. A2 independently rechecked current main 2cbc9e730f9f105ad202326d31c49b62104bb8a8; the relevant marker accumulation, longest-head selection, chrome and title-fallback branches remain as described below. Swift is not installed locally. **No native Swift/Vision execution, device reproduction, source patch, or CI dispatch was performed. A2 relayed the confirmed findings on PR #16.**

All ten supplied screenshots were inspected. App screenshots corroborate the title/teaser/News tabs as false steps and the substitution of a repeated recipe title for source step 3 “Set aside.” The five reference pages are only a prefix, not the full recipe nor necessarily Joe’s complete chosen input batch.

## Highest-value finding — a duplicate navigation marker can replace a short real instruction

**Source review**, RecipeImporter.swift:
- Line 792 treats every recognized `Step 3`/`STEP 3` as a body boundary.
- Lines 813–816 append the intervening text to that head.
- Line 841 chooses whichever head for a given number has the most characters.
- Apple News reference pages 2–5 each display a navigation “Step n” above the repeated recipe title, then a second body “STEP n”.
- When the selected title is wrong (as Joe’s “0001 -” output establishes), the repeated actual title is not filtered by line 754.

Thus, with accurate Latin OCR, step 3 acquires these two heads:

```
3 → [
  "Lavender-Ginger Meringue Twists",
  "Set aside."
]
```

The long title wins and “Set aside.” is lost. A longer instruction (e.g. source step 4) wins against the same header title and remains intact. This explains **why the short step alone could be substituted by a title**, matching app step 6, without requiring any mixed-script OCR.

**Supplemental check:** `supplemental-check.py` mirrors the applicable guards/head accumulation/longest-copy selection and confirms this result plus the long-instruction control. It is a narrow Python model, not execution of Swift’s parser. The “0001 -” control is a synthetic recognized line supplied to reproduce the wrong-title condition; its actual origin on Joe’s device remains unknown.

A1 should execute this exact pure Swift fixture in ScreenshotOrderTests:

```swift
let wrongTitleControl = [
    OCRLine(text: "0001 -", top: 0.03, height: 0.02),
    OCRLine(text: "Ingredients", top: 0.08, left: 0.2, height: 0.02),
    OCRLine(text: "Directions", top: 0.08, left: 0.5, height: 0.02)
]
let shortInstruction = [
    OCRLine(text: "11:25", top: 0.02, height: 0.02),
    OCRLine(text: "Ingredients", top: 0.08, left: 0.2, height: 0.02),
    OCRLine(text: "Directions", top: 0.08, left: 0.5, height: 0.02),
    OCRLine(text: "Step 3", top: 0.125, height: 0.02),
    OCRLine(text: "Lavender-Ginger Meringue Twists", top: 0.15, height: 0.015),
    OCRLine(text: "STEP 3", top: 0.205, height: 0.025),
    OCRLine(text: "Set aside.", top: 0.245, height: 0.04)
]
let parsed = try RecipeImporter.parse(screenshots: [wrongTitleControl, shortInstruction])
XCTAssertEqual(parsed.title, "0001 -")
// Current-source modeled result; this asserts the defect rather than its fix.
XCTAssertEqual(parsed.directions, ["Lavender-Ginger Meringue Twists"])
```

After the owner’s fix, the expected direction is `["Set aside."]`; add a longer-body control, title-below-tabs case, and header-without-duplicate-body-marker case to avoid overfiltering cookbook steps.

## Corrections to A1’s PR #16 source trace

1. **“0001 - must have been found above the tabs in the top 16%” is not proven.** Line 1015 is only the first title strategy. Lines 1027–1038 scan the entire page for the tallest run, excluding exact headers/markers/chrome but not plausible instructions or numeric artifacts. A synthetic line at `top=0.30`, `height=0.06` wins against median `height=0.015`; the Python supplemental check confirms it. We can only conclude that screenshotTitle returned it **if** there was no later user edit; not which branch, position, or original image produced it.

2. **Split News tabs are a proven general gap, but not a confirmed raw recognition trace.** `isChrome(normalizedKey("Today News+ Audio Following Search"))` is true, while each separate `Today`, `News+`, `Audio`, `Following`, `Search` is false. Same-row OCR blocks can later be joined into the observed full line after they already passed filtering. A1’s row-split explanation is plausible and source-supported; actual Vision boxes are needed to call it the actual mechanism.

3. **Mixed script is one possible omission mechanism, not the established cause of “Set aside.”** Lines 744–749 silently skip unreliable text; markUnreliable flags even one Greek/Cyrillic scalar on a >=85%-Latin import. That is a real general defect, but the repeated STEP 3/longest-head mechanism above provides an accurate-Latin alternative closer to the observed substitution. There is no length filter that drops a clean “Set aside.”; `trimOverlap` leaves a two-word instruction alone.

4. **Import-time corruption is strongly supported; save/load is not exhaustively exonerated by source review alone.** RecipeViews.swift lines 442–444 feed recognized pages directly to parse/screenshots then build. The observed failure is reproducible in the parser model. Capture parser output before save to establish the exact boundary for Joe’s batch.

## Other established source weaknesses

- **Title below tabs:** the repeated-title strategy never examines it; that does not mean the later height fallback can never find it. On these layouts, the title is smaller than the body, so the height fallback may prefer instruction text or unrelated oversized text.
- **Cover metadata requirement:** `isCover` requires both a known time/yield label and a known button. A cover/editorial page missing either becomes eligible for bare unnumbered directions. A tab-row page also sets `hasHeader=true` before the tab row is dropped, meaning section-vs-navigation roles are conflated.
- **Header titles can become previous-step tails:** text before firstMarker `n>1` is appended as tail `n-1` unless it was marked unreliable. A misidentified first navigation marker or below-tab title therefore needs classification before firstMarker/anchors are computed.
- **OCR uncertainty is discarded:** ScreenshotReader returns best candidate string and box but no recognition confidence/candidate alternatives. ImportedRecipe has notes but no content-uncertainty/gap report. Timing estimates do not imply content completeness.
- **Title filtering uses substring containment:** `titleKey.contains(key)` can drop an actual short action if it happens to be part of the selected wrong title. Prefer exact metadata-role matching over title-substring filtering.
- **Do not apply a global “single tabWords are chrome” rule.** It worsens role conflation and could erase body headings/notes. Group adjacent blocks into a known navigation row using position/repetition; keep body context and short real commands. Rest/Drain are not currently tabWords, but a future verb-less-token policy must preserve them.

## Smallest robust owner direction

1. Identify navigation/title/body regions before selecting title, firstMarker, or step heads. Support repeated title below tabs and distinguish navigation Step n from a body heading.
2. Treat text roles separately from timing. Cover/editorial text should not be scheduled merely because metadata labels are absent.
3. Choose compatible body fragments for the same source step, rather than blindly selecting longest text across metadata and instructions. Disagreement/missing numbered content should surface a content-review warning.
4. Preserve short commands, source step numbers and legitimate recipe notes. Do not require a duration or fixed English verb list to retain an instruction.
5. Group split chrome by spatial row/known repeated controls, not a global blacklist.
6. A1/A3: run actual Vision on Joe’s **full selected original batch**; keep raw strings, normalized boxes, candidate confidence, page order, classified roles, chosen title branch, head candidates and final numbered steps. The five reference pages here cannot establish the source of the cover “0001 -” artifact or the full 14-step count.

No competing importer patch is supplied. A3 remains implementation owner; A1 owns actual OCR/Swift regression evidence.

