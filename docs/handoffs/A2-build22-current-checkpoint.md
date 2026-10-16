# Build 22 — current A2 handoff checkpoint

Observed **2026-10-16 20:57:19 UTC** (Denver UTC−06:00). Supersedes historical branch, approval, ownership and hardware-date notes in the [backup runbook](A2-build22-contingency-2026-10-16.md) and the source branch's older lead checkpoint. [Previous full checkpoint](https://github.com/josephdorseyc-boop/dinner-together/blob/a1ceed0dbfdc88120445273fde5d3930dfedf2fe/docs/handoffs/A2-build22-current-checkpoint.md) preserves detailed baseline evidence. Refresh GitHub before acting.

## Ownership and watch boundaries

- **Explicit handoff, not silence:** A3 transferred implementation/integration to A2 at Joe's request in [#24/6221940209](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6221940209), confirmed to A1 in [#15/6221940484](https://github.com/josephdorseyc-boop/dinner-together/issues/15#issuecomment-6221940484).
- **A2 temporarily leads through October 17, 2026, 22:00 America/Denver (October 18, 04:00 UTC)**; A3 resumes then, per [6222060301](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6222060301). A1 retains assigned independent testing. This watch merely records that separately authorized transfer; it initiates no takeover.
- A1's latest assignments remain staged-harness review, evidence-preserving finalization-hang investigation and a proposed manual/automatic timer-test split. A2 retains harness integration and Page color investigation. No new A1 result since the previous checkpoint.
- Read all **63 comments in #24 / 56 in #15**. Latest #24: [6224154892](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6224154892), native pass / arranging same-SHA Duo validation; latest #15 remains the handoff confirmation.
- Documentation-only update on `a2/build22-contingency-20261016`. No app edits, implementation-branch pushes, dispatches/reruns, release-setting changes or release action. Docs-only paths are ignored by native-validation; engine-quick is limited to wip/**.

## Current source and implemented state

| Ref | Exact SHA | State |
| --- | --- | --- |
| `a2/build22-lead-20261016` | **772f8be14924154ac3084f28c67ed249d324288c** | Explicitly announced continuation; current integrated candidate. Native green, no exact-SHA Duo run. |
| `wip/build22` | **4ae4f31c851ae9b496aea0ec915a7c8c1c7c6667** | Unchanged A3 handoff baseline. Native green; its Duo run failed. |
| `wip/a2-build22-harness-20261016` | **3f8195925968b684f841146812e84bea572b988d** | Historical staging branch; now integrated in 772f8be, not outstanding integration. |
| `wip/a2-build22-social-import-20261016` | **772f8be14924154ac3084f28c67ed249d324288c** | Same import candidate as continuation, not a competing successor. |
| `main` | **cb0e3973fca5a03fd5faa5e0487bfd45cd11f3f3** | Build 21 release baseline, unchanged. |

[Verified five-commit comparison](https://github.com/josephdorseyc-boop/dinner-together/compare/4ae4f31c851ae9b496aea0ec915a7c8c1c7c6667...772f8be14924154ac3084f28c67ed249d324288c):

1. **ff86f2a12e179f38fab142cc7ba947bb400ccb89:** bake full-screen capture orientation into landscape PNG/attachments; preserve raw screen/app comparisons and provenance. Test-export change, not app-layout change.
2. **1084869ed739a1620a27c6b0f418e8d9eb252927:** exclude test53 only for the exact selected closed/default/0-hinge Duo, after sharding; recalculate expected counts and report hardware gap. Ordinary-iPhone test53 stays required; test55 stays selected. Reject invalid K/N and empty/zero-count selections before Xcode, with no unfiltered fallback/skip allowance.
3. **3f8195925968b684f841146812e84bea572b988d:** preserve harness file permissions.
4. **393ff12be194d0370a7271ee6a96221b8e98fbad:** normalize explicit inline ingredient bullets and consecutive numbered directions; conservative promotional-text cleanup; preserve fractions/decimals/time ranges and food-storage instructions.
5. **772f8be14924154ac3084f28c67ed249d324288c:** place eight import regressions in existing native-target SocialImportTests.swift.

Import approval/integration: [6222936925](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6222936925) / [6222954751](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6222954751). Green-bean fixture reconstructs Joe's screenshots: 10 ingredients, six directions, durations [4, nil, 1, nil, 5, nil]. Live Instagram caption extraction remains unverified; existing saved recipes are not rewritten, and need explicit re-import. Build 23 broader parsing is now formally approved/tracked in [#25](https://github.com/josephdorseyc-boop/dinner-together/issues/25), not implemented by this bounded patch.

## Exact-SHA verification

### Current 772f8be — native GREEN; Duo NOT RUN

[Native run **38953971764**](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38953971764) binds **772f8be14924154ac3084f28c67ed249d324288c**. Completed **October 16, 20:13:30 UTC / 14:13:30 Denver**. All required gates and result publication succeeded.

| Job | Evidence |
| --- | --- |
| Core **117152060010** | Xcode 26.2 Debug build-for-testing and simulator Release build; **247/247 XCTest**, zero failures/skips; **236/236 macOS engine/store tests**; 32 seeded screenshots. |
| iPhone part 1 **117152059997** | **28/28 UI**, zero failures/skips/expected failures; includes test53 and full-screen test55. |
| iPhone part 2 **117152060121** | **28/28 UI**, zero failures/skips/expected failures; includes Page color AX3 test35, mid-cook test54 and night-mode test56. |
| iPad **117152060051** | **26/26 UI**, zero failures/skips/expected failures. |
| Linux **117152060393** | Required Linux harness/count gate passed. |
| JS/fake-toolchain **117152059906** | Model, harness and release dry-run steps passed; control-flow checks, not signing/device proof. |
| Merged evidence **117174339686** | Publication succeeded. |

Immutable merged evidence **52e8c6e1d0e7396a3a2914f4bd3a393e245faa0f**: [RUN.txt](https://github.com/josephdorseyc-boop/dinner-together/blob/52e8c6e1d0e7396a3a2914f4bd3a393e245faa0f/RUN.txt), [SUMMARY.md](https://github.com/josephdorseyc-boop/dinner-together/blob/52e8c6e1d0e7396a3a2914f4bd3a393e245faa0f/SUMMARY.md), [status.txt](https://github.com/josephdorseyc-boop/dinner-together/blob/52e8c6e1d0e7396a3a2914f4bd3a393e245faa0f/status.txt) (**REQUIRED_FAILURES=0; PARTS=4**). Direct [core cases](https://github.com/josephdorseyc-boop/dinner-together/blob/52e8c6e1d0e7396a3a2914f4bd3a393e245faa0f/parts/core/20-test-iphone-cases.txt) confirm all eight SocialCaptionSeparatorTests passed natively.

Exact-head [engine-quick **38953758786**](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38953758786) also succeeded, 236 tests. Earlier orientation-only native [38947972243](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38947972243) on ff86f2a completed success; superseded by current-head evidence, not still running.

Current [landscape provenance](https://github.com/josephdorseyc-boop/dinner-together/blob/52e8c6e1d0e7396a3a2914f4bd3a393e245faa0f/ui-screenshots/iphone/r31b-nightstand-landscape-capture-provenance.txt) confirms orientation-baked primary PNG and retained raw screen/app routes; app/window 874×402, raw screen 1206×2622 with imageOrientation=2. New capture exists, but **no new human pixel-fit review is claimed by this watch**. Geometry/provenance are not real-device verification.

Exact-head Actions query returns only native-validation and engine-quick: **no Duo or release run** for 772f8be. Latest #24 says Duo dispatch is being arranged; that is intent, not a run. This watch dispatches nothing.

### Historical 4ae4f31 — native GREEN; Duo FAILED

[Native **38931626337**](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38931626337): 239 XCTest, 28+28 iPhone UI, 26 iPad UI; immutable result **cf8d402a24893cf652337ef643aec11636354bf8**.

[Duo **38931629825**](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38931629825): all three required gates failed; 56 executed, 52 passed, three failed, one skipped. Every part reached suite summary, then finalization exit 124 / export 64; direct captures survive.

| Part/job | Failed or missing evidence |
| --- | --- |
| 1 / **117076797059** | test55 automatic nightstand fallback rejected unknown orientation (runner=0; 466×678). Immutable evidence **ed29b14eb073ed7ffb45bacd634133bc23ae8283**. |
| 2 / **117076797429** | test53 skipped; skip gate failed. Selection fix is now implemented but not Duo-verified. Evidence **2ce3d869b3694a12f5034d76721c533deae9b2b9**. |
| 3 / **117076797641** | test03 launch timeout and test35 AX3 Page color sheet failed to dismiss. Evidence **4b1e16a7ca2575031976f93461ba1313225bb78a**. |

Ordinary-native passes of the same named tests do not classify those Duo failures or prove Duo runtime code bug-free.

## Pending owners and evidence boundaries

- **A1/A2:** finalization-hang experiment and manual/automatic timer-test split; no new delivered experiment/patch. Unknown orientation is not accepted as verified pose. Closed-Duo automatic entry/landscape/re-entry remain unverified; no broad early-return pass or gate waiver.
- **A1:** independent selection/count diff review still pending. Local reported checks were eight selection/guards, ten parser, seven screenshot-process and 25 fake-toolchain scenarios; current native supplemental job passed too. Actual closed-Duo filtering remains unexecuted on this candidate.
- **A2:** classify Duo test35 dismissal / test03 launch; pixel-review orientation-baked captures. No new Duo result closes these.
- Prior assigned regression evidence remains to reconcile: unmatched wording-edit refusal; remaining-step edits reflected in Cooking while started steps stay fixed; Live Activity retry injection; moved-alarm deadline cancel [throw, success], repeated cancel failure and revoked permission; Go to Cooking versus ordinary Done/unsaved-editor preservation, selected-timer label and deadline continuity. Baseline source fixes were reported integrated; missing targeted verification is not a claim that they remain unimplemented.
- **Real-device verified: none newly.** Actual alarms through silent/Focus, Lock Screen Stop, charging/unplug behavior, locked StandBy, tent/cover pose, opened/closed fit and timer continuity remain physical-device checks. Joe's Duo availability is **December**, not October 23, per [6222487023](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6222487023).

## Design, delivery and release

- Boards **02 and 03 approved** in [6215903573](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6215903573), exact design commit **3db56d9810d0e1fc9ff032e81f648f5d39f1d279**. Snapshot pending-approval wording is superseded. Full-screen **tent AND nightstand** remain mandatory; a small system Live Activity is not a substitute for the dedicated foreground page.
- Preserve dark/dim behavior, one-dish cream fallback, fixed glass-card position, native navigation, accessibility and editing/readiness safeguards. No Add a step/global Timing Save scope.
- Joe's later live-chat request targets **TestFlight today, October 16**, conditional on exact-candidate checks, signing/upload and Apple processing; it supersedes older October 20/21 target notes for Build 22, without waiving defects.
- Latest release remains [**38845842034**](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38845842034), Build 21 / cb0e397. GitHub releases list is empty. **No Build 22 archive/export signing, upload, Apple processing or tester availability established.**
- Preserve require_green=true and exact-candidate gates. Current release.yml's toolchain=27 path also requires same-SHA Duo success; do not default to toolchain=26 merely to avoid it. Archive/export must establish new widget signing; simulator Release/fake signing cannot do so.
- **Notification decision:** native pass/import integration and the pending Duo/sign-in work are already in Joe's active conversation. No newly discovered blocker, new handoff, upload milestone or user decision beyond that context. Update this checkpoint without repeating those notifications. Continue observing; do not disable this ongoing watch or initiate implementation/release.
