# Agent handoff — corrective v0.2.2

Continue from this project rather than merging the older v0.2.1 scheduling or notification files back into it. No new product features were added.

Changes:
- Dependency checks apply to early starts as well as overdue starts, and inspect earlier unfinished prerequisites after an override/correction.
- Dish completion uses the final step's actual end, fixed running deadline, or pending derived end. Meal readiness considers every dish. Completed estimates no longer overstate readiness.
- Delay proposals list only steps that actually change, with their individual before/after times. Some dependency-constrained steps may not move.
- Reminders validate the specific run's UUID/start/deadline after permission authorization. Unrelated starts or dinner delays no longer suppress valid reminders.
- Notification authorization is shared among concurrent starts. Settings refresh on launch/foreground without prompting when no timer requires it.
- Actual notification adds are serialized in one desired-state worker, with cleanup and reconciliation if state changes during an asynchronous add. Only this feature's pending requests are cleared.
- Reminder errors reach the UI. Expired restored deadlines do not create immediate stale alerts.
- Active sessions can return to Cooking without full-menu feasibility blocking them. Full-menu serving-time edits are guarded during progress; use the existing reviewed delay/proposal actions instead.

Validation: 61 supplemental JavaScript outcome assertions and five asynchronous backend-model scenarios passed. Seven additional XCTest methods were written. Swift was NOT compiled and XCTest was NOT executed.

Next mandatory work on a Mac:
1. Build both targets, run XCTest, fix any compiler/SDK issues, and verify the project opens correctly.
2. Test first-time permission with two timers; permission denial/re-enable; completion/reset/undo while authorization or add is pending; foreground/relaunch; and cancelled alerts near deadline.
3. Verify real UNUserNotificationCenter ordering/delivery. The JavaScript backend model does not establish Apple platform guarantees. Delivery already underway may not be retractable.
4. Check plan/proposal screens and iPad layouts, Dynamic Type, and VoiceOver.

Remaining product questions (not claimed solved): estimates vs real recipes, equipment conflicts, early-finish advice for intermediate steps, handling overdue running timers when actual completion is still unknown, and the tone/frequency of late-finish sheets. Do not add recipe scanning or commerce before validating the cooking flow.

## v0.2.4 superseding addendum

Continue from this visual release. Read DESIGN.md and the current VALIDATION.md. It includes the two reported v0.2.3 corrections and UI polish; do not overwrite these views with older versions. Compare with the agent's actual v0.2.3 package if it contains additional work. Xcode/device validation is still the immediate priority before adding features.


## v0.2.5 — cooking and planning refinement

- Duration estimates open a local editor with Save, Cancel, and restoration of the catalog estimate. No mutation occurs while tapping the stepper; Save commits one undo frame. Identical effective estimates create no history or undo entry.
- Ready pending steps report lateness from their planned start after a full minute, labeled “late to start”; this appears in Right Now and timeline rows. Running timers retain their own deadline and Check now behavior.
- Reset, menu changes, and stale-plan resolution clear any pending serving-time proposal from the prior session.
- Existing scheduling/notification engines, palette, no-account offline behavior, and pinned running deadlines are retained.

Validation: 61 existing supplemental JavaScript outcome assertions and five asynchronous notification-reconciliation model scenarios pass. Three XCTest regressions were added for no-op estimates, reversible committed estimates, and proposal cleanup; not executed here. Xcode compilation, native UI rendering, VoiceOver, iPhone/iPad layout, notifications, and device testing remain pending. JavaScript checks do not execute Swift.

Next Mac review: open Dishes & timing, edit several times then Cancel (no change); Save (one undo); unchanged Save disabled; undo saved edit restores previous estimate. Set a feasible near-future dinner, wait until a ready step is one minute late, verify late-to-start copy; start it and confirm countdown uses its actual start. Verify sheet fits large Dynamic Type and landscape iPad.

---
# Addendum — v0.2.6 reviewer recommendations (2026-10-09, no Mac available)

Built on v0.2.5. Implements the reviewing agent's remaining FEEDBACK-v024.md
recommendations (v0.2.5 had already handled the duration-editor undo and
proposal cleanup items):

1. Overlap warnings auto-expand when they appear; a new warning re-expands.
   The cook can collapse; collapse is never overridden.
2. The featured expired timer's "Mark done" is now the primary tomato action.
   Other running timers keep the quiet control.
3. Stale-plan copy: "already underway" → "already started".

No logic changes. Marketing version 0.2.6, build 7. Still unverified:
compilation, XCTest, device rendering, notification delivery.


## v0.2.7 — warning-panel correction

Warning observation now lives on the cooking screen rather than inside the conditional warning panel. Initial nonempty warnings expand; a newly added warning expands; removing or reordering existing warnings preserves manual collapse. Clearing every warning collapses the panel, and a subsequent warning expands it again. START_HERE.md now identifies v0.2.7; project version is 0.2.7, build 8.

Validation: reviewed the UI diff and checked transition cases with a supplemental model. Existing 61 JavaScript scheduling assertions and five asynchronous reconciliation scenarios pass. Scheme XML and archive integrity pass. No Swift compilation, XCTest execution, or native UI rendering occurred; check warning collapse/removal/addition on a Mac or device.


## v0.2.8 — out-of-order meal readiness

expectedMealEnd evaluates every planned step using actual completion for done steps, the pinned deadline for cooking steps, and derived end for pending steps. A final step marked done early no longer hides unfinished prerequisites. The supplemental model reproduces running and pending middle-step cases and confirms a later dinner proposal for the running case. Existing 61 outcome assertions still pass, plus four additional assertions (65 total); five notification-reconciliation scenarios pass.

Store policy now matches the UI: duration edits are rejected once any step has progress. Four XCTest methods were added covering running/pending out-of-order readiness, mid-cook edit rejection, and proposal cleanup for both stale-resolution choices. These tests are written, NOT executed.

Stale-plan policy is retained: explicitly resuming a plan with progress preserves serving time and actual timer deadlines; it does not silently move dinner or restart timers. A long-past serving time remains visible. A better reviewed recovery flow is a product decision for a later pass.

Native compilation, XCTest execution, simulator/device rendering, and notification delivery remain unverified. The counterpart agent's reported issue guided this fix; FEEDBACK-v027.md itself was not attached.
