# A2 live handoff: reject ambiguous screenshot order

Prepared October 12, 2026. Patch baseline: `wip/fixtures`
`724dc3b5bd182ba14ad9edf42d9ec1fbae8dfac0`.

## Problem and proposed behavior

**S2 / source review:** a screenshot import that mixes numbered and unnumbered
directions sorts every numbered step first, then appends every unnumbered step.
Selecting the images in recipe order does not fix this. The reproducible fixture
`STEP 1: Mix` / unnumbered `Rest` / `STEP 2: Bake` becomes Mix -> Bake -> Rest.
This cannot be treated as merely an arbitrary-selection-order limitation.

The proposed patch rejects that ambiguous mixture before returning a schedulable
recipe and uses the existing inline error flow. Proposed user copy:

> These screenshots mix numbered and unnumbered directions, so their order is
> uncertain. Paste or type the full recipe in the Text tab, in recipe order.

Numbered-only imports keep their numeric ordering. Unnumbered-only imports keep
selection order and still require review. Numbered-step continuation fragments
that the importer attaches to a numbered step remain supported. No automatic
deletion of repeated directions: repeated actions can be legitimate.

This deliberately favors an explicit fallback over guessing a cross-page
direction's position. Some valid but structurally ambiguous imports will require
manual text entry; that trade protects the timing plan's sequence until an
editable direction-review flow exists. It does not promise general OCR accuracy.

## What this PR contains

The `.patch` is the proposed source/test change for Agent 3 to integrate. This PR
itself adds only the patch and handoff documents; merging it alone does not change
app behavior. This respects Agent 3's integration ownership and avoids editing
their active source branch while they are building the capture pass.

Apply `A2-10-mixed-screenshot-text-fallback.patch` after checking the branch head.
It changes only RecipeImporter.swift and the already registered
ScreenshotOrderTests.swift. Existing source test counts derive automatically.
One old mixed-order characterization becomes the rejected-import regression;
two methods are added: clear fallback copy and a supported numbered continuation.

Agent 1 can now verify the proposed policy and tests without writing a duplicate
parser fix. No scheduling engine, recipe-library persistence, signing or release
workflow changes are proposed.

## Checks actually performed

- **Supplemental check:** git apply --check and actual application passed in an
  isolated copy of the fetched baseline; resulting source/test bytes match the
  proposal. The repository worktree was not edited.
- **Source review:** the guard executes before recipe sections are returned.
  AddRecipeSheet catches LocalizedError before library.add; the existing failure
  path keeps the sheet open and reports the description.
- **Not executed:** Swift compilation, XCTest, simulator or device testing of
  this new patch. A green check on this documentation-only PR validates its base
  app, not the enclosed proposed source patch.

## Integration / validation (one batch)

1. Agent 3 applies the patch to the latest compatible source, then runs engine
   and native suites. If the enum/error path changed, adapt rather than force it.
2. Agent 1 verifies mixed-order rejection, in-order unnumbered behavior,
   numbered reverse-selection behavior and numbered continuation. Preserve
   exact-overlap characterization as a documented limitation, not desired output.
3. Add an interactive mixed-order import error capture: no recipe created, no
   Added announcement, chosen images remain available, current dinner unchanged,
   clear path to the Text tab. Verify the fallback also permits manual typing.
4. Proceed with the planned recipe captures (iPad, AX3, dark, hero and failed
   deletion). R7/R8/R9 save/confirmation assertions remain required.

## Prior render review status

The eight iPhone/light/default images from main `d0c28d4` were reviewed by Agent 2.
R7/R8/R9 are integrated per Agent 3 and are being validated by native run 41 on
`da18ad5`; they are not visually closed until the updated capture set is inspected.
R6's guard is confirmed in source, with visible save-failure state in r07. Physical
VoiceOver, notifications and real cooking remain device checks.

When reviewing the new set, Agent 2 will check pinned Save at 180/181, clear
confirmation on Timing, preserved long direction text, compact metadata, image
width/contrast and honest rollback feedback. No extra feature scope is requested.
