# Build 22 contingency handoff — A2 backup

> **Current status:** see [A2-build22-current-checkpoint.md](A2-build22-current-checkpoint.md), reconciled October 16 at 14:27 UTC. It supersedes historical head/approval/run observations below. Current source is 928660b; boards 02/03 and Joe-relayed patches are implemented, current-head native/Duo verification is pending, and a newly reproduced screenshot-probe false-negative hazard needs A3/A1 review. The older P1 alarm-cancellation finding is now addressed in source, not yet native/device-verified.

Prepared October 16, 2026, at Joe's request. Backup preparation only: A3 remains implementation/integration/release lead; A1 owns test review and investigation. No takeover or release has been initiated.

## Verified starting points
- Repository: josephdorseyc-boop/dinner-together.
- Active implementation branch at this check: `wip/build22`, `e879b35fa55b15cee85c887a87f7cd60f4972cfe`.
- Last released Build 21 app baseline: `cb0e397`; A3 reported upload run 38845842034.
- Latest reported green Build 22 native baseline: `a6f827a`, run 38866184863 (239 unit tests; 27 + 26 iPhone UI; 26 iPad UI; one AX3 retry). This does NOT automatically validate later commits.
- A2 design branch: `a2/build22-design-boards-20261016`, commit `3db56d9810d0e1fc9ff032e81f648f5d39f1d279`.
- Design index: `docs/design/build22-proposals-2026-10-16/README.md` on that branch.
- Current task/ownership directive: issue #24 comment 6214907671. Consolidated A2 findings/boards: comment 6215323419. Simulator investigation: issue #15.
- These are timestamped observations. Refresh branch heads and issue notes before implementation; do not start from a stale local checkout.

## Source map
| Responsibility | Files |
| --- | --- |
| App wiring / foreground reconciliation / routes | DinnerTogetherApp.swift, ContentView.swift |
| Session actions, progress, undo, persistence | SessionStore.swift, Models.swift |
| Whole-meal IDs / compatibility / max four recipes | Models.swift (WholeMeal, recipe/pair/meal identifiers), DinnerCatalog.swift |
| Scheduling, feasibility, actual starts | Scheduling.swift |
| Recipe storage, rollback, step edits, imports | RecipeLibrary.swift, RecipeImporter.swift, SocialImport.swift, SharedInbox.swift |
| Recipe reader and Timing editor | RecipeViews.swift, RecipePageStyle.swift, RecipePalette.swift |
| Cooking / shared ring faces | CookingView.swift, KitchenTimerViews.swift, TimerCenter.swift |
| Independent Directions timers / notifications | QuickTimers.swift, Notifications.swift |
| Alarm authorization / stable alarm IDs / scheduling | SystemAlarms.swift, TimerAlarm.swift |
| Live Activity state / widget surfaces | LiveDinnerTimers.swift, DinnerTimersActivity.swift, DinnerTimers/DinnerTimersWidget.swift |
| Window layout / reader spread / week | Spread.swift, SpreadViews.swift, WeekPlan.swift, WeekPlanViews.swift, WeekShowcaseView.swift |
| Simulator geometry / scroll helper | UITestSceneGeometry.swift, ScrollGeometry.swift, DinnerTogetherUITests/UITestSupport.swift |
| File registration / app and extensions | DinnerTogether.xcodeproj/project.pbxproj |

Paths in the source map are under DinnerTogether/ unless an explicit other directory is shown.

## State boundaries to preserve
- SessionStore owns plan progress and actual step records; independent kitchen timers live in QuickTimerStore. A timer ending is attention, never automatic completion.
- QuickTimerStore reminders use their own namespace. Changing a dinner or refreshing plan notifications must preserve independent reminders and original deadlines (cb0e397).
- Whole-meal membership edits differ from simply reading another recipe. Preserve each reader's tab/position, running timers and chosen serving time across orientation/route changes.
- During cooking, only not-started steps can be edited. Recheck at the mutation/save boundary. Stable step IDs preserve actual starts, done records and timer deadlines. Failed persistence rolls back; unresolved Directions matching is refused.
- A later readiness estimate uses the existing notice/review action; never silently move dinner time.
- Live Activity request failure and authorization changes must remain retryable without duplicate activities. A1 owns the injectable seam/regression work; do not duplicate it without reconciling branches first.

## What remains
1. FULL-SCREEN timers in BOTH tent mode AND nightstand mode: Joe's explicit requirement. A small inset Live Activity alone does not satisfy it. Confirm a dedicated full-usable-screen app presentation if the system-owned surface cannot provide it. Entry/exit, safe areas, idle lock, orientation, every timer's controls and preservation of prior route/deadlines require verification.
2. Board 01 alarm/system countdown surfaces; board 02 compact Timing control arrangement; board 03 warmer Duo Cooking. The NEW board compositions still await Joe's visual approval. Existing approved photo-left/reader-right and side-left/main-right layouts remain the basis.
3. A1: recurring Duo part-2 pre-test hang investigation; new-test intent review; unmatched wording edit refusal test; mid-cook edit reflected in Cooking while started step stays fixed; Live Activity retry seam + test; plain-language device checklist.
4. Capture/validate Timing wording editor and running/completed locked states; full-screen tent/nightstand; one/two dishes in wide and upright windows.
5. No Add a step feature unless Joe approves. Four visible timer slots in a board is not a new timer-store cap.

## Takeover sequence
1. Read latest #24/#15 comments and A3/A1 branch heads; record exact SHA, open work and running workflows. Ask for any unpushed changes if A3 is reachable.
2. Create an isolated worktree/branch from the latest implementation head. Preserve other agents' work. Do not reset, overwrite, force-push or merge stale support branches.
3. Reconcile A1's delivered patches and A2's design approvals; choose one owner per remaining item and report the current integration baseline.
4. Implement a focused change; register new Swift files in all required targets and Package.swift only when their code belongs in that harness. Widget types shared by app/extension must stay consistent.
5. Run appropriate local checks, then native GitHub validation on the exact candidate SHA. Examine per-part status, expected/executed counts and screenshots, rather than relying on a headline green.
6. Publish implementation/evidence links in #24. Preserve A3's release checks. Treat implementation, native pass, visual fit and real-device behavior as separate claims.

## Validation and build routes
- Engine harness: `swift test` (real source list in Package.swift; excludes SwiftUI/ActivityKit/AlarmKit production UI). `engine-quick.yml` runs it on Linux for wip/** pushes.
- Supplemental checks: `node logic-checks/mirror-test.cjs`; `node logic-checks/reconciliation-test.cjs`; `bash native-validation/dry-run/run.sh`; `bash release/dry-run.sh`. Dry runs test harness control flow, not app/device behavior.
- Native: `.github/workflows/native-validation.yml`, four macOS parts (core, two iPhone UI halves, iPad UI), normally Xcode 26.2. On wip/** branches dispatch explicitly; the workflow excludes those push triggers.
- Native entry points on a Mac: `bash native-validation/run-native-pass.sh` then the relevant screenshot script; respect DT_PART and the workflow environment.
- Duo/new toolchain: `.github/workflows/duo-validation.yml`, Xcode 27.1 runner; duo_only, window, window_only inputs; hinge-flat opened-window probe. The window job is continue-on-error, so overall green does not prove it passed.
- A3 reported the a6f827a Duo opened-window pass as 2/2. Recurring pre-test runner hang and other simulator failures remain unresolved. Source-only investigation is not a reproduced diagnosis.
- Review results on ci-results, ci-results-linux and ci-results-duo-* branches. These can be overwritten: record RUN.txt provenance/source SHA/run and preserve evidence links. Screenshots must correspond to the claimed commit.

## Release route and limits
- release.yml is manual. Keep require_green=true. It checks native-validation for the exact commit; toolchain=27 also checks duo-validation for that same commit.
- Workflow default is toolchain=26; do not leave that choice unexamined when the release requires the newer SDK's Duo behavior.
- release/build-release.sh archives unsigned then signs during export through the existing CI setup. Existing secrets are referenced by name only; no keys copied into the repo, chat or runbook.
- App, share extension and the new timers widget extension must have correct related bundle IDs, provisioning and embedded target setup. Test the actual archive/export; a Debug simulator build does not prove extension signing.
- submit=true uploads to App Store Connect/TestFlight; this runbook does not initiate an upload or public release.
- A3's stated target was RC Tuesday October 20 / TestFlight Wednesday October 21. Joe moved BOARD delivery to today, October 16; that does not independently approve a changed release schedule.
- This environment can read/publish GitHub content. Native Xcode, Swift CLI and gh were not installed locally at this check. Local code work is possible; native compilation, signing and simulator execution require the existing remote macOS workflows. Workflow dispatch and signing access must be rechecked when needed; they were not exercised by this preparation.
- Joe subsequently authorized a recurring GitHub handoff watch. Its observations go in the current docs-only checkpoint; it does not initiate takeover, CI dispatch or release. If Joe requests a takeover, resume with the latest source and available access.

## Handoff hygiene for A3
Please keep unfinished implementation in a pushed WIP commit/branch and leave #24 a short checkpoint: head SHA, in-progress files, running run IDs, next action, blockers and release status. This protects against a usage cutoff leaving unseen local work. A2 can continue from the checkpoint if needed; A3 remains lead until a handoff.
