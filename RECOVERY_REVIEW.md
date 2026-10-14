# Recovery review — v0.2.8 baseline (October 9, 2026)

> r2 note: the implementation this review recommends was revised after the
> reviewing agent's feedback (dependency carry, all-done guard, copy,
> rounding, lower-bound wording). See `RECOVERY_HANDOFF.md` §0.

Scope: mid-cook recovery only. Read against the v0.2.8 source, the vision
board, and the eleven acceptance scenarios in AGENT_PROMPT.md. Examples use
the Steak night menu with dinner at 7:00: steak prep 6:20–6:30, cook
6:30–6:50, rest 6:50–7:00; mash 6:25–6:35, 6:35–6:55, 6:55–7:00; beans
6:45–6:50, 6:50–7:00.

## What works and should be kept

- The engine is sound. Planned times are derived; actuals are pinned;
  `applyDelay` only moves `serveAt`; the dependency-aware plan prevents the
  double-apply bug. All eleven invariants in the brief hold in the code I
  read, and the v0.2.8 out-of-order readiness fix is correct.
- Delay preview ("Adjust time" → +5/+10/+15 → sheet listing exactly what
  moves, early-finish notes, then confirm) is the right shape for an explicit
  decision. The candidate reuses it rather than inventing a second path.
- The featured expired timer in RIGHT NOW with "Check now" and a primary
  "Mark done" is close to the vision board's "expired means check" direction.

## Three problems with routine lateness

**1. The late-finish sheet is chatty by construction.**
`completeStep` stores a proposal whenever `max(expectedMealEnd, now)` is more
than a minute past `serveAt`; `CookingView` opens `ServingSheetView` whenever
that field is non-nil; "Keep" only clears the field. Nothing records that the
cook already declined, so the same question reappears on every later
completion while any drift remains.

Example: prep finishes at 6:37 (7 min late). Sheet: "Dinner time needs a
nudge — move to 7:07?" Cook taps Keep. Mash prep finishes 6:38 → the sheet
returns, still 7:07. Steak cook finishes 6:58 → sheet again. Beans prep → sheet
again. A cook 3 minutes behind on an eight-step menu can see the same modal
five times, each one blocking the screen that is supposed to answer "what do I
do right now?"

**2. The proposal is a cached snapshot, so it can apply an obsolete estimate.**
The stored `(date, explanation)` is computed once, at completion time. The
sheet is modal, so another completion cannot happen underneath it, but time
can pass: a cook who taps nothing, puts the phone down, and returns from
background 10 minutes later still sees "Move dinner to 7:07" and can apply it,
although the unfinished work can no longer finish by 7:07. Undo, reset, menu
change, and stale resolution clear the field (v0.2.5 work; good), but nothing
recomputes it: a return from background shows and applies the old number.

**3. The readiness number the sheet reports ignores work nobody has started.**
`expectedMealEnd` uses the derived plan for pending steps, and the derived
plan always ends at `serveAt` for a dish with no actuals. At 6:55 with the
beans untouched (planned 6:45 start, 15 min of work), readiness is "7:00" and
no proposal is ever produced, while the RIGHT NOW card says "10 min late to
start". The v0.2.8 completion-effect code partially patches this with
`max(…, now)`, which can only ever say "not before now", never "now plus the
work that remains". The two signals on screen disagree.

## Smaller observations (not changed in this candidate)

- `PlanView` tells a cook with progress to "Use 'Running late' while cooking";
  the cooking screen's button is "Adjust time". One of the two strings should
  change (suggest the plan copy).
- `ServingSheetView` and `DelaySheetView` explain overlapping things in
  different vocabularies ("needs a nudge" vs "take a little more time").
- `session.history` is written on every action but rendered nowhere. Not a
  bug, but the late-finish explanation that used to live only in the modal
  now goes there, so a future "what happened tonight" view has material.

## Recommendation (implemented in this candidate)

1. **Report routine drift inline, persistently, without a modal.** Under
   DINNER AT, show "Running about N min behind", the chosen time, the
   estimated readiness, and one derived reason. No dismiss control — it is a
   status, not a question, and it disappears on its own when the estimate
   meets the chosen time.
2. **Derive it; store nothing.** `Scheduling.readinessReport(menu:session:now:)`
   is a pure function of the session and the clock. The cooking screen
   recomputes it every tick. There is no field to invalidate after undo,
   reset, menu change, delay confirmation, another completion, or a return
   from background, because there is no field.
3. **Make the estimate now-aware.** A new pure `projectedReadiness` walks each
   dish forward: done → actual end; cooking → pinned deadline, floored at now;
   pending → planned start, but not before now or the predecessor's projected
   end. `expectedMealEnd` and `completeStepEffects` are untouched, so the
   v0.2.8 invariant and its tests stand; the notice simply uses the estimate
   that also counts idle time.
4. **Keep the modal for the explicit decision, opened only by the cook.**
   "Review dinner time" presents a live sheet labeled *Chosen dinner time* vs
   *Estimated readiness*, built from the existing `proposeDelay` (so the
   cook sees exactly which pending steps move and which running timers would
   finish early) and applied through `applyDelay` once, undoably.
5. **Interruption policy:** the app never opens a timing sheet on its own.
   Drift of ≥ 1 minute shows the notice (same margin the old proposal used);
   ≥ 10 minutes switches the notice to the amber tone. Both numbers are
   initial UX choices, not correctness rules, and both live in one named
   constant each.

What this does not do: it does not touch expired-timer completion, stale-plan
policy, timer extension, notifications, or persistence. See
RECOVERY_COPY_AND_FLOWS.md for the proposed (unimplemented) direction on
expired timers and stale resume, and RECOVERY_HANDOFF.md for validation
limits and merge notes.
