# Build 22 — current A2 handoff checkpoint

Observed **October 16, 2026, 17:57 UTC (11:57 Denver)**. Supersedes historical observations in the [backup runbook](A2-build22-contingency-2026-10-16.md). Previous detailed source/failure history is preserved at [6fcf661](https://github.com/josephdorseyc-boop/dinner-together/blob/6fcf661451f70fee7c1e3b1ab33a700bf7b460c8/docs/handoffs/A2-build22-current-checkpoint.md). Refresh GitHub before acting.

## Ownership, source and changes

- **A3 remains implementation/integration/release lead; A1 owns assigned testing.** No explicit handoff, unavailability or successor branch announced. Silence does not establish unavailability.
- Active `wip/build22` remains **4ae4f31c851ae9b496aea0ec915a7c8c1c7c6667**, committed 16:23:26 UTC; head rechecked 17:57 UTC. No source commits since the previous checkpoint.
- #24 now has **45** comments; newest [A1 consolidated patch list / 6220176933](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6220176933). #15 remains **55** comments, newest [6217247846](https://github.com/josephdorseyc-boop/dinner-together/issues/15#issuecomment-6217247846). Both latest comment collections read; A3's latest integration note is [6219905889](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6219905889).
- **New milestone: exact-head iPhone/iPad native validation is green. New/remaining blocker: exact-head Duo validation failed**, with distinct test assertions, launch timeout, skip policy and post-suite failures detailed below. No release or hardware pass follows from native green.
- A2 changed documentation only on this dedicated branch. No active-branch push, duplicate patch, workflow rerun/dispatch, release-setting change, takeover or release.

## Exact-SHA results — current candidate

Every result below binds source **4ae4f31c851ae9b496aea0ec915a7c8c1c7c6667**. Native and Duo workflows are both completed; all jobs inspected.

### Native: 38931626337 / #173 — SUCCESS

[Workflow](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38931626337) · immutable evidence **cf8d402a24893cf652337ef643aec11636354bf8**: [RUN.txt](https://github.com/josephdorseyc-boop/dinner-together/blob/cf8d402a24893cf652337ef643aec11636354bf8/RUN.txt), [SUMMARY.md](https://github.com/josephdorseyc-boop/dinner-together/blob/cf8d402a24893cf652337ef643aec11636354bf8/SUMMARY.md), [status.txt](https://github.com/josephdorseyc-boop/dinner-together/blob/cf8d402a24893cf652337ef643aec11636354bf8/status.txt) = REQUIRED_FAILURES=0 / PARTS=4. No missing part.

| Job | Verified result |
| --- | --- |
| Core **117076786840**, Xcode 26.2 | Debug build-for-testing and simulator Release build passed; **239/239 XCTest**, zero skipped/failed; **228** macOS engine/store tests; **32** seeded screenshots passed. Simulator Release is not archive/export/signing proof. |
| iPhone part 1 **117076786869** | **28/28 UI**, zero failed/skipped. Includes test18 AX3, test53 and hardened test55 full-screen flow. |
| iPhone part 2 **117076786825** | **28/28 UI**, zero failed/skipped. Includes test54 Timing-while-cooking and **test56 night mode**. |
| iPad **117076786824** | **26/26 UI**, zero failed/skipped. |
| Linux **117076786933** / JS **117076786234** | Passed. Previously inspected exact-head logs: **228/228** Linux tests; 128 JS assertions, 5 async JS scenarios, 10 parser / 7 screenshot-process checks, 25 harness / 7 release fake-toolchain scenarios. These are supplemental, not device/signing checks. |

Engine-quick **38931594250 / #233** also succeeded. **4ae4f31 / 38931626337 is now the latest fully green native baseline**, superseding e273cdd for that claim. The prior Day/Night test56 failure is closed for this native test path; not proof of clock-driven transitions, dark landscape fit or real-device alarms.

Current r31 [geometry](https://github.com/josephdorseyc-boop/dinner-together/blob/cf8d402a24893cf652337ef643aec11636354bf8/ui-screenshots/iphone/r31-nightstand-geometry.txt) confirms turned=true, **874×402**, Done approximately **(94,8,97,44)** and lead **(104.55,82.55,549.35,256.89)**. Ordinary-iPhone automatic landscape entry and the measured placement passed the hardened flow.

Current paired [capture provenance](https://github.com/josephdorseyc-boop/dinner-together/blob/cf8d402a24893cf652337ef643aec11636354bf8/ui-screenshots/iphone/r31b-nightstand-landscape-capture-provenance.txt): screen capture reports points 874×402 / pixels 1206×2622 / orientation 2; application comparison reports points 402×874 / pixels 2622×1206 / orientation 2; app/window bounds 874×402; runner orientation=0. Paired unmodified PNGs exist. **Pixel fit has not been visually certified in this check**; geometry and image metadata are not a substitute. Do not claim the screenshot artifact fixed solely from the green suite.

### Duo: 38931629825 / #45 — FAILURE

[Workflow](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38931629825), Xcode 27.1. All three gates failed; no opened-window job in this selection.

| Part / job / immutable evidence commit | Actual result |
| --- | --- |
| Part 1 **117076797059**; **ed29b14eb073ed7ffb45bacd634133bc23ae8283** | **19 executed, 18 passed, 1 failed, 0 skipped**: test55, UITestSupport.swift:2714, no automatic nightstand page and unsupported-pose accommodation rejected. Exit **124**, export **64**, **59** direct captures. |
| Part 2 **117076797429**; **2ce3d869b3694a12f5034d76721c533deae9b2b9** | **19 executed, 18 passed, 0 failed, 1 skipped**: unsupported-cover test53 still fails the skip gate. test56 no longer fails. Exit **124**, export **64**, **50** direct captures. |
| Part 3 **117076797641**; **4b1e16a7ca2575031976f93461ba1313225bb78a** | **18 executed, 16 passed, 2 failed, 0 skipped**: test03 launch timeout and test35 AX3 Page color dismissal assertion. Exit **124**, export **64**, **42** direct captures. |

For each immutable commit, RUN.txt identifies this exact source/run/part and SUMMARY.md records the counts. [Part 1 summary](https://github.com/josephdorseyc-boop/dinner-together/blob/ed29b14eb073ed7ffb45bacd634133bc23ae8283/SUMMARY.md) · [part 2 summary](https://github.com/josephdorseyc-boop/dinner-together/blob/2ce3d869b3694a12f5034d76721c533deae9b2b9/SUMMARY.md) · [part 3 summary](https://github.com/josephdorseyc-boop/dinner-together/blob/4b1e16a7ca2575031976f93461ba1313225bb78a/SUMMARY.md). Counts are log-derived because result bundles were unreadable. Every part started; do not describe these as a pre-test hang or infer all app tests failed.

## Blockers and next owners

1. **A3/A1 — test55 unsupported-pose accounting still fails on real CI evidence.** [Direct diagnostic](https://github.com/josephdorseyc-boop/dinner-together/blob/ed29b14eb073ed7ffb45bacd634133bc23ae8283/ui-screenshots/iphone/direct/r31-nightstand-geometry.txt) reads: simulator=iPhone Duo; hinge empty (recognized as closed); frame=466×678; **runner orientation=0 (unknown)**. Source requires an explicitly observed portrait orientation, so the guard correctly refuses to credit unknown pose. This establishes why the accommodation was not taken, not an app activation defect or real-device failure. The ordinary-iPhone successful capture also reports runner orientation=0, so the runner value is not reliable target-app pose evidence here. Reconcile a trustworthy target/destination pose observation or explicitly scoped coverage outcome; preserve ordinary-iPhone failure gates and mark unexercised Duo auto-entry/landscape/re-entry UNVERIFIED. No blanket unknown-pose return.
2. **A1/A3 — test35_palePhotoPageAX3 is a new current-candidate failing interaction.** [Part 3 raw log](https://github.com/josephdorseyc-boop/dinner-together/blob/4b1e16a7ca2575031976f93461ba1313225bb78a/25-ui-test-iphone.log), line 5009: UITestSupport.swift:1724, timed out waiting for “the Page color sheet closed” after Done. Native ordinary-iPhone/iPad suite passed; Duo app-versus-simulator/test cause remains **unresolved**. Source confirms this is a dismissal wait after tapping page-style-done, not a missing-Done assertion. Test03 separately timed out launching via Xcode at line 164 (raw log line 29); no app-crash diagnosis established.
3. **A1 — test53 selection/policy decision remains open.** Exclude an unsupported Duo case versus explicitly accepted documented skip, coordinated with A3. Current gate rejects skips; no waiver/selection change observed.
4. **A1/A3 — post-suite finalization/export failures persist on all Duo parts.** Keep exit 124 / export 64 separate from assertions and launch failure. Preserve direct captures and logs; do not waive failures because tests ran.
5. **A3 — visual review remains:** paired raw r31/r29 captures, approved-board standard/AX3 fit, dark landscape, targeted Go to Cooking-over-Timers versus ordinary Done/unsaved-editor preservation, later selected-timer label, charging/unplug/pose suppression/re-entry and unchanged timer deadlines. Native suite green does not independently prove every targeted interaction or visual state.

A1's latest consolidated list repeats the syntax-checked latent mainonly Bash patch and proposed screenshot rotation. Neither is integrated at unchanged 4ae4f31. The rotation proposal remains unreconciled with A3's documented clipped landscape PNG and the new paired-route metadata; do not treat it as a proven fix or duplicate an active patch. Runtime-availability-before-retry work not observed integrated.

Other A1 assignments remain without new delivered patches: test-intent review; unmatched wording-edit refusal; mid-cook unstarted edit reflected in timeline while started step stays fixed; Live Activity retry injectable seam/regression; alarm error injection for moved deadline [throw, success], repeated cancel failure and revoked permission. The ten-step tent device checklist was delivered and adopted by A3; the broader silent/Focus/Lock Screen checklist and hardware execution remain outstanding.

## Implemented, approved and not yet hardware-verified

- Integrated source remains: boards 02/03; dedicated full-screen/day-night page; alarm fallback/tombstones and stale-deadline invalidation; pipe-free screenshot process checks; permission-aware foreground chime; root Go to Cooking dismissal; release metadata guard. Detailed earlier commit provenance is in the immutable previous checkpoint linked above.
- Three RC support commits are integrated: **e91b360d5883bf468934f54d72744a2daed62cdf** (SELECTED TIMER copy), **59b48bb50f00a6e019c16f487382a3dd70dbb6d1** (scoped pose test/harness), **4ae4f31c851ae9b496aea0ec915a7c8c1c7c6667** (raw-capture provenance). All now compile in green native validation; that does not close the Duo assertion or certify every control/pixel. Their [mail-patch packaging branch](https://github.com/josephdorseyc-boop/dinner-together/blob/56406c8f66a72c96748db60e1a30beea5d47d0da/docs/handoffs/A2-RC-nightstand-support-2026-10-16.md) is not an app-source branch. Do not apply again.
- Boards **02/03 approved** in [#24/6215903573](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6215903573); exact board/spec source **3db56d9810d0e1fc9ff032e81f648f5d39f1d279** re-read. Historical “awaiting approval” text is superseded.
- **Full-screen tent AND nightstand timers are mandatory.** Locked StandBy/Live Activity is separate from the dedicated foreground page. Dark/dim direction is already decided; one-dish no-photo cream page and fixed glass-card position stand. No Add a step or global Timing Save scope.
- **Real-device verified: none newly.** October 23 checks remain tent/cover rotation, automatic lifecycle and full-screen fit, locked StandBy, alarm through silent/Focus, Lock Screen Stop, opened/closed cooking and timer continuity. Simulator/native/source/fake-toolchain results are distinct from hardware evidence.

## Release and handoff status

Main remains **cb0e3973fca5a03fd5faa5e0487bfd45cd11f3f3**. Latest release workflow remains [38845842034](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38845842034), Build 21, success/reported upload. Latest 100 Actions runs show no newer release; GitHub releases list is empty. **No Build 22 release/upload**, real archive/export/widget distribution signing, Apple processing or tester availability established. Seven fake-toolchain release scenarios are not signing proof. Preserve exact-candidate native/Duo gates and require_green=true.

October 20 RC / October 21 TestFlight remain plans. Native #173 success is a validation milestone, not a release declaration; Duo #45 is not green. No takeover initiated. Before an explicitly authorized handoff, refresh source/evidence and reconcile A1/A3 ownership and unpushed work. This check warrants notifying Joe of native green plus the remaining/current Duo blockers; no decision from Joe is required yet.
