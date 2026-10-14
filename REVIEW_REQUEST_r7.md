# Review request — Dinner_Together_Recovery_Candidate_v028 **r7** (first green native run)

From: Agent 3 (build owner / integrator) · October 9, 2026 · via Joe
To: Agent 1 (engineering verification) and Agent 2 (product/design review)

Source of truth is now the repository `josephdorseyc-boop/dinner-together`,
branch `main` (commit in the cover note); the ZIP is a snapshot of it. Rules
unchanged from `REVIEW_REQUEST_r4.md`.

## What happened
Five CI runs on GitHub's macOS runners (Xcode 16.4). Run 5 is fully green:
app target compiles with 0 errors/0 warnings; XCTest 61/61 on iPhone 17 and
61/61 on iPad (A16) simulators (Xcode result bundles, 0 failed/0 skipped);
`swift test` 61/61 on macOS and Linux; 28 seeded screenshots. The
run-by-run findings and the evidence are in `RECOVERY_HANDOFF.md` (top) and
`docs/evidence/run-5/` (summary, result-bundle JSON, 12 screenshots,
README with what each shows). All 28 PNGs and full logs are on the repo's
`ci-results` branch.

Evidence tier for all of the above: **Swift compilation (Xcode), XCTest
execution (simulator), simulator rendering.** Not device, VoiceOver, or
notification delivery.

## Code changes since r6 (all driven by run findings; no engine/store change)
| Change | Why | Evidence |
|---|---|---|
| `project.pbxproj`: test target `PRODUCT_NAME`, `LD_RUNPATH_SEARCH_PATHS`; `DEBUG` once at project level | run 2: `Multiple commands produce …/PlugIns/.xctest`; run 4: `-DDEBUG -DDEBUG` | build logs |
| `LaunchOptions.notificationService()` is `@MainActor` | run 3: the only compile error in the app target | build log |
| `CookingView.readinessNotice` compact at accessibility text sizes | run 4 screenshot: notice filled the first screen, urgent card below the fold (A2's prediction) | `docs/evidence/run-5/iphone/expired-timer-ax-large-text.png` vs. run 4 |
| Harness: xcresult-based test counts, complete-app check, `-DDEBUG` grep, results to git branches | run 5: interleaved log line undercounted passes by one; run 3: partial `.app` counted as present | `SUMMARY.md`s |

## Asks
- **Agent 2:** design review of the real renders in `docs/evidence/run-5/`
  (tone, hierarchy, Dark Mode, iPad composition, the compact
  accessibility notice). One decision: with an expired timer at default
  text size the featured card's primary button sits at the fold
  (`iphone/expired-timer-light.png`) — move the notice below RIGHT NOW when
  an expired timer is featured, or leave as is?
- **Agent 1:** sanity-check the harness count change (reads
  `xcresulttool get test-results summary`; falls back to the log) and the
  `ci-results` publishing step for anything that could mask a failure.
  The compile-risk list in the handoff §3 is now moot except for items
  that only a device can show.
- **Both:** what should the next validation target be — an XCUITest target
  so the review sheet and dialogs get photographed, or a TestFlight build
  (needs Apple Developer enrollment) so a real iPhone runs it?
