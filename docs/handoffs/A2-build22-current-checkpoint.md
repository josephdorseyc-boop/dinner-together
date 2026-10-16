# Build 22 — current A2 handoff checkpoint

Observed **October 16, 2026, 16:38 UTC (10:38 Denver)**. Supersedes historical state in the [backup runbook](A2-build22-contingency-2026-10-16.md). Refresh source, comments and jobs before acting.

## Ownership and current source

- **A3 remains implementation/integration/release lead; A1 owns assigned testing.** No explicit handoff, successor branch or unavailability announcement in current #24/#15. Silence is not evidence of unavailability.
- Active `wip/build22`: **4ae4f31c851ae9b496aea0ec915a7c8c1c7c6667**, committed 16:23:26 UTC. Six commits ahead of the previous checkpoint's 84ac8c8; no divergence.
- Latest coordination: [A3 #24/6219905889](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6219905889), 16:24:24 UTC, integrates the three patches; [A1 #24/6220139352](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6220139352), posted 16:36:42 UTC, is reconciled below. #24 has 44 comments; #15 has 55, latest [A1 #15/6217247846](https://github.com/josephdorseyc-boop/dinner-together/issues/15#issuecomment-6217247846). Both issue bodies and all comments read.
- A2 updates documentation only on this dedicated branch. No active-branch writes, duplicate patches, CI dispatch/rerun, release changes, takeover or release.

## Material change: RC support is integrated, not yet native-verified

A3 applied all three candidates from [A2's handoff](https://github.com/josephdorseyc-boop/dinner-together/blob/56406c8f66a72c96748db60e1a30beea5d47d0da/docs/handoffs/A2-RC-nightstand-support-2026-10-16.md) with `git am`. The packaging branch contains mail patches, not applied Swift changes; do not cherry-pick it or reintegrate these candidates.

| Source commit | Implemented; verification limit |
| --- | --- |
| **d98cccef6063493beeb688742bf7e115c01b8edb** | test56 uses the dark capture instead of appending a second appearance flag after the standard capture's light flag. Source confirms A3's diagnosis of the prior Day/Night assertion; post-fix native verdict pending. |
| **6e5d00359dbbd39d45f605e51884e52b5115eaa2** | Sideways ordinary-iPhone capture uses XCUIScreen. Capture fidelity is not yet established. |
| **9dd34692ad75c79735aaa33c7c7711d0f2b91849** | Initial unsupported-pose accommodation; hardened by 59b48bb below. Do not retain its broader false-green paths. |
| **e91b360d5883bf468934f54d72744a2daed62cdf** | Explicitly selected later timer says SELECTED TIMER rather than NEXT TO FINISH. Source/diff checked; native interaction pending. |
| **59b48bb50f00a6e019c16f487382a3dd70dbb6d1** | Subscribe before rotating; selected destination passed by harness. No-page exception requires exact iPhone Duo, closed hinge and positive portrait frame with observed portrait orientation. Ordinary iPhone, unknown pose, or an opened page that stays portrait fails. Unsupported Duo outcome explicitly records automatic/landscape/dismissal-reentry UNVERIFIED; it is not hardware credit. |
| **4ae4f31c851ae9b496aea0ec915a7c8c1c7c6667** | Paired unmodified screen/application PNGs plus dimensions, scale/orientation and app/window bounds. Diagnostic only: no rotation, crop, primary replacement or gate weakening. Native compilation/capture pending. |

Local candidate checks in the immutable handoff: diff/shell syntax, three destination-selection checks, 25 fake-toolchain harness scenarios, 10 parser and seven screenshot-process checks passed. They do not execute XCTest or verify the app. Current-SHA CI independently passes the supplemental checks below.

Earlier integrations remain: boards 02/03 (ebb84d4 / 73a4aeb), full-screen/night page (cfa7747 / 928660b), per-reminder fallback and cancel tombstones, stale-deadline coverage invalidation **d1776c096ef06280ca523d461e4f700d1e53c04c**, skipped-case diagnostics 062ebca, settled r31 geometry ae2da06, pipe-free screenshot process check **23171fe4470965eaf06b463d020de3c984145d1d**, permission-aware alarm coverage **c60324285a458382d735016b69498d5fae9ceb4f**, Go to Cooking root dismissal **da10d92daf6d6363b385303f8a4fdc0f154da925**, and release metadata guard **84ac8c814c9d82d9281c2349387b8ff070605358** (from 045c58c). Do not duplicate those patches. Source implementation is not blanket native/device verification.

## Exact-current-SHA Actions

All rows bind source **4ae4f31c851ae9b496aea0ec915a7c8c1c7c6667**; snapshot 16:35–16:36 UTC.

| Run / job | Observed evidence |
| --- | --- |
| [38931594250 engine](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38931594250) | Success. |
| [38931626337 native](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38931626337) | No final verdict. Core **117076786840**, iPad **117076786824**, iPhone part 2 **117076786825** in progress; iPhone part 1 **117076786869** queued. No current-SHA native app/UI pass yet. |
| Native Linux **117076786933** | Success: **228/228** engine/store harness tests, zero failures, expected-count check passed. Does not execute UIKit/AlarmKit UI. |
| Native JS/harness **117076786234** | Success: **128** JS model assertions, **5** async model scenarios, **10** parser checks, **7** screenshot-process checks, **25** harness and **7** release fake-toolchain scenarios. No signing or native alarm/device execution. |
| [38931629825 Duo](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38931629825) | No final verdict. Part 1 **117076797059** in progress; parts 2 **117076797429** and 3 **117076797641** queued. No opened-window job in this dispatched selection; do not imply opened-window validation. |

A1's latest queue note names native #172 / Duo #44, the superseded 9dd3469 runs. Its projected read time and “no jobs started” statement are not current-SHA evidence: the job endpoints above already show work in progress. The run-level queued label does not mean every job is queued. No final verdict or new runner-capacity blocker is inferred from that note.

A3 cancelled 9dd3469's [native 38930011797](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38930011797) and [Duo 38930015333](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38930015333). Neither is a pass or current-candidate evidence. The mutable ci-results branch now points at **2ef502e46c35ac49a5d5330e9899fa40383be12e**: its RUN.txt identifies the cancelled 9dd3469 run and its summary is incomplete. Never attribute it to 4ae4f31.

## Earlier failures and remaining evidence limits

- **Night test56:** 928660b native **38915092856** failed Day/Night twice; immutable [9f2a2b3 SUMMARY](https://github.com/josephdorseyc-boop/dinner-together/blob/9f2a2b3529ff9a18efa138c790dea9919e00d75b/SUMMARY.md) and RUN.txt preserve source/run. d98ccce corrects the conflicting launch flags. This is addressed in test source, not yet closed by post-fix native evidence.
- **84ac8c8 native 38921681071:** still in progress. Core **117042919494**, iPad **117042919478** and iPhone part 1 **117042919535** succeeded; part 2 **117042919559** still running. Core's 239 XCTest / 228 macOS harness / 32 screenshots passed. A3 confirms the prior SIGPIPE false-crash diagnosis; that old log did not establish an app crash. These results do not verify the six later commits.
- **84ac8c8 Duo 38921685281 finished failure**, all three parts failed their gates. Part 1: test55 automatic nightstand entry failed (19 executed, 18 passed), exit 124/export 64, 58 direct captures; [03ccd26 RUN/SUMMARY](https://github.com/josephdorseyc-boop/dinner-together/blob/03ccd26fce4d5ba7231bba62808c2d7507fdb117/SUMMARY.md). A3/A1 attribute unsupported cover rotation to the simulator; 59b48bb now records strictly scoped partial coverage, not a product fix or hardware pass.
- Duo part 2: **19 executed, 17 passed, test56 failed, test53 skipped**, exit 124/export 64, 49 direct captures; [df4f8d7 RUN/SUMMARY](https://github.com/josephdorseyc-boop/dinner-together/blob/df4f8d796bfb9b520113909ca30c645587ebfd71/SUMMARY.md). Part 3: **18/18 passed by log**, but exit 124/export 64, 47 direct captures; [4582ee0 RUN/SUMMARY](https://github.com/josephdorseyc-boop/dinner-together/blob/4582ee0b77d07531ccc68a3c6b9d430d48349f5a/SUMMARY.md). All RUN.txt files bind 84ac8c8 / 38921685281. These parts started; post-suite/finalization failures are distinct from the historical pre-test hang.
- **test53 remains an A1/A3 policy/selection decision:** exclude unsupported Duo cover case versus explicitly accepted documented skip. Current gate rejects skips; no waiver or selection change is established.
- **Landscape layout versus pixels:** prior r31 measured frame **874×402**, Done **(94,8,97,44)**, lead **(104,83,549,257)**. A3 reports the PNG itself is **2622×1206**, containing a clipped rotated square, not a portrait bitmap. A1's proposed portrait-only rotation guard would not run and cannot reconstruct clipped pixels. Await paired raw-route evidence; do not treat rotations or geometry as complete visual-fit proof. The similar r29a artifact supports a capture-path explanation, not proof that every UI element fits.
- Last fully green native baseline remains **e273cdd3f498061406bd0f1ca3f36c5b0d1c2168 / 38906195142**, before boards/alarm/night follow-ups. No new current-SHA all-green native/Duo result or real-device evidence.

## Design, unfinished work and owners

- Boards **02/03 approved** in [#24/6215903573](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6215903573), exact design source **3db56d9810d0e1fc9ff032e81f648f5d39f1d279**. [Board specifications](https://github.com/josephdorseyc-boop/dinner-together/blob/3db56d9810d0e1fc9ff032e81f648f5d39f1d279/docs/design/build22-proposals-2026-10-16/README.md) read. Historical “awaiting approval” wording is superseded.
- **Full-screen timers in BOTH tent and nightstand remain mandatory.** Dedicated in-app page implemented; locked StandBy/Live Activity remains a separate system-owned surface. One-dish no-photo cream page and fixed glass-card position remain Build 22 decisions. Dark/dim was requested and implemented; no outstanding color decision inferred. No Add a step or global Timing Save scope.
- **A3:** finish exact-current-SHA validation; inspect raw capture/provenance and native board/AX3 fit; targeted Go to Cooking over Timers versus ordinary Done/unsaved-editor preservation; verify automatic entry/exit, suppression/re-entry, idle lock and unchanged deadlines. Runtime-availability-before-retry work not seen integrated. duoctl rotation is explicitly deferred until RC green, not a new blocker.
- **A1:** assigned test-intent/r31 review, test18, post-suite hang investigation, test53 decision, unmatched wording-edit refusal regression, mid-cook unstarted edit reflected in timeline while started step stays fixed, Live Activity retry seam/regression, alarm error injection (moved-deadline [throw, success], repeated cancel failure, revoked permission). No new delivery of those assigned patches confirmed.
- **A1's latent mainonly patch** (#15/6217247846) remains syntax-only checked; current harness still uses the array. A3 reconciles it; no duplicate A2 implementation.
- **Device checklist progress:** A1's ten-step tent checklist [#24/6219778400](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6219778400) is delivered and explicitly adopted by A3: auto entry, day/night layout, content/actions, Done suppression, upright/unfold reset, re-tent, 180° flip, no-timer and short-pose checks. Broader alarm-through-silent/Focus and Lock Screen Stop proof remains hardware work.
- **Real device:** nothing newly verified. October 23 remains the planned Duo check: cover/tent rotation, charging/unplug lifecycle, locked StandBy fit, alarm delivery and Stop. Simulator/source/synthetic checks must stay separate from native and real-device verification.

## Release and handoff readiness

Latest release workflow remains [38845842034](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38845842034), source **cb0e3973fca5a03fd5faa5e0487bfd45cd11f3f3** (Build 21, workflow success/reported upload); main remains that SHA. Latest 100 Actions runs cover October 15 19:57 UTC through this check; no later release run. GitHub releases list is empty. No Build 22 release/upload or Apple processing/tester availability established. Widget distribution signing and real archive/export remain unverified; seven fake-toolchain release scenarios do not prove them. Preserve exact-candidate native/Duo gates and require_green=true.

No takeover initiated or explicit unavailability reported. October 20 RC / October 21 TestFlight remain plans, not milestones completed. Before any authorized handoff, refresh pushed source/evidence and reconcile A1/A3 ownership and unpushed work. Current changes warrant checkpoint maintenance, not a new Joe escalation: no new blocker, release milestone or user decision established.
