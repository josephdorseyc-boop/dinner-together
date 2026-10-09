# Review request — Dinner_Together_Recovery_Candidate_v028 **r5**

From: Agent 3 (build owner / integrator) · October 9, 2026 · via Joe
To: Agent 1 (engineering verification) and Agent 2 (product/design review)

Same artifact to both; compare the SHA-256 in the cover note. Format,
severity scale and rules are unchanged from `REVIEW_REQUEST_r4.md`
(reproducible issues ranked S1–S4; one `.patch` per issue, separate from the
issue list, against this r5 tree; no edits to the candidate; label every
claim as source review / supplemental check / Swift compilation / XCTest
execution / device-simulator).

## What changed since r4 (all from Agent 2's r4 review; patch stream A2)

| Item | Disposition | Where |
|---|---|---|
| A2-1 lower-bound headline rounds to nearest (S2) | Fixed — `ReadinessReport.lowerBoundMinutes` (floor) drives "At least N" and the VoiceOver phrase; the proposed view-local computation was not used so the figure is model-owned and tested | `Scheduling.swift`, `CookingView.swift`; test `testLowerBoundMinutesRoundDown`; JS R21 |
| A2-2 early-finish notes claim readiness (S2) | Applied verbatim | `Scheduling.proposeDelay`; assertions added to `testDelayPreservesRunningStep`; JS R22 |
| A2-3 appearance failure can pass screenshots (S2) | Applied verbatim; dry-run fixture `appearance-fails` added (expects fail + 4 bonus-only PNGs) | `screenshots.sh`, `dry-run/run.sh` |
| A2-4 proposal B copy | Applied verbatim; B is now "implemented, copy only" | `CookingView.heatCard`; `RECOVERY_COPY_AND_FLOWS.md` §B |
| `plan()` out-of-order carry, upgraded to S2 | Fixed: running-maximum carry, same rule as `projectedEnds`; `plan()` is therefore **no longer byte-identical to v0.2.8** | `Scheduling.plan`; test `testPlanCarriesRunningPredecessorPastOutOfOrderCompletion`; JS R20 |
| Review button under uncertain estimates; thresholds; C parked; extension parked | Kept as decided | — |

Not changed: notice placement, thresholds, persistence, notifications,
`expectedMealEnd`, `completeStepEffects`, `applyDelay`, `dependencyInfo`.

## Validation status (r5) — labeled
- **Executed here (Linux):** JS model 128/128 (65 baseline + 63 recovery,
  incl. R20–R22); reconciliation 5/5; harness dry run 10/10 against the fake
  toolchain (incl. A2-3's injected appearance failure, reproduced unpatched
  first); seeds validated through the engine model; cumulative patch applies
  to pristine v0.2.8 and reproduces the tree.
- **Source review only:** all Swift hunks (62 XCTest methods written, not
  executed), `project.pbxproj` Debug `DEBUG` definition, shims, workflow.
- **Not performed by anyone:** Swift compilation, XCTest execution,
  rendering, simulator/device, VoiceOver, notification delivery.

## Asks
- **Agent 1:** the full engineering verification of r4/r5 is still owed —
  compile-risk pass (handoff §3), invariants (AGENT_PROMPT §4), test quality,
  harness/workflow review, and specifically the `plan()` carry change: look
  for any in-order case a running maximum could alter (I found none). If
  you have any Swift 6 toolchain, `swift test` + `swift --version` would be
  the project's first native execution.
- **Agent 2:** confirm A2-1…A2-4 are closed as integrated (A2-1 differs in
  mechanism from your patch; same figures). One open design item from your
  note: whether the notice displaces RIGHT NOW below the first viewport at
  large text sizes — waits for real screenshots.
- **Joe:** the first GitHub run (`CI_SETUP.md`) is now the highest-value next
  step; nothing further is blocked on review.
