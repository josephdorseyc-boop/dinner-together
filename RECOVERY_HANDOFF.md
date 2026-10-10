# RECOVERY_HANDOFF — Dinner_Together_Recovery_Candidate_v028 **r7** — first fully green native run

> **Native validation has run.** GitHub Actions (`josephdorseyc-boop/dinner-together`),
> Xcode 16.4 on macOS 15.7.9, iOS 18.5/18.6 simulators. CI run 5
> (`214b87f`): app and test targets compile with **0 errors, 0 warnings**;
> **XCTest 61/61 on an iPhone 17 simulator and 61/61 on an iPad (A16)
> simulator** (Xcode result bundles: 0 failed, 0 skipped); `swift test`
> 61/61 on macOS and on Linux; 28 seeded screenshots captured and reviewed.
> Evidence and 12 representative screenshots: `docs/evidence/run-5/`.
> Full logs and all 28 PNGs: the repo's `ci-results` branch (force-updated
> every run).
>
> Getting there took five runs, each finding one real thing: run 2 — the
> hand-written project never gave the test bundle a `PRODUCT_NAME`
> (`PlugIns/.xctest`); run 3 — my r3 debug hook called a `@MainActor`
> initializer from a nonisolated context (the only compile error in the
> app target); run 4 — Agent 2's predicted defect confirmed by rendering: at
> accessibility text size the notice filled the first screen and hid the
> urgent card, fixed by a compact notice at those sizes; run 5 — green, and
> a log-interleaving artifact that made the prose test counter undercount
> by one, fixed by reading Xcode's result bundle instead. Reviewers' earlier
> findings (A1-1…3, A2-1…4) are all confirmed closed by execution.
>
> **Still not performed by anyone:** physical device, VoiceOver reading
> order, notification delivery, haptics, and the interactive flows (the
> review sheet and dialogs are not photographed; that needs an XCUITest
> target). One open design observation for Agent 2 in
> `docs/evidence/run-5/README.md` (primary button at the fold with an
> expired timer at default text size).
>
> r7 code delta vs. r6: `CookingView.readinessNotice` compact mode at
> accessibility sizes; `LaunchOptions.notificationService()` is `@MainActor`;
> `project.pbxproj` test-target `PRODUCT_NAME`/`LD_RUNPATH_SEARCH_PATHS` and
> `DEBUG` defined once at project level; harness: `-DDEBUG` grep, complete-app
> check, xcresult-based counts, results published to git branches. No
> scheduling, store, model or persistence change since r5.

> **r6 verified by Agent 1 — 61/61.** `swift test` on the pristine r6 tree:
> all 61 XCTest methods pass, 0 failures, all 12 classes, first try (Swift
> 6.0.3, Ubuntu). Evidence tier: **XCTest execution, Linux, engine + store
> only.** Agent 1 compared my re-implementations of A1-1/A1-2/A1-3 against
> their original patches line by line (functionally identical; nothing to
> forward), traced the r5 `plan()` running-maximum change on every path
> (provably a no-op for in-order flows; the only behavior change is the
> targeted out-of-order case, consistent with `dependencyInfo`), confirmed
> the A2 copy changes agree with the updated assertions, confirmed the
> cumulative patch reproduces r6 byte-for-byte, and confirmed the CI gate's
> expected count (61) equals the executed count. **No new findings.** Code
> files in r6.1 are byte-identical to r6; only this file, `ENGINE_TESTS.md`
> and `CI_SETUP.md` changed. Agent 2's confirmation of A2-1…A2-4 (r5) is
> still open; nothing is blocked on it.

> **r6 integrates Agent 1's r4 findings** (`AGENT1_FINDINGS_r4.md`, via Joe;
> their three `.patch` files did not arrive, so each fix was re-implemented
> from the finding text). **First native execution in the project:** Agent 1
> ran `swift test` (Swift 6.0.3, Ubuntu 24.04, x86_64) on r4 via the
> Package.swift harness — **59/59 XCTest methods passed, 0 failures, all 12
> classes**, after the two harness fixes below. Evidence tier: XCTest
> execution, Linux, engine + store only; views, TimerCenter and the real
> NotificationManager remain unexecuted; nothing has been compiled for iOS.
> Patch stream A1 (harness/test-only; no app source changes):
> A1-1 (S1) Linux has no `URL.documentsDirectory` → `#if os(Linux)` stand-in
> in `EngineTestSupport.swift` (never evaluated by tests) · A1-2 (S1) nine
> synchronous methods in `@MainActor` test classes break Linux test
> discovery → marked `async` (Xcode-safe) · A1-3 (S2) the CI gate's
> `grep -c 'func test'` counted the `testMenu()` helper → renamed
> `makeTestMenu()`; the expected count is now the true **61** (59 executed
> by Agent 1 on r4 + 2 added in r5, which nobody has executed yet).
> JS 128/128; dry run 10/10. `recovery-candidate-r5-to-r6.patch` is the delta.

> **r5 integrates Agent 2's r4 review** (`AGENT_2_REVIEW_R4.md`, received via
> Joe). Patch stream A2 (kept separate, applied by the integrator):
> A2-1 lower-bound headline floors (implemented as `ReadinessReport.lowerBoundMinutes`
> + VoiceOver phrase, not the view-local computation in the proposed patch;
> same outcome, testable) · A2-2 early-finish notes name the timer deadline
> and ask to check (applied verbatim) · A2-3 screenshots fail when a required
> appearance can't be set (applied verbatim; new dry-run fixture) · A2-4
> proposal B copy (applied verbatim; B is now implemented, copy only).
> Product note upgraded to S2: `plan()` now carries a running maximum over
> each dish (same rule as `projectedEnds`), so the displayed plan agrees with
> `dependencyInfo` after an out-of-order completion — **`plan()` is no longer
> byte-identical to v0.2.8**; one Swift test and three JS assertions cover
> it; the 65 baseline JS assertions still pass. Agent 1's engineering
> verification of r4/r5 is still owed. 61 XCTest methods (written; 59
> executed by Agent 1 on r4, see r6 note); JS 128/128; dry run 10/10. `recovery-candidate-r4-to-r5.patch`
> is the delta.

> **r4 (same cooking behavior as r2/r3) fixes the validation path after
> Agent 2's pre-run review.** (1) `project.pbxproj` Debug configurations now
> define `DEBUG` (`SWIFT_ACTIVE_COMPILATION_CONDITIONS`), so the `#if DEBUG`
> launch flags exist; the pass script also verifies `-D DEBUG` in the build
> log. (2) Required steps that fail or cannot run (missing simulator, app not
> built, tests not executed, screenshots missing, no summary) now produce ❌,
> `status.txt`, a non-zero exit, and a failed workflow job; `swift test |
> tee` no longer masks failures (pipefail). (3) Test counters are fixed (no
> `"0\n0"`), and executed counts are checked against the 60 `func test`
> methods in the source on iPhone, iPad and `swift test`. (4) Found by the
> new dry run: `devices.env` values are now quoted — real simulator names
> like "iPad Pro 13-inch (M4)" broke `source` and lost `APP_PATH`.
> `native-validation/dry-run/run.sh` exercises the scripts against a fake
> toolchain in nine scenarios (ten since r5; all pass here) and runs in CI. No Swift source
> changed between r3 and r4. `recovery-candidate-r3-to-r4.patch` is the delta.

> **r3 (same cooking behavior as r2) adds the no-Mac validation path.**
> Joe has no Mac, so native validation runs on GitHub's macOS machines:
> `.github/workflows/native-validation.yml` + `native-validation/` (build,
> XCTest on iPhone and iPad simulators, `swift test` on Linux and macOS,
> seeded simulator screenshots), with `CI_SETUP.md` as the step-by-step.
> The only Swift changes since r2 are two DEBUG-only launch options
> (`LaunchOptions` in `DinnerTogetherApp.swift`; initial tab in
> `ContentView.swift`) used by the screenshot script; release builds ignore
> them. `recovery-candidate-r2-to-r3.patch` is that delta. Everything else
> in this document describes r2's behavior and is unchanged.

Candidate for routine-lateness recovery, built on the unmodified v0.2.8
package. **Not a release.** Marketing version and build number are left at
0.2.8 / 9 on purpose; assign the next canonical number at integration.
Revision 2 responds to `FEEDBACK_RECOVERY_CANDIDATE.md` (reviewing agent,
October 9, 2026). Written on Linux on October 9, 2026 by the recovery-UX
agent. **No Swift was compiled, no XCTest executed, no UI rendered, no
device used** — this environment cannot reach a Swift toolchain (swift.org,
GitHub and apt are all blocked here). Direct inter-agent messaging was not
available; the other agents were not contacted directly. Joe forwards.

Companion files: `RECOVERY_REVIEW.md` (why), `RECOVERY_COPY_AND_FLOWS.md`
(screen copy and flows; A implemented, B and C proposed),
`ENGINE_TESTS.md` (**new**: how to run the native engine/store tests with
`swift test`, no Xcode), `recovery-candidate-v028.patch` (unified diff
against pristine v0.2.8, r2), `recovery-candidate-r1-to-r2.patch` (what
changed since the reviewed r1), `optional-expired-timer-copy.patch`
(proposal B as copy-only patch, **not applied**).

## 0. r2 — response to the review, finding by finding

| # | Finding | Status in r2 | Where |
|---|---|---|---|
| 1 | `projectedEnds` dependency carry: an out-of-order Done step reset the floor, so a3 projected +65 instead of +75 | **Fixed.** Carry is a running maximum (`dependencyFloor = max(dependencyFloor ?? end, end)`); the Done step's own entry keeps its actual end. Mirrored in JS. | `Scheduling.projectedEnds`; tests `testOutOfOrderCompletionKeepsDependencyCarry` (reviewer's fixture: +75, a2 keeps +40, a3 still blocked by a1 per `dependencyInfo`), `testRunningFirstStepCarriesPastCompletedMiddleStep` (+72 ≥ deadline + 10); JS R15 (reviewer's single-dish repro → 75), R16, R19 (in-order and out-of-order-final unchanged) |
| 2 | All-done guard belongs in the report/store, not only the view | **Fixed.** `Scheduling.readinessReport` returns nil when no step is unfinished; the view's own `allDone` filter was removed so there is one rule. `moveDinnerToEstimatedReadiness` therefore returns nil with no undo frame or history. | tests `testFinishedDinnerReportsNothingEvenIfLate` (pure; `projectedReadiness` still reports the honest late end), `testFinishedDinnerCannotBeMoved` (serveAt, undo depth, history unchanged); JS R8, R18 |
| 3 | "check it and mark it done" implies expiry = readiness | **Fixed.** Reasons now read "check the food; mark this step done when it's ready" / "…mark that step done when it's ready. After it, about N min of X steps remain." State transitions unchanged. | `Scheduling.holdUpReason`; tests assert "check the food" present and "mark it done" absent; JS R5 |
| 4 | Rounding to nearest can set the target before the estimate | **Fixed as recommended.** `ReadinessReport.driftMinutes` (nearest) stays for the headline; new `moveMinutes` (rounded up) drives the proposal. `SessionStore.readinessMoveProposal(now:)` builds the preview and `moveDinnerToEstimatedReadiness` applies exactly that proposal — one function, so preview and apply cannot diverge. Sheet caption: "Dinner moves in whole minutes, so the new time is never earlier than the estimate." | tests `testMoveMinutesRoundUpWhileDriftDisplaysNearest` (7 m 20 s → display 7, move 8; exact 7 → 7), `testPreviewAndMoveAgreeAndNeverUndershootEstimate` (store: preview == applied, serveAt ≥ estimate, applied once); JS R14, R17 |
| 5a | PlanView says "Running late" | **Fixed.** Now "Use “Adjust time” or “Review dinner time” while cooking, or reset progress to choose a new time." | `PlanView.swift` (one line) |
| 5b | Floored estimate is a lower bound; keep that visible | **Done.** `ReadinessReport.estimateIsLowerBound` is true when an expired, still-cooking timer is in the critical step's dish. Notice headline becomes "At least N min behind" / "…can't finish before 7:05"; sheet column reads "EARLIEST READINESS" with an amber note; VoiceOver says "Earliest readiness". | `Scheduling.readinessReport`, `CookingView.readinessNotice`, `ServingSheetView`; tests assert the flag in the expired-timer and late-prep scenarios; JS R5, R2 |
| 5c | Keep implemented vs. proposed separate; no timer extension / overnight recovery | **Kept.** B and C remain proposals. B's copy-only change is shipped as a *separate, unapplied* patch for Joe's call. | `optional-expired-timer-copy.patch`, `RECOVERY_COPY_AND_FLOWS.md` |

Also new in r2, beyond the review: a `swift test` harness so the engine and
store tests can actually be executed by anyone with a Swift 6 toolchain or
Docker — see §3 and `ENGINE_TESTS.md`.

## 1. Changed files (cumulative vs. pristine v0.2.8)

| File | Change |
|---|---|
| `DinnerTogether/Scheduling.swift` | **Added** `ReadinessReport` (fields: `serveAt`, `estimatedReadyAt`, `driftMinutes`, `lowerBoundMinutes` (r5), `moveMinutes`, `estimateIsLowerBound`, `criticalStepID`, `reason`); `readinessNoticeThreshold` (60 s); `projectedEnds` (running-max dependency carry); `projectedReadiness`; `readinessReport`; private `holdUpReason`. **Modified (r5):** `plan()` dependency carry is a running maximum (out-of-order completions no longer pull later steps ahead of an unfinished predecessor); `proposeDelay` early-finish note copy (A2-2). Unmodified: `expectedMealEnd`, `completeStepEffects`, `applyDelay`, `dependencyInfo`, `checkFeasibility`, `attentionWarnings`. |
| `DinnerTogether/SessionStore.swift` | **Removed** `@Published pendingServingProposal`, `acceptServingProposal()`, `keepServingTime()` and the five `pendingServingProposal = nil` lines. **Added** `readinessReport(now:)`, `readinessMoveProposal(now:)`, `@discardableResult moveDinnerToEstimatedReadiness(now:) -> DelayProposal?`. `completeStep` appends the feasibility sentence to history instead of caching a proposal; never touches `serveAt`. |
| `DinnerTogether/CookingView.swift` | Auto-presented serving sheet removed; `@State showReadinessReview`; derived `readiness`; `readinessEmphasisMinutes` (10); `readinessNotice` card after `servingCard` (lower-bound wording, floored minutes r5); `.sheet(isPresented:) { ServingSheetView() }`; accessibility labels "Chosen dinner time …" and "Timer deadline …". **r5 (A2-4):** expired featured timer reads "Check the food", explains that the timer ending is not the food finishing, and its primary button is "Mark done after checking" with a VoiceOver hint. Warning-panel logic untouched. |
| `DinnerTogether/Sheets.swift` | `ServingSheetView` is a live view (`@EnvironmentObject store`/`timers`, no init parameters) showing chosen vs. estimated/earliest readiness, the reason, the lower-bound note, the whole-minute caption, the `DelayProposal` explanation and early-finish notes, "Move dinner to …" / "Keep … for now". Other sheets untouched. |
| `DinnerTogether/PlanView.swift` | One copy line (review 5a). |
| `DinnerTogetherTests/DinnerTogetherTests.swift` | 3 tests rewritten to the new API with their regression intent kept; 20 added (`RecoveryNoticeTests` 13, `RecoveryStoreTests` 7); `testDelayPreservesRunningStep` gained two copy assertions (A2-2). **r6:** nine synchronous store tests marked `async` (A1-2); helper `testMenu()` → `makeTestMenu()` (A1-3). 41 → 61 test methods, 12 classes. |
| `logic-checks/mirror-test.cjs` | Mirror of the readiness functions, the `plan()` carry and the mini-store move/preview; scenarios R1–R22. 65 → 128 assertions. |
| `Package.swift`, `DinnerTogether/EngineTestSupport.swift`, `EngineSupport/SwiftUIShim/SwiftUI.swift`, `ENGINE_TESTS.md` | **New** `swift test` harness. `EngineTestSupport.swift` is deliberately not referenced by the Xcode project; **r6** adds a Linux-only `URL.documentsDirectory` stand-in to it (A1-1). Executed by Agent 1 on Linux: 59/59 (r4). |
| `DinnerTogether/DinnerTogetherApp.swift`, `DinnerTogether/ContentView.swift` | **r3:** DEBUG-only `LaunchOptions` (`-dt-open-cooking`, `-dt-inert-reminders`) and `InertNotificationService`; `ContentView` starts on Cooking when asked. Release builds: constant false, real `NotificationManager`, Tonight tab — unchanged. |
| `.github/workflows/native-validation.yml`, `native-validation/*`, `CI_SETUP.md` | **r3:** GitHub Actions validation (Linux `swift test` + JS model; macOS Xcode build, XCTest on iPhone/iPad simulators, seeded screenshots; artifact upload). |
| `DinnerTogether.xcodeproj/project.pbxproj` | **r4:** `SWIFT_ACTIVE_COMPILATION_CONDITIONS = "$(inherited) DEBUG"` added to the two Debug configurations (project C002, app target C011). Release configurations untouched. No file references changed. |
| `START_HERE.md` | Pointer lines. |
| `RECOVERY_*.md`, `recovery-candidate-v028.patch`, `recovery-candidate-r1-to-r2.patch`, `optional-expired-timer-copy.patch` | New / refreshed. |

Untouched: `Models.swift` (persistence schema), `Notifications.swift`,
`TimerCenter.swift`, `Theme.swift`,
`DinnerCatalog.swift`, the scheme. No files were added to the Xcode
targets; the only project-file edit is the Debug `DEBUG` definition (r4).

Net state: one `@Published` field removed, one `@State` Bool added, no
persisted fields added.

## 2. Behavior

### Routine lateness (implemented)
- The cooking screen derives `ReadinessReport` from the session and the
  clock on every tick. When unfinished work is estimated to finish ≥ 1 min
  after `serveAt`, an inline card under DINNER AT shows "Running about N min
  behind" (or "At least N min behind" when the estimate is a lower bound),
  both times, and one derived reason. No modal opens on its own; there is
  no dismiss and nothing to invalidate. A finished dinner shows nothing.
- **Estimate.** `projectedReadiness` walks each dish forward: done → actual
  end; cooking → pinned deadline, floored at `now`; pending → derived
  planned start, but not before `now` or before every earlier step in the
  dish is projected to finish (running-max carry, r2). The derived plan is
  read, never rewritten; `expectedMealEnd` (the v0.2.8 invariant) is
  untouched.
- **Explicit decision.** "Review dinner time" opens `ServingSheetView`,
  which shows the live report and `readinessMoveProposal(now:)` — the
  existing `proposeDelay` built from `moveMinutes` (rounded up). "Move
  dinner to X" calls `moveDinnerToEstimatedReadiness(now:)`, which
  recomputes at that instant, applies the same proposal once via
  `applyDelay`, pushes one undo frame, appends a history line. The next
  report derives from the new `serveAt`, so there is no residual drift and
  no double application. Undo restores the prior session including timer
  deadlines (existing machinery).
- **Interruption policy (initial UX choices):** notice at ≥ 1 min
  (`Scheduling.readinessNoticeThreshold`), amber at ≥ 10 min
  (`CookingView.readinessEmphasisMinutes`).

### Invariants checked against the diff
Unchanged and untouched: delay keeps actuals/deadlines; early start checks
prerequisites; unstarted completion confirms and leaves start unknown; undo
never restarts a timer; readiness considers every step (`expectedMealEnd`;
`projectedEnds` also iterates every step and, since r2, carries every
earlier step's projected end forward exactly as `startStep`'s prerequisite
check does); notification continuation validation and reconciler; warning
expansion; duration-edit lock. Reset/menu/stale "proposal clearing" is now
vacuous (nothing stored) and tested as "the report follows the new session".

### Expired timer (B) and stale resume (C)
Design only. B's copy-only change is available as
`optional-expired-timer-copy.patch` (unapplied). See
`RECOVERY_COPY_AND_FLOWS.md`.

## 3. Validation performed — precisely

Performed here (Linux, Node 22), r2:
- `node logic-checks/mirror-test.cjs` → **PASS: 120 supplemental outcome
  assertions** (65 baseline + 55 recovery). The reviewer's `repro.cjs`
  fixture is reproduced as R15 and now yields 75 (was 65). Every number the
  native tests assert has an executed JS counterpart built from the same
  fixtures (test menu and Steak night).
- `node logic-checks/reconciliation-test.cjs` → PASS: 5 (unchanged).
- Bracket-balance script (strings/comments stripped) passes on all Swift
  files, candidate and baseline.
- Manual static review of every changed hunk.
- `recovery-candidate-v028.patch` applied with `patch -p1` to a fresh
  extraction of the original v0.2.8 ZIP; the result is byte-identical to the
  candidate tree, and the JS checks pass there.

**Executed — Xcode 16.4, GitHub macOS runner (CI run 5, `214b87f`):** app
+ test targets compile (0 errors, 0 warnings); XCTest **61/61 on iPhone 17
simulator and 61/61 on iPad (A16) simulator** per Xcode's result bundles;
`swift test` 61/61 on macOS; 28 seeded screenshots on both devices in light,
dark and accessibility text size, reviewed against `EXPECTATIONS.tsv`
(`docs/evidence/run-5/`).

**Executed — Linux:** Agent 1, r4 59/59 and r6 61/61 (Swift 6.0.3); the CI
Linux job, 61/61 on every run since r6.

**Not performed by anyone:** physical device, VoiceOver reading order,
notification delivery, haptics, interactive flows (review sheet, dialogs).
The JavaScript results remain algorithm-model results.

**What would close most of that gap in one command:** `swift test` from the
project root (macOS with Xcode 16 CLT, or `docker run --rm -v "$PWD":/src
-w /src swift:6.0 swift test`). It compiles the real engine and store files
and runs all 61 XCTest methods — not the views. Executed by Agent 1 on
Linux (r4); the macOS leg is still unexecuted. Watch items are in
`ENGINE_TESTS.md`.

### Compiler watch items (unverified, not confirmed errors)
1. `readinessReport`: `ends.max(by:)` over `[String: Date]` with a nested
   `rank` function; a closure-based `lowerBound` constant. Expected fine.
2. `holdUpReason`: `compactMap` to a labeled optional tuple then `.max`.
   Expected fine in Swift 5 mode; a tiny struct is the fallback.
3. `readinessNotice` / `ServingSheetView.body`: `let` bindings inside
   `if let` blocks in `@ViewBuilder` bodies (the baseline already does this
   in `actionColumn`). The sheet's `if let a = …, let b = …` two-clause
   binding inside a ViewBuilder is ordinary Swift.
4. `(drift / 60).rounded(.up)` — `FloatingPointRoundingRule`; fine.
5. `ServingSheetView` relies on `TimerCenter` reaching the sheet through the
   environment, as `StalePlanView` relies on `SessionStore`.
6. Harness-only: ~~Swift 6 Foundation on Linux for `URL.documentsDirectory`;
   `@MainActor` XCTest classes on Linux~~ — both confirmed real by Agent 1
   and fixed in r6 (A1-1, A1-2). The Linux-only `SwiftUI` shim target name
   was accepted by SwiftPM in Agent 1's run.
7. Carried over, untouched: `Task { @MainActor [weak self] … }` in
   `NotificationManager.ensureAuthorization` and the unstructured Tasks in
   `resyncNotifications`.

## 4. Open questions

1. **One readiness definition or two?** `completeStepEffects` still uses the
   plan-anchored `max(expectedMealEnd, now)` for its (now history-only)
   feasibility sentence, while the notice uses `projectedReadiness`. They
   can differ when work is late to start. Harmless today (the sentence is
   only logged), but if history is ever rendered, pick one. My suggestion:
   switch the sentence to `projectedReadiness` at that point, with a test.
2. **Hide "Review dinner time" while the estimate is a lower bound?** The
   flag exists; it is a one-line UI decision. I left the button visible
   because the sheet now explains the situation.
3. **Should "Keep … for now" write a history line?** Still no (repeatable,
   changes nothing). The old `keepServingTime` did.
4. ~~`plan()` out-of-order carry~~ — fixed in r5 at Agent 2's request
   (S2: the timeline could show a planned interval that conflicts with an
   unfinished prerequisite). Agent 1: please verify the regression
   `testPlanCarriesRunningPredecessorPastOutOfOrderCompletion` and look for
   any in-order case the running maximum could change (I found none; the
   65 baseline JS scenarios still pass).

## 5. Merge instructions

Preferred: apply the cumulative patch to a pristine v0.2.8 and review hunk
by hunk. Reviewers who already read r1 can read
`recovery-candidate-r1-to-r2.patch` instead.

```
unzip Dinner_Together_Native_v0_2_8.zip            # pristine baseline
cd DinnerTogether-v0.2.8
patch -p1 --dry-run < /path/to/recovery-candidate-v028.patch
patch -p1 < /path/to/recovery-candidate-v028.patch
node logic-checks/mirror-test.cjs && node logic-checks/reconciliation-test.cjs
swift test                                          # Mac CLT or Docker; see ENGINE_TESTS.md
```

Overlap points for concurrent edits:
- `SessionStore.swift`: deletions of `pendingServingProposal` lines plus one
  new "Readiness (derived, never cached)" section. Any added use of
  `pendingServingProposal` elsewhere must move to `readinessReport(now:)`.
- `CookingView.swift`: state var; `readiness` + constant; `.sheet`
  replacement; `readinessNotice` after `servingCard`; two accessibility
  labels. `onChange(of: warnings…)` deliberately untouched.
- `Sheets.swift`: only `ServingSheetView`. `ServingSheetView(current:…)` no
  longer exists.
- `PlanView.swift`: one string.
- Tests: three rewrites in place; new classes appended.
- New files (`Package.swift`, `EngineTestSupport.swift`, `EngineSupport/`,
  `ENGINE_TESTS.md`) are additive and can be dropped without affecting the
  app if the team doesn't want the harness.

Suggested CHANGELOG entry:
> **Routine lateness is reported inline, not by a modal.** The cooking
> screen shows chosen dinner time vs. estimated readiness (now-aware; idle
> time and every earlier unfinished step count) with a derived reason and a
> "Review dinner time" action. The cached `pendingServingProposal` is gone;
> moving dinner is an explicit, once-applied, undoable action through the
> existing delay path, rounded up to whole minutes. A finished dinner shows
> no notice. 18 native tests added (not executed); JS model 65 → 120; a
> `swift test` harness runs the engine and store tests without Xcode.

## 6. Remaining native checks

First, cheap and real: `swift test` (see `ENGINE_TESTS.md`); record the
toolchain and per-class results here.

Then on a Mac/device, unchanged from r1 plus the r2 items:
- Build both targets in Xcode; run the full XCTest suite (adds the views'
  compile check the harness can't give).
- Finish a step 2–3 min late → notice, quiet tone, reason names the step;
  dinner time unchanged; no sheet. Three more late finishes → one notice,
  numbers update.
- Leave a pending step unstarted 8 min past plan → notice with "late to
  start"; timeline planned ranges unchanged.
- **r2:** force-start and complete a dish's *second* step while its first is
  still pending (timeline "Review start" → "Start anyway", then Mark done).
  The notice must count the first step's remaining time; the third step
  stays "Waiting for …".
- Tap Review dinner time → both labeled times, reason, delay lines,
  early-finish notes; Move applies the button's time exactly; Undo restores;
  Keep changes nothing. **r2:** with a drift that isn't a whole minute, the
  applied time is the next whole minute, never earlier than the estimate.
- Let a timer expire → notice reads "At least N min behind … can't finish
  before …", reason says "check the food"; sheet shows "EARLIEST READINESS"
  and the amber note; mark done → estimate settles and wording returns to
  "estimated".
- Finish every step late → no notice; "Time to enjoy dinner."
- ≥ 10 min drift → amber, legible in Dark Mode. Reset / change menu → no
  notice.
- iPad regular width, narrow split view, largest Dynamic Type, VoiceOver
  order (DINNER AT → chosen time → timing update → Review button; running
  card "Timer deadline"; sheet "Chosen dinner time" then
  "Estimated/Earliest readiness").
- Re-check warning panel collapse (scenario 9) and the existing "Adjust
  time" flow after merge.
