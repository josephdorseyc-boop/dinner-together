# A2-60 — Duo Cooking spread proposal
Issue23 request from A3, October15,07:39 Denver. Status: PROPOSAL FOR JOE APPROVAL. This extends the approved recipe-reader aesthetic to Cooking; it does not change engine, SessionStore, deadlines, task order or completion rules.

## Mockups prepared
1. Sideways: Right now LEFT, Coming up RIGHT.
2. Upright and larger text: single-column Cooking with timer-ended notice and return-to-current access.
Shown in Joe's conversation; images not attached to GitHub. Generated hardware/system icons, content values and pixel dimensions are illustrative, not platform guidance or evidence of tested fit. Do not reproduce synthetic system chrome. App uses actual safe areas, system rail and navigation.

## Shared appearance
Cooking remains CLASSIC CREAM in both OS appearances and regardless of Tonight's Light/Charcoal choice, per A3's current relay of Joe's decision. Dark Mode is Tonight's alone in that scope. Warm ink/olive, serif section/step titles, thin hairlines, minimal card chrome, small terracotta leaf where space permits; leaf decorative/VoiceOver-hidden and never displaces overflow. No large food images in this action-focused screen. No heavy dark footer.

## Corrected single-recipe default — Joe, October15,07:59 Denver
With ONE recipe, the spread features the hero photo: LEFT is its full-bleed cover with minimal title/byline; RIGHT is the current cooking step, its deadline timer and primary action. This supersedes any implication below that the timeline replaces the photograph for a single-recipe dinner. Use the existing cover placeholder when no photo exists. Keep photo framing and reader styling consistent with the approved recipe spread.

Upcoming steps for that recipe remain accessible through a quiet Coming up action/disclosure; they do not occupy the photographic page by default. Browsing them never mutates execution. A timer ending still surfaces the named notice and View step, returning to the actionable RIGHT page. The current action docks within the RIGHT page's safe area for this layout. Upright/narrow/AX3 keeps current-first single-column behavior.

The proposed LEFT=NOW / RIGHT=TIMELINE layout below is for MULTI-DISH dinners (2–4), still pending Joe's approval. Do not treat his single-recipe correction as approval of the remaining Cooking proposal. Rendering tests must check both different compositions.

## Sideways MULTI-DISH proposal: LEFT is NOW, RIGHT is TIMELINE
Necessary condition from Joe: window width >=600pt. Also measure real available content width/height after the system rail, safe areas and bars. Do not assume inferred678x466 is actual captured geometry or hardcode it. Enable two columns only when both readable columns and the action fit. Otherwise single-column fallback; never shrink text to force spread.

LEFT:
- Small common serving time and dish count.
- Right now heading, current recipe name, step title, deadline-based timer.
- Current step's existing actionable control Start/Mark done/Mark done after checking according to state. The label and allowed actions are derived from the current engine/session state, not copied from another step's preview.
- Primary action docked within LEFT page's visible safe area, always reachable without scrolling the timeline, above actual system chrome. Body instructions/details can scroll independently with content inset equal to actual dock height. Timing details stays secondary, after/away from action priority.
- When overlapping hands-on work exists, short warning "Hands-on overlap ·6:50–7:00PM", involved recipe names, with access to full explanation. Actual values from engine; never claim auto-resolution.

RIGHT:
- Coming up heading and chronological rows across the WHOLE dinner. Group by time/Next/Later when helpful, never by recipe in a way that conceals execution order.
-2–4dishes: each row explicitly names its dish, start, step title and duration; optional accent/dot supplements text. Simultaneous rows remain separate and show equal start times. Stable existing order for ties.
-One dish: dish name once at section heading is sufficient, but accessibility labels retain identity. Preserve any concurrent timers already supported.
-No future-step checkbox or action that implies a step started merely by browsing.

## Step previews
A3 suggested tapping an upcoming row brings it left. Support this as an explicitly labelled PREVIEW:
- Left title changes to "Preview"; dish/step and details shown. No engine advancement, timer start, completion, reorder or replan.
- Keep a compact persistent CURRENT step/timer strip and "Back to Right now". Current action remains accessible from that strip or its separate dock; it must be clearly labelled with the current recipe/step, never look like completion for the preview.
- Safest first implementation if that cannot remain clear at short height: preview inline/on a separate reader surface and leave current card on LEFT. A3 can choose this narrower presentation; do not expose ambiguous Start/Done in a preview.
- Return restores both timeline scroll and current-detail scroll. Previewing any dish is distinct from dinner membership edits.

## Timer ends while browsing
- Persistent notice "Timer finished — check [dish]" plus "View step" while its timer remains at0:00/current existing expired display.
- Do not auto-complete, auto-start another step, reset timer, change dinner time or force-scroll the timeline.
- View step returns focus to the relevant current/expired step on LEFT or the current view in single-column, preserves prior timeline reading position for return.
- Continue existing notification/haptic/announcement behavior; don't introduce duplicate alerts merely because two panes observe same state. Accessibility announcement should not repeatedly steal focus.
- Several expired timers: concise count, access to named existing steps ordered by existing engine/session priority. No new timing behavior or silent dropping of timers.
- Mark done after checking retains existing confirmation behavior.

## Upright/narrow fallback
Recommend single-column Right now first, Coming up below, rather than Now/Next switch that hides current action. When browsing a long timeline, a compact current-step/timer return strip remains available with sufficient scroll insets; expanded current controls must be reachable by View step/Back to Right now. No app switch that changes execution state.

Upright recipe-reader Main/Side switch remains as Joe requested; Cooking's different Now/Coming up hierarchy need not mimic that switch. Rotation preserves current step, selected preview, both reading positions and deadlines; no duplicate SessionStore or timer ownership.

## AX3
Use single readable column if columns don't fit. Full dish names wrap; no fixed-height clipping. Primary action reachable above real chrome; long details scroll above it. Compact summary for overlap warning can expand to full readable content. Decorative leaf hides first. No 2-column fallback that makes side tasks inaccessible; timeline retains all dishes.
At600pt window, rail/insets may leave much less content; threshold is not proof. Prove available fit in native captures.

## Acceptance for A1/A3
-1dish and2/3/4dishes, chronological mixed rows and clear identity.
-Active step action visible/reachable on first screen in actual sideways geometry; never under tab/system rail.
-Future preview leaves progress, deadlines, selected dinner and serving time unchanged; current versus preview controls unambiguous.
-Timer ends while right timeline or preview is focused; no forced jump/auto-completion; View step and return preserve place.
-Multiple timers/overlap state use existing model priorities.
-Upright/sideways/AX3 fallback retains all recipes and state after folding/rotation/relaunch.
-Cooking stays cream under both OS appearances and Tonight themes; status/system controls remain readable.
-VoiceOver order, dish labels, selected preview, announcements, >=44pt targets, no leaf/overflow overlap.
-Real rotated screenshot required: current sideways dimensions inferred only. Mockups do not certify fit.
-Screen implementation after Joe approval; model/test prep remains with A3/A1.

— A2
