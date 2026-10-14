# Review request — Dinner_Together_Recovery_Candidate_v028 **r6**

From: Agent 3 (build owner / integrator) · October 9, 2026 · via Joe
To: Agent 1 (engineering verification) and Agent 2 (product/design review)

Same artifact to both; compare the SHA-256 in the cover note. Format and
rules unchanged from `REVIEW_REQUEST_r4.md`.

## What changed since r5 — Agent 1's r4 findings (patch stream A1)

Agent 1's **59/59 `swift test` run on Linux is the first native execution
of anything in this project.** Thank you. Their three `.patch` files did
not reach me (only `AGENT1_FINDINGS_r4.md` did), so each fix was
re-implemented from the finding text; Joe, if the originals differ from
what's below, please forward them and I'll reconcile.

| Item | Disposition | Where |
|---|---|---|
| A1-1 (S1) `URL.documentsDirectory` missing on Linux | Fixed: `#if os(Linux)` stand-in in `EngineTestSupport.swift` (harness only; never evaluated by tests) | `DinnerTogether/EngineTestSupport.swift` |
| A1-2 (S1) nine synchronous `@MainActor` test methods break Linux discovery | Fixed: the nine methods are `async` (`testPersistenceRoundTrip` is `async throws`) | `DinnerTogetherTests.swift` |
| A1-3 (S2) gate counts the `testMenu()` helper as a test | Fixed: helper renamed `makeTestMenu()` (31 call sites); `grep -c 'func test'` now returns the true 61 | `DinnerTogetherTests.swift` |
| Doc nit: harness protocol `@MainActor` differs from the real one | **Not a difference** — `Notifications.swift` lines 5–6 declare the real `NotificationService` `@MainActor` too; the copy is verbatim. No change. | — |

Counts corrected everywhere: 61 test methods (not 62/60). 59 of them were
executed by Agent 1 on r4; the 2 added in r5 (`testLowerBoundMinutesRoundDown`,
`testPlanCarriesRunningPredecessorPastOutOfOrderCompletion`) and the r6
fixes themselves have not been executed by anyone yet.

## Validation status (r6) — labeled
- **XCTest execution (Agent 1, Linux, r4):** 59/59, Swift 6.0.3. Engine +
  store only.
- **Executed here (Linux, supplemental):** JS model 128/128; reconciliation
  5/5; harness dry run 10/10; cumulative patch reproduces the tree from
  pristine v0.2.8.
- **Source review only:** r5's `plan()` carry change and A2 copy; r6's three
  A1 fixes; `project.pbxproj` `DEBUG`; workflow.
- **Not performed by anyone:** iOS app-target compilation, XCTest on
  simulators, rendering, device, VoiceOver, notification delivery.

## Asks
- **Agent 1:** please re-run `swift test` on r6 — it should be green on the
  first try, now with 61 executed — and send `swift --version` plus the
  per-class lines. Then the r5 items you haven't seen: the `plan()` running
  maximum (`testPlanCarriesRunningPredecessorPastOutOfOrderCompletion`;
  look for any in-order case it could alter) and the A2 copy changes'
  effect on existing assertions. Your run also tells us the Linux CI job
  should pass; the macOS job is still untested.
- **Agent 2:** nothing new for you in r6 (harness/test only). Still open from
  r5: confirm A2-1…A2-4 closed; the large-text viewport question waits for
  real screenshots.
- **Joe:** the first GitHub run is now expected to go green on Linux and to
  tell us what Xcode thinks on macOS.
