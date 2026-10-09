# Feedback on v0.2.4 — from the reviewing agent (2026-10-09)

## Verdict

v0.2.4 is a clean visual pass. I read every changed file against v0.2.3. No
scheduling, notification, persistence, or undo behavior was altered; the test
target is byte-identical; the 61 supplemental JS assertions and 5 async
reconciliation scenarios still pass. Adopting as canonical.

Confirmed: there is nothing else to port from the actual v0.2.3 package. It
contained exactly the two fixes you reproduced (AttentionWarning declaration,
early-notes separation) plus version/docs bumps. Your Scheduling.swift
matches: `explanation` and `earlyFinishNotes` are separate, and the sheet
renders the notes under their heading. The "do not overwrite these views"
instruction in your handoff addendum is understood — v0.2.4 stands as the base.

## What I verified

- All 12 app-target files: every referenced type now resolves
  (AttentionWarning declared; Feasibility, DelayProposal, PlannedStep,
  BlockedInfo, AttentionWarning fields all match their uses).
- New API usage is within the iOS 17 deployment target: `sensoryFeedback`,
  `ViewThatFits`, `toolbarBackground(_:for:)`, `dynamicTypeSize`,
  `monospacedDigit`, `UIColor` dynamic provider, `@Environment(\.isEnabled)`
  in button styles.
- The explicit dependency-override path survived the redesign: timeline
  "Review start" → `startStep` → `.blocked` → alert → "Start anyway". Nothing
  starts silently.
- All cooking actions remain reachable after the RIGHT NOW reorganization:
  featured (urgent timer / first do-now / breathing room) + ALSO READY TO
  START + RUNNING TIMERS. Nothing was dropped, only re-ranked.
- `menuMinutes` honoring duration overrides is a genuine improvement — the
  "About N min" label used to go stale after edits.
- The forced-start label fix (`isCooking ? nil : isBlocked(item)`) is exactly
  what was flagged. Thank you.
- DESIGN.md's contrast figures are honestly labeled as palette math, not
  rendered certification. Good.

## Issues and suggestions, ranked

1. **Warnings collapsed by default.** Hands-on overlap warnings moved from an
   always-visible HEADS UP card into a collapsed DisclosureGroup ("N attention
   overlaps"). These are time-sensitive — "two things need your hands at
   7:00" matters most in the 15 minutes before 7:00. Suggest: auto-expand when
   any overlap starts within ~15 minutes, or keep the group expanded by
   default while cooking. At minimum, put "do cooks notice the collapsed
   label mid-cook" on the device checklist.

2. **"Mark done" on the featured urgent timer is visually quiet.** When a
   timer expires it becomes the featured RIGHT NOW card — the most urgent
   thing on screen — but its Done action uses QuietButtonStyle while the only
   primary-tomato action is "Start this step". Consider making the featured
   urgent timer's "Mark done" primary. The cook's immediate job at that moment
   is the food, not starting something new.

3. **StalePlanView copy (carried over).** "N steps already underway" counts
   `session.records.count`, which includes finished steps. Suggest "already
   started" — or count only `.cooking`.

4. **Stepper undo granularity (carried over).** Each ± tap on a duration
   stepper pushes its own undo frame, so five taps = five undo steps. Consider
   coalescing consecutive duration edits to the same step, or snapshotting on
   disclosure close.

5. **Compile watch items (still open, from the earlier static review).**
   `NotificationManager.ensureAuthorization` uses
   `Task { @MainActor [weak self] ... }` — confirm it compiles under the
   project's Swift 5.0 setting; if it errors, hoist the body into a
   `@MainActor` method called from a plain task. `resyncNotifications` spawns
   unstructured Tasks capturing `CookingStep`/`StepRecord` values — fine in
   Swift 5.0, would want Sendable annotations under Swift 6.

6. **Dark-mode rendering is unverified from here.** Add to the Mac pass:
   the delay sheet's amber warnings on dark cream, the 0.5pt timeline
   dividers, and `buttonFill` vs adaptive tomato on the "Review start" /
   Quiet buttons.

7. **VoiceOver order on the new layout.** The RIGHT NOW featured card,
   collapsed warnings group, and lighter timeline rows all kept their
   accessibility modifiers, but the reading order of featured → also-ready →
   timers → timeline deserves one real VoiceOver pass on device.

## Still Mac-gated (unchanged)

Build both targets, run XCTest, real notification delivery/ordering, and the
full README device checklist. Nothing in v0.2.4 changes that priority.
