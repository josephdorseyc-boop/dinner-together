# Build 22 — current A2 handoff checkpoint

Observed **2026-10-17 01:24 UTC / October 16, 19:24 Denver**. Refresh GitHub before acting. Supersedes historical state in the [backup runbook](A2-build22-contingency-2026-10-16.md). [Previous checkpoint](https://github.com/josephdorseyc-boop/dinner-together/blob/ee755cf5b9d752c163652900ff0c081b3decce94/docs/handoffs/A2-build22-current-checkpoint.md) and [detailed earlier evidence](https://github.com/josephdorseyc-boop/dinner-together/blob/f8ecb55cdc19cf11c49b2137e554a6e4ae4e7495/docs/handoffs/A2-build22-current-checkpoint.md) preserve older findings and source/run provenance.

## Ownership and boundaries

- A3 explicitly handed implementation/integration to A2 at Joe's request ([#24/6221940209](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6221940209), [#15/6221940484](https://github.com/josephdorseyc-boop/dinner-together/issues/15#issuecomment-6221940484)). This is an explicit recorded handoff, not inferred absence.
- A2's temporary lead window ends **October 17, 22:00 Denver / October 18, 04:00 UTC**, then A3 resumes ([6222060301](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6222060301)). A1 owns independent assigned testing. A2's interactive lead session owns harness/integration/dispatch/upload; this watch does not exercise those powers.
- Latest read: **94 comments in #24 / 56 in #15**. Latest #24 [6227902953](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6227902953); #15 unchanged since handoff.
- **This watch remains docs-only:** no active implementation branch edits, duplicate patches, CI dispatch/rerun/cancellation, release-setting changes, takeover or release.

## Current source and implementation

| Ref | Exact SHA | State |
| --- | --- | --- |
| `a2/build22-lead-20261016` | **d6aaaaabd22a6674dc90d018b47c0018d62d9fdd** | Explicitly announced successor; current candidate, native/27.1 verdicts pending. |
| `wip/build22` | **4ae4f31c851ae9b496aea0ec915a7c8c1c7c6667** | A3 handoff baseline, unchanged. |
| `main` | **cb0e3973fca5a03fd5faa5e0487bfd45cd11f3f3** | Build 21, unchanged. |

[Ancestry comparison](https://github.com/josephdorseyc-boop/dinner-together/compare/4ae4f31c851ae9b496aea0ec915a7c8c1c7c6667...d6aaaaabd22a6674dc90d018b47c0018d62d9fdd): current candidate is **nine commits ahead, zero behind A3's handoff**.

**New, implemented but not native-verified:** [d6aaaaa](https://github.com/josephdorseyc-boop/dinner-together/commit/d6aaaaabd22a6674dc90d018b47c0018d62d9fdd) adds six lines in `native-validation/run-native-pass.sh`: `-collect-test-diagnostics never` on primary AND flaky-retry UI commands, with explanatory notes. Parent is **79aecbad03f7d47055d100ca7c28e3f24f43a332**. Production Swift, UI assertions, test selection, release workflow, process/count/skip/readable-result/export gates are unchanged. This tests an optional-diagnostic-collection hypothesis; it is **not yet a demonstrated fix**.

**Local checks, reported by implementation owner only:** 25 harness scenarios + 31 focused checks passed; reported checked/published tree **bc9027904f9da37722ada721a0152979cbf4b7ae** ([6227816139](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6227816139)). This watch independently inspected the source diff and ancestry, not a local/native re-execution.

Earlier implemented scope remains: full-screen tent/nightstand; boards 02/03 Timing/Cooking styling; alarms/fallbacks, Live Activities and reliability work; normalized capture provenance; fail-closed selection; caption import (10 ingredients/six directions fixture; live extraction unverified; old imports need re-import). **6b320f4** separates manual test55, night test56 and strict automatic test57; verified closed/default-hinge Duo excludes rotation-only tests53/57 and explicitly records missing hardware coverage. **886dac3** shares 300-second primary/retry finalization policy. **79aecba** adds app-local UserDefaults CA92.1 privacy declaration; resource/source checks are not archive/signing proof. Broader overhaul remains Build 23 / #25.

## Exact-current-SHA verification — no green verdict yet

Both required runs below bind **d6aaaaabd22a6674dc90d018b47c0018d62d9fdd**. Job state, not a stale workflow banner, is authoritative.

| Run / toolchain | Part / job | Current status |
| --- | --- | --- |
| Native **38989926720**, Xcode 26.2 | JS/harness **117269822501**; Linux **117269822674** | PASS (scoped harness evidence only). |
| Native | core **117269822617** | IN PROGRESS. |
| Native | iPhone 1 **117269822733**; iPhone 2 **117269822803**; iPad **117269822780** | IN PROGRESS; no completed exact-current UI verdict. |
| Duo **38990012070**, Xcode 27.1 | ios27 core **117270091706**; iPhone 1 **117270091562**; iPhone 2 **117270091445**; iPad **117270091602** | All QUEUED. |
| Duo | closed-Duo parts 1/2/3 **117270091649 / 117270091571 / 117270091538** | All QUEUED. |

[Native run](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38989926720); [all-seven-part required 27.1/Duo run](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38990012070). No optional window-only substitution. Neither run supplies complete current-candidate release credit.

### Parent evidence — retained, not current-SHA credit

- **79aecba native 38981468135 completed SUCCESS at 00:44:46 UTC / October 16, 18:44:46 Denver.** All seven jobs including merged publication passed. **247/247 XCTest**, **236** macOS harness tests; iPhone **29/29 + 28/28**, iPad **26/26**, zero UI failures/skips, readable results/export; core captures **32**. Test57 automatic nightstand is included on ordinary iPhone. Immutable merged evidence **ed812494e971388ba6392b7f2d63f0385ffcb4fa**: [RUN.txt](https://github.com/josephdorseyc-boop/dinner-together/blob/ed812494e971388ba6392b7f2d63f0385ffcb4fa/RUN.txt), [SUMMARY.md](https://github.com/josephdorseyc-boop/dinner-together/blob/ed812494e971388ba6392b7f2d63f0385ffcb4fa/SUMMARY.md).
- **79aecba Duo 38981592831 is now CANCELLED**, not green. Three completed UI failures survive cancellation:
  - ios27 iPhone 2 **117243473211**: **28/28 passed**, then 300-second finalization deadline exit124, unreadable result/export64. Immutable **0e5a635255b0864f3ab8a54e820667cfe616ce48** retained in previous checkpoint.
  - ios27 iPhone 1 **117243473459**: **29 executed, 28 passed, one failed, zero skipped**. `test22_coverCropHappyPath` failed waiting for stubbed screenshots at UITestSupport.swift:1542, separately followed by exit124/export64. **85** direct captures. Immutable **acde4a08e71cccd45591ece5be85cfd383ce42ed**: [RUN.txt](https://github.com/josephdorseyc-boop/dinner-together/blob/acde4a08e71cccd45591ece5be85cfd383ce42ed/RUN.txt), [summary](https://github.com/josephdorseyc-boop/dinner-together/blob/acde4a08e71cccd45591ece5be85cfd383ce42ed/SUMMARY.md).
  - closed-Duo part3 **117243473447**: **18 executed, 17 passed, one failed, zero skipped**. `test35_palePhotoPageAX3` timed out waiting for Page color sheet closure at UITestSupport.swift:1731, separately exit124/export64; **46** direct captures. Immutable **5e8298cb57632d392a2bf752b919e67cb9ac968c**: [RUN.txt](https://github.com/josephdorseyc-boop/dinner-together/blob/5e8298cb57632d392a2bf752b919e67cb9ac968c/RUN.txt), [summary](https://github.com/josephdorseyc-boop/dinner-together/blob/5e8298cb57632d392a2bf752b919e67cb9ac968c/SUMMARY.md).
- Remaining parent Duo iPad/parts1/2 were cancelled and earn no credit. Earlier native/Duo source results remain in prior checkpoints; never transfer them to d6aaaaa.

## Investigations and pending owners

- **A1:** independently review diagnostic flag, test22 interaction/hierarchy/frame/chooser scrolling, test35 Page color dismissal, and 27.1 release-source preflight (effective app/share/timers bundle IDs/versions, App Groups/AlarmKit entitlements and export readiness). No secret values or archive dispatch. Assignment/review: [6227839500](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6227839500), [6227878196](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6227878196).
- A1's proposed test22 retry patch [6227856000](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6227856000) is **not integrated**. The failed parent already performed a retry tap; removing an isSelected condition does not by itself explain that failure. Toolchain/viewport/timing causes remain hypotheses, not a demonstrated app or iOS root cause.
- Separate **diagnostic** branch/source **wip/a2-build22-finalization-probe-20261016 @ e8be24868dc5649f569fdbbb5aafa646145449f1**, run **38989191428**. Completed 27.1/keep job **117267516555** and 27.0/keep **117267516824** both failed with **test_exit124 / summary_exit64**; optional discard-success job **117267516677** was still cleaning up. No release credit.
- The 27.1 keep diagnostic passed test10/test22 **2/2** with the original helper, per A2's artifact examination ([6227902953](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6227902953)), then runner exit0 preceded a pending asynchronous-diagnostics finish message. This supports, but does not prove, the d6 hypothesis. No claim that a source patch fixed test22.
- A1's log-verdict promotion [6227771017](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6227771017) was **rejected/not integrated** ([6227786414](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6227786414)): suite-log marker/counts alone do not establish exact selected-case completeness or result/export integrity. Strict gates remain. `invalidDigitCount` diagnostics are observed; causal responsibility for the hang is unproven.
- Preserve follow-up review of edit refusal/remaining-plan updates, Live Activity retry, alarm replacement/retry/revocation, navigation/drafts, selected timer identity/deadlines, capture fit and privacy packaging. Missing fresh evidence is not a claim of missing implementation.

## Design approval and real-device boundary

- Boards **02/03 approved** in [6215903573](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6215903573), design commit **3db56d9810d0e1fc9ff032e81f648f5d39f1d279**. README's pending wording is superseded. Full-screen **tent AND nightstand** remain mandatory, not inset Live Activity substitutes.
- Preserve native navigation/accessibility, cream fallback, glass/timer continuity, safe saves/readiness and reader state. No Add a step/global Timing Save; no new timer-store cap from four visible timers.
- **Real-device verification absent.** Duo arrival is **December**, not October23 ([6222487023](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6222487023)). Physical tent/cover pose, charging/unplug/locked StandBy, silent/Focus alarms, Lock Screen Stop and continuity remain open. Simulator rotation accommodations are not hardware passes. Capture counts are not pixel-fit/VoiceOver review.

## Release and notification

- Joe confirmed **Xcode 27.1 remains the shipment target** ([6227769413](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6227769413)); this supersedes the immediately preceding 26.2 contingency. **No 26.2 release/upload started.**
- **No Build22 release/upload established.** Current main unchanged. Latest 100 Actions runs contain no new release; latest release is **38845842034**, source **cb0e397**, Build21. No Build22 archive/export signing, Apple processing or tester availability proven.
- Keep `require_green=true` and exact-SHA process/result/count/skip/export gates. No release ETA from queued checks, no log-verdict waiver or toolchain switch from this watch.
- **No new user notification this check:** candidate/diagnostic progress and existing failures are already communicated in the active discussion; required successor 27.1 results remain pending. Continue watching for a material new blocker, explicit ownership change, release milestone or decision.
