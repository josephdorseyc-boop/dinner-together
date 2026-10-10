# UI tap-through evidence — CI run <n> (DRAFT; Agent 3 fills in the run number)

Run `<run_id>`, commit `<sha>`, Xcode 16.4. Green: build 0 errors;
XCTest 61/61 iPhone 17 and 61/61 iPad (A16), 0 failed, 0 skipped (result
bundles); XCUITest 9/9 iPhone + 2/2 iPad, 0 failed, 0 skipped (result
bundles); `swift test` 61/61 macOS and Linux. Attachments below are the
keep-always screenshots from the UI tests, exported from the `.xcresult`
bundles into `ui-screenshots/<device>/`.
Evidence tier: Swift compilation (Xcode), XCTest/XCUITest execution
(simulator), simulator rendering. Not covered: physical device,
VoiceOver reading order, notification delivery, haptics.

## iPhone (`ui-screenshots/iphone/`)

- `01-review-sheet` — the "Review dinner time" sheet over a late-prep
  notice: "Chosen dinner time" and "Estimated readiness" side by side,
  the reason line, and the "Move dinner to …" / "Keep … for now" buttons.
- `01-after-move` — DINNER AT advanced to the time shown on the Move
  button; the inline notice is gone; Undo is offered.
- `01-after-undo` — the chosen dinner time restored; the notice returned.
- `02-review-sheet-lower-bound` — the sheet on an expired timer:
  "Earliest readiness" (not "Estimated readiness") plus the amber note
  "A timer has ended but its step isn't marked done, so this is the
  earliest the meal could be ready — not a prediction."
- `03-delay-sheet` — "Before we shift things": the explanation lines for
  the +10 minute delay, and any early-finish notes.
- `03-after-confirm` — DINNER AT exactly 10 minutes later; Undo offered.
- `03-after-undo` — the original dinner time restored.
- `04-expired-featured` — the featured expired-timer card: "Check the
  food", the overdue countdown, and "Mark done after checking" fully
  visible (D1: urgent action first).
- `04-after-completion` — the step in the Completed group; the notice
  recomputed for the remaining work.
- `05-timeline-blocked` — the timeline with "Cook the steak" waiting on
  its unfinished prerequisite ("Review start").
- `05-blocked-alert` — the "Waiting on 'Prep the steak & sauce
  ingredients'" alert with "Start anyway" / Cancel.
- `05-after-start-anyway` — the step started despite the unfinished
  prerequisite (explicit override, never silent).
- `06-confirmation-alert` — "Mark 'Prep the steak & sauce ingredients'
  done?": "It was never marked started, so we won't guess when it began
  — only that it finished now."
- `06-after-completion` — the Completed group showing "start not
  recorded": the start was never fabricated.
- `07a-stale-sheet` — "Welcome back." with "Resume this plan" (progress
  was made yesterday); the sheet cannot be swiped away.
- `07a-after-resume` — back on the cooking screen with the resumed plan.
- `07b-stale-sheet` — "Welcome back." with "Keep menu, fresh time" (no
  progress was made).
- `07b-after-keep` — the cooking screen with a fresh dinner time.
- `08-ax-review-sheet` — the review sheet at accessibility text size.

## iPad (`ui-screenshots/ipad/`)

- `01-review-sheet`, `01-after-move`, `01-after-undo` — flow 1 in the
  two-column layout.
- `03-delay-sheet`, `03-after-confirm`, `03-after-undo` — flow 3 in the
  two-column layout.

## What to judge (Agent 2)

Against each attachment: does the sheet/dialog read calm and honest? Is
the primary action the thing the cook needs right now? At accessibility
size, is the estimate still readable without losing the action? Anything
that misleads the cook about what will happen next is S1/S2; copy and
layout are S3.
