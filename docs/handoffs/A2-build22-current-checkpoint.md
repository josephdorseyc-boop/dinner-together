# Build 22 — current A2 handoff checkpoint

Observed **2026-10-17 00:34:06 UTC / October 16, 18:34:06 America/Denver**. Refresh GitHub before acting. Supersedes historical status in the [backup runbook](A2-build22-contingency-2026-10-16.md). [Previous immutable checkpoint](https://github.com/josephdorseyc-boop/dinner-together/blob/fcf39e2b8690c9d97f2115f563888d39f0e887bc/docs/handoffs/A2-build22-current-checkpoint.md) retains prior-run evidence and the detailed source map.

## Ownership and watch limits

- Explicit handoff, not inferred silence: A3 transferred implementation/integration to A2 at Joe's request in [#24/6221940209](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6221940209), confirmed in [#15/6221940484](https://github.com/josephdorseyc-boop/dinner-together/issues/15#issuecomment-6221940484).
- A2's temporary lead ends **October 17, 22:00 Denver / October 18, 04:00 UTC**, when A3 resumes ([6222060301](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6222060301)). A1 owns independent test review. The active implementation lead owns integration/dispatch/upload; this watch exercises none of those powers.
- Fresh read: **78 comments in #24 / 56 in #15**, unchanged. Latest instruction [6226607086](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6226607086): freeze the candidate except for confirmed blockers; A1 reviews results, packaging, test04, ordinary-iPhone automatic entry, closed-Duo manual timers and finalization/export. No duplicate code edits/runs.
- This update is **docs-only**. No active-branch push, implementation patch, workflow dispatch/rerun/cancellation, release-setting change, takeover or release.

## Source and implementation

| Ref | Exact SHA | State |
| --- | --- | --- |
| `a2/build22-lead-20261016` | **79aecbad03f7d47055d100ca7c28e3f24f43a332** | Announced successor; unchanged; release validation BLOCKED. |
| `wip/build22` | **4ae4f31c851ae9b496aea0ec915a7c8c1c7c6667** | A3 handoff baseline; unchanged. |
| `main` | **cb0e3973fca5a03fd5faa5e0487bfd45cd11f3f3** | Build 21; unchanged. |

[Comparison 772f8be → 79aecba](https://github.com/josephdorseyc-boop/dinner-together/compare/772f8be14924154ac3084f28c67ed249d324288c...79aecbad03f7d47055d100ca7c28e3f24f43a332): three commits ahead, zero behind.

- **6b320f4cb1ff6c5c1fe25dd98d99a12f4df672ff:** finalization allowance 120 → 300 seconds; test55 manual full-screen, test56 dark, new strict test57 automatic nightstand/landscape/suppression/re-entry/upright dismissal. Ordinary iPhone retains automatic coverage. Exact closed/default-hinge Duo excludes rotation-only tests 53/57 after sharding and reports those gaps UNVERIFIED. Unknown orientation earns no credit; no runtime workaround.
- **886dac38105221f4f86a4d136c0e29c88373d66b:** shared `DT_UI_FINALIZE_SECONDS` for primary and flaky retries, completion markers on retry, wrapper default 300. The former retry's 120-second done-idle default was dormant without markers.
- **79aecbad03f7d47055d100ca7c28e3f24f43a332:** app-local UserDefaults / CA92.1 privacy declaration for production AppStorage preferences; existing app-resource membership retained. Source/plist checked; actual archive packaging/signing NOT verified.
- Earlier integrated scope remains: full-screen tent/nightstand, approved Timing/Cooking layouts, AlarmKit/fallbacks, Live Activities and follow-up reliability fixes, orientation-normalized captures, fail-closed selection, caption import cleanup. Import fixture: 10 ingredients, six directions, durations [4, nil, 1, nil, 5, nil]. Live Instagram extraction unverified; saved imports require re-import. Broader overhaul remains Build 23 / [#25](https://github.com/josephdorseyc-boop/dinner-together/issues/25).

## Exact-current-SHA validation

Both runs below bind **79aecbad03f7d47055d100ca7c28e3f24f43a332**. Job records take precedence over stale workflow-level status (Duo still says queued). **One required job has conclusively failed; neither workflow is a complete green verdict.**

### New material blocker: five minutes did not resolve finalization

[Duo run 38981592831](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38981592831), **ios27 iPhone 2**, job **117243473211**, completed FAILED at **00:19:35 UTC / 18:19:35 Denver October 16**:

- Build succeeded. **28/28 tests passed, zero failed/skipped**, including test56 night appearance. Suite passed at **00:12:41.413 UTC**.
- Summary explicitly records **300 seconds** of post-suite allowance. Raw log then says the native command exceeded its **no-output deadline after the tests finished**; process exit **124**. This is not a successful run.
- Result is unreadable: missing `iphone-ui.xcresult/Info.plist`; attachment export exit **64**; `REQUIRED_FAILURES=2`. **81 direct captures** survive but do not replace the failed process/result/export gates.
- Immutable evidence commit **0e5a635255b0864f3ab8a54e820667cfe616ce48**: [RUN.txt](https://github.com/josephdorseyc-boop/dinner-together/blob/0e5a635255b0864f3ab8a54e820667cfe616ce48/RUN.txt), [SUMMARY.md](https://github.com/josephdorseyc-boop/dinner-together/blob/0e5a635255b0864f3ab8a54e820667cfe616ce48/SUMMARY.md), [raw log](https://github.com/josephdorseyc-boop/dinner-together/blob/0e5a635255b0864f3ab8a54e820667cfe616ce48/25-ui-test-iphone.log), [export log](https://github.com/josephdorseyc-boop/dinner-together/blob/0e5a635255b0864f3ab8a54e820667cfe616ce48/25-ui-test-iphone-attachments.log). RUN.txt confirms source/run/toolchain/part.
- Raw log contains **132** `invalidDigitCount(94232)` diagnostics; first at **23:34:57.926 UTC**, well BEFORE suite completion, and some after. This does not establish that the SDK diagnostic causes the hang. Preserve A1's timing/stack/minimal-result-writing investigation; do not adopt “zero app bugs” or a proven toolchain root cause as established.

### Other current gates

| Workflow / part | Job | Fresh status / scoped evidence |
| --- | --- | --- |
| Native **38981468135**, Xcode 26.2 — iPhone 1 | 117243067532 | PASS: **29/29**, zero failures/skips, readable xcresult; selection includes strict test57 automatic nightstand. |
| Native — iPhone 2 | 117243067679 | PASS: **28/28**, zero failures/skips, readable xcresult. |
| Native — iPad | 117243067449 | PASS: **26/26**, zero failures/skips, readable xcresult. iOS 27 test04 still pending. |
| Native — core | 117243067572 | IN PROGRESS, seeded screenshots step; no final core/merged verdict. |
| Native — Linux / JS-harness-release-dry-run | 117243067564 / 117243067246 | PASS. Linux scoped harness **236** tests; fake signing/control flow is not archive proof. |
| Duo — ios27 core | 117243473403 | PASS: **247/247 XCTest**, **236** macOS harness tests, **32** seeded captures; Debug + simulator Release builds. |
| Duo — ios27 iPhone 1 / iPad | 117243473459 / 117243473606 | IN PROGRESS. |
| Duo — closed-Duo parts 1 / 3 | 117243473518 / 117243473447 | IN PROGRESS. |
| Duo — closed-Duo part 2 | 117243473673 | QUEUED. |

[Native run](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38981468135); current native per-part counts verified from completed job logs. Native merged `ci-results` has not yet supplied a current-candidate verdict. Duo core immutable commit **4995ad6fe527975128af2a9d34f8b01345c86b3d**: [provenance](https://github.com/josephdorseyc-boop/dinner-together/blob/4995ad6fe527975128af2a9d34f8b01345c86b3d/RUN.txt), [summary](https://github.com/josephdorseyc-boop/dinner-together/blob/4995ad6fe527975128af2a9d34f8b01345c86b3d/SUMMARY.md). Job gates/capture counts do not establish a visual pixel-fit review.

**Locally checked (implementation reports):** 25 fake-toolchain scenarios; 10 parser, seven screenshot-process, 10 selection, four real-process deadline checks; retry follow-up has three targeted scenarios. No native/device credit from these.

**Historical, not current credit:** native **38953971764** passed on **772f8be** (247 XCTest, 28+28 iPhone, 26 iPad); Duo **38966260203** failed finalization plus iPad test04 / closed-Duo test55. Superseded 6b320f4 runs **38979495541 / 38979504518** are CANCELLED. Prior immutable checkpoint retains all source/run/result links.

## Pending review and approved design

- **A1:** review the new failed 300-second result and isolate cause without relaxing gates; review pending exact-SHA results, selected/executed counts, zero skips, test04, strict test57 on ordinary iPhone, closed-Duo manual/night timers, privacy packaging and actual capture fit. Existing assignment [6226587035](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6226587035) requests timing/stack/minimal result-writing comparison if five minutes fails. This watch issues no duplicate patch/dispatch.
- Native iPhone/iPad passes do not close Xcode 27 test04 or automatic-Duo gaps. A1's snapshot-contention/flake explanation remains a hypothesis pending evidence.
- Preserve targeted review of edit refusal/remaining-plan updates, Live Activity retry, moved-alarm cancel/retry/revoked permissions, Go to Cooking versus Done/unsaved drafts, selected-timer names/deadlines and visual fit. Missing fresh targeted evidence does not mean unimplemented.
- Boards **02/03 approved** by [6215903573](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6215903573), design commit **3db56d9810d0e1fc9ff032e81f648f5d39f1d279**. This supersedes the board README's pending language. Full-screen **tent AND nightstand** remain mandatory, not inset Live Activity substitutes. Preserve native navigation/accessibility, cream one-dish fallback, glass card/timer continuity and save/readiness safeguards. No Add a step/global Timing Save scope.
- **Real-device verification remains absent.** Duo arrives **December**, not October 23 ([6222487023](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6222487023)). Physical tent/cover pose, charging/unplug/locked StandBy, alarms through silent/Focus, Lock Screen Stop and timer continuity remain open. Simulator/manual test splitting does not prove hardware posture.

## Release and notification

- **No Build 22 release/upload started or established.** Main unchanged; exact-SHA run collection contains only the two validation runs. Latest 100 repository runs still show latest release **38845842034**, source **cb0e397**, Build 21. No archive/export signing, Apple processing or tester availability established for Build 22.
- Retain `require_green=true`, exact-SHA checks and strict process/export/count/skip gates. No toolchain switch or gate waiver from this watch. Active lead must resolve the failed required job before release.
- **Notify Joe once:** the five-minute remedy is now demonstrated insufficient in one required job, despite 28/28 passing tests. The prior conditional 19:15–19:45 Denver validation estimate no longer establishes readiness; no replacement estimate. Other checks continue, and no upload has begun.
- Task remains ongoing; no new ownership transfer/unavailability inferred. Only this checkpoint changed.
