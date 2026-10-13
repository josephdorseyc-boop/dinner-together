# UI tests (XCUITest)

Tap-through of the interactive flows the static screenshot pass cannot
reach: the review sheet, the delay sheet, the stale-plan sheet, and the
confirmation dialogs. Runs on the existing GitHub macOS runner — no Apple
Developer Program enrollment, no signing, no TestFlight.

## Running locally (Mac with Xcode 16)

```bash
# Build once for the simulator you will test on:
xcodebuild build-for-testing \
  -project DinnerTogether.xcodeproj -scheme DinnerTogether \
  -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17'

# iPhone flows (10 tests):
xcodebuild test-without-building \
  -project DinnerTogether.xcodeproj -scheme DinnerTogether \
  -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DinnerTogetherUITests/DinnerTogetherUITests

# iPad flows (3 tests):
xcodebuild test-without-building \
  -project DinnerTogether.xcodeproj -scheme DinnerTogether \
  -configuration Debug -destination 'platform=iOS Simulator,name=iPad (A16)' \
  -only-testing:DinnerTogetherUITests/DinnerTogetherUITests_iPad
```

In CI these run inside `native-validation/run-native-pass.sh`, which counts
executed/passed/failed/skipped from the `.xcresult` bundle (failing on
executed < expected, any failure, any skip) and exports the keep-always
screenshots into `results/ui-screenshots/<device>/` for the `ci-results`
branch.

## How seeding works

A UI test cannot write into the app's sandbox, so each test builds its seed
in-test (`UISeed` in `DinnerTogetherUITests/UITestSupport.swift` — fresh
timestamps every run, the same JSON shape `SessionStore` decodes as
`native-validation/seed-sessions.py`) and passes it via the `DT_SEED_JSON`
environment variable. `DinnerTogetherApp.init()` writes it to the store's
file **before** `SessionStore` is created — DEBUG builds only; release
builds ignore the variable entirely. Every test sets the variable
explicitly: the app never deletes a seed file, so an unset variable would
leak the previous test's seed.

## What each test asserts

### iPhone — `DinnerTogetherUITests` (10)

| Test | Flow | Asserts |
|---|---|---|
| `test01_reviewDinnerTimeLatePrep` | Review dinner time (late-prep seed) | Sheet shows "Chosen dinner time" + "Estimated readiness"; the Move button's displayed time becomes the new DINNER AT and the notice disappears; Undo restores the time and the notice. Screenshots: `01-review-sheet`, `01-after-move`, `01-after-undo`. |
| `test02_reviewSheetLowerBound` | Review sheet (expired-timer seed) | "Earliest readiness" label + the amber lower-bound note; "Keep … for now" dismisses and changes nothing. Screenshot: `02-review-sheet-lower-bound`. |
| `test03_adjustTimeOnSchedule` | Adjust time (on-schedule seed) | Delay sheet opens with the chosen amount; confirming moves DINNER AT exactly 10 minutes; Undo restores it. Screenshots: `03-delay-sheet`, `03-after-confirm`, `03-after-undo`. |
| `test04_expiredTimerCompletion` | Expired timer (expired-timer seed) | Tapping "Mark Cook the steak done" (the button's accessibility label) finishes the step; it lands in the Completed group. Screenshots: `04-expired-featured`, `04-after-completion`. |
| `test05_blockedStartAnyway` | Blocked start (`blockedStart` seed: dinner in 20 min, nothing started, so s2 is due and blocked) | "Review start" on s2's timeline card opens the "Waiting on …" alert naming the prerequisite; Cancel changes nothing; "Start anyway" starts the step. Screenshots: `05-timeline-blocked`, `05-blocked-alert`, `05-after-start-anyway`. |
| `test06_unstartedCompletion` | Unstarted completion | "Mark done" on a step with no recorded start asks first ("It was never marked started…"); confirming completes with "start not recorded" — the start is never fabricated. Screenshots: `06-confirmation-alert`, `06-after-completion`. |
| `test07a_stalePlanWithProgress` | Stale plan, progress made | The non-dismissable "Welcome back." sheet offers "Resume this plan"; resuming dismisses it onto the cooking screen. Screenshots: `07a-stale-sheet`, `07a-after-resume`. |
| `test07b_stalePlanNoProgress` | Stale plan, no progress | The sheet offers "Keep menu, fresh time"; the cook lands on the cooking screen with a fresh dinner time. Screenshots: `07b-stale-sheet`, `07b-after-keep`. |
| `test08_reviewDinnerTimeAXTextSize` | Flow 1 at accessibility text size | The review sheet opens and the estimate is readable at `UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge`. Screenshot: `08-ax-review-sheet`. |
| `test09_tonightNineMenus` | Tonight (planning) screen, launched without `-dt-open-cooking` (`tonight` seed) | "Build my cooking plan" is hittable before any scrolling (the A2-S3 bottom inset) and the footer reads "Selected: Steak night"; scrolling to and choosing "Crisp tofu, cozy bowls" updates the footer while the action stays on screen; the action opens the cooking screen. Screenshots: `09-tonight-top`, `09-tonight-menus`, `09-tonight-into-cooking`. |

### iPad — `DinnerTogetherUITests_iPad` (3)

Re-runs flows 1, 3 and 9 on the iPad destination so the sheets and the
planning screen can be judged in the wide layout:
`test01_reviewDinnerTimeLatePrep_iPad`, `test02_adjustTimeOnSchedule_iPad`,
`test03_tonightNineMenus_iPad`.

## Integration notes (Agent 3, r9)

Applied on top of Agent 1's patches, each labeled in the source:

- **A3-U-F1** `XCTestCase.wait(for:timeout:)` returns `Void`; the
  result-returning wait is `XCTWaiter().wait(for:timeout:)`. Compile fix.
- **A3-U-F2** Flow 5 needs its own seed (`UISeed.blockedStart`): the
  timeline offers "Review start" only once a step is due
  (`Scheduling.blockedInfo` is gated on `now >= plannedStart`). With dinner
  in 32 min, "Cook the steak" is still two minutes in the future.
- **A3-U-F3** XCUITest never scrolls on its own. `scrollTo` drags in short,
  controlled steps until the element is hittable; `tapButton` and
  `scrollAndTap` use it, and `scrollToTop` precedes the "after undo"
  photographs. On iPhone, Undo, the Completed group and the s2 card are
  below the first screen; sheet buttons sit below the medium detent.
- **A3-U-F4** Dismissals are animated: `waitForDisappearance` replaces
  `XCTAssertFalse(element.exists)` immediately after a tap.
- **A3-U-F5** The "Adjust time" confirmation dialog is an action sheet on
  iPhone and a popover on iPad; the test taps its "Add 10 minutes" button
  as an app descendant instead of through `app.sheets`.
- **A3-U-F6** Label-prefix queries use `.any` descendants
  (`element(labelBeginning:)`), since the review sheet's time columns are
  combined accessibility elements whose reported type is SwiftUI's choice.
- **A3-U-F7** (harness) Exported attachments are renamed from
  `manifest.json` to their attachment names when the manifest has the
  expected shape (best effort, never a gate), and the "nothing exported"
  gate counts files of any extension.

After the first execution (CI run 14: iPhone 8/9, iPad 0/2):

- **A3-U-F8** `isHittable` is not "tappable": a button whose lower half
  sat under the tab bar reported hittable and the tap did nothing (Flow 5).
  `scrollTo` now demands the element be clear of the navigation-bar and
  tab-bar bands, aims it at mid-screen with a targeted drag, and holds at
  the end of each drag so the scroll view doesn't coast past it.
- **A3-U-F9** The review sheet is live: the button's time is recomputed
  every draw and can cross a minute boundary between reading the label and
  tapping (iPad: button said 3:45, applied 3:46). Flow 1 reads the label
  immediately before tapping and accepts that minute or the next.
- **A3-U-F10** iPad presents the "Adjust time" confirmation dialog as a
  popover whose buttons report not hittable; `tapEvenInPopover` falls back
  to a coordinate tap at the button's center.
- **A3-U-F11** A confirmation dialog opened from a Menu action is not
  reliable: the delete dialog requested from the More menu was dropped on
  iPhone in five consecutive CI runs (38275025677 → 38290508810) and once on
  iPad, with and without a 350 ms delay after the tap — the menu's dimming
  overlay was still on screen and the More button not hittable. A *sheet*
  from the same menu (Page color) presented every time, so the rule is:
  from a Menu action, present sheets only; a confirmation dialog or alert
  belongs on a plain button. Delete is now a button at the end of the recipe
  page, which presents its dialog every time (the dialogs from the Cooking
  screen's buttons have never been dropped).
- **Known limitation (iPad, Flow 3):** the "Adjust time" confirmation
  dialog is a popover on iPad, and its buttons report unlaid-out frames to
  XCUITest (runs 20–22: the popover's `Sheet` container has infinite/zero
  frames; taps at the reported button center land outside and dismiss it).
  `test02_adjustTimeOnSchedule_iPad` photographs the open dialog and records
  the hierarchy, then wraps the "delay sheet opened" assertion in a
  non-strict `XCTExpectFailure`, so the result bundle counts it as an
  expected failure — reported in `SUMMARY.md` every run, never as a pass —
  and passes outright once a tap path works. The delay sheet itself (same
  code on both devices) is tapped through on iPhone. Open for Agent 1.
- (harness) The unit-test run now passes `-only-testing:DinnerTogetherTests`;
  without it the xctestrun also executed the UI bundle ("executed 72,
  expected 61") and mixed its failures into the unit verdict.

## Notes for reviewers

- Assertions prefer the app's existing accessibility labels (they are
  deliberately descriptive). Identifiers are used only where labels are
  ambiguous: `serving-time` (the DINNER AT readout) and
  `timeline-step-<id>` (step cards, to scope taps to one step). Neither
  changes anything the cook sees.
- Flow 6 reaches the unstarted-completion confirmation via a seeded
  cooking record with no `actualStart` — the only UI-reachable path to
  that alert, since `startStep` always records the start.
- The tests assume the simulator uses the host locale (the +10-minute
  assertion round-trips displayed times through the short-style
  `DateFormatter`); CI runners are en_US.

## Flaky flows: one retry, always reported (October 13)

`run-native-pass.sh` reruns up to three failing UI flows alone, once, after
the full run (A1, issue #18: four consecutive build-12 runs each failed on a
different flow, ninety minutes a cycle). A flow that passes alone is a
**flaky pass**: the step is marked ✅ with the first run's exit code in the
line, the summary lists it under "retry on <device>", the run carries a
`::warning` annotation `flaky-ui-<device>`, and `FLAKY.txt` in the results
accumulates them. It is never hidden, and it is A1's lane to make it stop
flaking. A flow that fails alone too fails the gate exactly as before.
Four or more failures are not retried: that is a broken build. The retry's
own renders are exported under `ui-screenshots/<device>/retry/`, next to
the full run's failure-state renders, so both are evidence.

The credit fails closed (A1 #18, A2-33: the first version could have gone
green with a real failure). A flaky pass needs all of: every xcresult
failure named in the log (else a `retry-identity-<device>` warning and no
retry), the retry process exiting 0, the retry's own xcresult executing
exactly those tests with all passed and none failed or skipped, and the
retry log showing each passed and none failed. Anything else keeps the
original failure verdict, with the reason in the summary. The dry run
covers the three A2-33 cases (`ui-retry-partial-ids`,
`ui-retry-process-error`, `ui-retry-pass-then-fail`).

The unit tests run on the iPhone simulator only (plus Linux and macOS
`swift test`); the iPad simulator runs the UI tests (A1 #19).

Two harness rules came out of the recordings of run 38399682685 (A2-25):
`scrollAndTap` waits for the target's frame to stop moving before tapping
(the Undo tap had landed where Undo was a moment earlier), and every scroll
drag starts at a point that is not on a button (`dragStart`), after a
positioning drag that began on "Choose screenshots" opened Photos.

## Your Recipes: swipe Edit / Delete (r20, October 13)

The collection is a `List` (rows keep their card look) so rows swipe left
for **Edit** and **Delete** (Joe, build 12). Edit opens the Edit recipe
sheet (title with a clear button, yield; `recipe-edit-*` identifiers); the
same sheet is ••• → Edit title and yield on the recipe page. Delete asks
with an alert (not a confirmation dialog — alerts present reliably after a
swipe or menu closes), and is refused with "You're cooking this right now"
for tonight's recipe while it is being cooked. The swipe buttons are plain
buttons tinted red/olive, not `role: .destructive`, which animates the row
away before the cook confirms. Flow: `flowSwipeEditAndDelete` (test36 and
test37 AX3 on iPhone, test19 on iPad), renders r20a–r20d.

## The week (r23, October 13)

Tonight opens with **THIS WEEK**: seven chips (`week-day-0` is today and
shows tonight's actual dinner; 1–6 show the plan). A chip opens the day's
plan sheet (`day-plan-<menuID>`, `day-plan-open`, `day-plan-rotation`,
`day-plan-done`); today's choice goes through Tonight's own selection path.
Recipes has a **Dinner, Together classics** folder (`open-classics` →
`classic-<menuID>` → `plan-day-<0…6>`). UI tests get an empty plan on
every seeded launch (`DT_SEED_WEEK_PLAN`, default `{}`), and a seeded
session is never replaced by the plan. Flow `flowWeekPlan` — test43
(iPhone), test22 (iPad).
