# Build 22 — current A2 handoff checkpoint

Observed **2026-10-16 23:38:38 UTC / 17:38:38 America/Denver**. Supersedes historical status in the [backup runbook](A2-build22-contingency-2026-10-16.md). [Previous immutable checkpoint](https://github.com/josephdorseyc-boop/dinner-together/blob/282c54aaf08ad1eebb2b531e56365def68dd764d/docs/handoffs/A2-build22-current-checkpoint.md) preserves the full per-job evidence for the failed prior candidate. Refresh GitHub before acting.

## Ownership and boundaries

- A3 explicitly transferred implementation/integration to A2 at Joe's request: [#24/6221940209](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6221940209), confirmed in [#15/6221940484](https://github.com/josephdorseyc-boop/dinner-together/issues/15#issuecomment-6221940484). This is recorded authority, not inferred unavailability.
- A2's temporary lead window ends **October 17, 22:00 America/Denver / October 18, 04:00 UTC**, when A3 resumes ([6222060301](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6222060301)). A1 retains independent testing; active lead owns integration/dispatch/upload.
- Latest read: **78 comments in #24 / 56 in #15**. Latest direction is [6226607086](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6226607086): freeze the candidate except for confirmed blockers; A1 reviews packaging, test04, ordinary-iPhone automatic entry, closed-Duo manual timers, finalization/export. No duplicate runs or code edits. No newer comments were returned in the final refresh.
- **This watch remains docs-only:** no implementation push, patch, CI dispatch/rerun/cancellation, release-setting change, takeover or release initiated.

## Current source and implemented changes

| Ref | Exact source SHA | Status |
| --- | --- | --- |
| `a2/build22-lead-20261016` | **79aecbad03f7d47055d100ca7c28e3f24f43a332** | Explicit current successor; checks pending. |
| `wip/build22` | **4ae4f31c851ae9b496aea0ec915a7c8c1c7c6667** | Unchanged A3 handoff baseline. |
| `main` | **cb0e3973fca5a03fd5faa5e0487bfd45cd11f3f3** | Unchanged Build 21. |

[Comparison from prior candidate](https://github.com/josephdorseyc-boop/dinner-together/compare/772f8be14924154ac3084f28c67ed249d324288c...79aecbad03f7d47055d100ca7c28e3f24f43a332): **3 commits ahead, 0 behind**.

- **6b320f4cb1ff6c5c1fe25dd98d99a12f4df672ff:** post-suite allowance 120 → 300 seconds; test55 now manual full-screen, test56 dark appearance, new strict test57 automatic nightstand/landscape/suppression/re-entry/upright dismissal. Ordinary iPhone retains automatic coverage. Exact closed/default-hinge Duo excludes rotation-only tests 53/57 after sharding and reports missing coverage **UNVERIFIED**; manual/night remain required. Unknown orientation earns no credit. No app-runtime workaround.
- **886dac38105221f4f86a4d136c0e29c88373d66b:** shared `DT_UI_FINALIZE_SECONDS` policy for primary and flaky retries; retry completion markers; generic wrapper default 300. The old retry's 120-second default was dormant without markers, not an active two-minute retry deadline.
- **79aecbad03f7d47055d100ca7c28e3f24f43a332:** privacy manifest declares app-local UserDefaults / CA92.1 for production AppStorage preferences. Source declaration and existing app resource membership A114/B114/R001 checked. **Archive packaging/signing still unverified.**
- Earlier integrated work remains: full-screen tent/nightstand UI, approved Timing/Cooking layouts, alarms/Live Activities and follow-up fixes, orientation-normalized captures, fail-closed selection, and caption import cleanup. Import fixture is 10 ingredients / six directions / durations [4, nil, 1, nil, 5, nil]. Live Instagram extraction remains unverified; saved imports need re-import. Broader parsing is Build 23 / [#25](https://github.com/josephdorseyc-boop/dinner-together/issues/25).

## Verification — preserve exact-SHA boundaries

### Current candidate 79aecba: native verdict PENDING

| Run | Fresh job-level state |
| --- | --- |
| [native-validation **38981468135**](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38981468135), Xcode 26.2 | Linux **PASS: 236 tests, zero failures**; JS/harness/release dry-run job PASS. iPad **117243067449**, iPhone 1 **117243067532**, iPhone 2 **117243067679** building/testing; core **117243067572** queued. |
| [duo-validation **38981592831**](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38981592831), Xcode 27.1 | ios27 core **117243473403** and iPhone 2 **117243473211** building/testing; ios27 iPhone 1 **117243473459**, iPad **117243473606**, Duo parts 1/2/3 **117243473518 / 117243473673 / 117243473447** queued. Seven required parts; no optional opened-window job. |

Both run records bind **79aecbad03f7d47055d100ca7c28e3f24f43a332**. Workflow-level records still say queued, while job-level records show **five Mac jobs in progress / six queued**. No completed Mac gate/capture verdict yet. Linux [immutable RUN.txt](https://github.com/josephdorseyc-boop/dinner-together/blob/4f14c66d6661597b314d6be943c3a184e17e7731/RUN.txt) binds source/run; [log](https://github.com/josephdorseyc-boop/dinner-together/blob/4f14c66d6661597b314d6be943c3a184e17e7731/swift-test-linux.log) confirms 236 passed.

Superseded 6b320f4 runs **38979495541 / 38979504518** are **completed CANCELLED**, not release credit. Engine-quick **38980378960** passed on **886dac3**, not current 79aecba.

**Locally checked, as reported by the implementation commits:** 25 fake-toolchain scenarios; 10 parser, 7 screenshot-process, 10 selection and 4 real-process deadline checks; retry follow-up has three focused retry scenarios. These establish control-flow behavior, not native Swift/UI, device or signing proof. Current Linux CI confirms its scoped harness only.

### Historical candidate 772f8be: retain, do not transfer credit

- [Native **38953971764**](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38953971764) GREEN: 247 XCTest, 28+28 iPhone, 26 iPad, zero failures/skips; 236 engine/store tests, 32 seeded captures. Immutable [summary **52e8c6e1d0e7396a3a2914f4bd3a393e245faa0f**](https://github.com/josephdorseyc-boop/dinner-together/blob/52e8c6e1d0e7396a3a2914f4bd3a393e245faa0f/SUMMARY.md).
- [Duo **38966260203**](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38966260203) FAILED, completed 22:31:38 UTC: core passed; all seven UI gates failed finalization **124** / result export **64**. Five had zero named test failures. iPad test04 snapshot timeout and Duo test55 missing automatic entry additionally failed.
- [iPad evidence **bc2c13dc35063422de8b1a161e717e519356270c**](https://github.com/josephdorseyc-boop/dinner-together/blob/bc2c13dc35063422de8b1a161e717e519356270c/25-ui-test-ipad.log); [Duo part 1 **63720b250b5bff2dafeba40d5f883892be730279**](https://github.com/josephdorseyc-boop/dinner-together/blob/63720b250b5bff2dafeba40d5f883892be730279/25-ui-test-iphone.log). RUN.txt provenance and other part commits remain in the prior immutable checkpoint. Part 2 verified test53 exclusion, 18/18/no skips, and night test56; that is not a successful job or hardware proof.

## Pending findings, design and hardware

- **A1:** independently review current exact-SHA results/captures, selected/executed counts and zero skips, test04, test57 on ordinary iPhone, manual/night timers on closed Duo, privacy packaging, process/result readability and export gates.
- A1 now recommends retaining gates, superseding the initial warn-only export suggestion. Their SDK `invalidDigitCount(94232)` diagnostics and similar result sizes support investigation, **not a proven causal diagnosis**. A2 requested timing/stack or minimal result-writing comparison if five minutes still fails ([6226587035](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6226587035)). Root cause remains open. A1's test04 contention/flake classification is a hypothesis; unchanged rerun must supply evidence. Do not adopt “zero app bugs” as established.
- Preserve targeted review of editing refusal/remaining-plan updates, Live Activity retry, moved-alarm cancel/retry/revoked permissions, Go to Cooking vs Done/unsaved drafts, selected-timer labels/deadlines and visual pixel fit. Missing targeted evidence is not a claim these fixes are unimplemented.
- Boards **02/03 approved** in [6215903573](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6215903573), design commit **3db56d9810d0e1fc9ff032e81f648f5d39f1d279**. That approval supersedes the board README's stale pending language. Full-screen **tent AND nightstand** remain mandatory, not an inset Live Activity. Preserve native navigation, accessibility, cream one-dish fallback, fixed glass card, timer continuity and save/readiness safeguards. No Add a step/global Timing Save scope.
- **Real-device verification remains absent.** Joe's Duo arrives **December**, not October 23 ([6222487023](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6222487023)). Physical tent/cover pose, charging/unplug/locked StandBy, alarms through silent/Focus, Lock Screen Stop and timer continuity remain open. New test splitting explicitly records these gaps; it does not verify automatic Duo posture.

## Release and notification

- No Build 22 release run, main advancement, signing/archive/export, upload, Apple processing or tester availability established. Exact-current-SHA Actions contains only the two pending validation runs. Latest 100 repository runs show latest release [**38845842034**](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38845842034), source **cb0e397**, Build 21; releases collection is empty.
- Keep `require_green=true`, required exact-SHA checks and export/process/skip/count gates. Do not switch toolchains to bypass failure. Simulator Release and fake signing do not prove widget archive/export signing.
- Joe already received the corrected candidate/replacement-run update and conditional **19:15–19:45 Denver validation estimate**; upload/Apple processing follow passing checks. No new estimate or readiness claim from this watch.
- **Material checkpoint change, no new action-worthy notification:** source advanced to 79aecba, A1 findings/decisions reconciled, replacements running and superseded runs cancelled. These developments were already communicated in the active conversation. No new blocker, handoff or release milestone; avoid duplicate notification. Continue observing; task not completed.
