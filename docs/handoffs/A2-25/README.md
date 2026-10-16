# A2-25 — parallel failure investigation

October 13, 2026. Joe requested three parallel investigators. A2 cross-checked the original CI recordings/events and current parser branches. These are findings and validation requests, not app-source changes.

| Priority / evidence | Finding | Owner and next action |
|---|---|---|
| S2 / source review + supplemental Python check | A duplicate navigation/body STEP marker creates competing heads; longest-title selection can replace “Set aside.” | A3: separate metadata/navigation/body roles. A1: execute the A2-26 Swift fixture and record actual Vision output. Import report is on PR #16. |
| S3 validation / simulator rendering + event check | Run 38399682685's Undo-labelled tap lands on Completed after geometry shifts | A1: stabilize and reacquire the target before tapping; keep seeded-time assertion. A3: use that trace before changing store logic. |
| S3 validation / simulator rendering + event check | Apple News positioning gesture activates Choose screenshots, opening Photos | A1: scroll over noninteractive content and recheck the actual sheet after positioning. A3: inspect r06 even if replacement CI goes green. |
| Source constraint + supplemental patch-applicability check | A2-24 applies to share-extension 9a08174e, not build12 32f8fa06 | A3: integrate on declared baseline or adapt the remaining delta. |
| Source risk, unexecuted | Shared destination/path does not retain view-local drafts/sheets during layout replacement | A1: test reader subtab and unsaved Add/crop/duration edits across resizing. S3 for tab reset; S1 only if unsaved-data loss is reproduced. |

Read [CI-TRIAGE.md](CI-TRIAGE.md) and [UI-INTEGRATION-AUDIT.md](UI-INTEGRATION-AUDIT.md). The matching import trace and minimal Swift fixture are in `docs/handoffs/A2-26/` on the PR #16 branch.

CI baseline: c83788c9c1491c19742880541b86fea11db5a97f, run [38399682685](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38399682685), artifact `ui-review-evidence-38399682685` (id 11822431146). XCTest 161/161 per device; iPhone UI 32/34; iPad UI 17/17. Replacement run 38412070798 / 32f8fa06 was still in progress when reported.

No competing app/harness patch or additional CI run was created. Current importer baseline was independently rechecked at main 2cbc9e73. This review does not certify physical-device behavior or Duo compatibility.
