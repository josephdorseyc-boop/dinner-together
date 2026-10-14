# Dinner, Together — v0.2.4 design handoff

Direction: modern, calm, warm editorial. Preserve cream/tomato/olive. Use crisp system text for working screens, a restrained serif welcome headline, and larger rounded timer/dinner-time numbers with stable-width digits.

Visual changes:
- Cards reserved for the featured task and running timers. Timeline uses small status markers, whitespace, and subtle dividers.
- Primary tomato action is reserved for starting the featured step. Most secondary actions use neutral surfaces. Olive denotes completion; amber warnings use icons/text so color is not the only signal.
- Right Now features an expired running timer before suggesting new work. Other due actions and running timers remain visible; no automatic task-ordering claim is introduced.
- Planned/actual details and explanatory notes are available in disclosure controls.
- iPad: guidance on the left, timeline on the right. ViewThatFits and accessibility text-size fallback support a stacked layout.
- Warm Dark Mode surfaces preserve readable cream text and brighter brand accents. Filled buttons keep the dark tomato with white labels.
- Selection/completion use native sensory feedback. Button motion respects Reduce Motion.

Integration:
This build starts from our v0.2.2 source and adds visual changes. The agent's reported v0.2.3 ZIP could not be retrieved during this run; the two reported fixes were reproduced directly: AttentionWarning is declared, and the early-finish notes now appear under Worth knowing without being duplicated in the general explanation. Compare against the agent's actual v0.2.3 before bringing over any other changes.

Unchanged: scheduling calculations, persistence, per-run reminder validation, single-worker reminder reconciliation, and timer deadlines. Scheduling.swift changes only declare the missing type and separate the delay explanation from its dedicated early-finish notes.

Verified here: existing 61 supplemental JavaScript outcome assertions and five asynchronous reminder-model scenarios pass. Core backend files were compared with v0.2.2; the listed scheduler changes were reviewed. Defined normal text/surface color pairs have a minimum 5.17:1 contrast in Light Mode and 6.28:1 in Dark Mode; white labels on dark tomato also exceed 4.5:1. These are palette calculations, not rendered accessibility certification.

Pending on a Mac/device: compile both targets and XCTest; render all screens in light/dark, iPhone/iPad, split view, Dynamic Type and Reduce Motion; VoiceOver; SF Symbols availability; feedback behavior; native notification delivery. This is design implementation in SwiftUI source, not a screenshot-verified or submission-ready application.

Recipe scanning remains a v0.3 candidate; this v0.2.4 release does not add it.


## v0.2.5 — cooking and planning refinement

- Duration estimates open a local editor with Save, Cancel, and restoration of the catalog estimate. No mutation occurs while tapping the stepper; Save commits one undo frame. Identical effective estimates create no history or undo entry.
- Ready pending steps report lateness from their planned start after a full minute, labeled “late to start”; this appears in Right Now and timeline rows. Running timers retain their own deadline and Check now behavior.
- Reset, menu changes, and stale-plan resolution clear any pending serving-time proposal from the prior session.
- Existing scheduling/notification engines, palette, no-account offline behavior, and pinned running deadlines are retained.

Validation: 61 existing supplemental JavaScript outcome assertions and five asynchronous notification-reconciliation model scenarios pass. Three XCTest regressions were added for no-op estimates, reversible committed estimates, and proposal cleanup; not executed here. Xcode compilation, native UI rendering, VoiceOver, iPhone/iPad layout, notifications, and device testing remain pending. JavaScript checks do not execute Swift.

Next Mac review: open Dishes & timing, edit several times then Cancel (no change); Save (one undo); unchanged Save disabled; undo saved edit restores previous estimate. Set a feasible near-future dinner, wait until a ready step is one minute late, verify late-to-start copy; start it and confirm countdown uses its actual start. Verify sheet fits large Dynamic Type and landscape iPad.
