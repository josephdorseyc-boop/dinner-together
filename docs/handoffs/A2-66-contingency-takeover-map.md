# A2-66 — contingency takeover map
Read-only source review: October15,2026, about6:12PM Denver. Snapshot wip/duo-hinge at916c8fa0f920fd22d5d87630d8379cfa4be7acc6. This is orientation for continuity, not a takeover or release approval. Refresh refs/issues/run status before acting; A3 remains active owner.

## Where development stands
A3 reports1.0(20)released with26toolchain; Build21 work is on wip/duo-hinge, not assumed released. Whole-meal dinners, import-cover provenance/prompt, circular QuickTimer faces/strips, in-app timer chime, Duo Cooking1–2dish layouts, A2's WeekShowcaseView and new whole-meal UI tests are in current source. A2 showcase commits were acknowledged/cherry-picked and wired (issue23 comment6203569374); do not reapply them.

A3's current goal is a release candidate Saturday October17. Build22 is separate: AlarmKit/Live Activity/tent/system alarm presentation plus fuller cookbook styling. A2 design asks still queued on#24: alarm countdown/alerting surfaces and richer1dish/2dish/upright Cooking board.

## Architecture and ownership
- DinnerTogetherApp creates/injects SessionStore, RecipeLibrary, TimerCenter, QuickTimerStore, WeekPlanStore. Debug seeds precede persistence loading.
- Models.swift carries Recipe, DinnerSession, StepRecord, WholeMeal and QuickTimer value types.
- Scheduling.swift is pure planning/dependency/readiness/delay logic. Running deadlines are absolute and fixed; pending steps derive from dependencies; warnings do not magically resolve hands-on conflicts.
- SessionStore owns plan execution, undo snapshots, JSON persistence, menu/dish changes, stale recovery and plan reminders. Never reset deadlines on browsing/rotation. Menu/dish changes must obey existing progress guards.
- RecipeLibrary resolves recipe:/pair:/meal: menu IDs, persists recipes/images with rollback and owns cover provenance/editing. WholeMeal supports1–4recipes, main first, compatible with old pairs.4recipes is not a4timer cap.
- QuickTimerStore owns independent Directions timers, identity and deadlines. These do not mark cooking-plan steps done.
- TimerAlarm + TimerAlarmDriver give foreground audio/buzz/banner. Stop alarm only silences; Stop/Dismiss timer is a distinct action. Build21 background path is notification, not a promised through-Focus system alarm.
- Notifications.swift reconciles desired local reminders with async permission/run-identity guards. Shared notification ownership needs attention below.
- ContentView owns tabs/routing, phone-vs-iPad navigation, showcase entry/suppression and app-wide alarm overlay.
- PlanView/WeekPlanViews/WeekShowcaseView implement Tonight, day multi-check and photo-led7day browser. RecipeViews/SpreadViews handle reading/import/editor; CookingView owns coordinated meal guidance.
- SharedInbox/ShareExtension hand off URLs/text/images through App Group; RecipeImporter/SocialImport/ScreenshotReader handle extraction/review paths.

## Persistence
App Documents: dinner-together-v2.json(session), dinner-together-recipes-v1.json(recipes), recipe-images/(covers/plate/originals), week-plan.json, dinner-together-timers.json. Preserve compatible optional fields and source IDs; no migration/reparse of active cooking behind the user's back.

## Native layout facts and constraints
Closed cover466x678; opened native scene951x669, regular/regular. These are run-evidence observations, not assumptions for every window. Phone navigation stays tabs/native rail; iPad keeps sidebar. Spread requires800x450 and non-AX; broad book mode needs600shortside; closed upright is photo-first, closed sideways idleTonight showcase. Actual post-rail/safe-area fit still governs.
Duo XCTest app.frame/panel axes can be669x951 while scene/window/elements951x669. Use existing screenFrame/screenCoordinate helpers. Preserve raw inner-display captures alongside rotated reading exports. Vendored duo-hinge SPI tool opens the inner display headlessly; no need to rediscover failed XCUIDevice-only route.
Current approved visuals and precedence are in issues15/23/24 and A2-63/64; closed-cover12:12 amendment supersedes old cover cookbook boards. Cooking cream; Tonight owns dark/night page appearance.

## Build, test and evidence workflow
Package.swift compiles actual engine/store/import sources with a Linux SwiftUI shim. It excludes native UI/QuickTimerStore/TimerAlarm: a green Linux harness does NOT prove those compiled. Legacy README/HANDOFF version0.2.x text is historical and stale.
- engine-quick: short branch harness.
- native-validation: core +2iPhone UI shares +iPad on Xcode26.2/macOS runners.
- duo-validation: Xcode27.1/xcode-27, optional ios27 pass and3foldedDuo UI shares; window/window_only opens hinge and explicitly selects2openedDuo tests.
- ui-duo-window is continue-on-error evidence, NOT the release verdict. Inspect its individual results even when workflow is green.
- CI publishes RUN.txt/SUMMARY.md/logs/status/direct screenshots to ci-results*, including ci-results-duo-<pass>-<part>. Always match run/SHA before treating a screenshot as current.
- run-with-deadline.py bounds process/idle/suite-close hangs; fallback suite counts/direct screenshots survive unreadable xcresult. Avoid weakening assertions to obtain green.
- Current harness derives method counts; iPhone whole-meal tests48–51 and showcase53 added by A3 from A1's plan. Opened-Duo tests belong to DinnerTogetherDuoWindowTests. Follow exact identifiers/helpers, not guessed coordinates.

Snapshot run list (refresh before using):916c8fa engine-quick38827678143success; native38827686283inprogress; Duo38827688888 and38827691343queued. Prior green native38821832878 was fc104a1; prior green Duo38825327811 was ee16391. Neither proves current916c8fa, and window-only green never substitutes for ordinary coverage.

## Release path
release.yml is manual. require_green checks native-validation on EXACT SHA;27toolchain additionally checks duo-validation. Default26is proven path,27.1is needed for current Duo full-screen experience. Preserve exact-SHA/toolchain gates. release/build-release.sh archives unsigned then export signs/uploads with existing GitHub secrets. Read latest config/results instead of guessing secrets; never print credentials. This review did not access secret values or dispatch release/runs.

## Concrete source finding handed to A3/A1
Issue24 comment6205033142: QuickTimerStore shares SessionStore.notifications. SessionStore.chooseMenu/resyncNotifications calls cancelAll, then plan-only resync can remove pending quick-* reminders while timers remain visible; foreground refresh and undo can reach resync. QuickTimerStore has no restore reconciliation. Source evidence, not native reproduction. Need owner-scoped cancellation or coordinated rebuild retaining BOTH timer sources, original deadlines and stopped-state guards. Do not assume in-app ringing proves background notifications remain. A3 owns fix; A1 should cover dinner change/foreground/relaunch/undo interactions.

## Safe takeover sequence
1. Confirm A3 is paused/unavailable and obtain latest unpushed changes if any; no simultaneous edits.
2. Fetch live branch/issue comments and list active native/release jobs. Keep current worktree isolated; do not cancel/duplicate runs without need.
3. Compare pending source patches to integrated source; do not repeat A2showcase or A1plan-derived tests.
4. Fix smallest demonstrated blocker, appropriate source/native checks, preserve raw evidence and commit provenance.
5. Require actual UI/AX/notifications evidence where relevant; do not claim native execution on Linux.
6. Keep release scope21 vs22explicit. Joe already authorized routine development/team collaboration; publication/release remains governed by established task authorization and exact validation gates.

## Publication continuity
All A2handoffs/patches are on a2/duo-native-window-diagnostics-20261015; actual showcase source branch wip/a2-week-showcase-20261015 is now integrated. Earlier request to upload a complete indexed mockup package was interrupted during binary transfer; do not claim that package is complete until a reachable ref/tree and image hashes are verified. Existing approved boards are partly in A3's docs/design folders; pending work should avoid discarded extra-tab drafts and distinguish superseded closed-cover designs.

— A2
