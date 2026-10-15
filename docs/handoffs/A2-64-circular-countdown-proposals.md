# A2-64 — three circular countdown timer proposals
Requested by Joe October15,1:43PM Denver: circle with countdown in the middle, several mockups and3proposals for A3. Status: PROPOSALS, awaiting Joe's selection/approval. A3 owns platform feasibility and implementation; A1 native verification.

## 1. Cookbook ring — recommended default
Warm cream, olive finite circular remaining-time arc over a faint track. Large centered tabular countdown, dish name above and step/state below; small decorative leaf. One timer gets a generous circle;2timers side by side;3–4 use an equally readable grid if space allows. This is the clearest across-kitchen baseline, least dependent on photos and materials. Use an accessible list instead of forcing4small circles at AX/short height.
Visual in Joe's chat: exec-ba8048ea.

## 2. Frosted photo timers — photo-focused alternative
Same centered circular countdown, but a translucent ivory glass disc over the recipe's own hero photo, or existing default background. Strong text/ring contrast across pale/busy/dark images. With several timers use consistent glass tiles/background rather than an invented composite or generated imagery. User's actual photo/default assets only.
Reduce Transparency/Increase Contrast falls back to opaque cream, matching option1. No new adjustable-opacity control is implied for timer discs; existing approved Cooking card opacity remains separate.
Visual in Joe's chat: exec-77fcd36f.

## 3. Next-up focus — prioritization alternative
One large circle for the nearest deadline plus named smaller circles/list for other timers. Ended/unacknowledged timers take priority with clear Time's up; never disappear automatically. No automatic carousel hiding a timer. Stable order/tie-breaker and no reordering under a finger/VoiceOver focus. If others cannot remain readable show a named count and View timers, with expired count/state explicit.
Compact Lock Screen/Island content can use this information hierarchy regardless of selected visual skin. External-system presentation and interactions require validation; generated dimensions/black island are illustrative, not native acceptance evidence.
Visual in Joe's chat: exec-37f9833f.

## Shared circle/countdown specification
- Countdown always IN the circle. Dish + step associated with every timer, including multiple simultaneous timers for one recipe. Recipe count1–4 is NOT a cap of4active kitchen timers: durations/steps can produce more. Grid has a presentation capacity, not a storage limit. Show +N timers/View timers without hiding expiration; list retains all timers.
- Read remaining duration from stored absolute deadline and original duration, never a fresh render-local timer or an app process updating every second. Preserve IDs/deadlines on relaunch, selection, pose changes and Live Activity updates.
- Ring represents remaining fraction, starting full and draining clockwise; numeric time is primary. Known positive original duration required. At zero, no continued spinning, no negative count or misleading completed-food badge:00:00 + Time's up. Amber outline/status is attention, not fractional progress. Gravy's amber full outline in board1 is an ended-state outline, not100percent remaining.
- Use mm:ss under one hour and h:mm:ss when needed; no truncating a real duration to fit. Large tabular numerals, high contrast and no second-by-second VoiceOver announcements. State changes announce through existing behavior.
- Timer end does not mark a recipe step complete, replan dinner or assert food is cooked. No Mark done inside kitchen timer controls. View timers opens named details; Stop is explicit, separate, named and at least44pt. Tapping the ring should not silently stop/reset.
- Progress arc, colors and illustrative times in generated boards are not measured or mutually calibrated; code uses actual fraction. No hardware/display fit certified by images.
- Reduce Motion: no pulse/parallax/sweeping decorative second hand. Countdown remains accurate. System ambient/night rendering is respected; this proposal does not turn Cooking dark or change the Tonight-only dark-page rule.
- Timer source must remain explicit. A3's QuickTimerStore timers from Directions are independent of cooking-plan execution. Do not manufacture a second execution countdown or silently merge independent timers by dish/title. A reliable ID/source governs interactions.

## A3's Build21 Directions button / persistent timer question
Reviewed RecipeViews.swift at aa9a112: direction durations create their own QuickTimers; capsule is tinted idle, filled running, amber when ended. This fits the visual vocabulary. Recommend:
1. Idle clear Start15min/Start30sec action; don't display tiny decorative circles instead of readable source duration.
2. Running capsule shows timer glyph + countdown and an explicit/named Stop target; avoid a whole countdown that silently stops on any tap. If retaining current whole-button stop, make the stop affordance and VoiceOver action unmistakable.
3. Add a persistent compact Running timers strip when timers exist on Cooking and Directions; say e.g.3timers · Next: Green beans02:10, with named Time's up attention first. It opens the same full timer list/circular view. Keep current cooking action reachable; at AX use a concise accessible summary, not4tiny dials.
4. The full circular presentation can be in-app first; Build22 tent/Live Activity reuses source state. Do not replace all under-step buttons with large rings or add a new top-level Timers tab.
5. Source's minHeight40 should be reviewed for an actual44pt touch target. Accessibility label should include dish, step and duration/remaining, especially when a step has two durations. Stop named per timer. No pause/resume feature invented by boards.

## System surfaces / feasible rendering
Build22/#24 remains a proposed Live Activity/tent implementation; outer-display StandBy behavior, signing, interaction and stale-state limits are not validated by this design. One timer source/store, no posture API assumption. A3/A1 should establish actual supported surfaces.

Lock Screen: compact named timer/ring plus count/ended state for others. Expanded Island: next dish + step + countdown, total/ended count if it fits. Compact/minimal Island cannot show a readable four-circle grid; prioritize next/ended cue and use the app's details for all timers. No invented controls that widget APIs cannot perform.

Apple primary references reviewed:
https://developer.apple.com/design/human-interface-guidelines/live-activities
https://developer.apple.com/documentation/swiftui/progressview/init(timerinterval:countsdown:label:)
Apple notes date-relative ProgressView initializers don't support custom styles. Therefore do not assume a custom circular arc can be implemented merely by applying circular style to the date-relative initializer. A3 should validate a supported system-driven countdown/progress representation on EACH widget/StandBy surface. If accurate proportional-ring updating isn't supported, use a static decorative circle with accurate system countdown INSIDE, not a frozen arc pretending to be live. No once-per-second ActivityKit push/update loop.

## A1 verification
Original deadline consistency across app/widget/relaunch; two durations in one step;30seconds vs30minutes; expired vs stopped vs completed-step state; multiple timers same dish/step; >4timer presentation and expired visibility; source identity; photo contrast/solid fallback/AX focus; system source updates and stale-state behavior; actual tent screen/pose capture and device interaction. Keep raw evidence separate from rotated presentation exports.

## Recommendation / decision
Choose1for primary readability, reuse2where photo-focused visual is desired, consider3only if the priority hierarchy is preferred. These are alternatives, not a request to implement three themes. All three satisfy Joe's required centered countdown circle. Pending Joe's choice, no implementation/CI patch from A2.

— A2
