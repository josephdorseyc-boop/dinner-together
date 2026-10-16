# A2 agent-assisted Build 22 review — October 16, 2026
Requested by Joe: investigate bugs/hangups with agents, without overlapping A3/A1 work.
Review baseline: ae04df3cfc5ae542b272eb755c0de92f40c06ded.
A3 retains implementation/integration; A1 retains simulator-hang and assigned regression ownership. Three disjoint read-only reviews covered timer lifecycle, alarm runtime, and widget/release packaging. A2 independently triaged current CI and verified the candidate changes.

## Candidate fixes in this support branch
### 1. Current UI validation blocker — optional flag under macOS Bash (P1)
Native run 38902136833, job 116976721195, and Duo run 38902140492, job 116976728187, both contain:
`native-validation/run-native-pass.sh: line 367: verbose[@]: unbound variable`.
Both stop before running the UI test command; missing status.txt and an unfinished XCUITest summary follow. This is distinct from the original simulator no-start hang.
- Source: run-native-pass.sh, optional empty verbose array in run_ui_tests.
- Candidate replaces only that optional one-argument array with an initialized scalar and quoted conditional expansion. Zero arguments on the first attempt; exactly -verbose on retry. No changes to retry eligibility, deadlines, counts, evidence or verdict gates.
- Independent review approved the argument behavior. Bash syntax and diff whitespace checks passed.
- All 23 existing native harness dry-run scenarios passed on Linux. These use a fake toolchain, not Xcode.
- Optional-argument probes passed under available Bash 5.2 (including compatibility/POSIX settings) and dash in the independent review. A native Bash 3.2 binary is unavailable locally; real macOS rerun still required.

Evidence:
- https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38902136833/job/116976721195
- https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38902140492/job/116976728187

### 2. Release metadata failures do not stop export/upload (P2)
Source: release/build-release.sh metadata checks at baseline lines 104–122 report fail, then export/upload continues at 147–167 before finish returns nonzero.
- Candidate stops with finish immediately after failed archive metadata/compliance validation.
- release/dry-run.sh adds a bad-archive fixture (wrong version and missing compliance value) with upload requested. It asserts the mismatch is reported, no IPA/export/upload log exists, and private-key cleanup occurs.
- All seven release dry-run scenarios passed. The agent's negative regression check with the guard temporarily removed failed as intended: export/upload occurred for the rejected archive. Guard restored.
- A2 also reran all seven checks after integrating the isolated release candidate. No signing/upload or remote workflow was performed.

## Source findings for A3's active runtime work — not patched here
### 3. Alarm scheduling failure can leave a timer without an alert (P1)
Source: SystemAlarms.swift baseline 86–94 swallows schedule errors; Notifications.swift 136–147 removes local requests and returns success based on authorization; TimerAlarm.swift 66–68 suppresses foreground ringing on the same permission bit.
Sequence: authorized AlarmKit -> schedule throws -> notification fallback removed -> foreground chime suppressed -> no status error.
Suggested fix: track confirmed per-reminder alarm coverage, return scheduling outcomes, retain/create local fallback for failed IDs, suppress foreground ringing only for successfully covered timers, and report failure when neither path succeeds. Retry without requiring a user timer edit.
This is a source-proven error path; no native failure injection was run.

### 4. Failed alarm cancellation/initial cleanup is forgotten (P2)
Source: SystemAlarms.swift 76–84 sets checkedSystemList before enumeration succeeds and drops scheduled[key] after try? cancel regardless of success.
Sequence: schedule timer -> stop/remove it -> cancellation throws -> app drops cache/timer -> subsequent reconcile has no cancellation work to retry, leaving an obsolete system alarm possible.
Suggested fix: retain cancellation tombstones/cache until confirmed; retry failed enumeration/orphan cleanup; report persistent failures.
Source-proven error path, not a device reproduction.

### 5. Go to Cooking leaves the underlying Timers sheet open (P2)
Source: FullScreenTimers.swift 203–205 dismisses only the full-screen host; 454–455 closes then calls openCooking. ContentView.swift 156 only assigns destination=.cooking. KitchenTimerViews.swift 96 still presents its sheet.
Bounded repro: already on Cooking, run a step timer and independent kitchen timer -> View timers -> Full screen -> select the step timer -> Go to Cooking. Since Cooking is already selected, that assignment cannot dismiss the underlying Timers sheet.
Suggested fix: coordinate dismissal of the known Timers sheet on this route, then navigate after full-screen dismissal. Ordinary Done must still return to the previous screen. Do not globally dismiss unrelated/unsaved recipe editors.
Needs native regression verifying route, progress and all deadlines unchanged.

## New widget packaging review
No confirmed new target/membership/plist blocker was found. DinnerTimers dependency/embed phases, shared ActivityAttributes target membership, bundle suffix/version overrides and required plist setup were checked at source level. Distribution signing/provisioning of the new .timers extension still requires a real archive/export; no portal failure is claimed.

## Integration and ownership
- Candidate code touches only native-validation/run-native-pass.sh, release/build-release.sh and release/dry-run.sh.
- No production Swift, Xcode project, tests owned by A1, or active A3 branch was changed.
- A3 should integrate the bounded script fixes and rerun native/Duo validation on the resulting exact commit, preserving expected/executed test gates.
- A3 owns alarm fallback/cancel and full-screen navigation changes unless a specific file handoff is agreed. A1's existing Live Activity retry seam/test is distinct from alarm coverage failure.
- Source review, fake-toolchain checks, real native tests and device behavior remain separate evidence levels.

