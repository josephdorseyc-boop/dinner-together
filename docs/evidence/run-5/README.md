# Native validation evidence — CI run 5 (first fully green run)

GitHub Actions run `38005711328`, commit `214b87f`, October 9, 2026 23:4x UTC.
macOS 15.7.9 · Xcode 16.4 (16F6) · iOS 18.5/18.6 simulator runtimes.
Evidence tier for everything in this folder: **Swift compilation (Xcode),
XCTest execution (simulator), simulator rendering**. Not device, not
VoiceOver, not notification delivery.

| Check | Result | Source |
|---|---|---|
| Xcode project parses | ✅ | `SUMMARY.md` |
| App + test targets compile (Debug, iPhone simulator) | ✅ 0 errors, 0 warnings | `SUMMARY.md`, build log on the `ci-results` branch |
| `-DDEBUG` reached the compiler (screenshot launch flags) | ✅ | `SUMMARY.md` |
| XCTest on iPhone 17 simulator | ✅ 61/61 passed, 0 failed, 0 skipped | `20-test-iphone-summary.json` (Xcode result bundle) |
| XCTest on iPad (A16) simulator | ✅ 61/61 passed, 0 failed, 0 skipped | `20-test-ipad-summary.json` |
| `swift test` on macOS (Package.swift harness) | ✅ 61/61 | `SUMMARY.md` |
| `swift test` on Linux (CI job) | ✅ 61/61 | job log |
| Seeded screenshots, iPhone + iPad, light + dark | ✅ 24 required + 4 large-text bonus | this folder (12 of 28 kept) |

## What the screenshots show (reviewed by Agent 3)

- `iphone/late-prep-light.png` — opened on Cooking; notice "Running about 7 min
  behind", chosen time vs. estimate, reason names the late prep, quiet "Review
  dinner time"; RIGHT NOW leads with "Cook the steak".
- `iphone/expired-timer-light.png` — "At least 5 min behind … can't finish
  before", reason says check the food; featured card "Check the food",
  "Overdue 05:07", the A2-4 caption and primary button.
- `iphone/expired-timer-ax-large-text.png` — **after the fix**: compact notice
  (headline, one times line, button); the urgent card is on the first screen.
  In run 4 the full notice filled the screen and pushed it below the fold.
- `iphone/way-behind-dark.png` — amber tone at 15 min in Dark Mode; notice and
  RIGHT NOW card agree on "15 min late to start".
- `iphone/late-to-start-light.png`, `iphone/on-schedule-light.png`,
  `iphone/all-done-late-light.png` — controls: late-to-start reason;
  no notice when on schedule; no notice and "Time to enjoy dinner." when
  everything finished late.
- `ipad/*` — two-column composition: notice in the action column under
  DINNER AT; timeline on the right agrees with the estimate.

## Open design observation for Agent 2

At the default text size in the expired-timer state
(`iphone/expired-timer-light.png`), the featured card's primary button sits
at the bottom edge of the first screen. Option: when an expired timer is
featured, place the notice after the RIGHT NOW card so the kitchen action
comes first. Not changed; the product owner's call.
