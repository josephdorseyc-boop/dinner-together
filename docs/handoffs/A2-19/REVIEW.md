# A2-19–21 — build 12 render review and resize handoff

Prepared October 12 evening, Denver time. A2 product/design; A1 engineering execution; A3 integration.

## Provenance and scope

Reviewed **18 selected original simulator PNGs** from native run **38341383318**, source **50e74dd7c40c9ca3f8f80680ee395b3a7e1e4115** (wip/build12), Xcode 26.2. Artifact: **ui-review-evidence-38341383318**, ID **11789607239**. Downloaded/extracted without transforming images. REVIEWED.tsv lists every inspected PNG and its SHA-256. This is a focused review, not a claim to have inspected all 165 PNGs in the package.

Evidence tier **simulator rendering** applies to the visual judgments below. Source reading is labeled separately. No physical-device, VoiceOver, actual accessibility-setting, fold/unfold or notification execution by A2. The solid-card shots exercise the DEBUG `-dt-solid-cards` path: they show the fallback appearance, not proof that either system accessibility setting activates it.

The run's SUMMARY is **not green**: XCTest 161/161 on iPhone and iPad; iPad XCUITest 17/17; iPhone XCUITest 31/34. Failures: test20_appleNewsLinkAX3 (UITestSupport:993, Screenshots-sheet assertion); test22_coverCropHappyPath (:1110) and test23_coverSaveFailureRetry (:1125), import-recipe not comfortably visible after 12 scrolls. Hand those traces to A1/A3; A2 is not changing the harness or guessing these are app bugs.

Separately, `duo-ios27-evidence-38341872659` (artifact **11789197762**, main **e0706fdb**) reports Xcode 27.1 Debug and Release compile plus XCTest/macOS 161/161, but iPhone UI 26/27 and iPad UI 12/13. First iPhone failure is test18_recipeReviewGateAX3, `tonight-recipe` not comfortably visible after 12 scrolls. This is the **ios27** matrix leg, not the Duo leg. The Duo leg was still running at the check. A3/A1 own those failures and their newer harness corrections.

## Findings, in severity order

### S2 — destination can diverge across compact/regular layouts

**Evidence tier: source review.** ContentView on both main e0706fdb and wip/build13 56485814 stores `tab` and `sidebarSelection` independently. A direct compact tab tap changes only tab; the corresponding direct sidebar selection changes only sidebarSelection. A layout switch then reads the other, potentially older value. Example path: compact Tonight → direct tap Cooking → regular layout; sidebarSelection still defaults to Tonight. Reversing the layout can similarly reopen an older compact destination.

This is a reproducible assignment/state mismatch in source, **not an executed Duo repro**. It hides the current cooking destination during a resize; no claim that the SessionStore timer data is lost.

Proposed **A2-19-shared-destination.patch**, against **wip/build13 56485814f14ef47d5590868c6b81b0fe23dd8d36**: a single typed Destination backs tabs and the optional sidebar binding. It retains the recipePath, launch destination, recipe routing and existing stale-sheet modifier. No store, timer, alert, recipe persistence or project-file change.

A1 verification request, using the existing resize/Duo effort: direct tap each destination in compact mode, switch to regular and back; repeat from the sidebar; open a recipe then resize and verify its path stays open. With a live timer, confirm its deadline/run identity remains unchanged. This patch addresses the top-level destination only. Local recipe sub-tab/scroll position and presented sheets are still explicit resize test targets.

### S3 — status/chrome contrast still open in light appearance

**Evidence tier: simulator rendering.** `iphone/r14a-photo-colors.png`, `iphone/r15d-typed-tomato-directions.png`, and `ipad/r14a-photo-colors-ax3.png` still show black status content over the dark page. Dark variants show white content. The current toolbarColorScheme change has not closed the finding. The selected root-tab text is now light, but the light brown glass capsule in r14a can still wash out the white label.

A3 owns the actual chrome policy. Please capture top and scrolled content in light appearance after the change. Prefer a foreground/background pairing that remains legible as content scrolls beneath the status region; do not infer success from the modifier's presence. No speculative status-bar override patch supplied. Current palette body, timer accents and cards do not need a hue retune to solve this.

### S3 — true AX3 picker needs room and wider swatches

**Evidence tier: simulator rendering.** `iphone/r14c-page-color-sheet-ax3.png` shows only the first row initially; `iphone/r16-page-color-save-failed-ax3.png` pushes color options entirely below the visible medium sheet; `ipad/r14c-page-color-sheet-ax3.png` breaks Tomato/Saffron into multiple syllable lines in five narrow columns.

Proposed **A2-20-accessible-color-picker.patch**, same **56485814** baseline: accessibility sizes open at the large detent and use an adaptive minimum swatch width of 160 instead of 96. Default sizes keep medium/large detents and the old grid. Scroll remains available; this is not a promise all choices fit without scrolling. No save/selection changes. Re-render r14c/r15b/r16 at AX3 and assert Done/error/selection recovery with A1's existing flows.

### S3 — long recipe-review notice dominates AX3 reading captures

**Evidence tier: simulator rendering.** `iphone/r15d-typed-plum-directions-ax3.png` shows only STEP 1's heading above the pinned action; the corresponding iPad shot still devotes most content height to title/notice. The photo's notice is longer. These are poor moments to judge actual AX3 instruction readability. This does **not** prove the directions cannot be scrolled to.

Optional **A2-21-compact-recipe-review.patch**, same **56485814** baseline: accessibility headline “Review timing”; body “Check step times.” or an explicit estimated-step count, plus “Add recipe time.” when total is absent. Default copy stays intact. Step estimate labels, Timing explanations, review gate and missing-total behavior stay intact. Amounts/order should still be checked against the source recipe; the shorter body is navigation help, not a new claim of import accuracy. No inferred-time warning is removed.

After integration, photograph an actual instruction paragraph after scrolling into view, with the pinned action visible; the current header-only capture is insufficient reading evidence.

### S3 — recovery-sheet AX3 capture also needs a usable initial presentation

**Evidence tier: simulator rendering.** `iphone/08-ax-review-sheet.png` opens at medium height; the headline/chosen time fill it and estimated readiness/actions fall below the initial frame. Request large-detent presentation at AX sizes or a similarly measured adaptive presentation for this sheet. Do not reduce text size or remove the estimate. A3 can apply the policy alongside their other sheet work; no overlapping Sheets.swift patch supplied here.

## Design closures

**Evidence tier: simulator rendering**, scoped to the observed states:
- Apricot on Tomato Directions is clear and fits the warm palette. Keep it; no preset hue/saturation retune.
- Keep the soft pools at current strength. The solid fallback is calm and legible in the photographed brown card views.
- Delete's modest end-of-page button and anchored confirmation are approved. The native bubble lacks a visible Cancel in these captures; dismissing outside is platform behavior. The UI test's cancellation result belongs to A1's execution, not a conclusion from the photo.
- Picker helper copy now clearly explains immediate save; failure text names the operation. Its AX presentation needs the larger detent above.
- Dark Mode default brown/Plum pages read well. Light chrome and AX instruction/action composition remain open.
- A2-17/18 store/privacy/support copy is applied on main 3a3070eb; no resend.
- Missing-total editing (“Not stated” → Add time) is already in A3's build13 source. Older build12 images are not evidence that build13 lacks it.

## Integration and validation

All three independent proposed patches were generated against **56485814** and passed `git apply --check` against isolated exact-file copies. No active source tree edited. No Swift compilation or execution by A2; A1/A3's Mac validation remains required. Review source diff before applying to a later head.

This docs-only handoff targets main. Apply patch files to A3's active implementation branch, not the handoff docs branch. Keep current CI running; use the next implementation commit rather than scheduling extra full jobs solely for each copy change. Do not add a duplicate resize harness.

Top priority is Duo destination continuity and light chrome. The AX picker is a small practical fix; compact recipe copy is optional polish. No blanket Duo or accessibility signoff until new render/runtime evidence lands.
