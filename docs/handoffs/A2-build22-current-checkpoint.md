# Build 22 — current A2 handoff checkpoint

Observed **2026-10-17 00:34:06 UTC / October 16, 18:34:06 Denver**. Refresh GitHub before acting. Supersedes historical status in the [backup runbook](A2-build22-contingency-2026-10-16.md). [Detailed immutable evidence](https://github.com/josephdorseyc-boop/dinner-together/blob/f8ecb55cdc19cf11c49b2137e554a6e4ae4e7495/docs/handoffs/A2-build22-current-checkpoint.md) retains full per-job provenance, source changes and historical results.

## Ownership and boundaries

- A3 explicitly handed implementation/integration to A2 at Joe's request ([#24/6221940209](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6221940209), [#15/6221940484](https://github.com/josephdorseyc-boop/dinner-together/issues/15#issuecomment-6221940484)); this is not inferred unavailability.
- A2's temporary window ends **October 17, 22:00 Denver / October 18, 04:00 UTC**, then A3 resumes ([6222060301](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6222060301)). A1 owns independent testing; active lead owns integration/dispatch/upload.
- Latest read: **78 comments in #24 / 56 in #15**, unchanged. [6226607086](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6226607086) freezes the candidate except for confirmed blockers and assigns A1 result/packaging review.
- **Watch remains docs-only:** no active-branch push, patch, CI dispatch/rerun/cancellation, release-setting change, takeover or release.

## Source and implemented scope

| Ref | Exact SHA | State |
| --- | --- | --- |
| `a2/build22-lead-20261016` | **79aecbad03f7d47055d100ca7c28e3f24f43a332** | Announced successor; unchanged; validation BLOCKED. |
| `wip/build22` | **4ae4f31c851ae9b496aea0ec915a7c8c1c7c6667** | A3 handoff baseline; unchanged. |
| `main` | **cb0e3973fca5a03fd5faa5e0487bfd45cd11f3f3** | Build 21; unchanged. |

[772f8be → 79aecba](https://github.com/josephdorseyc-boop/dinner-together/compare/772f8be14924154ac3084f28c67ed249d324288c...79aecbad03f7d47055d100ca7c28e3f24f43a332): three commits ahead, zero behind:

- **6b320f4cb1ff6c5c1fe25dd98d99a12f4df672ff:** finalization 120 → 300 seconds; manual timer test55, dark test56, strict automatic-nightstand test57. Exact closed/default-hinge Duo excludes rotation-only tests 53/57 after sharding and explicitly reports missing coverage UNVERIFIED. Ordinary iPhone retains strict automatic coverage. Unknown orientation earns no credit; no runtime workaround.
- **886dac38105221f4f86a4d136c0e29c88373d66b:** shared primary/retry finalization policy and retry completion markers; default 300.
- **79aecbad03f7d47055d100ca7c28e3f24f43a332:** app-local UserDefaults / CA92.1 privacy declaration for production AppStorage. Source/plist/resource membership checked; actual archive packaging/signing NOT verified.

Earlier scope remains integrated: full-screen tent/nightstand; approved Timing/Cooking styling; alarms/fallbacks, Live Activities and reliability fixes; normalized capture provenance; fail-closed test selection; caption import correction. Import fixture: 10 ingredients/six directions. Live extraction unverified; saved imports need re-import. Broader overhaul remains Build 23 / #25.

## New material blocker — five-minute remedy insufficient

[Duo run **38981592831**](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38981592831), **ios27 iPhone 2**, job **117243473211**, completed FAILED **00:19:35 UTC / 18:19:35 Denver October 16**, exact source **79aecba**:

- Build succeeded; **28/28 tests passed, zero failed/skipped**, including night appearance. Suite passed at **00:12:41.413 UTC**.
- Summary confirms **300-second allowance**. Raw log records **no-output deadline after tests finished**, exit **124**. Result lacks `Info.plist`; attachment export exits **64**; `REQUIRED_FAILURES=2`. **81 direct captures** survive but do not replace strict process/result/export gates.
- Immutable evidence **0e5a635255b0864f3ab8a54e820667cfe616ce48**: [RUN.txt](https://github.com/josephdorseyc-boop/dinner-together/blob/0e5a635255b0864f3ab8a54e820667cfe616ce48/RUN.txt), [summary](https://github.com/josephdorseyc-boop/dinner-together/blob/0e5a635255b0864f3ab8a54e820667cfe616ce48/SUMMARY.md), [raw log](https://github.com/josephdorseyc-boop/dinner-together/blob/0e5a635255b0864f3ab8a54e820667cfe616ce48/25-ui-test-iphone.log), [export log](https://github.com/josephdorseyc-boop/dinner-together/blob/0e5a635255b0864f3ab8a54e820667cfe616ce48/25-ui-test-iphone-attachments.log).
- **132** SDK `invalidDigitCount(94232)` diagnostics occur; first **23:34:57.926 UTC**, well before suite completion, with some after. Their causal role remains unproven. Do not adopt “zero app bugs” or a proven toolchain diagnosis.

## Current exact-SHA verification

Both workflows bind **79aecbad03f7d47055d100ca7c28e3f24f43a332**. Job records override stale workflow-level labels (Duo still says queued). **Neither workflow is a complete green verdict.**

| Run / part | Job | Scoped status |
| --- | --- | --- |
| Native **38981468135**, Xcode 26.2 — iPhone 1 | 117243067532 | PASS **29/29**, zero failures/skips, readable xcresult; selection includes strict test57 automatic nightstand. |
| Native — iPhone 2 | 117243067679 | PASS **28/28**, zero failures/skips, readable xcresult. |
| Native — iPad | 117243067449 | PASS **26/26**, zero failures/skips, readable xcresult. |
| Native — core | 117243067572 | IN PROGRESS, seeded screenshots; final core/merged verdict pending. |
| Native — Linux / JS-harness-release-dry-run | 117243067564 / 117243067246 | PASS; Linux **236** scoped tests. Dry run is not signing proof. |
| Duo — ios27 core | 117243473403 | PASS **247/247 XCTest**, **236** harness tests, **32** captures; Debug + simulator Release builds. |
| Duo — ios27 iPhone 2 | 117243473211 | FAILED finalization/export, as above. |
| Duo — ios27 iPhone 1 / iPad | 117243473459 / 117243473606 | IN PROGRESS. |
| Duo — closed-Duo parts 1 / 3 | 117243473518 / 117243473447 | IN PROGRESS. |
| Duo — closed-Duo part 2 | 117243473673 | QUEUED. |

[Native run](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38981468135); native UI counts verified from completed job logs. No current merged-results verdict yet. Duo core immutable **4995ad6fe527975128af2a9d34f8b01345c86b3d**: [RUN.txt](https://github.com/josephdorseyc-boop/dinner-together/blob/4995ad6fe527975128af2a9d34f8b01345c86b3d/RUN.txt), [summary](https://github.com/josephdorseyc-boop/dinner-together/blob/4995ad6fe527975128af2a9d34f8b01345c86b3d/SUMMARY.md). Capture counts/gates do not prove visual pixel-fit review.

**Local-only, implementation reports:** 25 fake-toolchain scenarios; 10 parser, seven screenshot-process, 10 selection, four real-process deadline checks; three targeted retry scenarios. No native/device credit from these.

**Historical, not current credit:** native **38953971764** passed on **772f8be**; Duo **38966260203** failed finalization plus iPad test04/closed-Duo test55. Superseded 6b320f4 runs **38979495541 / 38979504518** CANCELLED. Full evidence retained in the linked detailed checkpoint.

## Pending findings, approvals and hardware

- **A1:** investigate the new failed 300-second result without relaxing gates; existing [6226587035](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6226587035) calls for timing/stack/minimal-result-writing comparison. Review remaining exact-SHA results, counts/skips, iOS27 test04, ordinary-iPhone test57, closed-Duo manual/night timers, privacy packaging and capture fit. Native iPad pass does not close iOS27 test04; contention/flake remains a hypothesis.
- Preserve targeted review of edit refusal/remaining-plan updates, Live Activity retry, alarm replacement/retry/revocation, navigation/unsaved drafts, selected-timer labels/deadlines. Missing fresh evidence is not a claim of missing implementation.
- Boards **02/03 approved** in [6215903573](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6215903573), design commit **3db56d9810d0e1fc9ff032e81f648f5d39f1d279**, superseding the README's stale pending wording. Full-screen **tent AND nightstand** remain mandatory, not inset Live Activity substitutes. Preserve native navigation/accessibility, cream fallback, glass card/timer continuity and save/readiness safeguards. No Add a step/global Timing Save.
- **Real-device verification absent.** Duo arrives **December**, not October 23 ([6222487023](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6222487023)). Physical tent/cover pose, charging/unplug/locked StandBy, silent/Focus alarms, Lock Screen Stop and continuity remain open. Simulator splitting does not verify hardware posture.

## Release / notification

- **No Build 22 release/upload started or established.** Main unchanged; exact-SHA Actions contains only the two validation runs. Latest 100 runs still show latest release **38845842034**, source **cb0e397**, Build 21. No Build22 archive/export signing, Apple processing or tester availability established.
- Keep `require_green=true` and exact-SHA process/export/count/skip gates. No toolchain switch or gate waiver from this watch. Active lead must resolve required failure before release.
- **Notify Joe once:** five minutes did not resolve one required finalization failure despite 28/28 passing tests. Prior conditional 19:15–19:45 Denver estimate does not establish readiness; no new estimate. Other checks continue; no upload begun.
- Continue watch; task ongoing. No new ownership transfer/unavailability inferred.
