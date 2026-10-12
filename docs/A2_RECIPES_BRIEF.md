# Agent 2 brief: "Your recipes" (A2-R series)

From: Agent 3 · October 11, 2026 · via Joe
Plan: `docs/RECIPES_PLAN.md` (read §1–4 first). Branch: `wip/recipes`.

## What exists now (functional, house style, not yet designed by you)

- **Tonight → YOUR RECIPES**: empty-state card; "Add a recipe" button; one
  row per recipe (thumbnail, title, byline, "Check the timing" or duration,
  tonight checkmark). Above ON THE MENU.
- **Add a recipe sheet** (`RecipeViews.swift › AddRecipeSheet`): Link | Text
  segmented; Paste button (no clipboard prompt); "Add recipe"; error copy
  from `RecipeImportError` / `RecipeFetchError`.
- **Recipe page** (`RecipeDetailView`): photo hero with title + byline over
  a gradient (serif title on cream when no photo); TOTAL TIME · YIELD ·
  STEPS; "Check the timing" banner; pill tabs **Ingredients · Directions ·
  Timing**; directions with tomato timer chips; "View the original on …";
  bottom "Cook this for dinner"; ••• menu with Share link / Delete.
- **Timing tab**: per step: title, minutes button (opens the existing
  duration editor), Needs you / Hands-off toggle, "Estimated" tag; planned
  total; "The recipe says X in total" when they differ by ≥10 min; "Timing
  looks right".

Joe's reference: Apple News+ Food recipe page (hero photo, Ingredients /
Directions / Nutrition / More tabs, orange timer chips, Start Cooking).
We match its structure, not its look.

## Your deliverables, in priority order

**R1 — Timing tab design.** The screen that makes this our feature. Is the
row the right shape? How should an *estimated* minute look so it invites a
tap without alarming? What does "Needs you / Hands-off" read like to a
first-time cook? Copy for the explainer line and the confirm button.

**R2 — Recipe page + Add sheet polish.** Hero height, title size on long
titles (EatingWell's is 7 words), stats row, tab bar, the empty state on
Tonight, error copy. Swift patches to `RecipeViews.swift` welcome.

**R3 — Long steps.** Recipes bring 3-hour freezes and 4-hour roasts. Review
copy where multi-hour durations appear: cooking screen countdowns
(`1:59:30`), "Running about X min behind" (should say "2 hr 5 min"), the
feasibility card ("this menu can reach the table at…" — tomorrow?). This
also closes your S5 "1650 min behind" item.

**R4 — S7 Thanksgiving**, unchanged from the previous brief, as catalog
content. Long hands-off roast steps are now allowed for catalog menus too
if you flag them `handsOn: false`.

**R5 — Five test recipes** with timings you trust (pasted-text form), one of
them with a "meanwhile" section, for UI-test seeds and store screenshots.

Format as before: renders/specs + patches, series `A2-R1…`, via Joe.
