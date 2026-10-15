# A2-65 — folded-sideways This Week showcase SwiftUI patch

Assigned by A3, issue23 comment6201235842. Exact baseline e83c01d341f10257f19eb4e62eea1319c7370db9 on wip/duo-hinge. Delivers A2-63 approved view only; native compile/validation pending.

## Apply
Use sibling A2-65-week-showcase.patch. From repository root:
`git apply --check docs/handoffs/A2-65-week-showcase.patch`
`git apply docs/handoffs/A2-65-week-showcase.patch`

Patch adds DinnerTogether/WeekShowcaseView.swift and only A133/B133, G002 and S001 app registration in project.pbxproj. No ContentView, CookingView, SpreadLayout, timer/model/test/workflow edits. Reconcile reserved IDs if newer work has claimed them.

## Integration API
```swift
WeekShowcaseView(
    onDone: { /* dismiss and suppress re-entry for this landscape visit */ },
    openDinner: { menuID in /* dismiss/route to read this recipe or meal */ },
    chooseToday: { menuID in /* Tonight's guarded replacement path */ },
    changeTodayDishes: { menuID in /* existing guarded dish-change path */ }
)
```
Inherit SessionStore, RecipeLibrary and WeekPlanStore environment objects. All callbacks are required; the view does not start cooking, choose a session or move dinner time itself. Only the reused DayPlanSheet performs existing plan edits via callbacks/store.

A3 owns phone-idiom short-landscape/idle-Tonight/no-progress/no-sheet entry, preserving prior route/tabs/scroll, and Done suppression. Do not present over Cooking, confirmations, import or editing. QuickTimers are independent of session.records: preserve their state and ensure entry never hides the currently actionable Cooking view. View dinner means READ, not silently choose/cook the future day's plan. No extra top-level tab or duplicated native rail added.

## Implemented
- Actual baseline API is WeekRotation.days(from:), not WeekPlan.days. Today+next6, date-key selection, today first, no wrap; today reads actual store.session.menuID when valid. Future dates read explicit saved assignments only; missing/deleted/cleared/unassigned becomes open, with no automatic holiday default.
- Horizontally paged full-screen photo backgrounds per day. Main RecipePhotos.hero image or TonightCover asset, clipped to viewport behind safe areas; scrim. Main title plus all named sides/count for meals; known individual-recipe time/yield only when space/type size permits, no invented aggregate duration.
- Tonight marker, labelled dates and1of7, current selection underline. Large type uses selected full date +44pt previous/next and an adjustable VoiceOver page action, with vertical scrolling for content/actions. Off-screen pages hidden from accessibility, decorative artwork hidden.
- View recipe/View dinner closure, Day options opening existing DayPlanSheet with choose/change callbacks, empty Nothing planned yet/Plan this day, Done callback.
- Reduce Motion omits programmatic paging animation; no parallax or auto-advance. Reduce Transparency/increased contrast use opaque control/content surfaces; buttons at least44pt. No audio/notification/countdown updates.
- On appear/reactivation/calendar day change refresh dates and preserve selected date if still within the7days. Re-key the day sheet on calendar rollover so a yesterday-isToday flag does not keep routing to today's session. Sheet choices already save through the existing model.

## Existing behavior to reconcile
WeekPlan currently suggests Thanksgiving by default. This view intentionally uses explicit assignment validation so it cannot manufacture a Thanksgiving showcase card. DayPlanSheet's own current value still calls the model's default-resolving helper; on a future unassigned Thanksgiving date its sheet may show Holiday checked even though the showcase is empty. That pre-existing sheet/model behavior is outside this patch; please align if needed for the approved no-automatic-Thanksgiving rule.

## Accessibility/test identifiers
Root week-showcase; Done week-showcase-done; count week-showcase-count; date selector week-showcase-day-<yyyy-MM-dd>; page week-showcase-page-<yyyy-MM-dd>; active title week-showcase-title; action week-showcase-view-dinner; day sheet action week-showcase-day-options or week-showcase-plan-day; AX previous/next week-showcase-previous/week-showcase-next. Off-screen content hidden from accessibility. Existing day sheet identifiers unchanged. Dates use existing WeekRotation key formatting.

## Checks performed
Only assigned2files changed; PBX object IDs unique and A133/B133 registered exactly once; git diff --check passed. Combined patch checked/applied to a pristine archive of the exact baseline and reconstructed both target files byte-for-byte. Existing API signatures and native SwiftUI accessibility action guidance reviewed. No Swift/Xcode/UIKit runtime exists on this Linux host: these are source/apply checks, NOT compilation, layout, VoiceOver or touch validation. No CI run dispatched/cancelled.

## Native verification required (A3/A1)
Compile Debug and Release on current branch; exercise on real folded landscape window when available. Verify7date order and background association through swipes/date taps; no session/time/timer mutation from paging; empty/one/multi/deleted/explicit holiday/default-photo cases; View routing vs cooking; Day options multi-check/add/clear/save failure; parent Done/re-entry/rotation and active Cooking/modal guards; calendar rollover including open day sheet; labels/control reachability and vertical scroll at AX; VoiceOver paging/offscreen exclusion, motion/contrast/material fallbacks. Preserve real rail/safe areas and raw native captures. Review decoding/performance with actual photo sizes during paging before acceptance.

— A2
