# Dinner, Together — native iOS app · v0.2.4

“Your dishes, one dinner time — with clear guidance when plans change.”

A SwiftUI app for iPhone and iPad that plans multi-dish dinners backward from
serving time, shows what needs attention right now, and repairs the plan when
cooking runs late. Offline-first: no accounts, no cloud, no AI, no network.

## Project layout

```
DinnerTogether.xcodeproj/        Xcode project + shared DinnerTogether scheme
DinnerTogether/
  DinnerTogetherApp.swift        App entry
  Theme.swift                   Palette (warm cream / tomato red / olive green), shared styles
  Models.swift                  Catalog + session value types (steps, states, records, history)
  DinnerCatalog.swift            The three illustrative menus (timing estimates, not recipes)
  Scheduling.swift              Pure scheduling engine — no UI, no persistence
  SessionStore.swift             Session state, undo, JSON persistence, stale-plan handling
  TimerCenter.swift              Live "now" publisher; countdowns derive from absolute deadlines
  Notifications.swift            Local timer reminders (permission in context, graceful denial)
  ContentView.swift              Root: tabs on iPhone, sidebar + wide detail on iPad
  PlanView.swift                 Serving time, feasibility, menu preview, duration editing
  CookingView.swift              Do-this-now, timers, up next, warnings, timeline, undo
  Sheets.swift                   Stale-plan choice, delay explanation, serving-time proposal
DinnerTogetherTests/
  DinnerTogetherTests.swift      XCTest suite (see Validation below)
```

Separation of concerns: `Scheduling` is pure logic (testable without UI);
`SessionStore` owns state + persistence; `TimerCenter` owns time;
`Notifications` owns reminders; views only render and forward explicit actions.

## Build & run (needs a Mac)

1. Install Xcode 15 or later (iOS 17 SDK).
2. Open `DinnerTogether.xcodeproj`. Select the **DinnerTogether** scheme.
3. Pick an iPhone or iPad simulator running iOS 17+, then Product → Run (⌘R).
4. Run the tests: Product → Test (⌘U).

### On a physical device

1. In the DinnerTogether target → Signing & Capabilities, select your Apple
   team. Replace the placeholder bundle identifier `com.example.dinnertogether`
   with one you own (e.g. `com.yourdomain.dinnertogether`).
2. Connect the device, select it as the run destination, Product → Run.
3. App Store distribution and TestFlight require Apple Developer Program
   membership ($99/yr). This build has not been submitted to Apple.

## Device-testing checklist (before calling anything "working")

- [ ] Timers: start a step, background the app / lock the device, relaunch —
      countdown must reflect the absolute deadline, not restart.
- [ ] Notifications: start a first timer → permission prompt appears in context;
      deny it → timers still count down in-app with the "notifications off" note;
      allow it → reminder fires at the deadline and is cancelled on Done/undo.
- [ ] Delay: with a running timer, add 10 min — deadline unchanged, pending
      steps shift, early-finish warning appears when appropriate.
- [ ] Late finish: complete a step past its planned end — dependents shift,
      infeasible serving time offers an explicit move/keep choice, and
      accepting the proposal applies the delay exactly once.
- [ ] Blocked steps: with a timer running, its dependent shows "waiting"
      with a reason; Start is gated behind an explicit "Start anyway."
- [ ] Unstarted completion: marking a never-started step done asks first
      and records the start as unknown (never fabricated).
- [ ] Undo: every action (start, done, delay, duration edit, reset) undoes
      exactly, including timer deadlines.
- [ ] Feasibility: pick a serving time sooner than the longest dish allows —
      warning offers the earliest feasible time.
- [ ] Stale plan: cook yesterday (or change the device date), relaunch —
      resume-or-start-fresh choice appears.
- [ ] Date rollover: dinner after midnight plans and delays correctly.
- [ ] Airplane mode: everything works offline.
- [ ] Dynamic Type: largest accessibility sizes don't clip key controls.
- [ ] VoiceOver: full pass over Tonight + Cooking tabs.
- [ ] iPad: sidebar layout, two-column cooking screen, no stretched phone UI.
- [ ] Time-zone change mid-plan: deadlines are absolute instants and hold.

## Notes

- Saved state lives in the app's Documents directory
  (`dinner-together-v2.json`). v0.1 saves are not migrated — fresh start.
- Bundle ID, marketing version (0.2.4), and signing are placeholders until Joe
  provides real values.
- Recipe scanning/screenshots stay a v0.3 candidate (on-device text
  recognition + user-confirmed durations). Not in this build.
- "Social Battery Travel" is a separate future app — untouched.

## Corrective v0.2.4 handoff

Read HANDOFF.md and VALIDATION.md first. This is native source, not a compiled IPA. The original agent's v0.2.1 documentation is superseded by these reports. New optional runID values decode older saves without requiring that field.

## Visual refinement

See DESIGN.md for the visual direction and v0.2.4 validation limits. Native screens have not been rendered or inspected on-device.


## v0.2.5 — cooking and planning refinement

- Duration estimates open a local editor with Save, Cancel, and restoration of the catalog estimate. No mutation occurs while tapping the stepper; Save commits one undo frame. Identical effective estimates create no history or undo entry.
- Ready pending steps report lateness from their planned start after a full minute, labeled “late to start”; this appears in Right Now and timeline rows. Running timers retain their own deadline and Check now behavior.
- Reset, menu changes, and stale-plan resolution clear any pending serving-time proposal from the prior session.
- Existing scheduling/notification engines, palette, no-account offline behavior, and pinned running deadlines are retained.

Validation: 61 existing supplemental JavaScript outcome assertions and five asynchronous notification-reconciliation model scenarios pass. Three XCTest regressions were added for no-op estimates, reversible committed estimates, and proposal cleanup; not executed here. Xcode compilation, native UI rendering, VoiceOver, iPhone/iPad layout, notifications, and device testing remain pending. JavaScript checks do not execute Swift.

Next Mac review: open Dishes & timing, edit several times then Cancel (no change); Save (one undo); unchanged Save disabled; undo saved edit restores previous estimate. Set a feasible near-future dinner, wait until a ready step is one minute late, verify late-to-start copy; start it and confirm countdown uses its actual start. Verify sheet fits large Dynamic Type and landscape iPad.
