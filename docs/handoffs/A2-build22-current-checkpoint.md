# Build 22 — current A2 handoff checkpoint

Observed **October 16, 2026, 14:27 UTC (08:27 Denver)**. Supersedes historical status in the [backup runbook](A2-build22-contingency-2026-10-16.md). Refresh GitHub before acting.

## Ownership and source

- **A3 remains implementation/integration/release lead. A1 owns assigned testing.** Latest #24/#15 comments contain no explicit handoff or unavailability announcement. Silence is not evidence of either.
- Active implementation: `wip/build22` at **928660b17adda278473cdc4f022db67228d9bb3e**, committed 14:21:09 UTC. No announced successor. Latest coordination: [A3 #24/6217436348](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6217436348); [A1 #15/6217247846](https://github.com/josephdorseyc-boop/dinner-together/issues/15#issuecomment-6217247846).
- A2 changed documentation only in this watch. No active-branch push, competing patch, CI dispatch/rerun, release-setting change, takeover or release.

## Implemented vs verified

| Source change | Evidence/status |
| --- | --- |
| cfa7747b3734109fedb949efb5ddf9f34c14ba01 / ae04df3cfc5ae542b272eb755c0de92f40c06ded | Dedicated full-screen timers, manual/tent/nightstand activation, idle-lock handling; Back to Cooking guidance and locked Timing rows. **Native tests passed at e273cdd**, not proof of every pose/layout. |
| e273cdd3f498061406bd0f1ca3f36c5b0d1c2168 | Bash 3.2 verbose-array blocker fixed. A2's duplicate Bash candidate is superseded. |
| ebb84d4fc95f5622342673be199960bc0637dbb3 / 73a4aeb8d9ee9a23b6fc45e2e11a6c465c218bac | Approved boards 02/03 implemented in source; per-reminder alarm fallback and cancellation tombstones. Board-layout native validation is **not fully green**. |
| d1776c096ef06280ca523d461e4f700d1e53c04c | A3 integrated Joe-relayed alarm patch. It clears stale coverage before replacement cancellation; addresses [P1 #24/6216958837](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6216958837) **in source**. A1 native failure injection remains pending. |
| 062ebca0a34c2583608849aa36197e2a068b1b83 | Joe-relayed skipped-XCTest diagnostic patch integrated. A3 reports **10 parser checks + 25 fake-toolchain scenarios passed**. Hangs, skips and incomplete results still fail. |
| ae2da062c3c87515ce7e05126f024d3af09d662b | r31 nightstand capture now settles and checks turned geometry. Prior mid-turn screenshot is not accepted layout proof. New native evidence pending. |
| 928660b17adda278473cdc4f022db67228d9bb3e | A3 records Joe's 08:19 request for dark/dim timers at night. Implemented Dark Mode or 21:00–06:00, 72% content opacity, test56/r31d. Cooking otherwise stays cream. **Native/visual/device verification pending.** |

## Exact-SHA Actions evidence

Run/job details were read; top-level queue status can differ from individual jobs.

| Source SHA | Run | Observation |
| --- | --- | --- |
| **928660b17adda278473cdc4f022db67228d9bb3e** | [38915063873 engine](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38915063873) | Successful. |
| Same current SHA | [38915092856 native](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38915092856) | Linux + JS/model/harness/release dry-run jobs successful; four macOS jobs queued. Linux job 117020403565 confirms **228/228 tests**. No current-head native pass. |
| Same current SHA | [38915097014 Duo](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38915097014) | Three UI parts queued; no current-head Duo verdict. |
| ae2da062c3c87515ce7e05126f024d3af09d662b | [38914241820 native](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38914241820), [38914246396 Duo](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38914246396) | Both cancelled after newer 928660b runs appeared. Not passes; no reason inferred beyond API status. |
| 73a4aeb8d9ee9a23b6fc45e2e11a6c465c218bac | [38906946003 native](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38906946003) | Core gate **failed**: 239/239 unit tests passed, but static capture `ipad/all-done-late-dark` was reported not running. **31 screenshots, 1 failure**; three UI jobs still running. See new harness finding below. |
| e273cdd3f498061406bd0f1ca3f36c5b0d1c2168 | [38906195142 native](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38906195142) | **Fully successful**, all required gates. Job logs confirm **239 unit, 28+27 iPhone UI, 26 iPad UI**, no skips/failures. This predates boards 02/03, alarm patches and dark/dim changes. |
| Same e273cdd SHA | [38906198562 Duo](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38906198562) | Part 2 failed; parts 1/3 running. A3/log review: **18 executed, 17 passed, test53 skipped**, then post-suite finalization hung (exit 124), unreadable bundle/export exit 64. Pre-test startup did succeed for this part; original hang is not proven universally resolved. |

### NEW: screenshot app-running probe can falsely fail

Observed [core job 116992782498](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38906946003/job/116992782498) logs at 14:13:36 UTC:

- `screenshots.sh: line 82: printf: write error: Broken pipe`
- `FAIL: ipad/all-done-late-dark: app is not running 4s after launch (crash?)`

The same [probe remains at current head](https://github.com/josephdorseyc-boop/dinner-together/blob/928660b17adda278473cdc4f022db67228d9bb3e/native-validation/screenshots.sh#L78-L83): under `set -o pipefail`, `printf '%s' "$list" | grep -q "UIKitApplication:$BUNDLE"` can fail because grep exits after its match and printf receives SIGPIPE. **Local synthetic shell reproduction** with the exact app identifier present in a long process listing returned 1 and the same Broken pipe; a non-pipeline shell-pattern control returned 0. This confirms the false-negative mechanism, **not the actual simulator process state or an app crash**.

**A3 owns harness integration; A1 verifies.** Inspect original launchctl/crash evidence; use a pipe-safe probe and preserve genuine missing-process failures. No patch or new CI from A2. Run artifact `ui-review-evidence-38906946003-core` ID **12050889368** preserves this source/run; artifact `ci-part-core` ID **12050754622** also exists. Do not waive the failed gate or label it a product crash on current evidence.

## Designs and captures

Boards **02 and 03 approved** in [#24/6215903573](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6215903573), superseding stale proposal wording. Approved source: **3db56d9810d0e1fc9ff032e81f648f5d39f1d279**, [board directory](https://github.com/josephdorseyc-boop/dinner-together/tree/3db56d9810d0e1fc9ff032e81f648f5d39f1d279/docs/design/build22-proposals-2026-10-16).

**Full-screen timers in BOTH tent and nightstand remain mandatory.** Dedicated app presentation and system-owned locked/StandBy behavior are separate claims. Geometry-based tent activation, charging/landscape nightstand and manual entry must preserve underlying routes and deadlines. Dark/dim is now implemented per A3's recorded Joe direction; no outstanding color decision is inferred.

Native r31a/r31c evidence is at **762fd97a080f563366c6f6773922eebf7b40e2ef** on `ci-results`; its [RUN.txt](https://github.com/josephdorseyc-boop/dinner-together/blob/762fd97a080f563366c6f6773922eebf7b40e2ef/RUN.txt) explicitly binds it to **e273cdd / 38906195142**. A3 accepts upright manual entry/return captures but rejects r31b as mid-turn. Await settled landscape, dark/dim, AX3 and current-board captures; do not reuse old screenshots as current-head proof.

Duo part-2 immutable evidence: **9050897a4a2aa8eb5ec8d0104dab3aec8bb73bff**, [RUN.txt](https://github.com/josephdorseyc-boop/dinner-together/blob/9050897a4a2aa8eb5ec8d0104dab3aec8bb73bff/RUN.txt). Its old summary incorrectly says zero executed; the integrated parser corrects diagnostics on future runs, not this historical artifact's verdict.

## Pending work and release

- **A1:** simulator startup/r31/test18 review; test53 selection decision (A3 favors excluding the unsupported cover test, no gate relaxation authorized here); post-suite hang; unmatched edit refusal, mid-cook timeline, Live Activity retry seam, alarm error injection including moved-deadline [throw, success]/repeated failures, plain-language October 23 hardware checklist. No fresh delivery of these regressions/checklist confirmed in reviewed comments.
- **A1 latent mainonly patch:** [#15/6217247846](https://github.com/josephdorseyc-boop/dinner-together/issues/15#issuecomment-6217247846), syntax-only checked by A1; current source still uses the array. A3 owns reconciliation; no duplicate A2 patch.
- **A3:** Go to Cooking over the underlying Timers sheet ([#24/6216359507](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6216359507)) remains pending, with ordinary Done/unsaved editors preserved. Runtime-availability verification before retry remains A3's accepted harness work.
- **Release-only candidate:** `wip/a2-build22-release-gate-20261016`, **045c58c815729b66cc067ab757a7ccb0c4c79e3c**. Seven fake-toolchain cases reported passed; current release script still lacks the post-metadata fail-fast guard. A3 integrates. Do not cherry-pick combined duplicate b786816.
- **Real device:** no new evidence. Actual cover rotation/tent entry, locked StandBy/Live Activity fit, silent/Focus alarm delivery and Lock Screen Stop remain hardware checks. Native compile/UI, Linux tests, synthetic shell checks and fake toolchains are distinct evidence levels.
- Latest release workflow remains [38845842034](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38845842034), **cb0e3973fca5a03fd5faa5e0487bfd45cd11f3f3**, reported Build 21 upload. No Build 22 release observed; Apple processing/tester availability not established. New widget distribution signing/archive/export remains unverified. Keep exact-candidate native/Duo gates and `require_green=true`.
- No takeover initiated. Fresh A3/A1 reconciliation and unpushed-work check are required before any explicit handoff. October 20 RC / October 21 TestFlight remain historical plans, not completion evidence.
