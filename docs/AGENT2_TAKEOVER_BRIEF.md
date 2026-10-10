# Dinner, Together — Agent 2 brief while Agent 3 is paused

From: Agent 3 · October 10, 2026, 12:15 AM MT · via Joe
Tree: `Dinner_Together_Recovery_Candidate_v028r9.zip` (SHA-256 in Joe's
message) = `main` at `5ad370e` plus `docs/evidence/run-22/` and
`docs/store/frames-preview/`. Rules unchanged (`REVIEW_REQUEST_r4.md`).
Patch series for this phase: `A2-S5…`. Agent 1 is the integrator until
Agent 3 resumes — send patches to Joe as before; Agent 1 applies them.

## What is now proven that was not before (read `docs/evidence/run-22/README.md`)

The interactive flows have been driven by XCUITest in the simulator for the
first time: review sheet, delay sheet, stale-plan sheet (both paths),
expired-timer completion, blocked start with "Start anyway", unstarted
completion, and the Tonight screen with your nine menus. iPhone 10/10
flows pass; iPad 2/3 (the third is a test-tooling limit on the popover,
not a product finding). Your S1 catalog compiles and its 8 tests pass;
your S3 footer renders and is tappable before scrolling
(`iphone/09-tonight-top.png`); your S4 listing is live in
`docs/store/LISTING.md`.

Two real bugs surfaced and were fixed: the blocked-start alert never
presented (two alert modifiers on one view), and the delay sheet could be
dropped behind a dismissing popover on iPad.

## Your review, in priority order

### S5 — Render review of the first tap-through (`docs/evidence/run-22/`)

Same format as D1–D4: for each render, calm and honest? primary action
where the cook needs it? Severity S1/S2 for anything that misleads about
what happens next; S3 for copy and layout. Specific questions:

- `iphone/01-review-sheet.png` — "Move dinner to 5:50 AM?" with chosen
  5:44 / estimated 5:49 (whole-minute ceiling). Is the headline + two
  columns + reason + the "whole minutes" caption the right amount of text
  at the medium detent? The Move button is below the fold at that detent.
- `iphone/02-review-sheet-lower-bound.png` — amber "Earliest readiness"
  and the lower-bound note. Clear enough that this is not a prediction?
- `iphone/05-blocked-alert.png` — alert copy for the dependency override.
- `iphone/07a-stale-sheet.png` and the cooking screen behind it: a resumed
  day-old plan reads **"Running about 1650 min behind"**. Accurate, absurd.
  This is scenario C (`RECOVERY_COPY_AND_FLOWS.md`) asking to be designed:
  what should "Resume this plan" do with a dinner time that has passed by
  a day? Propose copy and behavior; a patch if it is contained.
- `iphone/09-tonight-menus.png` — nine cards with "Dishes & timing"
  disclosures: is the list scannable, or does it want grouping (weeknight /
  Sunday / meat-free)?

### S6 — The App Store frames (`docs/store/frames-preview/`)

Twelve frames composed from real renders on the store-size simulators with
your six captions (`release/compose-store-frames.py`). Judge caption
wording, order, and which render each frame uses (mapping in
`docs/store/LISTING.md`). The clocks read 4–5 AM because CI ran at night;
the submission set will be re-rendered around 6 PM Mountain Time, so
ignore the times. iPad frames 1 and 5 currently use the same render
(iPad's scrolled-menu attachment was missing in that run); say whether
frame 5 on iPad should be the scrolled list or something else.

### S7 — Thanksgiving

Joe's launch window is before Thanksgiving (November 26). A full holiday
menu (turkey, stuffing, mashed potatoes, gravy, green beans, rolls; 3–4
hours, several hands-off roasting stages) is the single best launch move:
it is the archetypal "everything must finish together" meal, it makes the
4.2 "thin content" question disappear, and the engine already handles the
duration. Same format and constraints as S1 (steps 3–30 min; a 4-hour
chain needs the catalog's bounds test relaxed for that one menu — say so
in the patch, with the test change). Deliver as `A2-S7`.

### Already closed by you

Icon (keep the cloche), listing (A2-5 applied), D1–D4 renders confirmed,
S1–S4 integrated. Agent 1's unstarted-completion question: your answer
("safety net in 1.0") stands.

## Not yours

Signing, workflows, test tooling (Agent 1). Pricing: decided.
