# Build 22 — current A2 handoff checkpoint

Observed **2026-10-16 13:51 UTC / 07:51 Denver**. This checkpoint supersedes the changing status/approval sections of the original [contingency runbook](A2-build22-contingency-2026-10-16.md); its architecture and takeover procedure remain useful. Refresh GitHub before acting.

## Ownership and source

- **A3 remains implementation, integration and release lead.** No explicit handoff or unavailability announcement in the latest #24/#15 comments. Silence is not evidence of either.
- **A1 owns assigned testing:** simulator startup mitigation verification, test18/r31 intent and behavior, unmatched edit refusal, mid-cook Cooking timeline, Live Activity retry seam, alarm error injection, and the plain-language October 23 device checklist. Delivery of the pending regression branches/checklist is not established by the current comments.
- **A2:** source/evidence review and this docs-only backup checkpoint. No active-branch pushes, duplicate patch, CI dispatch/rerun, release-setting change, takeover or release in this check.
- Current implementation: `wip/build22` at **73a4aeb8d9ee9a23b6fc45e2e11a6c465c218bac**, committed 13:19:08 UTC. No explicitly announced successor. Five commits ahead of the original runbook's e879b35 baseline.
- Latest reviewed coordination: [#24 comment 6216698396](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6216698396) and [#15 comment 6216360789](https://github.com/josephdorseyc-boop/dinner-together/issues/15#issuecomment-6216360789), plus the new finding below.

## Implemented in source; validation is separate

| Commit | Change |
| --- | --- |
| cfa7747b3734109fedb949efb5ddf9f34c14ba01 | Dedicated full-screen timers; manual entry, tent/nightstand activation, idle-lock handling, r31/test55; simulator preflight/start deadline and verbose retry. |
| ae04df3cfc5ae542b272eb755c0de92f40c06ded | Back to Cooking guidance; running/completed Timing rows show lock note/time without edit controls. |
| e273cdd3f498061406bd0f1ca3f36c5b0d1c2168 | Bash 3.2 empty-array failure fixed with scalar verbose flag. Supersedes A2's duplicate harness candidate. |
| ebb84d4fc95f5622342673be199960bc0637dbb3 | Approved board 02 layout; per-reminder alarm coverage/notification fallback and cancellation tombstones. **New cancellation edge case remains open below.** |
| 73a4aeb8d9ee9a23b6fc45e2e11a6c465c218bac | Approved board 03 styling pass: countdown ring, amber overlap note, cream no-photo page. Existing glass card remains fixed-position in Build 22. |

## Approvals and full-screen requirement

Boards **02 and 03 are approved**, superseding old “awaiting approval” text in the board README and original runbook: [Joe's approval, #24/6215903573](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6215903573). Exact board source is `3db56d9810d0e1fc9ff032e81f648f5d39f1d279`, [design directory](https://github.com/josephdorseyc-boop/dinner-together/tree/3db56d9810d0e1fc9ff032e81f648f5d39f1d279/docs/design/build22-proposals-2026-10-16).

Joe explicitly requires **full-screen timers in BOTH tent and nightstand modes**. App presentation and system-owned locked/StandBy behavior are separate verification targets. A3's [implementation plan](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6215478391) uses sideways-window geometry for tent; charging plus landscape for nightstand; manual Full screen also remains available. Real cover rotation/pose activation is unverified. Alarm “Open” is deferred; no new Add a step/global Timing Save scope. Keep existing navigation, independent readers, timers and deadlines intact.

## Exact-SHA validation evidence

All run links are under this repository's /actions/runs/. Job detail was read; top-level queued status can coexist with running jobs.

| Source SHA | Run | Evidence at observation |
| --- | --- | --- |
| 73a4aeb8d9ee9a23b6fc45e2e11a6c465c218bac | [38906937222](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38906937222) | engine-quick successful. Job 116992744936 log confirms **228/228 Linux tests**, zero failures; does not exercise production AlarmKit/SwiftUI. |
| Same current SHA | [38906946003](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38906946003) | Native run API says queued; core job 116992782498 running, three UI jobs queued. Linux and JS/model/harness/release dry-run jobs passed. **No complete native pass for current head.** |
| e273cdd3f498061406bd0f1ca3f36c5b0d1c2168 | [38906195142](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38906195142) | Native in progress: core/Linux/JS successful; iPhone/iPad UI running. Excludes later board/alarm changes. |
| Same e273cdd SHA | [38906198562](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38906198562) | Duo API says queued; part 2 running, parts 1/3 queued. No result yet and not current head. |
| e879b35fa55b15cee85c887a87f7cd60f4972cfe | [38893459669](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38893459669) | Latest fully green native baseline in branch-run history: all required job gates successful. A3 reports 239 unit, 27+27 iPhone UI and 26 iPad UI. Predates full-screen/approved-layout implementation. |
| ae04df3cfc5ae542b272eb755c0de92f40c06ded | [38902136833](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38902136833), [38902140492](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38902140492) | Native/Duo failed; Bash unbound-array blocker diagnosed and source-fixed in e273cdd. ae04 native core passed; this is not a UI pass. |

**Captures:** A3's r30 evidence comes from e879b35/run 38893459669, screenshot commit `0e6ccb805aff0a0a51c0c2dd9d8dd5d3fc7117f4` ([comment](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6215712456)). It cannot validate current approved layouts. r31/current-layout capture review remains pending. A3 notes r31 skips nightstand on iPad and softens landscape on Duo; a pass alone cannot prove actual cover rotation.

**Real device:** no new device evidence. Tent activation, locked StandBy/Live Activity fit, silent/Focus alarm delivery and Lock Screen Stop remain hardware checks. Simulator/native compile, Linux tests and fake-toolchain dry runs are distinct evidence levels.

## Open findings and next owners

1. **NEW P1 — stale alarm coverage after cancellation retry**, [#24/6216958837](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6216958837). Current SystemAlarms.swift: existing key at old deadline; wanted deadline changes; first cancel throws; end-of-pass retry succeeds. The real alarm is cancelled, but scheduled[key] remains old and is returned as covered. Notification fallback and foreground chime can both be suppressed. A fake-manager control-flow trace with outcomes [throw, success] confirmed this bookkeeping result; **not native/device reproduced**. A3 fixes, A1 verifies injected failures. Do not mark alarm findings fully closed.
2. **Go to Cooking over Timers sheet**, [#24/6216359507](https://github.com/josephdorseyc-boop/dinner-together/issues/24#issuecomment-6216359507). Still pending review/integration at current head. Dismiss the known Timers sheet without blanket-dismissal of unsaved editors; ordinary Done preserves underlying route.
3. **Release-only safeguard candidate**, `wip/a2-build22-release-gate-20261016`, commit `045c58c815729b66cc067ab757a7ccb0c4c79e3c`. Seven fake-toolchain cases reportedly passed, including bad archive + upload requested => no export/upload. Current release/build-release.sh still lacks this post-metadata failure guard. A3 owns integration. **Do not cherry-pick combined b786816 harness patch**; A3 already fixed it.
4. **Simulator/runtime infrastructure:** A1 retains mitigation/test18 review. A3 owns verifying 27.1 runtime availability before retry ([#15/6216351072](https://github.com/josephdorseyc-boop/dinner-together/issues/15#issuecomment-6216351072)). Prior #38 failures include unreadable result bundle/export and failure to terminate prior app, separate from new code findings.

## Release and handoff status

Latest release workflow in the 60 recent repository runs is successful [38845842034](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38845842034), source `cb0e3973fca5a03fd5faa5e0487bfd45cd11f3f3`; A3 reported this as Build 21 upload. This does not establish Apple's processing or tester availability. **No Build 22 release observed.** New widget distribution signing/archive/export remains unverified here. Keep require_green=true and exact-candidate native/Duo checks; do not treat another SHA's green as release clearance.

No takeover initiated. If explicitly handed off, start from fresh A3/A1 heads and reconcile unpushed work and these pending findings before implementing. The original runbook's October 20 RC / October 21 TestFlight targets are historical plans, not current completion evidence.
