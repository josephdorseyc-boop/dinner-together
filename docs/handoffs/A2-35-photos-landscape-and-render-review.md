# A2-35 — photos on Tonight/Cooking; landscape sequencing
October 13, 2026. Response to A3's updated build13 handoff. Source reviewed at wip/share-extension b96c47fc; this document specifies proposed behavior, not implemented UI. A3 owns app integration; A1 owns validation. No active branch edits or new CI dispatch by A2.

## Decisions
1. Cooking stays on Theme.cream (the current theme's light/dark surface). The recipe's colors can tint the photo's transition and card ornament, not the whole Cooking page or operational text. Keep tomato actions and established warning/overdue colors.
2. Tonight can lead with the chosen recipe's photograph. RIGHT NOW uses a much smaller crop, collapsing to a thumbnail when space or urgency requires it.
3. Use existing saved covers only in phase 1. Catalog dinners keep the branded symbol/text treatment. No synthetic food photo or publisher photograph is being supplied for catalog/store assets.
4. Agree to A3's build15 short/wide render leg before enabling phone landscape. Defer the orientation change from the current validation; preserve Duo compatibility as a 1.0 requirement. Build15 can remain a pre-submission validation milestone. Do not infer shipping compatibility from the failed older Duo run or from a build compiled with a different selected toolchain.
5. Store frame5 remains A2-32: “Your recipes. Your timing.” / “Bring a recipe. Check the steps. Make a plan.” Use the standard typed-recipe Plum capture; do not redo the settled decision.

## Tonight composition
Keep the page centered to the current 720-point maximum; regular width does not mean enlarging a phone screenshot.

Order when a saved recipe is chosen: page heading; TONIGHT'S DINNER card; dinner-time card; any feasibility notice; choose-recipe action; catalog menus. The build/back-to-cooking action stays in its current safe-area inset, including the truthful “Build plan for <time>” behavior. Selection and progress-reset confirmation do not change.

| State | Cover treatment | Text and actions |
|---|---|---|
| Compact, default text | 120-point crop band inside a 24-point rounded card; bottom fade into the card surface | Title and timing/step summary below the photo on an opaque surface; tap opens recipe |
| Regular, default text | 160-point band within the same bounded column | Same hierarchy, without giant type or full-screen wallpaper |
| Accessibility text | 48-point inline thumbnail, or omit decorative image if it crowds text | Title wraps fully; no truncation of feasibility or serving time |
| No cover / file missing | No empty hero region; keep existing symbol and recipe details | Same actions and information; no “add a photo” interruption |

Image heights are starting design values, not fixed acceptance guarantees. Favour a tighter crop over a taller card. Preserve a user-confirmed cover crop; do not OCR or recrop again to decorate Tonight.

## RIGHT NOW composition
Existing order and semantics remain: serving-time controls, RIGHT NOW featured step, and (for an expired timer) the readiness notice after the food check. The photograph must not reorder these priorities.

| State | Cover treatment | Required foreground content |
|---|---|---|
| Compact, default, ordinary start | Up to 64-point top crop strip; subtle transition into the card surface | Dish, actual step instruction, attention label and Start this step |
| Regular, default, ordinary start | Up to 96-point strip within the existing action column | Same content, timeline remains the adjacent column when it fits |
| Expired timer, readiness warning, or short viewport | 40–48-point trailing thumbnail within existing header row; no added vertical photo band | Check the food, overdue timer, pinned deadline and Mark done after checking stay prominent |
| Accessibility sizes, either width | Omit the decorative cover or use a 32-point inline thumbnail only if it fits without compressing text | Full step text and actionable controls; no smaller text to make a photo fit |
| No usable cover | Current symbol/text card; no reserved photo height | Identical actions, scheduling and timers |

Use view bounds and content size to choose the compact treatment; a content viewport around 600 points tall is a useful starting trigger, not a device-name test. If the primary action becomes harder to reach than the current image-free state, shrink/remove the photo first. Do not let an image hide the expired-timer action at the fold.

Put no timer, instruction or action text directly over food photography. The transition may borrow the recipe wash but must resolve to the theme's opaque card surface before operational text. A recipe's deep/pale page setting does not change the Cooking page's root appearance.

A recipe cover depicts the dish, not the current step. Do not imply that a finished-dish photo illustrates “preheat” or proves doneness. No tappable photo/crop editor on RIGHT NOW in this phase.

## Timers and timeline
Use 32-point covers at a recipe/dish group header, not repeated full images for every step. Retain the existing step-state/attention symbols and all start/end/deadline labels. In AX layouts, drop thumbnails first. For today's single imported-recipe plan, show its cover once per visible group; do not invent independent photos for its parallel branches.

## Implementation boundaries
- Resolve selected recipe through RecipeLibrary.recipe(menuID: store.session.menuID); reuse RecipePhotoCache.load/imageURL. CookingView will need access to the existing library. Keep decoding/palette sampling cached by filename; do not decode on every TimerCenter tick.
- A missing/deleted/unreadable cover falls back synchronously to the no-photo state; local images must work offline.
- No changes to timer creation, actual timestamps, undo snapshots, feasibility or notice logic to support imagery.
- Keep current accessibility IDs and actions. Decorative covers should be hidden from accessibility where the same recipe name is already spoken.
- Keep layout/scroll positions stable when an image becomes available; do not add automatic animation around clock ticks.
- New camera capture, catalog photo storage, per-step image extraction and Live Activity are separate future increments. They are not prerequisites for phase1.

## A1 capture contract for A3's next planned photo implementation
Use existing deterministic import/cover stubs, not Joe's privately supplied publisher screenshots. Cover samples: one pale, one deep, and no cover.
Capture compact/default Tonight; ordinary RIGHT NOW; expired-timer RIGHT NOW plus readiness; compact AX3 Tonight and expired timer; regular two-column Cooking; short/wide outer-style viewport. If one AX capture cannot show both full instruction and action, take top and continuation captures rather than shrinking text.
Assert the urgent primary action remains hittable, deadlines survive layout/pose changes, and missing covers leave the same controls. Verify meaningful tab/sheet/draft continuity; a shared top-level route alone is not sufficient.
Native source/runtime screenshots are authoritative. The earlier generated Duo mockup is a composition concept, not a test image or a list of already-shipping features.

## Updated copy and palette review
A2-34-edit-scope-copy.patch is a separate two-string patch against b96c47fc. Source-review finding: “Fix anything the import got wrong” overstates an editor that changes only title/yield. Use “Change the title or yield. Review timing or remove steps on the Timing tab.” and sheet title “Title and yield”. Keep menu item “Edit title and yield”, blank-title message, yield example, Save changes, and failed-save wording. The existing UI assertion for “A recipe needs a title.” remains intact. Applicability check passes; native rendering/compilation unexecuted by A2.

Simulator rendering review, immutable fa04aa0 artifact ui-review-evidence-38425982728: sampled iPhone r19a/r19b, r19c AX3, r19d AX3; iPad r19c; classic iPhone r14d. Pale wash, dark text, selected paper capsule and More glyph read clearly in those samples. Retain the floors/clamp/PaleText for this pass; no retune required from these renders. The synthetic cover establishes transition/layout behaviour, not appearance over Joe's actual food photo, real-device contrast, or VoiceOver.

S3 capture/layout follow-up: r19c-pale-timing-ax3 shows the long introductory explanation before any editable step row, with Timing looks right already pinned. It does not demonstrate readable/editable timing rows. Photograph the first row and confirmation separately. Consider a shorter AX-only introduction: “Check each time and attention label against your recipe.” Put the full explanation behind an accessible detail disclosure; keep all actual step details. This is a design recommendation, not evidence of inaccessible rows.
r19b AX framing was already corrected in ef85e7a; review its new capture instead of reapplying that change.

## Validation and release provenance
ef85e7a native run38447317751 is in progress. Latest b96c47fc Duo run38448870850 is in progress and includes the More-menu identifier fix. Older Duo38425944734 has failed; it is not compatibility signoff.
The handoff's earlier “release13 from8b910f7 if fa turns green” paragraph is superseded by the integrated changes. Choose the final submission SHA explicitly and require its relevant checks. Photos should not change an already-running validation tree.
