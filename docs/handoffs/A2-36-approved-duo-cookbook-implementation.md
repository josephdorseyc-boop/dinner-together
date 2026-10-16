# A2-36 — Approved Duo cookbook: first implementation slice
Prepared October 13, 2026. Product/design owner: A2. Integration: A3. Engineering verification: A1.

## Decision and evidence
Joe approved the combined concept and its frosted-glass drawer on October 13.
The concept is an AI-generated design reference, not a simulator screenshot or device test.

The first deliverable is one real, interactive Cooking spread: photo-led left page, cream cooking workspace right, a revealable glass navigation drawer, and preserved cooking/navigation state when resized. Use existing art until this slice is working. The full illustration set and unrelated weekly-planner changes must not block it.

Approval record: https://github.com/josephdorseyc-boop/dinner-together/pull/14#issuecomment-6156842146

## Inspected baseline
Source review only, wip/week-plan cd98223dbb79cd31fff1e1653be638cd7068f9e3:
- ContentView.swift owns one destination and recipePath across compact/regular presentations. Reuse those bindings; a drawer must not introduce another selected-tab or selected-recipe state.
- ContentView currently selects NavigationSplitView versus TabView by size class.
- CookingView currently lays actionColumn beside timelineColumn when regular and non-AX, with ViewThatFits fallback. Its dialogs, readiness review, undo and timer-derived content already exist.
- Theme.swift supplies adaptive cream/paper/ink/olive/tomato plus a fixed readable filled-button color.
- The app's Debug and Release configurations still declare only portrait for iPhone. This is an S3 source-review gap for the approved landscape composition, not proof of an executed orientation failure.
- Main release.yml already offers Xcode 26.2 or 27.1 and requires matching native/Duo evidence for the latter. No duplicate workflow is needed.

## Apple guidance checked today
Official news:
https://developer.apple.com/news/?id=kkphp5qo
Official preparation guide:
https://developer.apple.com/iphone-duo/prepare/

Apple's full-display behavior uses the iOS 27.1 SDK, including vertical system bars. A validated Debug build does not establish which SDK produced the distributed archive. Verify the selected release toolchain for the final commit.

Apple recommends current view/window geometry, resizing tests, Device Hub and the Duo simulator. An exported resizability skill is available through xcrun agent skills export. Apply it where the Xcode runner supports it; record tool availability rather than silently claiming it ran.

The October 5 announcement permits Duo-optimized submission now and says Duo screenshots become required in April 2027. Prepare real product-page assets and use App Store Connect's preview. Those are separate from the concept mockup.

## A3 implementation: three small commits

### 1. Adaptive Cooking spread using existing content
Add a wide Cooking composition in the existing layout lane. The decision uses actual available space and content fit; regular width alone is not a device identifier.

Left page:
- Real recipe cover -> cook's plate photo when available -> current illustrated-plate fallback on a soft brand-colored backdrop.
- Photo fills most of the left page and fades into a warm olive footer. Dinner title and dish names sit on a readable footer, away from the busy image.
- Preserve crop/focal content; use the available pane aspect ratio. No generated or stock food imagery is introduced by this design.
- Keep the gutter clear. The mock's center crease and hardware proportions are illustrative, not layout coordinates.

Right workspace:
- Heading, dinner time and existing RIGHT NOW content, then readiness notice, running timers, Up next/attention information and timeline.
- Reuse the existing actions and live derived state. Do not hardcode the mock's text, sample times or sample dishes.
- Keep cream operational surfaces. A photo palette applies to the visual page/drawer, not to the entire cooking screen.
- Avoid adding a photo pane outside the current action-plus-timeline columns and accidentally creating three cramped columns. In the book spread, the right pane's content can stack/scroll while the left stays visual.
- The expired-timer hero exception is Joe's decision: retain imagery only if the complete primary check-food action is visible. Short/AX layouts collapse imagery first.
- If either page becomes too narrow, use the existing compact/stacked composition. No fold transition may reset the run, restart timers, lose undo or reopen a different recipe.

First proof: a native capture with an actual recipe cover and a live expired timer. This proves hierarchy before decorative polishing.

### 2. Revealable frosted-glass navigation
Integrate at the shared navigation owner, using the same destination/recipePath.

- Slim full-height overlay at the outer LEFT of the visual page.
- Same continuous image under it; blur plus restrained warm ivory/olive shading creates the frost. A separate flat gradient is not the approved treatment.
- Tonight, Cooking, Recipes have clear labels/icons and selected state. Keep brand tomato on the selected Cooking capsule.
- A visible bookmark-like handle opens/closes it by tap; an optional horizontal drag inside its affordance also works. Do not intercept vertical content scrolling or rely on a hidden screen-edge gesture.
- Drawer expands over the visual pane and leaves the operational right pane usable.
- Choose its width from readable controls/labels, with a bounded normal-size width; do not multiply a hardware screen width or scale mockup pixels literally.
- Do not display a competing permanent sidebar, bottom tabs and system vertical destination controls all at once. Inspect the iOS 27.1 system-bar render before selecting the container strategy.
- Accessible names: Open navigation / Close navigation; selected destination announced. Reading order excludes concealed drawer controls. Closing restores focus appropriately.
- Use a suitably shaded solid alternative for Reduce Transparency and Increase Contrast. Validate text against real bright/dark renders; plain palette math cannot certify a system material.
- Reduced motion uses a quiet/nonessential transition. Navigation remains fully usable.

### 3. Pose/orientation and release proof
A3 and A1 explicitly check the current portrait-only iPhone declaration against the requested wide/landscape pose, then implement any required orientation capability in both Debug and Release. Orientation support and geometry-based layout decisions are separate concerns.

Check the exported skill's output and actual system bar/safe-area behavior. Archive with the proven Xcode 27.1 path only after the final source commit has the required green checks. Reconfirm previous iPhone and iPad flows.

## A1 focused capture/interaction contract
Use the same session/run for transition assertions; separate launches at different sizes do not demonstrate preservation through a fold.

| Scenario | Capture/assertion |
| --- | --- |
| Normal wide spread, drawer closed | Left visual page, complete current action, cream workspace |
| Drawer open/closed | Correct selection, readable labels, right-side primary action still usable |
| Bright cover / deep cover | Real material contrast, drawer tint and selected capsule |
| No cover | Intentional illustrated fallback; no empty photo hole |
| Expired timer | Check the food and full action visible/hittable before optional decoration |
| AX + short viewport | Readable operational content, accessible navigation, image shrinks before action is buried |
| Reduce Transparency / Increase Contrast | Clear opaque alternative; same controls and selection |
| Fold/resize mid-cook | Same destination, recipe UUID, serveAt, run UUID and actual timer deadline; undo remains usable |
| Selected recipe -> compact -> wide | Recipe path returns to the same detail |
| Landscape/vertical bars/sheet | No clipping or overlap; More/Done/crop action usable in the actual presentation |
| Release | Toolchain/SDK and exact source SHA recorded; archive corresponds to validated composition |

Capture names proposed: duo-cookbook-closed, duo-cookbook-drawer-open, duo-cookbook-bright-cover, duo-cookbook-deep-cover, duo-cookbook-expired, duo-cookbook-ax-short, duo-cookbook-solid, duo-cookbook-resized. Use existing naming conventions if those are already reserved.

Keep all existing correctness assertions. The earlier More-menu retry, offscreen crop-slider gesture, lazy Lagoon query and disappearing Done evidence are separate failures; this visual slice is not a reason to loosen them or to change expected dinner times.

## A2 contribution and boundary
A2 supplies this contract, reviews actual renders against the approved image, and prepares the plate/dish artwork separately. A2 is not editing A3's active app/test/workflow branches or spinning up duplicate CI runs.

Starting point for the art set: current DinnerCatalog dishes, existing PlateIllustration vocabulary, cream/tomato/olive palette, readable silhouettes at thumbnail size. Production artwork will be a separate deliverable; reuse placeholders for the first working spread.

## Ready for Joe
First milestone: a real screenshot and a short interaction recording showing the glass drawer open/close and the same cooking session surviving resize. Then polish against the approved concept, run the full checks, and distribute a TestFlight build from that proven commit.

State clearly which evidence exists: source review, supplemental check, simulator rendering/execution, or physical device. The concept alone is not a Duo-compatibility claim.
