# Recovery copy and flows — candidate v028 r5

Three mid-cook situations. **A and B (copy only) are implemented in this
candidate; C is a proposal only.** Times are examples; the app formats them
with the device locale.

---

## A. Small late finish — IMPLEMENTED

### Where it appears
Cooking screen, directly under the DINNER AT card, in the action column (left
column on iPad, top of the stack on iPhone and at accessibility text sizes).
It is a restrained paper card with a thin stroke; no modal, no banner, no
dismiss.

### When it appears
Whenever the estimated readiness of unfinished work is ≥ 1 minute after the
chosen dinner time and the meal is not complete. It leaves on its own when
the estimate meets the chosen time (after the cook moves dinner, after an
"Adjust time" delay that covers the drift, after undo, or after a step
finishes earlier than its projected end).

### Inline notice copy

```
[clock.badge.exclamationmark]  Running about 7 min behind
Dinner is set for 7:00. Unfinished steps are estimated to finish around 7:07.
"Prep the steak & sauce ingredients" finished 7 min late.
[ Review dinner time ]            ← quiet button
```

Tone: muted ink for < 10 min; amber headline and icon at ≥ 10 min. The
numbers are initial UX choices (`Scheduling.readinessNoticeThreshold`,
`CookingView.readinessEmphasisMinutes`).

When an expired timer is still cooking on the critical path, the estimate is
floored at *now* and is a lower bound, so the notice says so instead of
predicting (r2, review finding 5). The "At least N" figure is rounded
**down** (r5, A2-1): 5 m 40 s behind reads "At least 5 min behind", while
the ordinary headline would say "about 6".

```
[clock.badge.exclamationmark]  At least 5 min behind
Dinner is set for 7:00. Unfinished steps can't finish before 7:05.
The "Cook the steak" timer ended at 7:04 — check the food; mark that step
done when it's ready. After it, about 10 min of Steak steps remain.
[ Review dinner time ]
```

Reason line variants (all derived, one sentence):

| Situation | Copy |
|---|---|
| Earlier step in the slowest dish finished late | `"Prep the steak & sauce ingredients" finished 7 min late.` |
| Slowest dish's next step hasn't been started and is overdue | `"Trim beans & prep garlic" is 8 min late to start, and about 15 min of Green beans steps remain.` |
| A running timer sets the estimate for its dish | `The "Cook the steak" timer ends at 7:05, then about 10 min of Steak steps remain.` |
| That timer has expired | `The "Cook the steak" timer ended at 7:04 — check the food; mark that step done when it's ready. After it, about 10 min of Steak steps remain.` |
| The critical step itself is running | `The "Cook potatoes until tender" timer ends at 7:05.` |
| The critical step itself is an expired timer | `The "Cook potatoes until tender" timer ended at 7:04 — check the food; mark this step done when it's ready.` |
| Fallback | `About 25 min of Steak steps remain.` |

(A finished dinner shows no notice at all, however late it finished — r2,
review finding 2. The "finished at" wording survives in code only as a
defensive branch.)

VoiceOver (combined element): *"Timing update. Chosen dinner time 7:00 PM.
Estimated readiness 7:07 PM, about 7 minutes later. 'Prep the steak & sauce
ingredients' finished 7 min late."* (With an expired timer: *"Earliest
readiness 7:05 PM…"*.) Then the button: *"Review dinner time"*,
hint *"Shows the estimate and lets you move dinner to it. Nothing changes
until you choose."*

Also added for scenario 11: the big DINNER AT time reads as *"Chosen dinner
time 7:00 PM"*; a running card's "Ends 7:05" reads as *"Timer deadline 7:05
PM"*. Unverified with VoiceOver here.

### Review sheet copy (opened only from the notice)

```
Nav title: Review dinner time

Move dinner to 7:07?

CHOSEN DINNER TIME        ESTIMATED READINESS      ← "EARLIEST READINESS" when
7:00                      7:07  (amber)                it is a lower bound

"Prep the steak & sauce ingredients" finished 7 min late.
(amber, only for a lower bound:) A timer has ended but its step isn't marked
done, so this is the earliest the meal could be ready — not a prediction.
Dinner moves in whole minutes, so the new time is never earlier than the estimate.
ⓘ Dinner moves from 7:00 to 7:07.
ⓘ 3 upcoming steps change time; dependency constraints may keep other steps in place.
ⓘ "Drain, mash & season": 6:55 → 7:02.
ⓘ "Trim beans & prep garlic": 6:45 → 6:52.
ⓘ "Cook & season beans": 6:50 → 6:57.
   (the steak's own pending steps already sit behind the late prep, so they
    don't move and aren't listed — this is the existing proposeDelay rule)
ⓘ 2 finished steps keep recorded times.
ⓘ 1 running timer keeps its deadline — the food doesn't wait for the plan.

Worth knowing before you decide:              (only when a running timer's
⚠ The "Cook potatoes until tender" timer       deadline is > 1 min before the
  deadline is 6:55 — about 12 min before the   new dinner time)
  new dinner time. Check the food to confirm
  it's ready. We won't guess a safe holding
  time; check your recipe.                     (r5, A2-2: a deadline is not
                                                readiness — same wording in
                                                "Adjust time")

[ Move dinner to 7:07 ]      ← primary (tomato)
[ Keep 7:00 for now ]        ← secondary

Keeping the time changes nothing. The estimate stays on the cooking screen
while steps run late, and you can come back here any time.
```

The ⓘ lines and the ⚠ notes are the existing `DelayProposal` explanation and
early-finish notes, so the two sheets ("Adjust time" and "Review dinner
time") say the same things in the same words. The sheet re-reads the live
estimate on every tick: the time on the primary button is the time that gets
applied. Minutes are rounded **up** for the move (r2, review finding 4): a
7 m 20 s drift shows "about 7 min behind" and "Move dinner to 7:08"; the
headline rounds to nearest, the move never lands before the estimate, and
preview and apply share one function (`readinessMoveProposal`). If drift clears while the sheet is open (not reachable today, kept
defensively), it shows *"Back on schedule."* with a Done button.

### Flow

1. Cook marks a step done late → `completeStep` records the actual end,
   appends the feasibility note to history, and **does not** touch `serveAt`.
2. Cooking screen recomputes `readinessReport(now:)` → notice appears.
3. Cook keeps cooking. Other steps start and finish; the notice tracks the
   current estimate. Undo / reset / menu change / "Adjust time" → the notice
   recomputes from the new session (nothing to clear).
4. Cook taps **Review dinner time** → live sheet.
5. **Move dinner to 7:07** → `moveDinnerToEstimatedReadiness(now:)` builds a
   `DelayProposal` for the rounded drift, applies it once through
   `applyDelay`, pushes one undo frame ("Moved dinner to 7:07"). Notice clears
   because the next report derives from the new time. A second tap cannot
   double-apply: there is no drift left to move.
6. **Keep 7:00 for now** → dismiss; nothing changes; notice stays.

### Known honest edge
With an expired timer on the critical path, the estimate is floored at *now*,
so "At least N min behind" ticks up a minute at a time until the cook marks
that step done. The notice and the sheet both say it is a lower bound, and
the reason line says what to do ("check the food; mark that step done when
it's ready"). Moving dinner in that state is allowed but rarely useful; the
sheet's amber note makes that visible. If this reads as nagging on device,
the simplest tweak is to hide the Review button while
`report.estimateIsLowerBound` is true — a one-line change in
`readinessNotice`.

---

## B. Expired running timer — IMPLEMENTED (copy only, r5)

v0.2.8 showed "Check now", "Overdue 02:10" and a primary **Mark done**.
Agent 2's r4 review approved the copy-only change below (applied as patch
A2-4; `heatCard` in `CookingView.swift`). The step still stays Cooking, no
actual end is invented, and no timer-extension feature exists.

```
Featured RIGHT NOW card (timer expired)
Badge:     Check the food            (was: Check now)
Countdown: Overdue 02:10             (unchanged)
Caption:   The timer ended; the food may not have. Check it before marking
           this step done.           (new line under "Ends 7:04")
Button:    Mark done after checking  (was: Mark done; VoiceOver hint added:
           "The timer ended. Confirm the food is ready before marking this
           step done.")
```

Non-featured running cards with expired timers keep the quiet "Mark done";
their badge changes to "Check the food" for consistency. Timeline rows: the
"Timer: Overdue 02:10" line gains no new copy — the card is the place for it.

Why: "Check now" reads as an instruction about the app; "Check the food"
says what to do in the kitchen and matches the vision board. "Mark done after
checking" keeps the primary action but names its precondition. Nothing
completes automatically, no actual end is invented, and the notice above
(A) already explains the dinner-time consequence separately.

Timer extension — proposed as a separate, explicit feature, not copy:

- Action on an expired card: **Add 2 min / Add 5 min** (two buttons, quiet).
- Effect: a new run? No — the same run. Set `timerDeadline += n min`,
  keep `runID`, `actualStart`, and `confirmedMinutes`; append a history
  line; push one undo frame ("Extended 'Cook the steak' by 5 min").
- Undo restores the previous deadline (the invariant "undo never starts a
  new timer" holds because nothing restarts; the deadline merely returns).
- Notifications: the deadline changed, so the reminder must be re-scheduled
  through `notifications.schedule` with the same revalidation pattern used in
  `startStep` (await authorization, then check runID / actualStart / state /
  the NEW deadline). `cancel(stepID:)` first so the reconciler drops the old
  request.
- It is a deliberate exception to "a running step's deadline never changes
  implicitly": it changes *explicitly*, once, with undo. Document it as such.
- Not recommended until native validation has run once; it touches the
  reminder reconciler.

---

## C. Stale-plan recovery — PROPOSED (not implemented)

Current (v0.2.8): on launch, a non-dismissable sheet offers *Resume this plan*
(keeps old `serveAt` and pinned deadlines; with no progress, re-anchors to
now+60) or *Start fresh* (clears progress). Resuming a plan with progress
leaves a long-past dinner time on screen; with this candidate the readiness
notice would then honestly say "Running about 1,140 min behind".

Proposed flow (a design, with consequences, before any new transition is
added):

```
Welcome back.

You started Steak night yesterday. 3 steps finished, 1 was cooking, 4 never
started. That dinner time has passed.

[ Plan the unfinished steps for a new time ]   ← primary
[ Start fresh ]                                ← secondary
[ Keep it exactly as it was ]                  ← quiet (today's "Resume")
```

**Plan the unfinished steps for a new time** opens a second screen:

```
Pick a new dinner time
7:30 PM  (date picker, ≥ now + remaining chain)

Finished steps keep their recorded times:
  ✓ Prep the steak & sauce ingredients  — done 6:37 PM yesterday
  ✓ Peel & cut potatoes                 — done 6:38 PM yesterday
  ✓ Trim beans & prep garlic            — done 6:52 PM yesterday
Was cooking when you left:
  ◉ Cook the steak — timer ended 6:50 PM yesterday
     [ It finished ]  [ It didn't — start over ]      ← explicit choice
Not started: 4 steps, about 45 min, replanned backward from 7:30.

[ Use 7:30 and continue ]
```

Consequences to state before building:

- A step that was Cooking across a day boundary cannot be "resumed": the
  deadline is a day old. The cook must say whether it finished (record done,
  actual end unknown-but-past, shown as "end not recorded") or reopen it
  (`correctStep` semantics: back to Not Started, timer cleared). No automatic
  choice; no holding period is invented.
- Finished steps keep yesterday's actuals. The app does not claim the food is
  safe to serve; the plan simply doesn't ask the cook to redo recorded work.
  A one-line note ("Timing only — use your judgment on food that sat
  overnight") is honest and sufficient.
- New `serveAt` must satisfy feasibility for the *unfinished* chain only;
  `checkFeasibility` currently uses the longest whole dish and would need a
  remaining-work variant (pure function, easy to test).
- This is a new transition (`resolveStale(.replan(newServeAt:cookingResolutions:))`).
  It clears the undo stack like the current resolution does, and writes one
  history line per decision.
- "Keep it exactly as it was" stays available because the current policy is
  deliberate and some cooks reopen the app the same evening after the
  1-hour-past threshold.

Not recommended for this candidate: it is a product decision with three new
screens' worth of copy and a new state transition; do it after native
validation of the cooking loop, as the vision board's build order says.
