# A2-63 — Build21 whole-meal, folded showcase and video-cover proposals

Status: NEW PROPOSALS for Joe's approval, not approval inferred from the earlier Duo boards. Source review baseline beebcf1 on wip/duo-hinge. A3 owns implementation/integration; A1 owns UI acceptance tests. No active-source edits or CI changes by A2.

## Precedence
Joe's12:12–12:14 amendment relayed by A3 supersedes the earlier CLOSED-cover single cookbook page: closed upright mirrors iPhone's photo-first experience. Closed sideways is proposed This Week photo showcase below. Approved OPENED Duo recipe/Cooking compositions remain in force. Tent timers are Build22/#24, not an implied part of this proposal.

## Folded sideways: This Week photo showcase
One horizontally paged full-screen card per calendar day: today then next6, using the same WeekRotation.days/date identity as WeekStrip. No infinite wrap. Today reads actual Tonight selection; future days read WeekPlan. Today is labelled Tonight. Browsing/swiping never changes dinner, starts cooking or edits a plan.

Day labels rather than7 anonymous dots at standard type; selected underline plus1of7 text. Full date announced/accessibly available. AX fallback: one selected day/date and page count with accessible previous/next actions rather than squeezing7labels.

Background: main dish's actual hero image, else existing default Tonight hero; always edge-to-edge with legible gradient/scrim and glass controls. Multiple dishes: main title plus brief named sides/count; allow wrapping/scroll at AX. Do not invent a total meal duration or serving count. Recipe time/yield optional only if known and space permits; omit rather than crowd primary content. Source of scene/window geometry remains actual available space; do not infer display identity from a mocked device.

Planned card: View recipe for one dish / View dinner for several. Separate Day options button opens the existing day planning sheet. Sheet owns selecting/changing1–4 recipes (favorites-first; search if available), Add a new recipe and clearing that day. Do not place a destructive clear button over a photo or silently substitute Cook tonight for View. If a future plan needs to become tonight, expose an explicit action with existing replacement/timing/progress safeguards.

Empty card: default hero, Nothing planned yet, Plan this day. No automatic Thanksgiving assignment: show Thanksgiving only when explicitly selected. Calendar rollover and absent/deleted recipes follow existing plan rules, with honest empty/missing state.

Explicit Done returns to prior route and suppresses automatic re-entry for that landscape visit (avoid a Done/reopen loop). Turning upright/opening also restores route, selected tabs, scroll positions and absolute timer deadlines. A day sheet already open adapts without silently discarding choices.

Recommended entry priority: showcase from idle Tonight; never automatically replace active Cooking/timer/completion/confirmation, import/photo picker, recipe editing or other modal work. A running dinner stays Cooking when turned sideways. Reading a future day has no execution effects. This narrower entry rule is proposed for approval, not already approved.

VoiceOver: paged group says day/date, Tonight if applicable, dinner title/dishes and1of7; explicit next/previous actions, decorative image hidden. No parallax under Reduce Motion; text scrim/material solid fallback for Reduce Transparency and Increase Contrast. Keep44pt targets. At large type, use one day label, text/controls in a scrollable high-contrast surface; never shrink labels to fit.

## Tonight and day sheet source review
ALSO TONIGHT already fits the cozy style:44pt optional thumbnail, concise name/time, separate44pt remove target. Preserve heading. Standardize add affordance to Add a dish, show below4 even when no additional cookbook recipe exists, and offer existing Add a new recipe in the empty picker. Current beebcf1 condition library.recipes.count > tonightDishIDs.count hides the action when only the main exists.

Removal copy: Remove [dish] from tonight's dinner; never imply deletion of the cookbook recipe. Keep selected serving time unless existing engine requests a necessary explicit change; no quiet reset.

Day sheet copy:
- Choose up to4 dishes. The first is your main.
- Changes save as you choose.
- Main dish shown on first selected row even when only one selected.
-3of4 dishes selected /4of4 dishes selected; selected rows remain removable.
- Unchecked/untimed recipe: Check timing on the recipe page, using existing timing policy.
- Done dismisses; do not claim it is an atomic save or add a fake Cancel. Display real save errors and keep failed changes visibly unresolved.

Behavior concern handed to A3/A1: future-day AddRecipeSheet completion currently calls weekPlan.set(.menu(recipe.menuID)), replacing previously checked dishes. Recommend append through WholeMeal under cap or explicit replacement confirmation rather than silent replacement. No patch applied by A2. DayPlanSheet source is not currently searchable, so the board's search field is a proposed usability addition rather than a verified existing control.

## iPhone whole-meal Cooking
One vertically scrolling chronological timeline for ALL selected dishes, not one independent schedule per recipe. Cream surface. Compact Dinner at chosen time header and named dish summary. First-screen Right now step/action names its dish; retain existing eligibility, blocked-start and timer-ended checks. If several steps are actionable use existing engine order and named compact rows, never auto-resolve hands-on conflicts.

Compact running timer rows each name recipe+step/state and retain actual deadline. Coming up rows show actual chronological planned time, dish name, step and optional View directions. Distinguish textually, not by color alone. Future-direction preview is read-only; no Start/Mark done for future steps. Returning preserves timeline reading position, session and deadlines. No large hero in whole-meal Cooking if it would push controls off screen; no repeated warning cards. Existing whole-dinner overlaps/readiness/undo remain visible through their established controls.

All1–4dishes use the same iPhone timeline; this does not approve new3–4dish Duo columns. At AX, wrap dish labels and stack metadata, prioritize current action above optional imagery and expose all timers in an accessible list. Timer end names correct dish, announces through existing behavior and never completes automatically. Native reachability remains required.

## Imported video cover
Use accurate copy Cover from the video post rather than asserting a thumbnail is certainly the first frame. Body: Choose a photo or screenshot of the finished dish. CTA Choose a better cover opens existing Edit cover. Secondary Keep this cover dismisses only this gentle prompt.

Show one inline prompt after successful video-post import/review, not a blocking permission/modal chain and not before save succeeded. If user already chose/replaced a cover during import do not prompt. After Keep, use a quiet persistent source line under/on the cover: Cover from video post · Change cover, while provenance still matches. After successful replacement, remove that provenance prompt/line. A later voluntary Edit cover remains available.

Use reliable cover origin/user-replacement state, not publisher alone or coverChecked alone (that records crop checking, not every provenance fact). Do not automatically edit covers again or remove originals/restore options. Existing edit flow still owns choose/crop/save. Picker cancel or save failure preserves existing recipe/cover and prompt opportunity; show retry through existing error path. Replacement must not edit recipe steps, timing or active session. No promise to extract the video's final frame or to access unavailable video.

## Visual proposal references
Rendered in Joe's chat, not native fit evidence:
- Folded photo-first/This Week: exec-7bd3dd39.
- iPhone whole-meal Cooking/day multi-check: exec-5a789af6.
- Video-cover inline prompt/existing editor: exec-8dfb9b82.
Recipe text, generated ingredients/icons, exact statusbar, device proportions and timer values are illustrative. No new app tabs; only Tonight/Cooking/Recipes. These new boards await Joe's approval.

## A1 suggested acceptance focus
Today+6 stable date order/rollover; swipe nonmutation; planned/empty/default-photo cards; saved multi-dish selection including Add new; cap/unchecked timing/save failures; labelled timers and timeline with no session resets; rotation/Done return without takeover of active Cooking or modal edits; VoiceOver paging/AX/scrim/Reduce Motion; video prompt once with true provenance, keep/cancel/failure/replacement/restore behavior. Record actual native geometry and raw captures, no mockup-as-proof.

— A2
