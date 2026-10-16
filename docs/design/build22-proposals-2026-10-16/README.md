# Dinner, Together — Build 22 design proposals
Prepared by A2 on Friday, October 16, 2026, after Joe moved the handoff deadline to today. Responds to A3's consolidated directive in issue #24, comment 6214907671.

**Status: proposals for Joe's visual approval. Posting these boards does not approve them.**
Source baseline reviewed: `wip/build22` at `e879b35`. These are visual concepts, not native screenshots or fit/contrast verification. No production source, project entries, workflow, or test changes.

## Boards
1. [Alarm, Live Activity and tent surfaces](01_Alarms_Live_Activity_Tent.jpg)
2. [Editable Timing cards](02_Editable_Timing_Cards.jpg)
3. [Warmer Duo Cooking pages](03_Duo_Cookbook_Cooking.jpg)

## 01 — Alarm, Live Activity and tent surfaces
- Carry the approved cream-and-olive timer family across countdown surfaces. Countdown sits inside a circle when space supports it; dish and step remain attached to it.
- One timer gets a generous ring. Multiple timers show the next to finish first and up to three named secondary timers. This is a four-visible presentation, not a new restriction on the timer store. If more are running, show a count/overflow route rather than silently hiding their existence.
- A finished timer takes attention priority and says “Time’s up” / “Check the food.” Expiry never completes a step. Stopping an alarm, dismissing a finished timer, and Mark done remain distinct actions.
- Lock Screen: compact horizontal card. StandBy/tent: larger countdown with named secondary rows. Minimal Island: a timer glyph; compact Island: glyph + system countdown; expanded: dish, step, countdown and secondary timers as space permits. Never force the full app card into a compact Island.
- Keep named timers identifiable when dish names repeat: accessible labels include dish, step, status, remaining time, and a stable timer identity. Do not merge timers by dish/title.
- Ring animation is illustrative. A3 must verify the supported timer-relative API on each system surface; use a static ring with a system-updated numeric countdown if a live arc is unsupported. Do not rely on an app tick loop while backgrounded.
- The alerting alarm is SYSTEM-DRAWN. Its depicted styling is illustrative, not a custom layout to implement. Supply permitted title/tint/Stop; show secondary Open only if implemented through a supported App Intent. Do not add a custom photo/ring to the system alarm alert.
- Device shape, camera placement, posture activation, wallpaper, dates and system chrome are illustrative. A native capture and Joe's hardware check must establish actual tent-mode behavior.
- Reduce Motion removes decorative easing; Reduce Transparency uses a solid readable surface. At larger text, use named rows instead of tiny secondary dials. Keep Stop/Open reachable on supported surfaces and never make a decorative leaf an action.

## 02 — Timing step cards
- Compact card order: step number/title/detail; obvious duration edit control; visible two-state Needs you/Hands-off control; Edit directions and quieter Remove step side by side.
- Duration label: “20 min · Edit time.” Selected hands-off state has a filled treatment AND checkmark, so color alone does not carry state.
- The selected hands state is one mutually exclusive value. Selecting the already selected segment is a no-op; do not implement it as two independent toggles.
- At larger text or narrow widths, allow rows to stack with wrapping labels and full touch targets. Do not shrink text to preserve the compact arrangement. The broad AX example illustrates hierarchy, not proof that both segments fit at AX3.
- During cooking, each row has its own eligibility. Not started remains editable. Running: “Cooking — can’t edit this step.” Completed: “Completed — can’t edit this step.” A lock icon supplements the words. Do not expose enabled-looking edit controls on locked rows.
- Save rechecks current step eligibility. A refused edit leaves the editor available with the reason. Failed persistence rolls back the recipe and keeps the user's draft for retry.
- Wording edits preserve stable step ID, minutes and hands state, and update the matched Directions text too. If matching is ambiguous, show the existing error rather than silently diverging.
- Changes refresh the remaining Cooking plan; actual starts, running deadlines, completed records and the chosen serving time remain intact. If the meal becomes late, use the existing readiness report/review action. The amber note is an example of that existing surface, not a second competing warning.
- The bottom “Save updates” artwork is explanatory board copy, NOT a new global Timing Save button. Duration and wording editors retain their established save flows; the hands control retains its established persistence flow.
- Any decorative tagline in the board is not new product copy. Add a step is NOT included in this proposal.

## 03 — Warmer Duo Cooking
- One recipe in a usable book spread: photo LEFT with adjustable frosted Right now card; current step, circular countdown and explicit Mark done stay on that card. Coming up/Directions reader RIGHT.
- Two recipes: cream cookbook pages, SIDE LEFT / MAIN RIGHT; small real dish thumbnails beside serif names, discreet leaf, light separators and warm paper cards. No full-bleed hero photo replacing either recipe.
- Each page keeps its own Coming up/Directions tab and reading position. Selecting a page, previewing an upcoming step, or switching Main/Side never starts/completes a step or resets timers.
- “Ready to start” has Start step. Running shows a countdown and the appropriate existing cooking action. An ended timer shows an amber 00:00 attention state and “Check the food”; completion still requires the user's action.
- Opened upright: one readable page with Main/Side selector and a persistent named status strip for the other dish. Each dish keeps its reading position. With three/four dishes, retain a quiet Change side selector; never squeeze extra columns in.
- A hands-on overlap note names both affected dishes/steps and its time window. It warns; it does not claim to resolve a conflict. Present the dinner time once.
- Preserve Tonight/Cooking/Recipes navigation and existing overflow, accessibility and cooking actions even where omitted for space in a concept. Mocked bottom placement is illustrative: retain the app's native adaptive tab/rail placement. In-app material is warm frosted glass, never a new opaque black side strip. Hardware bezel and system-owned chrome are separate.
- Warning/status strips must not cover navigation or touch targets. The two-dish panel omits navigation to emphasize page structure; implementation MUST retain it, allowing content to scroll instead.
- Spread eligibility follows usable window geometry, safe areas and Dynamic Type. Fall back to one readable page rather than force two narrow pages. Decorative paper/leaf/shadows must not lower contrast or crowd controls.

## Verification handoff
A3 owns native implementation and integration; A1 owns tests. Review real captures on standard text, AX3, light/dark, reduced transparency, and opened/upright/closed windows. Check 1/2/4 timers, expiry while backgrounded, retry without duplicate activity, long/duplicate dish names, mid-cook not-started edits and save failures. Simulator results alone do not confirm real-device alarms through silent/Focus or tent behavior.

The JPEGs were produced with the built-in image-generation tool. Prompt text is preserved in GENERATION_PROMPTS.md. JPEG conversion changes format only. Approval and implementation notes belong in issue #24.


## Full-screen tent and nightstand requirement — latest Joe direction
Joe explicitly requested: “I want the times [timers] to be full screen in tent mode and nightstand mode.” The revised board 01 supersedes its initial inset-card tent/nightstand composition.
- BOTH tent and nightstand timer layouts fill the full usable display edge to edge inside the hardware bezel: one generous olive ring/countdown, named dish and step, secondary timers arranged with breathing room. Respect safe areas without introducing decorative black strips or a floating-card screen.
- Treat this as a full-screen in-app design target. A small system Live Activity card is not a substitute for that requirement. If the system-controlled locked/StandBy route cannot fill the display this way, implement a dedicated in-app timer presentation and document the separate background/locked alarm/countdown behavior.
- Keep an accessible way to exit, inspect every timer, Stop/Dismiss a selected timer and return to Cooking; artwork simplifies these controls and does not authorize removing them. Do not interpret Stop as completing a cooking step. Show more-timers count/route when needed.
- A3 should confirm entry/exit, foreground and auto-lock behavior, orientation changes and background transitions. Exit restores the prior route and timers; no timer restart on pose or mode change. Actual full-screen fit and alarm delivery require native captures and hardware checks.
