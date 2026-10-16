# Build 22 — current A2 handoff checkpoint

Observed **2026-10-16 19:00:22 UTC** (Denver is UTC−06:00). Supersedes historical ownership, hardware dates and branch observations in the [backup runbook](A2-build22-contingency-2026-10-16.md). Prior detailed baseline evidence is preserved at [41c56db](https://github.com/josephdorseyc-boop/dinner-together/blob/41c56db731f94b6a9a5c2b52939da2f1aae4ff27/docs/handoffs/A2-build22-current-checkpoint.md). Refresh GitHub before acting.

## Ownership and scope

- **Explicit handoff has occurred; not inferred from silence.** A3 handed implementation/integration to A2 in [#24/6221940209](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6221940209) and stopped pushes, dispatches and scheduled check-ins. [#15/6221940484](https://github.com/josephdorseyc-boop/dinner-together/issues/15#issuecomment-6221940484) confirms this to A1.
- **A2 is temporary implementation/integration lead until Saturday October 17, 2026, 22:00 America/Denver (October 18, 04:00 UTC)**; ownership returns to A3 then. See [window clarification](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6222060301). This watch observes that separately authorized transfer; it initiates no takeover or implementation.
- **A1 retains assigned testing.** [Acknowledgment](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6222175822) and read-only findings delivered. A2 owns harness integration and page-color investigation. A1's newest assignments are independent staged-diff review, evidence-preserving post-suite hang investigation, and a proposed manual/automatic timer-test split; no duplicate workflow dispatches or overlapping harness edits.
- Full #24/#15 comment collections read: **60 / 56 comments** respectively; newest #24 is [hardware-date correction 6222487023](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6222487023), newest #15 is the handoff confirmation above.
- This observation changes documentation only on the dedicated contingency branch. No app/runtime patch, active-branch push, CI dispatch/rerun, release setting change or release action.

## Current source and implemented changes

Refs and commit diffs verified directly:

| Branch / exact head | State |
| --- | --- |
| `wip/build22` — **4ae4f31c851ae9b496aea0ec915a7c8c1c7c6667** | A3 handoff baseline, unchanged. Latest fully green ordinary native baseline; Duo is not green. |
| `a2/build22-lead-20261016` — **ff86f2a12e179f38fab142cc7ba947bb400ccb89** | Announced A2 continuation, one commit ahead: bake screen-capture orientation into landscape PNG/attachment; retain unmodified raw screen and app comparisons plus provenance. Test-only export change, not app layout. |
| `wip/a2-build22-harness-20261016` — **3f8195925968b684f841146812e84bea572b988d** | Separate staged harness branch, based on ff86f2a. **1084869ed739a1620a27c6b0f418e8d9eb252927** adds closed-Duo test53 filtering and fail-closed selection guards; 3f81959 preserves harness file permissions. Not integrated into the continuation branch. |
| `main` — **cb0e3973fca5a03fd5faa5e0487bfd45cd11f3f3** | Build 21 release baseline; unchanged. |

[Continuation commit](https://github.com/josephdorseyc-boop/dinner-together/commit/ff86f2a12e179f38fab142cc7ba947bb400ccb89) · [staged comparison](https://github.com/josephdorseyc-boop/dinner-together/compare/ff86f2a12e179f38fab142cc7ba947bb400ccb89...3f8195925968b684f841146812e84bea572b988d) · [A1 integration decisions / 6222366202](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6222366202) · [staging report / 6222411769](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6222411769).

Staged filtering applies only to exact selected `iPhone Duo` with closed/default/0 hinge, after round-robin sharding. It retains other assignments, recomputes expected counts, reports the hardware gap, preserves ordinary-iPhone test53 and leaves test55 selected. Invalid K/N and empty/zero-count selections fail before Xcode; no unfiltered fallback or skip allowance. A1's proposed unknown-orientation accommodation was **not adopted**. Do not duplicate or cherry-pick these active patches without the implementation owner's reconciliation.

## Exact-SHA validation

### Continuation ff86f2a — native verification IN PROGRESS

[Native run **38947972243 / #174**](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38947972243) binds **ff86f2a12e179f38fab142cc7ba947bb400ccb89**, started October 16 at 18:31:15 UTC (12:31 Denver).

| Job | Observed state |
| --- | --- |
| Linux **117131822501** | Completed success. |
| JS / fake-toolchain checks **117131822445** | Completed success; supplemental, not native UI/hardware proof. |
| Core **117131822015** | Build + XCTest step succeeded; seeded screenshot step still in progress; final required gate pending. |
| iPhone part 1 **117131822536** | Build + XCTest wrapper in progress; final gate pending. |
| iPhone part 2 **117131822597** | Build + XCTest wrapper in progress; final gate pending. |
| iPad **117131822458** | Build + XCTest wrapper in progress; final gate pending. |

No new complete native pass or visually reviewed ff86f2a landscape artifact yet. Do not transfer baseline pass counts or screenshot certification to this commit. No exact-ff86f2a Duo run observed.

### Staged harness 3f81959 — local/source checks and Linux only

A2 reports eight selection/guard checks, ten parser checks, seven screenshot-process checks, all 25 fake-toolchain harness scenarios, Bash syntax and diff checks passed. These are local/control-flow claims, not native verification. Exact-head [engine-quick **38949878358 / #235**](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38949878358) succeeded; preceding 1084869 [38949830675 / #234](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38949830675) also succeeded. **No native or Duo validation observed for 3f81959.** A1 diff review pending.

### Unchanged handoff baseline 4ae4f31 — native GREEN, Duo FAILED

All results here bind **4ae4f31c851ae9b496aea0ec915a7c8c1c7c6667**, not either newer branch. Actions conclusions rechecked; detailed counts/evidence carried from the immutable prior checkpoint.

- [Native **38931626337 / #173**](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38931626337): success; **239/239 XCTest, 28+28 iPhone UI, 26 iPad UI**, no skips/failures; 228 engine/store tests, 32 seeded screenshots. Immutable results **cf8d402a24893cf652337ef643aec11636354bf8**: [RUN.txt](https://github.com/josephdorseyc-boop/dinner-together/blob/cf8d402a24893cf652337ef643aec11636354bf8/RUN.txt), [SUMMARY.md](https://github.com/josephdorseyc-boop/dinner-together/blob/cf8d402a24893cf652337ef643aec11636354bf8/SUMMARY.md), [status.txt](https://github.com/josephdorseyc-boop/dinner-together/blob/cf8d402a24893cf652337ef643aec11636354bf8/status.txt). Core job **117076786840**; iPhone **117076786869 / 117076786825**; iPad **117076786824**. Night-mode test56 and ordinary-iPhone full-screen test55 passed this path, not real-device alarms/pose behavior.
- [Duo **38931629825 / #45**](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38931629825): all three required gates failed on Xcode 27.1; **56 executed, 52 passed, 3 failed, 1 skipped**. Every part reached its summary, then exit **124** / export **64**; results unreadable, direct captures preserved. No opened-window job in this selection.

| Duo part / job / immutable evidence | Evidence |
| --- | --- |
| 1 / **117076797059** / **ed29b14eb073ed7ffb45bacd634133bc23ae8283** | 19 executed, 18 passed, test55 failed at UITestSupport.swift:2714. Simulator=iPhone Duo; hinge empty; frame=466×678; runner orientation=0 (unknown), not verified portrait. 59 direct captures. [Summary](https://github.com/josephdorseyc-boop/dinner-together/blob/ed29b14eb073ed7ffb45bacd634133bc23ae8283/SUMMARY.md). |
| 2 / **117076797429** / **2ce3d869b3694a12f5034d76721c533deae9b2b9** | 19 executed, 18 passed, one skipped (test53); skip gate failed. 50 direct captures. [Summary](https://github.com/josephdorseyc-boop/dinner-together/blob/2ce3d869b3694a12f5034d76721c533deae9b2b9/SUMMARY.md). |
| 3 / **117076797641** / **4b1e16a7ca2575031976f93461ba1313225bb78a** | 18 executed, 16 passed; test03 launch timeout and test35 AX3 Page color sheet failed to dismiss after Done. 42 direct captures. [Summary](https://github.com/josephdorseyc-boop/dinner-together/blob/4b1e16a7ca2575031976f93461ba1313225bb78a/SUMMARY.md). |

Baseline [r31b provenance](https://github.com/josephdorseyc-boop/dinner-together/blob/cf8d402a24893cf652337ef643aec11636354bf8/ui-screenshots/iphone/r31b-nightstand-landscape-capture-provenance.txt): screen points 874×402 / pixels 1206×2622 / imageOrientation=2; app comparison points 402×874 / pixels 2622×1206 / same flag; app/window=874×402; runner orientation=0. Screen-route full pixels and app-route clipping are separate facts. This supports the export change; only a new rendered capture can verify it.

## Open work and evidence boundaries

1. **A1/A2 — post-suite finalization/export failure:** independent bounded, evidence-preserving experiment requested. Do not waive exit 124 / export 64 or equate wrapper success with a required-gate pass. No new experiment/result delivered.
2. **A2 — test35 dismissal and test03 launch:** still unclassified. Ordinary native green does not establish Duo code is bug-free; a single timeout does not prove an infrastructure flake. Focused native evidence remains needed.
3. **A1/A2 — test55 coverage split:** manual full-screen behavior versus automatic pose activation; unknown runner orientation is not verified pose. Closed-Duo automatic entry/landscape/re-entry remain unverified. Ordinary-iPhone gates must remain required.
4. **A1 — review staged selection/count safeguards:** recommendation delivered and implemented in isolation, but no new native proof/integration. A1's old string-based mainonly patch and blanket unknown-pose return are not the chosen fix.
5. **A2/A1 — landscape export visual review:** wait for ff86f2a captures; preserve raws. Baseline measured landscape Done/lead placement passed, but geometry is not pixel-fit certification.
6. Prior assigned regression gaps remain unclosed without new evidence: unmatched wording-edit refusal; mid-cook unstarted edits reflected while started steps remain fixed; Live Activity retry injectable seam; alarm injection for moved deadline [throw, success], repeated cancel failure and revoked permission. Also targeted Go to Cooking versus ordinary Done/unsaved-editor preservation, later selected-timer label and timer-deadline continuity.
7. **Real-device verified: none newly.** Hardware checklist exists, but tent/cover posture, locked StandBy, actual alarm delivery through silent/Focus, Lock Screen Stop, charging/unplug lifecycle, opened/closed fit and timer continuity have not been physically verified.

## Approved design, deadlines and release

- Boards **02/03 approved** in [#24/6215903573](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6215903573), exact source **3db56d9810d0e1fc9ff032e81f648f5d39f1d279**, reviewed against current issue. Snapshot “awaiting approval” wording is superseded.
- **Full-screen tent AND nightstand timers remain mandatory.** Dedicated foreground page is separate from system-owned Live Activity/locked StandBy. Preserve dark/dim direction, one-dish no-photo cream page, fixed glass-card position, navigation and accessibility. No Add a step or global Timing Save scope.
- **December replaces October 23 for Joe's physical Duo availability**, explicitly corrected in [#24/6222487023](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6222487023). All old October 23 hardware-check references are stale. **October 20 RC / October 21 TestFlight remain targets**, not proof of readiness or an authorization to waive confirmed cooking/timer/data defects.
- Latest 100 Actions runs show latest release **38845842034**, source **cb0e3973fca5a03fd5faa5e0487bfd45cd11f3f3**, successful Build 21/reported upload. GitHub releases collection is empty. **No Build 22 upload/release, current widget archive/export signing, Apple processing or tester availability established.**
- A3's handoff explicitly requires Joe's word before release. Preserve `require_green=true` and exact-candidate gates. The handoff's suggested toolchain=26 must still be reconciled with shipping SDK/Duo requirements; native Debug/simulator Release and fake signing are not archive/export proof.
- At this watch, no newly discovered blocker, fresh completed native/release milestone or user decision beyond changes already communicated in Joe's active conversation. Do not repeat a handoff or pending-run notification. Continue observing; do not infer A3's future unavailability or start implementation from this watch.
