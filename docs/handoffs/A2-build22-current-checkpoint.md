# Build 22 — current A2 handoff checkpoint

Observed **October 16, 2026, 16:05 UTC (10:05 Denver)**. Supersedes historical state in the [backup runbook](A2-build22-contingency-2026-10-16.md). Refresh head, comments and jobs before acting.

## Ownership and current source

- **A3 remains implementation/integration/release lead; A1 owns assigned testing.** No explicit handoff, successor branch or unavailability announcement in current #24/#15. Silence is not evidence of unavailability.
- Active `wip/build22`: **84ac8c814c9d82d9281c2349387b8ff070605358**, committed 15:09:18 UTC; ref rechecked 16:04 UTC.
- Latest coordination: [A3 #24/6218468354](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6218468354) (15:09 UTC); [A1 #15/6217247846](https://github.com/josephdorseyc-boop/dinner-together/issues/15#issuecomment-6217247846). Both issue bodies and comments reconciled; no later comments at check time.
- A2 writes documentation only on this dedicated branch. No active-branch write, duplicate patch, CI dispatch/rerun, release change, takeover or release.

## New validation blockers — root causes not established

### 1. Night-mode assertion fails twice on 928660b

[Native 38915092856](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38915092856), source **928660b17adda278473cdc4f022db67228d9bb3e**, finished **failure**. iPhone part 2 job **117020403305**:

- `test56_fullScreenTimersNight`: actual accessibility value **Day**, expected **Night** at UITestSupport.swift:2642, under the test's `-dt-appearance dark` path.
- 28 executed, 27 passed, 1 failed, 0 skipped. Isolated retry also failed: 1 executed, 0 passed.
- Core, iPad and iPhone part 1 passed; part 1 required retry of test01. This is not a fully green native run.
- Immutable evidence **9f2a2b3529ff9a18efa138c790dea9919e00d75b**: [RUN.txt](https://github.com/josephdorseyc-boop/dinner-together/blob/9f2a2b3529ff9a18efa138c790dea9919e00d75b/RUN.txt) binds source/run; [SUMMARY.md](https://github.com/josephdorseyc-boop/dinner-together/blob/9f2a2b3529ff9a18efa138c790dea9919e00d75b/SUMMARY.md) records assertion and failed retry.

**A3 investigates appearance/launch/presentation; A1 verifies test intent and actual rendering.** The night-mode production/test source is unchanged between 928660b and current head, but current-head test56 has no verdict yet. Do not infer a device-wide dark-mode failure or waive the assertion.

### 2. Current-head Duo automatic nightstand entry fails

[Duo 38921685281, job 117042934599](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38921685281/job/117042934599), source **84ac8c814c9d82d9281c2349387b8ff070605358**:

- Part 1 **failed**: `test55_fullScreenTimers`, UITestSupport.swift:2653, “the nightstand opens the timers on its own.” 19 executed, 18 passed, 1 failed, 0 skipped (log-derived; result bundle unreadable).
- Also exit **124** and attachment export exit **64**, with **58 direct captures** preserved. Test assertion and post-suite/finalization failure are separate evidence; this part did start and execute its tests.
- Immutable evidence **03ccd26fce4d5ba7231bba62808c2d7507fdb117**: [RUN.txt](https://github.com/josephdorseyc-boop/dinner-together/blob/03ccd26fce4d5ba7231bba62808c2d7507fdb117/RUN.txt), [SUMMARY.md](https://github.com/josephdorseyc-boop/dinner-together/blob/03ccd26fce4d5ba7231bba62808c2d7507fdb117/SUMMARY.md).
- Test source already documents that the Duo simulator cover does not turn. Whether this failure is an app activation defect, orientation/test-fixture limitation or another issue is **unresolved**; it is not proof of a real-device failure.

**A3 owns implementation/harness reconciliation; A1 owns pose/test review and hang verification.** Preserve automatic full-screen tent/nightstand behavior as a product requirement; do not silently skip it or claim the old pre-test hang explains this assertion.

## Source integrations since the previous checkpoint

A3 confirms all in [#24/6218468354](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6218468354); commit comparison 928660b...84ac8c8 reviewed.

| Commit | Implemented in source; verification limit |
| --- | --- |
| **23171fe4470965eaf06b463d020de3c984145d1d** | Pipe-free screenshot process check; 7 regressions, 10 parser checks and 25 fake-toolchain scenarios pass in current CI. Earlier false-crash finding is addressed; no actual app crash established by that old log. |
| **c60324285a458382d735016b69498d5fae9ceb4f** | Cached alarm coverage requires enabled permission, preserving foreground fallback after revocation. Native error injection/device delivery still pending. |
| **da10d92daf6d6363b385303f8a4fdc0f154da925** | Go to Cooking dismisses from window root; Done retains local dismissal. Source-reviewed, targeted native Timers-sheet/editor-preservation proof pending. |
| **84ac8c814c9d82d9281c2349387b8ff070605358** | Release metadata fail-fast guard integrated from **045c58c815729b66cc067ab757a7ccb0c4c79e3c**; 7 release dry-runs pass. No signing/archive/export/upload verification implied. |

Earlier integrated: boards 02/03 (`ebb84d4` / `73a4aeb`), per-reminder fallback/tombstones, stale-deadline coverage invalidation (**d1776c096ef06280ca523d461e4f700d1e53c04c**), skipped-case diagnostics (`062ebca`), settled r31 capture checks (`ae2da06`), dark/dim night timers (**928660b17adda278473cdc4f022db67228d9bb3e**). These are implementation claims, not blanket native/device passes. Do not integrate duplicate A2 Bash/release candidates.

## Exact-current-SHA Actions

Snapshot 16:04 UTC, all source **84ac8c814c9d82d9281c2349387b8ff070605358**:

| Run | Current evidence |
| --- | --- |
| [38921631454 engine](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38921631454) | Success. |
| [38921681071 native](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38921681071) | In progress. Core job **117042919494 passed**: Debug and simulator Release builds, **239/239 XCTest**, **228/228 macOS engine/store**, **32 screenshots, 0 failures**. Linux and JS/harness jobs passed; iPad and both iPhone UI jobs remain running. Not a full native pass; static captures do not establish full-screen visual fit. |
| Same native run, job **117042919160** | 128 JS model assertions + 5 async model scenarios; 10 parser + 7 process checks; 25 harness + 7 release fake-toolchain scenarios pass. These do not execute native alarm/device behavior. |
| [38921685281 Duo](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38921685281) | In progress overall, but part 1 already failed as above; parts 2/3 running. No all-green Duo result. |

Current core artifact **12057330730**, `ui-review-evidence-38921681071-core`, and **12057046472**, `ci-part-core`, preserve source/run. Previous 928660b Duo **38915097014** was cancelled, not passed. Historical fully green native baseline remains **e273cdd3f498061406bd0f1ca3f36c5b0d1c2168 / 38906195142** (239 unit, 28+27 iPhone UI, 26 iPad UI), before boards/alarm/night follow-ups.

## Design and remaining work

- Boards **02/03 approved** in [#24/6215903573](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6215903573). Exact source **3db56d9810d0e1fc9ff032e81f648f5d39f1d279**; [board specs](https://github.com/josephdorseyc-boop/dinner-together/blob/3db56d9810d0e1fc9ff032e81f648f5d39f1d279/docs/design/build22-proposals-2026-10-16/README.md) read. Their “awaiting approval” text is historical and superseded.
- **Full-screen timers in BOTH tent and nightstand are mandatory.** Dedicated in-app page is implemented; locked StandBy/Live Activity is a separate system-owned surface. Actual tent entry, charging/orientation lifecycle, safe areas, idle lock, exit/restored route and unchanged deadlines need verification.
- Dark/dim requested by Joe and implemented; current native evidence fails test56. No outstanding color decision is inferred. One-dish no-photo cream page and fixed glass-card position remain Build 22 decisions. No Add a step or global Timing Save scope.
- **A1 outstanding:** new test intent/r31 review; test18; post-suite hang; test53 unsupported-cover selection decision; unmatched wording-edit refusal; mid-cook unstarted edit reflected in timeline while started step stays fixed; Live Activity retry seam/regression; alarm error injection including moved deadline [throw, success], repeated cancel failure, revoked permission; plain-language October 23 device checklist. No fresh delivery confirmed.
- **A1 latent mainonly patch** (#15/6217247846) remains syntax-only checked; current harness still uses the array. A3 reconciles; no duplicate A2 patch.
- **A3 outstanding:** new night/nightstand failures, runtime-availability-before-retry work, targeted Go to Cooking-over-Timers and ordinary Done/unsaved-editor checks, current-board/AX3/settled landscape visual review. Current native UI results are still pending.
- **Real device:** no new evidence. Cover/tent rotation, locked StandBy fit, silent/Focus alarm delivery and Lock Screen Stop remain hardware-only checks; simulator compile/UI, source analysis, synthetic tests and hardware verification must stay distinct.

## Release and handoff readiness

Latest release run remains **38845842034**, source **cb0e3973fca5a03fd5faa5e0487bfd45cd11f3f3** (Build 21, successful workflow/reported upload); `main` remains that SHA. No Build 22 release run or GitHub release observed; Apple processing/tester availability not established. Widget distribution signing and real archive/export are unverified. Keep exact-candidate native/Duo gates and `require_green=true`.

No takeover initiated. October 20 RC / October 21 TestFlight remain historical plans, not completion evidence. Before any explicit handoff, refresh pushed source/evidence, reconcile A1/A3 ownership and request any unpushed work; never overwrite A3's active branch.
