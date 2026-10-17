# Build 22 — current A2 handoff checkpoint

Observed **2026-10-17 02:43 UTC / October 16, 20:43 Denver**. Refresh GitHub before acting. Supersedes historical observations in the [backup runbook](A2-build22-contingency-2026-10-16.md). [Previous checkpoint](https://github.com/josephdorseyc-boop/dinner-together/blob/bf8ecb1411fd08df2e5f8f62297ed27c5cc97f49/docs/handoffs/A2-build22-current-checkpoint.md) preserves parent failures, earlier source/run provenance and rejected proposals.

## Ownership and boundaries

- A3 is implementation/integration lead by default; an **explicit temporary handoff** to A2 is recorded at Joe's request in [#24/6221940209](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6221940209) and [#15/6221940484](https://github.com/josephdorseyc-boop/dinner-together/issues/15#issuecomment-6221940484), not inferred from silence.
- A2's interactive lead window ends **October 17, 22:00 Denver / October 18, 04:00 UTC**, then A3 resumes ([6222060301](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6222060301)). A1 retains independent assigned testing. The interactive lead owns integration, dispatch and upload.
- **This watch remains docs-only:** no active source-branch edits, duplicate patches, CI dispatch/rerun/cancellation, release-setting changes, takeover or release.
- Latest read: **107 comments in #24 / 56 in #15**. Latest #24 [6228618481](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6228618481), October 17 02:40:37 UTC; #15 unchanged since handoff.

## Source and implemented scope

| Ref | Exact SHA | State |
| --- | --- | --- |
| `a2/build22-lead-20261016` | **d6aaaaabd22a6674dc90d018b47c0018d62d9fdd** | Explicit successor, unchanged candidate; complete required workflows still pending. |
| `wip/build22` | **4ae4f31c851ae9b496aea0ec915a7c8c1c7c6667** | A3 handoff baseline, unchanged. |
| `main` | **cb0e3973fca5a03fd5faa5e0487bfd45cd11f3f3** | Build 21, unchanged. |

[Compare](https://github.com/josephdorseyc-boop/dinner-together/compare/4ae4f31c851ae9b496aea0ec915a7c8c1c7c6667...d6aaaaabd22a6674dc90d018b47c0018d62d9fdd) confirms **nine commits ahead, zero behind**, merge base exactly A3's handoff. Follow-ups cover capture orientation/provenance (`ff86f2a`), fail-closed selection and permissions (`1084869`, `3f81959`), caption parsing/regression registration (`393ff12`, `772f8be`), automatic/manual test separation and five-minute finalization (`6b320f4`), primary/retry consistency (`886dac3`), app-local UserDefaults CA92.1 privacy declaration (`79aecba`), and optional diagnostic collection (`d6aaaaa`).

**Implemented:** full-screen tent/nightstand, approved boards 02/03 Timing/Cooking treatment, alarms/fallbacks and Live Activities/reliability work remain in A3's baseline. Caption fixture extracts 10 ingredients/six directions; live social extraction is unverified and old imports need re-import. Broader overhaul remains Build 23 / #25.

**Latest one-file diff independently inspected:** [d6aaaaa](https://github.com/josephdorseyc-boop/dinner-together/commit/d6aaaaabd22a6674dc90d018b47c0018d62d9fdd) adds `-collect-test-diagnostics never` to BOTH primary/flaky-retry UI commands, plus notes. Production Swift, assertions, selection and release gates are unchanged from parent **79aecbad03f7d47055d100ca7c28e3f24f43a332**. Completed 27.1 parts now give positive evidence for the workaround; do not claim universal closure before remaining parts finish.

**Locally checked, owner-reported only:** 25 harness scenarios + 31 focused checks; published tree **bc9027904f9da37722ada721a0152979cbf4b7ae** ([6227816139](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6227816139)). This watch inspected source, APIs, published summaries/JSON and logs, not a local/native re-execution.

## Exact-current-SHA verification

Both required runs bind **d6aaaaabd22a6674dc90d018b47c0018d62d9fdd**. **Five of seven 27.1 jobs are green, including all three closed-Duo gates.** Both overall workflows remain in progress.

| Required run / toolchain | Part / job | Observed verdict |
| --- | --- | --- |
| [38990012070](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38990012070), Xcode 27.1 | core **117270091706** | PASS: Release compilation, **247/247 XCTest**, **236** macOS harness tests, 32 static PNGs; both failure counters zero. |
| Same | iPad **117270091602** | PASS: **26/26**, zero failures/skips/expected failures; exit0, 94 PNGs. |
| Same | closed-Duo part1 **117270091649** | PASS **with existing strict isolated retry**; details below. Manual full-screen test55 included. |
| Same | closed-Duo part2 **117270091571** | PASS: **18/18**, zero failures/skips/expected failures; exit0, 53 PNGs. Includes test22 and night-mode test56. |
| Same | closed-Duo part3 **117270091538** | PASS: **18/18**, zero failures/skips/expected failures; exit0, 47 PNGs. Includes test35 without a patch/retry. |
| Same | ordinary iPhone1 **117270091562**; iPhone2 **117270091445** | Both IN PROGRESS; no completed verdict. |
| [38989926720](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38989926720), Xcode 26.2, attempt2 | iPhone1 **117280934137** | Fresh-runner retry IN PROGRESS, started **02:30:08 UTC**. |
| Same | core **117280934770**, iPhone2 **117280934995**, iPad **117280935311**, Linux **117280958413**, JS/harness **117280967792** | Preserved successes from attempt1, NOT new executions: core 247/247 + 236; iPhone2 28/28; iPad 26/26. Merged attempt2 publication still pending. |

### Immutable evidence and retry transparency

Every 27.1 result commit below has independently read `RUN.txt` binding run **38990012070**, source **d6aaaaa**, pass/part and Xcode27.1, plus `REQUIRED_FAILURES=0`. Result branches are mutable; use these immutable commits:

| Part | Immutable evidence commit / summary |
| --- | --- |
| 27.1 core | [3bc36c9af56aad9b0a9d1968f62ec2c382db7716](https://github.com/josephdorseyc-boop/dinner-together/blob/3bc36c9af56aad9b0a9d1968f62ec2c382db7716/SUMMARY.md) |
| 27.1 iPad | [1617d836d82434a63c3485e4c7539cc523f58da7](https://github.com/josephdorseyc-boop/dinner-together/blob/1617d836d82434a63c3485e4c7539cc523f58da7/SUMMARY.md) |
| Duo part1 | [2f17c3aa38ee20e63ded8bdd494204211b455507](https://github.com/josephdorseyc-boop/dinner-together/blob/2f17c3aa38ee20e63ded8bdd494204211b455507/SUMMARY.md) |
| Duo part2 | [6a508a0c1d3777effdfcde7af7196ab7a20922b2](https://github.com/josephdorseyc-boop/dinner-together/blob/6a508a0c1d3777effdfcde7af7196ab7a20922b2/SUMMARY.md) |
| Duo part3 | [57dac32b603d7d8be1c24976864f37dc2dbe2acc](https://github.com/josephdorseyc-boop/dinner-together/blob/57dac32b603d7d8be1c24976864f37dc2dbe2acc/SUMMARY.md) |

**Duo part1 is NOT a clean first-pass 19/19.** Primary readable JSON: 19 executed, 18 passed, one failed, zero skips/expected failures, exit65. `test09_tonightFirstLaunch` failed matching the Thanksgiving card snapshot at UITestSupport.swift:1055. Existing isolated retry: **exit0, readable JSON 1 executed/1 passed/0 failed/0 skipped/0 expected failures**, normal export; gate success at **02:39:27 UTC**, 87 PNGs. [Primary JSON](https://github.com/josephdorseyc-boop/dinner-together/blob/2f17c3aa38ee20e63ded8bdd494204211b455507/25-ui-test-iphone-summary.json), [retry JSON](https://github.com/josephdorseyc-boop/dinner-together/blob/2f17c3aa38ee20e63ded8bdd494204211b455507/25-ui-test-iphone-retry-summary.json), [FLAKY.txt](https://github.com/josephdorseyc-boop/dinner-together/blob/2f17c3aa38ee20e63ded8bdd494204211b455507/FLAKY.txt). A1 retains flake follow-up; no helper/app/retry-policy change was integrated to obtain this pass.

**Native attempt1 remains failed:** iPhone1 **117269822733**: 29 executed, 12 passed, **17 launch/background-assertion failures**, zero skips/expected failures; normal finalization/export, 66 PNGs. [Immutable merged evidence 2e4a3be04cc93f04e820d9b8d04ead2f5d689ad3](https://github.com/josephdorseyc-boop/dinner-together/blob/2e4a3be04cc93f04e820d9b8d04ead2f5d689ad3/SUMMARY.md) still records `REQUIRED_FAILURES=2`; a successful publishing job is not a suite pass. The retry's verdict must supersede this for release.

**Diagnostic-only:** [38991670126](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38991670126), source **04e7947ba5e1169575dfa52bf25a8d57c6e5e629**, job **117275200800**: 2/2 (including original-helper test22), test/summary/attachment exits all0. Positive finalization evidence, NOT current-candidate release credit. Older parent **79aecba** native pass and cancelled/failed Duo runs remain in the previous checkpoint; never transfer their credit to this SHA.

## Pending work and owners

- **A1:** current assignment [6228530143](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6228530143): compare native retry startup with first-17 background-assertion failures; independently verify exact part counts/normal exit/readability/export and timer/landscape pixel fit; review isolated Apple checker and report concrete blockers. Preserve new test09 flake follow-up.
- **A2 interactive lead:** keep d6 unchanged while remaining parts finish; own artifact review, any evidence-based integration, all dispatches and signed1.0(22) upload. No duplicated jobs/patches from this watch.
- Test22 retry proposal and test35 stable-frame proposal remain **prepared/unintegrated**. Root-cause claims remain hypotheses; both tests have passed completed required Duo parts without these patches. Do not add speculative changes during current validation.
- A1 reports release source preflight clear ([6228023997](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6228023997)); this does NOT prove actual new `.timers` extension signing/export. Prior log-verdict promotion remains rejected; strict process/result/count/skip/export gates stay intact.
- Isolated support branch `wip/a2-build22-testflight-verification-20261016 @ e8f7d530c051f4bbc08e7b06d15726dcc7c38bb6` adds read-only checker/workflow/tests, **not integrated into d6**. Seven local checks are owner-reported. [Preflight38995789575](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38995789575), job117287948650, completed successfully: log confirms **1.0(21), VALID, IN_BETA_TESTING, ready=true**. This verifies the read integration for **Build21 only**, not Build22 upload/processing/availability. No mutation or release was initiated by this watch.
- Preserve edit eligibility/save rollback/readiness, stable timer identities/deadlines, activity/alarm retry/revocation and route/draft continuity review. Missing fresh evidence is not missing implementation.

## Design, visuals and real-device boundary

- Boards **02/03 approved** in [6215903573](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6215903573), design commit **3db56d9810d0e1fc9ff032e81f648f5d39f1d279**. README's pending wording is superseded. **Full-screen tent AND nightstand remain mandatory**, not inset Live Activity substitutes.
- Preserve native navigation/accessibility, cream fallback, glass/timer continuity and save/readiness safeguards. No Add a step/global Timing Save/new timer-store cap.
- A2 reports completed Duo night timer capture fits/readable and artifact hashes checked ([6228576967](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6228576967)). This watch verified textual evidence, **did not independently perform pixel/VoiceOver review**. Screenshot counts are not blanket fit proof.
- **Real-device verification absent.** Joe's physical Duo arrives **December**, not October23 ([6222487023](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6222487023)). Closed/default-hinge Duo explicitly excludes rotation-only tests53/57; automatic=UNVERIFIED, landscape=UNVERIFIED, dismissal-reentry=UNVERIFIED. Ordinary-iPhone test57 remains required. Physical tent/cover pose, charging/unplug/locked StandBy, silent/Focus delivery, Lock Screen Stop and continuity remain open.

## Release and next observation

- Joe's target is **Build22 in TestFlight tonight, October16**, using **Xcode27.1**. Latest lead posts retain `require_green=true`; no toolchain26 fallback was adopted. Both exact-candidate workflows must finish green.
- **No Build22 release dispatch/upload established.** Latest100 runs contain only prior release **38845842034**, Build21, source **cb0e397**; main unchanged. Prepared release form is not a dispatch. Build22 archive/export signing, Apple processing and tester availability remain unproven.
- Next: two 27.1 ordinary-iPhone verdicts + native iPhone1 retry/merged publication, then the interactive lead's release decision. No ETA inferred from running jobs.
- **Material milestone for Joe:** all three required closed-Duo gates now cleared, transparently including one strict isolated retry. Overall validation and TestFlight upload remain pending.
