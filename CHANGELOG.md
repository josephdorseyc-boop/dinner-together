# v0.2.6 — reviewer recommendations (2026-10-09)

Implements the reviewing agent's remaining recommendations from
FEEDBACK-v024.md on top of v0.2.5. No scheduling, notification, persistence,
or undo logic changed. Swift remains uncompiled here.

### Changed
- **Overlap warnings auto-expand.** The "N attention overlaps" disclosure
  now opens automatically when warnings appear (and when a genuinely new
  warning arrives); the cook can still collapse it, and collapsing is never
  overridden. A mid-cook hands-on overlap is no longer hidden behind a
  collapsed label.
- **Featured urgent timer gets the primary action.** When an expired timer is
  featured in RIGHT NOW, its "Mark done" button uses the primary tomato
  style — the most urgent moment in the app gets the loudest button. Other
  running timers keep the quiet control.
- **Stale-plan copy.** "N steps already underway" → "already started"
  (the count includes finished steps).

### Still Mac-gated
Build both targets, run XCTest, verify the new disclosure/button behavior on
device (including Dark Mode and VoiceOver order), real notification delivery.

# v0.2.4 — native visual refinement

- Warm light/dark palette; rounded system times and restrained serif welcome heading.
- Lighter timeline rows, one featured action, secondary timer controls, simplified copy.
- Responsive wide layout with stacked fallback at narrow widths/accessibility text sizes.
- Menu-selection and successful-completion haptics; pressed-button motion respects Reduce Motion.
- Added the missing AttentionWarning declaration and rendered early-finish notes under their heading, implementing the agent's reported v0.2.3 corrections.
- Running rows no longer show an unfinished-prerequisite label after an explicit forced start.
- Source remains uncompiled; native layout/haptics/notification delivery are unverified.

# v0.2.2 — review fixes

See HANDOFF.md for dependency, readiness, reminder reconciliation, active-session navigation, and test changes. Native execution remains unverified.

# Changelog

## v0.2.1 (2026-10-09) — corrective release

Corrects issues found in an independent review of v0.2. No new product
features. The v0.2.0 project remains in history; v0.2.1 is the canonical
implementation going forward.

### Fixed
- **Double-applied late finishes (issue 2).** The accumulated `stepShifts`
  offsets fought with serving-time moves: accepting a +7 min proposal
  re-applied the same +7. Replaced with a dependency-aware plan calculation —
  within a dish, a step never plans to start before its predecessor's
  expected completion (actual end if done, timer deadline if cooking). There
  is no stored offset left to double-apply. Regression test covers the full
  completion → proposal → acceptance flow (ends at +67, not +74).
- **Dependencies around running/completed steps (issue 3).** A pending
  dependent can no longer be scheduled before its predecessor's expected
  completion (e.g. rest no longer plans at 6:50 while cooking runs to 7:00).
  "Due by the clock" vs. "ready to start" are now distinct: blocked steps
  show their reason ("Waiting for 'Cook the steak' — ready around 7:00"),
  `startStep` refuses without an explicit "Start anyway" override, and the
  override path is one tap away in the timeline.
- **Notification safety (issue 4).** Authorization now suspends behind an
  async boundary that revalidates afterward (step still cooking? same
  deadline? no intervening undo/reset/menu change?) before any reminder is
  created. A change counter drops stale work, including stale resync tasks.
  Scheduling errors and permission changes surface explicitly as denial; the
  in-app countdown remains the source of truth. `NotificationService` is
  protocol-injected — tests simulate delayed authorization with a mock.
- **Xcode project (issue 1).** `SessionStore.init` loads from the resolved
  `self.fileURL` (was the optional parameter); `PBXContainerItemProxy`
  `containerPortal` now references the `PBXProject` (was the main group);
  app Debug enables `ENABLE_TESTABILITY` for `@testable` imports.
- **UI/state inconsistencies (issue 5).** Serving sheet labels the current
  vs. proposed dinner times separately; feasibility recomputes after duration
  edits and gates entering cooking; unselected menu previews are read-only
  (select first, then adjust); menu changes are genuinely undoable (no more
  push-then-clear); reset requires confirmation; the stale-plan sheet can't
  be swiped away and handles no-progress stale plans (re-anchors dinner);
  completing an unstarted step asks first and records "start unknown" instead
  of fabricating one; running steps show planned and actual intervals
  distinctly.
- **Validation (issue 6).** Rewrote the checks as outcome-based regression
  tests (52 assertions, 19 scenarios) mirroring the XCTest suite; the JS
  mirror is documented as supplemental logic validation only.

### Changed
- `DinnerSession.stepShifts` removed (see above). Old saves still decode;
  the key is ignored.
- `SessionStore.startStep` / `completeStep` now return `StartResult` /
  `CompleteResult` so the UI can present blocked/confirmation paths.
- Marketing version 0.2.1, build 2.

### Kept out (per scope)
Scanning, monetization, accounts, sync, shopping lists, servings scaling,
full kitchen-resource simulation — unchanged from v0.2.

## v0.2 (2026-10-09) — native rebuild

Rebuilt the native app from the ground up around explicit cooking states and
reliable timers. The v0.1 SwiftUI project and browser demos remain as reference
prototypes; this project replaces them as the primary product.

### Added
- Explicit step states: Not Started / Cooking / Done, with actual start and
  completion timestamps recorded separately from planned times.
- Timers from absolute deadlines: countdowns stay accurate across
  backgrounding and relaunch; nothing restarts silently.
- "Running late" now explains the proposed adjustment BEFORE applying it:
  what moves, what keeps its time, and which running dishes would finish too
  early (flagged — the app never invents a safe holding period).
- Late completion shifts dependent steps automatically and offers an explicit
  move/keep choice when the original serving time is no longer feasible.
- "Do this now" section, hands-on vs. hands-off distinction, live running
  timers, "Up next" summary, start–end ranges, and plain overdue messages.
- Attention warnings for overlapping hands-on tasks (informative only — the
  app doesn't claim to resolve kitchen conflicts).
- Feasibility check: serving times that require starting in the past explain
  why and offer the earliest feasible time.
- Stale plans from previous days get an explicit resume-or-start-fresh choice.
- Menu preview (dishes & steps) before choosing; per-step duration editing
  before cooking.
- Undo for every action, restoring the exact prior session including timers.
- Completed-step history with per-step correction ("Start over").
- iPad layout: sidebar navigation + two-column cooking screen.
- Local notification reminders: permission requested in context when the
  first timer starts, graceful denial, reminders cancelled/updated with the plan.
- XCTest suite covering planning, delays, late completion, undo, persistence,
  date rollover, attention warnings, and stale detection.
- Accessibility groundwork: 44pt+ touch targets, Dynamic Type-friendly type,
  VoiceOver labels, AA-passing color pairs.

### Changed
- Planned times are now DERIVED (serving time + edits + shifts) instead of
  stored per-step overrides — the plan can't drift out of sync with dinner time.
- Running steps are pinned to their actual start and timer deadline; delays
  move the plan around them.

### Kept out (per scope)
Subscriptions, payments, storefronts, corporate events, affiliates, accounts,
sync, shopping lists, servings scaling, full kitchen-resource simulation,
recipe screenshot scanning (v0.3 candidate).

## v0.1 (2026-10-09) — reference prototype
Initial SwiftUI source + browser demo: backward scheduling, completion
tracking, running-late delays, local persistence. See `../source/`.


## v0.2.5 — cooking and planning refinement

- Duration estimates open a local editor with Save, Cancel, and restoration of the catalog estimate. No mutation occurs while tapping the stepper; Save commits one undo frame. Identical effective estimates create no history or undo entry.
- Ready pending steps report lateness from their planned start after a full minute, labeled “late to start”; this appears in Right Now and timeline rows. Running timers retain their own deadline and Check now behavior.
- Reset, menu changes, and stale-plan resolution clear any pending serving-time proposal from the prior session.
- Existing scheduling/notification engines, palette, no-account offline behavior, and pinned running deadlines are retained.

Validation: 61 existing supplemental JavaScript outcome assertions and five asynchronous notification-reconciliation model scenarios pass. Three XCTest regressions were added for no-op estimates, reversible committed estimates, and proposal cleanup; not executed here. Xcode compilation, native UI rendering, VoiceOver, iPhone/iPad layout, notifications, and device testing remain pending. JavaScript checks do not execute Swift.

Next Mac review: open Dishes & timing, edit several times then Cancel (no change); Save (one undo); unchanged Save disabled; undo saved edit restores previous estimate. Set a feasible near-future dinner, wait until a ready step is one minute late, verify late-to-start copy; start it and confirm countdown uses its actual start. Verify sheet fits large Dynamic Type and landscape iPad.


## v0.2.7 — warning-panel correction

Warning observation now lives on the cooking screen rather than inside the conditional warning panel. Initial nonempty warnings expand; a newly added warning expands; removing or reordering existing warnings preserves manual collapse. Clearing every warning collapses the panel, and a subsequent warning expands it again. START_HERE.md now identifies v0.2.7; project version is 0.2.7, build 8.

Validation: reviewed the UI diff and checked transition cases with a supplemental model. Existing 61 JavaScript scheduling assertions and five asynchronous reconciliation scenarios pass. Scheme XML and archive integrity pass. No Swift compilation, XCTest execution, or native UI rendering occurred; check warning collapse/removal/addition on a Mac or device.


## v0.2.8 — out-of-order meal readiness

expectedMealEnd evaluates every planned step using actual completion for done steps, the pinned deadline for cooking steps, and derived end for pending steps. A final step marked done early no longer hides unfinished prerequisites. The supplemental model reproduces running and pending middle-step cases and confirms a later dinner proposal for the running case. Existing 61 outcome assertions still pass, plus four additional assertions (65 total); five notification-reconciliation scenarios pass.

Store policy now matches the UI: duration edits are rejected once any step has progress. Four XCTest methods were added covering running/pending out-of-order readiness, mid-cook edit rejection, and proposal cleanup for both stale-resolution choices. These tests are written, NOT executed.

Stale-plan policy is retained: explicitly resuming a plan with progress preserves serving time and actual timer deadlines; it does not silently move dinner or restart timers. A long-past serving time remains visible. A better reviewed recovery flow is a product decision for a later pass.

Native compilation, XCTest execution, simulator/device rendering, and notification delivery remain unverified. The counterpart agent's reported issue guided this fix; FEEDBACK-v027.md itself was not attached.
