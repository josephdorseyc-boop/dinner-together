# Build 22 — current A2 handoff checkpoint

Observed **2026-10-17 08:37 UTC / October 17, 02:37 Denver**. Release evidence below was checked at the prior 04:01 UTC observation. Refresh GitHub before acting. Supersedes the historical [backup runbook](A2-build22-contingency-2026-10-16.md); [previous checkpoint](https://github.com/josephdorseyc-boop/dinner-together/blob/2d042bdd1c7f54ea50c3f73395e17c09f0b121d4/docs/handoffs/A2-build22-current-checkpoint.md) retains detailed source, earlier failures and rejected proposals.

## Post-release timer correction and Joe's approval

- **October17, 02:43 Denver:** Joe explicitly requested “Start build23.” Full required Xcode27.1/Duo validation was dispatched and GitHub confirmed [run39019047696](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/39019047696) on exact **2668151e48820ded84454797acadfc40e082d9a8**; all seven required jobs are present (four ios27 + three Duo). Native39017692737 remains in progress. No duplicate native run or release workflow was dispatched. Signed1.0(23) archive/upload remains pending successful exact-SHA gates and visual verification.

- **October 17, 02:37 Denver:** Joe approved the revised three-view cream timer concept board shown in conversation: Lock Screen card, full-screen single timer, and full-screen multiple timers. Palette: solid cream #FAF6ED, olive rings, dark text, restrained terracotta leaf. The revised Lock Screen mockup raises the card closer to the clock. Exact system-owned Lock Screen placement remains a visual target requiring platform verification, not a verified app-controlled change.
- **Current continuation head: 2668151e48820ded84454797acadfc40e082d9a8**, directly atop released d6aaaaa. [Correction commit](https://github.com/josephdorseyc-boop/dinner-together/commit/2668151e48820ded84454797acadfc40e082d9a8) adds an explicit opaque cream background to LockScreenTimers in DinnerTimers/DinnerTimersWidget.swift. Existing system background tint and olive/dark palette remain. Only this file changed; source reread and diff verified.
- **Implemented, not native-verified yet:** [native-validation39017692737](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/39017692737) is IN PROGRESS on exact 2668151. No Xcode27.1/Duo result, Lock Screen pixel verification or physical-device verification is established for this successor. The screenshot Joe supplied is real-device evidence that released Build22's card appears yellow; no corrected on-device capture exists yet.
- The correction is assigned to **Build23**, per Joe's follow-up; no Build23 archive/upload is established. Build22 remains released source d6aaaaa. Do not transfer its green results to 2668151.
- Mockups express approved visual direction; ring animation, timer controls and system placement still require implementation/evidence reconciliation. No additional runtime changes, CI dispatch or release were performed while recording this approval.

## Ownership and watch boundaries

- A3 remains the default implementation/integration lead. Joe's **explicit temporary handoff** to A2 is recorded in [#24/6221940209](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6221940209) and [#15/6221940484](https://github.com/josephdorseyc-boop/dinner-together/issues/15#issuecomment-6221940484), not inferred from silence.
- A2's interactive lead window ends **October 17, 22:00 Denver / October 18, 04:00 UTC**, then A3 resumes ([6222060301](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6222060301)). A1 retains assigned independent testing. The interactive lead owns integration/dispatch/upload.
- **This watch is docs-only:** no active-branch edits, duplicate patches, CI dispatch/rerun/cancellation, release-setting changes, takeover or release.
- Read all **111 comments in #24 / 56 in #15**. Latest #24 [6229153849](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6229153849), 03:40:10 UTC, says release succeeded and no additional dispatch is needed. #15 remains unchanged since handoff.

## Source and implemented scope

| Ref | Exact SHA | State |
| --- | --- | --- |
| `a2/build22-lead-20261016` | **2668151e48820ded84454797acadfc40e082d9a8** | Post-release cream correction for Build23; native validation pending. |
| Released Build22 source | **d6aaaaabd22a6674dc90d018b47c0018d62d9fdd** | Validated and uploaded as 1.0 (22). |
| `wip/build22` | **4ae4f31c851ae9b496aea0ec915a7c8c1c7c6667** | A3 handoff baseline, unchanged. |
| `main` | **cb0e3973fca5a03fd5faa5e0487bfd45cd11f3f3** | Still Build 21; not the Build 22 release source. |

[Compare](https://github.com/josephdorseyc-boop/dinner-together/compare/4ae4f31c851ae9b496aea0ec915a7c8c1c7c6667...d6aaaaabd22a6674dc90d018b47c0018d62d9fdd) independently confirms **nine commits ahead, zero behind**, merge base exactly A3's baseline. Follow-ups: capture orientation/provenance, fail-closed selection, caption normalization/regression registration, manual/automatic test separation, consistent 300-second finalization, app-local UserDefaults CA92.1 privacy declaration, and optional diagnostic collection.

**Implemented:** A3's full-screen tent/nightstand, boards 02/03 Timing/Cooking, alarms/fallbacks and Live Activity reliability work are retained. Caption correction applies on re-import; live Instagram extraction remains unverified. Broader import overhaul belongs to Build 23 / #25.

**Locally checked (owner-reported):** latest one-file d6 change passed 25 harness scenarios + 31 focused checks ([6227816139](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6227816139)); published tree bc9027904f9da37722ada721a0152979cbf4b7ae. This watch independently inspected d6's diff: `-collect-test-diagnostics never` added to both primary/retry UI commands; no production Swift, assertion, selection or release-gate changes in that commit. No local/native re-execution by this watch.

## Released-SHA native verification — complete

Both workflows bind **d6aaaaabd22a6674dc90d018b47c0018d62d9fdd**. [27.1/Duo 38990012070](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38990012070) completed **SUCCESS 03:15:48 UTC**, all seven required jobs green. [Standard native 38989926720](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38989926720), attempt 2, completed **SUCCESS 03:19:22 UTC**, including merged publication. No validation remained running at the release observation; the successor run is tracked above.

| Xcode 27.1 part / job | Verdict | Immutable evidence commit |
| --- | --- | --- |
| Core 117270091706 | 247/247 XCTest, 236 macOS package tests, Release compile, 32 static PNGs | [3bc36c9af56aad9b0a9d1968f62ec2c382db7716](https://github.com/josephdorseyc-boop/dinner-together/blob/3bc36c9af56aad9b0a9d1968f62ec2c382db7716/SUMMARY.md) |
| iPad 117270091602 | 26/26, no failures/skips | [1617d836d82434a63c3485e4c7539cc523f58da7](https://github.com/josephdorseyc-boop/dinner-together/blob/1617d836d82434a63c3485e4c7539cc523f58da7/SUMMARY.md) |
| Duo 1 117270091649 | 19 executed, 18 passed; test09 strict isolated retry 1/1; manual full-screen test55 included | [2f17c3aa38ee20e63ded8bdd494204211b455507](https://github.com/josephdorseyc-boop/dinner-together/blob/2f17c3aa38ee20e63ded8bdd494204211b455507/SUMMARY.md) |
| Duo 2 117270091571 | 18/18; includes test22 and dark test56 | [6a508a0c1d3777effdfcde7af7196ab7a20922b2](https://github.com/josephdorseyc-boop/dinner-together/blob/6a508a0c1d3777effdfcde7af7196ab7a20922b2/SUMMARY.md) |
| Duo 3 117270091538 | 18/18; test35 passed without patch/retry | [57dac32b603d7d8be1c24976864f37dc2dbe2acc](https://github.com/josephdorseyc-boop/dinner-together/blob/57dac32b603d7d8be1c24976864f37dc2dbe2acc/SUMMARY.md) |
| Ordinary iPhone 1 117270091562 | Clean 29/29, exit0, no skips/expected failures; includes strict tests53/57 | [72714c6b169662af69515581f8a7ac022d040203](https://github.com/josephdorseyc-boop/dinner-together/blob/72714c6b169662af69515581f8a7ac022d040203/SUMMARY.md) |
| Ordinary iPhone 2 117270091445 | 28 executed, 27 passed; test25 launch failure, then strict isolated retry 1/1 exit0 | [02f03d0eb1aacb3c83a8942d3dd76946646e69fc](https://github.com/josephdorseyc-boop/dinner-together/blob/02f03d0eb1aacb3c83a8942d3dd76946646e69fc/SUMMARY.md) |

New ordinary-iPhone RUN.txt/xcresult JSON/status files independently read: exact source/run/toolchain, correct counts, zero final required failures. All seven job Gate steps and attachment exports succeeded. **Not a clean first-pass matrix:** preserve Duo test09 snapshot flake and ordinary-iPhone test25 launch flake.

Standard native retry job **117280934137** passed **29/29**, zero failures/skips/expected failures; fresh-runner execution supersedes attempt1's first-17 background-assertion failures for release, not for root-cause history. Other successful jobs were retained from attempt1, not rerun. [Immutable merged evidence ae7704b47e002eed2a951c155e708b0609356f9b](https://github.com/josephdorseyc-boop/dinner-together/blob/ae7704b47e002eed2a951c155e708b0609356f9b/SUMMARY.md): core247/247 + package236; ordinary iPhone29+28; iPad26. RUN.txt and retry JSON independently read.

The diagnostics workaround now has complete required-matrix evidence, not a claim of universal simulator stability. Old failed/cancelled/diagnostic runs receive no release credit.

## Release and Apple availability — verified

- [Release38998377752](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38998377752), run **22**, exact source **d6aaaaa**, completed **SUCCESS 03:26:47 UTC / October16 21:26:47 Denver**. Archive/export/upload succeeded with **Xcode27.1**, version **1.0(22)**. [Immutable release results d5991ee8afc5721a3554945b669e89ba8842fb6e](https://github.com/josephdorseyc-boop/dinner-together/blob/d5991ee8afc5721a3554945b669e89ba8842fb6e/run-22/SUMMARY.md); RUN.txt independently binds source/run/version/submit=true.
- A1 independently confirmed upload in [6229138632](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6229138632). Interactive owner reports exported app + both extensions all1.0(22), iOS27.1 SDK; this watch did not independently re-extract the IPA.
- [Read-only Apple status38999577886](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38999577886), job **117299459636**, checked **03:38:54 UTC / October16 21:38:54 Denver**. Log independently read: **Build1.0(22): VALID; internal=IN_BETA_TESTING; ready=true**. [Artifact12088023296](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38999577886/artifacts/12088023296), digest **8486aff61ac9fe342604c16b277a75a07b912dbdef4ba60c51267efb5c34b77c**.
- Checker ran from isolated **e8f7d530c051f4bbc08e7b06d15726dcc7c38bb6**, NOT the released app source; it reports Apple build state, not app/native correctness. Earlier checker38995789575 was Build21 only.
- **Internal TestFlight availability established; no public App Store release or real-device test established.** Joe already received this milestone and upload confirmation; do not duplicate the notification.

## Design and remaining owners

- Boards **02/03 approved** in [6215903573](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6215903573), design commit **3db56d9810d0e1fc9ff032e81f648f5d39f1d279**; supersedes README's pending wording. **Full-screen tent AND nightstand required**, not inset-card substitutes.
- Preserve native navigation/accessibility, cream fallback, stable timer identities/deadlines, route/draft continuity, edit eligibility/save rollback/readiness and alarm/activity retry/revocation safeguards. No Add a step/global Timing Save/new timer-store cap.
- **A1:** retain test09/test25/startup flake investigation, independent exact-result/export and pixel review, and December hardware checklist. Test22/test35 proposals remain prepared but unintegrated; passing required cases do not prove the proposed root causes. iOS27 xcresults also contain Environment<Bool> default-value warnings; diagnostic only, no new causal blocker established.
- **A2 interactive lead:** preserve released source and current evidence; prepare explicit handback before the ownership deadline. Old source-embedded lead checkpoint contains historical pending claims; this timestamped checkpoint and immutable results supersede them. No automatic main advance or further release is authorized by this watch.
- **Visual boundary:** owner reports readable, fitting full-screen dark Duo capture and landscape review ([6228576967](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6228576967)); this watch did not independently perform pixel/VoiceOver review. Counts alone do not prove complete visual fit.
- **Real-device verified: NONE recorded.** Physical Duo arrives **December**, not October23 ([6222487023](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6222487023)). Exact closed/default-hinge Duo excludes unsupported rotation-only53/57; automatic/landscape/dismissal-reentry remain UNVERIFIED there. Ordinary-iPhone57 passed in simulator. Physical tent/cover posture, charging/unplug/locked StandBy, silent/Focus alerts, Lock Screen Stop and timer continuity remain open.

**Next observation:** exact-2668151 validation, approved-design reconciliation or explicit handback; no new user decision at this check. Watch remains active for handback/unfinished evidence; upload was not the only watch objective.
