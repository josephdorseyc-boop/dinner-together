# Validation — v0.2.4, October 9, 2026

Passed in this environment:
- Existing JavaScript model: 61 outcome assertions.
- Existing asynchronous reminder-worker model: five scenarios.
- Defined text/brand/warning contrast against both surfaces: minimum 5.17:1 light / 6.28:1 dark, plus white primary-button labels above 4.5:1.
- No changes to Models, SessionStore, Notifications, TimerCenter, DinnerCatalog, or DinnerTogetherApp compared with v0.2.2. Scheduler changes only add the missing AttentionWarning type and separate early-finish notes from general explanation.
- Project references, source paths, scheme XML, version settings, and ZIP integrity checked when packaged.

Not performed:
- Swift compilation, XCTest, simulator/device runs, native screenshots or visual QA, accessibility or haptic testing, notification delivery, recipe validation, or App Store submission.
- Actual agent v0.2.3 package comparison. See DESIGN.md for integration notes.

The JavaScript checks are supplemental models, not execution of the Swift application. Full native validation remains the next milestone.


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
