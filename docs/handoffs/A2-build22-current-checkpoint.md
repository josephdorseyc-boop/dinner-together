# Build 22 — current A2 handoff checkpoint

Observed **2026-10-16 22:32:27 UTC** (Denver UTC−06:00). Supersedes historical head, approval, run, ownership and hardware-date notes in the [backup runbook](A2-build22-contingency-2026-10-16.md). [Previous detailed checkpoint](https://github.com/josephdorseyc-boop/dinner-together/blob/d0d54cebe643c64e7abac603740e0bc85171a921/docs/handoffs/A2-build22-current-checkpoint.md) preserves baseline evidence and patch history. Refresh GitHub before acting.

## Ownership / scope

- A3 explicitly handed implementation/integration to A2 at Joe's request: [#24/6221940209](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6221940209), confirmed in [#15/6221940484](https://github.com/josephdorseyc-boop/dinner-together/issues/15#issuecomment-6221940484). This is an actual transfer, not an inference from silence.
- A2's temporary lead window ends **October 17, 2026, 22:00 America/Denver / October 18, 04:00 UTC**; A3 resumes then ([6222060301](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6222060301)). A1 retains assigned independent testing.
- Latest read: **67 comments in #24 / 56 in #15**. A1 [acknowledged](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6224989286) the [current-run review assignment](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6224755082): failures/counts/skips/finalization, landscape evidence, candidate identity, numbering and app/widget release preflight. Working read-only; no delivered current-run verdict yet. The active lead [reiterated the completed-failure review](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6225928872), retaining integration/upload ownership. A1 withdrew the competing mainonly patch in favor of A2's fail-closed implementation and acknowledged the test53 selection and corrected capture route.
- **This watch is documentation-only:** no implementation-branch push, app/test patch, CI dispatch/rerun/cancellation, release-setting change or release action. It records the separately authorized transfer without initiating one.

## Current source / implemented state

| Ref | Exact SHA | Meaning |
| --- | --- | --- |
| `a2/build22-lead-20261016` | **772f8be14924154ac3084f28c67ed249d324288c** | Explicit successor; unchanged integrated candidate. |
| `wip/build22` | **4ae4f31c851ae9b496aea0ec915a7c8c1c7c6667** | Unchanged A3 handoff baseline, not current continuation. |
| `main` | **cb0e3973fca5a03fd5faa5e0487bfd45cd11f3f3** | Unchanged Build 21 baseline. |

[Verified comparison](https://github.com/josephdorseyc-boop/dinner-together/compare/4ae4f31c851ae9b496aea0ec915a7c8c1c7c6667...772f8be14924154ac3084f28c67ed249d324288c): five commits ahead, none behind. Integrated: **ff86f2a12e179f38fab142cc7ba947bb400ccb89** orientation-baked full-screen capture with retained raw/provenance; **1084869ed739a1620a27c6b0f418e8d9eb252927** closed-Duo-only test53 exclusion after sharding and fail-closed count/selection guards; **3f8195925968b684f841146812e84bea572b988d** harness permissions; **393ff12be194d0370a7271ee6a96221b8e98fbad** conservative inline-caption normalization; **772f8be14924154ac3084f28c67ed249d324288c** eight import regressions placed in the native target. Staging branches are integrated, not outstanding competing successors.

Import fixture: 10 ingredients / six directions / durations [4, nil, 1, nil, 5, nil], reconstructed from Joe's screenshots. **Live Instagram extraction unverified**; existing saved recipes require explicit re-import and are not silently rewritten. Broader approved Build 23 parsing remains [#25](https://github.com/josephdorseyc-boop/dinner-together/issues/25).

## Exact-SHA verification

### Xcode 26.2 native — GREEN

[Run **38953971764**](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38953971764), same **772f8be**, completed October 16 **20:13:30 UTC / 14:13:30 Denver**. **247 XCTest**, including eight import regressions; **28+28 iPhone UI**, **26 iPad UI**, zero failures/skips; **236 macOS engine/store tests**, 32 seeded screenshots, Linux and supplemental gates, merged publication passed. Immutable [evidence **52e8c6e1d0e7396a3a2914f4bd3a393e245faa0f**](https://github.com/josephdorseyc-boop/dinner-together/blob/52e8c6e1d0e7396a3a2914f4bd3a393e245faa0f/SUMMARY.md): REQUIRED_FAILURES=0, PARTS=4. [Engine-quick **38953758786**](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38953758786): 236 passed.

### Xcode 27.1 / Duo — COMPLETED, FAILED

[Run **38966260203**](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38966260203), dispatched by the active lead, binds **772f8be**; started **21:00:05 UTC / 15:00:05 Denver**. All required ios27/Duo passes plus optional opened-window evidence. **Completed FAILED at 22:31:38 UTC / 16:31:38 Denver.** Core passed; all six required UI job gates and the optional window gate failed. No jobs remain running; this watch does not dispatch reruns.

| Pass / job | Current evidence / immutable result commit |
| --- | --- |
| ios27 core **117193390623** | **PASS**, 247 XCTest, Debug and simulator Release build, macOS harness and screenshot gate. `4ead1036cb521ee918704e3a01f4f4c4addfd421` |
| ios27 iPhone 1 **117193390494** | **Gate FAIL**: log reports **28/28 passed**, zero skips; finalization exit **124**, attachment export **64**. 88 direct captures. `cdece36d6c91f048ee1e8207f5d1ed009e1538c1` |
| ios27 iPhone 2 **117193390209** | **Gate FAIL**: **28/28 passed**, zero skips; exit **124** / export **64**. 81 direct captures. `bc7ce1e618dfdbce87d4124c82bfa3cffde33976` |
| ios27 iPad **117193390569** | **Gate FAIL**: **25/26 passed, one failed**, zero skips; exit **124** / export **64**, REQUIRED_FAILURES=3. 86 direct captures. `bc2c13dc35063422de8b1a161e717e519356270c` |
| Duo part 3 **117193390507** | **Gate FAIL**: **18/18 passed**, zero skips; exit **124** / export **64**. 47 direct captures. `72e1811e32264ff77bb428e4390c7bf57f44b693` |
| Optional opened window **117193390585** | **Gate FAIL** despite **2/2 passed**; exit **124** / export **64**. 14 direct captures. Optional job cannot establish required readiness. `173edfa0edf34207908d0afd512de88f221aee71` |
| Duo part 1 **117193390595** | **Gate FAIL**: **18/19 passed, one failed**, zero skips; exit **124** / export **64**, REQUIRED_FAILURES=3. 58 direct captures. `63720b250b5bff2dafeba40d5f883892be730279` |
| Duo part 2 **117193390774** | **Gate FAIL**: **18/18 passed**, zero skips; exit **124** / export **64**, REQUIRED_FAILURES=2. 49 direct captures. `6f48fdeb706962494bde7dfada97adb9d0e56d93` |

Every completed result commit above has **RUN.txt confirming run 38966260203 / source 772f8be / pass / part / Xcode 27.1**. SUMMARY.md and status.txt confirm gates. Passing wrapper steps do not override failures.

**Previously recorded current-run iPad failure:** [iPad raw log](https://github.com/josephdorseyc-boop/dinner-together/blob/bc2c13dc35063422de8b1a161e717e519356270c/25-ui-test-ipad.log), `test04_recipeReviewGate_iPad`, **UITestSupport.swift:1337**: “Failed to get matching snapshots: Timed out while evaluating UI query.” After Timing confirmation, a StaticText query retried; test failed after **305.727 seconds**. Cause remains **unclassified app vs test/runtime**. Same-SHA Xcode 26.2 success does not waive or explain this failure.

**Newly completed current-run nightstand failure:** [Duo part 1 raw log](https://github.com/josephdorseyc-boop/dinner-together/blob/63720b250b5bff2dafeba40d5f883892be730279/25-ui-test-iphone.log), `test55_fullScreenTimers`, **UITestSupport.swift:2721**, failed after **88.668 seconds**: nightstand did not open after the requested turn; the accommodation requires a verified closed Duo with observed portrait pose. [Direct geometry](https://github.com/josephdorseyc-boop/dinner-together/blob/63720b250b5bff2dafeba40d5f883892be730279/ui-screenshots/iphone/direct/r31-nightstand-geometry.txt): `no page; simulator=iPhone Duo; hinge=; runner orientation=0; frame=(0,0,466,678)`. Retained hierarchy shows Cooking, not `fullscreen-timers`. This repeats the previously observed automatic-entry/unknown-pose blocker on **772f8be**; it does not classify app versus simulator/test cause or verify orientation. Do not accept unknown orientation as proven portrait. The manual capture `r31a-fullscreen-by-hand.png` exists; later test55 assertions were not reached.

Duo part 2 now confirms the implemented test53 selection: **18 selected, 18 executed, zero skips**, with `test56_fullScreenTimersNight` **passed (62.539 seconds)**. This is native simulator evidence for that test only, not physical tent/StandBy verification or a successful job gate.

Post-suite exit 124 / unreadable-result export 64 recur across **all seven UI jobs**, including the optional window. Duo part 3 explicitly logged **Selected tests passed**, then build-record diagnostics including invalidDigitCount and eventual interruption. This supports a separate finalization/result-evidence problem; **root cause and corrective experiment remain pending**, not proof that all product code is bug-free. test03 launch and test35 AX3 Page color dismissal **passed in current Duo part 3**, superseding their earlier failing observations for this execution; stable closure still needs gate completion and A1 review.

## Pending owners / design / hardware

- **A1:** current-run independent review and read-only packaging preflight; finalization experiment proposal and manual-vs-automatic timer-test split remain undelivered. **A2 active lead:** integration/classification and capture review. This watch assigns no new implementation.
- Duo test53 exclusion is now native-executed with matching 18/18 counts and zero skips in part 2. test55 remains required and failed automatic entry in part 1; unknown orientation is not accepted as verified pose. A1's proposed manual/automatic split remains pending; do not relax gates or silently pass unsupported automatic behavior.
- Preserve pending targeted evidence for edit refusal/remaining-plan updates, Live Activity retry, moved-alarm cancel/retry/revoked permission, Go to Cooking vs ordinary Done/unsaved drafts, selected-timer label and deadline continuity. Source fixes were reported integrated; missing targeted verification does not mean unimplemented.
- Boards **02/03 approved** in [6215903573](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6215903573), design commit **3db56d9810d0e1fc9ff032e81f648f5d39f1d279**. Full-screen **tent AND nightstand** remain mandatory; a small Live Activity is not a substitute. Preserve native navigation, accessibility, dark/dim behavior, one-dish fallback, fixed glass card and save/readiness safeguards. No Add a step/global Timing Save scope.
- **Locally checked** harness/parser/screenshot-process/fake-toolchain reports remain control-flow evidence, not native app or signing proof. **Native simulator verified** evidence is scoped by toolchain/part above. **No new human pixel-fit review or real-device verification.**
- Joe's physical Duo availability is **December**, not October 23 ([6222487023](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6222487023)). Alarms through silent/Focus, Lock Screen Stop, charging/unplug/locked StandBy, tent/cover pose, opened/closed fit and timer continuity remain physical-device checks.

## Release / notification

- Joe's current target is **TestFlight today, October 16**, conditional on required checks, signing/upload and Apple processing. The active conversation's **17:00–18:00 Denver upload estimate is not assured**: current required gates are already failed.
- Exact-SHA Actions search: native success, engine-quick success, current Duo run completed failed; **no candidate release run**. The latest 100 repository runs contain no active jobs and no newer release run Latest release remains [**38845842034**](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38845842034), Build 21 / cb0e397. Main unchanged; releases collection empty. **No Build 22 archive/export signing, upload, Apple processing or tester availability established.**
- Keep require_green=true and required same-SHA checks; do not switch toolchains to bypass failure. Widget signing requires actual archive/export, not simulator Release or fake signing.
- **Material change for notification:** the remaining current-SHA Duo jobs have finished; automatic-nightstand test55 failed again, while part 2's night-mode test and scoped test53 exclusion passed. Required validation is now conclusively failed, with no upload initiated. The iPad and export failures were already reported; avoid repeating them as new findings. No takeover, gate waiver, implementation change or release was initiated. Continue observing; this watch has not completed and is not disabled.
