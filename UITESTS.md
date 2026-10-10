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

# iPhone flows (9 tests):
xcodebuild test-without-building \
  -project DinnerTogether.xcodeproj -scheme DinnerTogether \
  -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DinnerTogetherUITests/DinnerTogetherUITests

# iPad flows (2 tests):
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

### iPhone — `DinnerTogetherUITests` (9)

| Test | Flow | Asserts |
|---|---|---|
| `test01_reviewDinnerTimeLatePrep` | Review dinner time (late-prep seed) | Sheet shows "Chosen dinner time" + "Estimated readiness"; the Move button's displayed time becomes the new DINNER AT and the notice disappears; Undo restores the time and the notice. Screenshots: `01-review-sheet`, `01-after-move`, `01-after-undo`. |
| `test02_reviewSheetLowerBound` | Review sheet (expired-timer seed) | "Earliest readiness" label + the amber lower-bound note; "Keep … for now" dismisses and changes nothing. Screenshot: `02-review-sheet-lower-bound`. |
| `test03_adjustTimeOnSchedule` | Adjust time (on-schedule seed) | Delay sheet opens with the chosen amount; confirming moves DINNER AT exactly 10 minutes; Undo restores it. Screenshots: `03-delay-sheet`, `03-after-confirm`, `03-after-undo`. |
| `test04_expiredTimerCompletion` | Expired timer (expired-timer seed) | Tapping "Mark Cook the steak done" (the button's accessibility label) finishes the step; it lands in the Completed group. Screenshots: `04-expired-featured`, `04-after-completion`. |
| `test05_blockedStartAnyway` | Blocked start (late-to-start seed) | "Review start" on s2's timeline card opens the "Waiting on …" alert naming the prerequisite; Cancel changes nothing; "Start anyway" starts the step. Screenshots: `05-timeline-blocked`, `05-blocked-alert`, `05-after-start-anyway`. |
| `test06_unstartedCompletion` | Unstarted completion | "Mark done" on a step with no recorded start asks first ("It was never marked started…"); confirming completes with "start not recorded" — the start is never fabricated. Screenshots: `06-confirmation-alert`, `06-after-completion`. |
| `test07a_stalePlanWithProgress` | Stale plan, progress made | The non-dismissable "Welcome back." sheet offers "Resume this plan"; resuming dismisses it onto the cooking screen. Screenshots: `07a-stale-sheet`, `07a-after-resume`. |
| `test07b_stalePlanNoProgress` | Stale plan, no progress | The sheet offers "Keep menu, fresh time"; the cook lands on the cooking screen with a fresh dinner time. Screenshots: `07b-stale-sheet`, `07b-after-keep`. |
| `test08_reviewDinnerTimeAXTextSize` | Flow 1 at accessibility text size | The review sheet opens and the estimate is readable at `UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge`. Screenshot: `08-ax-review-sheet`. |

### iPad — `DinnerTogetherUITests_iPad` (2)

Re-runs flows 1 and 3 on the iPad destination so the sheets can be judged
in the two-column layout: `test01_reviewDinnerTimeLatePrep_iPad`,
`test02_adjustTimeOnSchedule_iPad`.

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
