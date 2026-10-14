# Native validation evidence — CI run 9 (Agent 2 design patches D1–D4)

Run `38010450198`, commit `3837266`, Xcode 16.4. Green: build 0 errors;
XCTest 61/61 iPhone 17 and 61/61 iPad (A16), 0 failed, 0 skipped (result
bundles); `swift test` 61/61 macOS and Linux; 28 screenshots.
Evidence tier: Swift compilation (Xcode), XCTest execution (simulator),
simulator rendering.

- `iphone/expired-timer-light.png` — **D1**: with an expired timer the
  first screen is RIGHT NOW ("Check the food", "Overdue 05:07", caption,
  "Mark done after checking" fully visible); the readiness notice follows.
  Compare run 5, where the notice came first and the button sat at the fold.
- `iphone/expired-timer-ax-large-text.png` — D1 + the compact notice at
  accessibility size.
- `ipad/late-prep-light.png` — **D4**: timeline rows read "Timer deadline
  1:20 AM" (cooking) and "Planned 1:02 AM – 1:22 AM" (pending); **D2**
  header unchanged at default size.
- `iphone/late-prep-dark.png`, `ipad/expired-timer-dark.png` — Dark Mode
  unaffected.

Build warnings in this run: 2 `appintentsmetadataprocessor` notices
(toolchain noise) and 1 unused-result warning in a baseline test
(`testNoStaleReminderAfterResetDuringPendingAuth`), fixed in r8. App
target: 0 warnings.
