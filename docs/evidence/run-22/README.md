# Evidence — CI run 22 (`1d6d746`), October 10, 2026, 05:18–06:05 UTC

Xcode 16.4, macOS 15.7.9, iPhone 17 and iPad (A16) simulators.
Evidence tier for everything here: **Swift compilation, XCTest execution,
XCUITest execution (tap-through of the real app), simulator rendering.**
Not device, not VoiceOver, not notification delivery.

| Check | Result |
|---|---|
| App + test targets compile (incl. asset catalog, privacy manifest, nine-menu catalog) | ✅ 0 errors |
| XCTest unit suite, iPhone | ✅ 69/69 (61 recovery/baseline + 8 CatalogTests), 0 skipped |
| XCTest unit suite, iPad | ✅ 69/69 |
| XCUITest flows, iPhone (`DinnerTogetherUITests`, 10) | ✅ 10/10 |
| XCUITest flows, iPad (`DinnerTogetherUITests_iPad`, 3) | 2/3 — flow 3's popover (see below) |
| `swift test` harness, macOS + Linux | ✅ 69/69 |
| Static seeded screenshots (7 scenarios × light/dark × 2 devices) | ✅ 28 required + 4 large-text |

## What the UI tests proved for the first time

- `iphone/01-review-sheet.png`, `01-after-move.png` — the review sheet
  opens from the inline notice, "Move dinner to …" applies the time on the
  button (within the minute the live estimate may cross), the notice
  disappears, Undo restores it.
- `iphone/02-review-sheet-lower-bound.png` — "Earliest readiness" and the
  amber lower-bound note when a timer has expired; Keep changes nothing.
- `iphone/03-delay-sheet.png`, `03-after-confirm.png` — "Adjust time" →
  the explain-before-apply sheet → exactly +10 minutes; Undo restores.
- `iphone/04-expired-featured.png` — expired timer is "check the food";
  marking done moves the step to Completed.
- `iphone/05-blocked-alert.png`, `05-after-start-anyway.png` — the
  blocked-start alert and the explicit override. **This alert never
  appeared before run 22: two `.alert` modifiers on one view, only the
  second presented. Fixed by routing both confirmations through one
  modifier (`CookingView.CookingPrompt`). Found only because the UI tests
  tapped it.**
- `iphone/06-confirmation-alert.png`, `06-after-completion.png` —
  unstarted completion asks first; "start not recorded" afterwards.
- `iphone/07a-stale-sheet.png`, `07b-after-keep.png` — the stale-plan
  sheet's two paths. Note for Agent 2: resuming a day-old plan shows
  "Running about 1650 min behind" behind the sheet — accurate and absurd;
  scenario C territory.
- `iphone/09-tonight-top.png`, `09-tonight-menus.png`,
  `09-tonight-into-cooking.png` — nine menus, the A2-S3 footer action
  reachable before scrolling, choosing "Crisp tofu, cozy bowls" updates
  the footer, the action opens cooking. Also `ipad/09-*` for the wide
  layout.
- `iphone/static-tonight-steak-light.png` — the static Tonight render used
  for App Store frame 1.

## Known gaps, stated plainly

1. **iPad flow 3 (delay choice popover):** XCUITest sees the popover's
   content with unlaid-out frames; taps land outside and dismiss it
   (`ipad/03-after-dialog-tap.png`: no popover, no sheet, time unchanged).
   From run 23 this is a surfaced expected failure, reported in every
   `SUMMARY.md`. The delay sheet itself is identical code and is tapped
   through on iPhone. Whether a real finger on iPad opens the sheet is
   **unverified** until TestFlight; the app now hands the sheet its
   proposal 350 ms after the dialog action so a dismissing popover cannot
   drop it.
2. **Flow 8 (accessibility text size)** is rendering at the default size
   (`iphone/08-ax-review-sheet.png`): the `-UIPreferredContentSizeCategoryName`
   launch argument is not honored by this app. Needs a DEBUG launch option
   that sets `dynamicTypeSize` on the root view (two lines in
   `DinnerTogetherApp.swift` + the test passing it). Until then the large
   text evidence is the static `*-ax-large-text.png` shots only.
3. Agent 2's S2 (accessibility header stack) therefore has no UI-test
   render yet; the static `expired-timer-ax-large-text.png` from this run
   is the place to check it.
