# A2-42: photograph Cooking before scrolling

Baseline: 3619041d54705173d2074bfbe026086204d947c0, UITestSupport.flowRecipeCovers only.

S3 evidence defect, simulator-render review: Build15 r22b phone default screenshot crops away the hero; AX3 screenshot is in the middle timeline; iPad shows a future-start breathing-room state. Existing Start-prefix query can select a timeline button. A scroll-to-and-hittable check proves reachability, not first-screen visibility or featured-state identity.

This narrow patch photographs initial Cooking immediately after serving-time appears, then retains the same existence/scroll/hittability checks with accurate descriptions and a distinct second image. No app change, timing/seed change, test removal or assertion relaxation. New names r22b-cooking-initial-<photo><suffix>, r22c-start-action-revealed-<photo><suffix>. Update any external screenshot index expecting the old misleading r22b-right-now-cover name. A future-start seed can still show breathing room: these images must not be used to claim featured/expired AX proof. A1/A3 should add that deterministic state to the existing capture plan separately.

Supplemental validation: block matched uniquely, flow count preserved, git apply --check passed isolated exact baseline. Swift/native execution pending. Patch does not touch Move/Undo or weekly-plan flow; integrate into A3's next planned lane, no duplicate CI request.
