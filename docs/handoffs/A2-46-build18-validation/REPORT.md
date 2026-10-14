# A2-46–48 — Build 18 validation investigation

October 14, 2026. Reviewed native run **38588198150**, source
**5b2cdac0bed752b0e36cee0132da3ffbd05710cf**, evidence commit
**6fef2340df5066139c94722753daa517612d4231**. No source/render verdict is
attributed to a different run. A3's later 1925694 is a documentation handoff;
the native run reviewed here tested 5b2cdac.

## The wait and the final verdict

GitHub reports the run started 09:18:39 and finished **11:16:39 Mountain**:
one hour 58 minutes. It is now **completed / failure**, not still waiting.
The job built and ran tests, then captured and published screenshots. Its
final required gate correctly failed. `RUN.txt` records
`job_status_so_far=success` before the final gate; that field is not the final
workflow verdict and must not be interpreted as green validation.

- Debug build-for-testing and Release build: passed.
- Native unit tests: 204/204 passed; macOS Swift harness also passed.
- iPhone UI: 37/44 passed, seven failures.
- iPad UI: 21/22 passed, one failure; isolated retry failed again.
- Static screenshot capture: 32 PNGs; interactive captures also published.

The screenshot of repeated wait calls alone cannot establish that A3's
session is hung. The actionable problem now is the failed result below.

## A2-46 — outdated empty-cookbook navigation in the harness

**Severity S1: blocks the native gate. Evidence: native XCTest logs + source.**

Six failures share `UITestSupport.swift:932`, `Choose from Recipes`:

- iPhone: test10_recipeLibraryEmpty, test12_appleNewsLink,
  test20_appleNewsLinkAX3, test22_coverCropHappyPath,
  test23_coverSaveFailureRetry.
- iPad: test06_appleNewsLink_iPad, also failed in the isolated retry.

The shared `openRecipesLibrary()` insists on `open-recipes`, which Tonight
intentionally omits when the cookbook is empty. First launch now offers
`tonight-primary` → Add your first recipe → the Add sheet in Recipes. These
six failures are not six independent importer/crop bugs; they stop before
those interactions execute.

The separate `A2-46-empty-cookbook-navigation.patch` keeps the existing
nonempty route. For an empty cookbook it uses the first-recipe route, checks
that the actual action is Add your first recipe, cancels the sheet, and
asserts the Recipes collection's existing Add control. It reuses the route
already exercised by the passing first-launch flows. No downstream assertion
is removed or softened.

**Supplemental verification:** patch passes `git apply --check` against
5b2cdac. Swift compilation and affected UI flows after application are
pending. A1/A3 integrate; active app/test source was not edited by A2.

## Other UI failures: keep their diagnoses separate

- **iPhone test01:** SpringBoard refused launch because the application was
  installing or uninstalling (`Busy`). This is explicit simulator lifecycle
  evidence; it is not evidence that Undo logic failed. A1 should inspect the
  install/warm-up → XCTest handoff before choosing a targeted retry/fix.
- **iPhone test18 AX3:** failed to reveal `tonight-recipe` after 12 scrolls.
  Its log includes repeated drags from [0.50, 0.30] to the **same point**.
  That identifies ineffective scroll gestures late in the attempt, but does
  not alone prove the title is unreachable to a real user. Investigate the
  large pinned footer and the visibility/scroll predicate; retain the
  title/navigation assertion and capture the failing viewport.

## A2-47 — status-bar appearance is inconsistent

**Severity S2. Evidence: original simulator PNGs, visually inspected.**

- iPhone `09-tonight-first-launch`: clock/Wi-Fi/battery are light.
- iPhone `r22a-tonight-cover-landscape`, `…landscape-ax3`, and `…pastel`:
  clock/Wi-Fi/battery are **dark** over the photo/test image.
- iPad first launch: the clock is light over the cream sidebar surface and
  consequently weak; the global status bar spans two different surfaces.
- iPad selected pastel: dark status-bar foreground; assess each underlying
  surface instead of forcing one color without a contrast check.

Therefore the requested clock/battery check does **not** pass consistently.
Selected-photo fixture patterns are debug test images, not accidental stock
food images or a missing recipe asset.

## A2-48 — full-bleed image also pulled header text into the status bar

**Severity S2. Evidence: original iPhone simulator PNGs, visually inspected.**

The iPhone first-launch and selected-photo covers place the serif Tonight
heading under/through the clock. At AX3, Dinner, Together itself overlaps
the clock/signal area. Keep Joe's photo full-bleed, but put the header text
below the actual safe-area/status-bar bounds. Do not revert the photo to an
inset card to fix the text placement.

Source review suggests checking the safe-area inset read from the outer
GeometryReader while that reader also ignores the top safe area. The overlap
is observed; that specific inset mechanism still needs implementation review.

## Acceptance checks 1–7: current scope

1. First-launch flows passed on both devices; notebook and empty-state
   renders exist. Header/status-bar findings above prevent visual signoff.
2. The timing-review flow verifies that review confirmation does not choose
   dinner. Fresh-import-only behavior is not newly established by this run,
   because several empty-import navigation flows stopped early.
3. Selected pale/deep photo renders exist. A-with-photo → B-without-photo →
   A transition is still not exercised by the current single-recipe cover flow.
4. Existing cover storage/replacement unit tests passed. Plate-photo
   add/replace/remove, priority and relaunch interaction need explicit checks.
5. Fresh-load missing/corrupt photo fallback has source support, not a new
   native render/interaction result in this evidence set.
6. Standard iPhone/iPad and AX3 cover renders exist. test18 failed; title
   overlap is real. Size-class/timer continuity is not established here.
7. Status-bar failures are established above. Tonight-specific Dark Mode,
   solid-card/Reduce Transparency/Increase Contrast and VoiceOver checks
   remain pending; recipe-page palette captures do not certify this cover.

Fix the shared empty-navigation harness and the observed header/status-bar
issues, investigate the two remaining UI failures, then validate the updated
source. No release signoff from A2 for this run.
