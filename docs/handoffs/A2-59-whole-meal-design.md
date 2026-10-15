# A2-59 — Whole-meal dinners, Build 21 design proposal

Issue: #23. Status: Joe approved the revised, simpler Duo direction on October15,2026 at06:27 Denver. The approved Duo refinement below supersedes the earlier side-pill/heavy-footer mockup. Other illustrative boards remain supporting design guidance. A3 owns model/integration; A1 owns verification. This supersedes the earlier one-recipe restriction for Build21 only. Build20 is not reopened by this proposal.

## Visual boards prepared for Joe
1. iPhone Light: Tonight, recipe add/replace, dish-labelled Cooking.
2. Duo: main reader RIGHT, one selected side LEFT, one quiet Change side selector for up to three sides; optional main-photo page.
3. Large text: charcoal iPhone Tonight and cream iPad Cooking.
Generated mockups are visual concepts, not executable UI, measured contrast evidence or authoritative recipe content. Illustrative recipe amounts, cooking text and timers must not become fixtures without A1's verification. Reference existing approved assets/components and Joe's final selected boards. Default photographic page follows MAIN recipe, not the selected side.

## 1. Tonight: preserve the approved cover
Retain the main photo reaching the top, fade into paper, light status text as appropriate, frosted dinner-time card and its existing opacity controls. One serving time for the WHOLE dinner. Replace single-recipe summary with dish count and earliest start: e.g. "2 dishes · Start cooking at 5:45 PM". Times are computed by engine, not by adding recipe durations.

Below the card: "TONIGHT'S DISHES · 2 OF 4". Short ordered list: thumbnail/placeholder, complete dish title, Main designation on first item, "About 75 min", explicit icon+text "Timing checked" or "Check timing". Do not imply unreviewed estimates are confirmed. Trailing accessible Dish options offers Check timing, Make main (for sides), Remove from dinner. Removing here never deletes from cookbook. Main change follows A3 reorder model; remaining first recipe becomes main if original main removed.

"+ Add a dish" opens the cookbook/picker with visible search, existing favorites and checked/disabled existing members. No duplicate recipes. At four, show "4 dishes — dinner is full" with "Remove a dish to add another"; retain access to dish options. Prefer explicit Add affordance with clear limit message rather than silent failure.

Footer retains one plan action. All checked: "Build my cooking plan". One unchecked: "Check 1 dish's timing"; more: "Check 2 dishes' timing". Route to unchecked dish review, returning to dinner. Do not start cooking until all required timing is reviewed. Zero dishes uses existing first-recipe state. Existing session actions remain authoritative.

Illustrative dinner at7PM:75min main starts5:45PM;35min side starts6:25PM,40min later. Engine determines real step offsets and overlap.

## 2. Recipe page actions
When another dinner is chosen: primary "Add to tonight's dinner"; secondary outlined/quiet "Cook this instead". Stack vertically on iPhone and AX3; no cramped pair of pills. Above actions, brief "Tonight: Roast chicken + 1 dish". Main cover stays as selected until Make main or replace.

When already a member: text "Already in tonight's dinner" plus actionable "View dinner"; do not duplicate. At limit: "Dinner has 4 dishes", provide View dinner/options and retain explicit replacement action. No dinner: existing "Cook this".

"Cook this instead" means replace the ENTIRE dinner with this recipe; it must not be visually equivalent to adding a side. Non-cooking confirmation when replacing several dishes: title "Replace tonight's dinner?", body "This replaces the [N] dishes with [recipe]. Your saved recipes stay in your cookbook.", actions "Keep dinner" / "Replace dinner".

During cooking, any add/remove/reorder/main change/replace uses A3's existing confirmation model before state changes. Proposed title "Change dinner while cooking?", body "This rebuilds the cooking plan. Current progress and timers will be reset." Actions "Keep cooking" / "Change dinner". A3 MUST align exact wording with actual timer/progress behavior; do not claim state loss or preservation that store doesn't implement. Cancel changes nothing. Reading another recipe/page never triggers this confirmation.

## 3. Cooking: one timeline with unmistakable dish identity
Retain RIGHT NOW / next/waiting structure. Each step has full recipe-name label + optional small thumbnail. Text is mandatory; color/thumbnail is supplemental. Distinct subtle accents may help, but never color alone. Timer, completion and controls remain tied to that exact recipe/step identity.

Top: "Dinner at7:00PM ·2 dishes". Overlap warning: "Two steps need your hands" and "[Dish A] and [Dish B] overlap,6:50–7:00PM." For3+ use actual involved names/count without truncating essential identity. Do not say conflict is fixed or auto-staggered; engine currently warns rather than resolves. No new automatic scheduler or manual-resolve workflow is implied.

Maintain readable task order when several are active. No tiny four-column dashboard. At AX3 use a single wide reading column, full labels and vertically stacked actions. Use neutral saved-recipe content; no invented cooking advice.

## 4. Duo: four dishes, still two readable pages
Main recipe stays RIGHT. LEFT initially the immersive main cover photo with minimal title/byline and "Show side dishes". When side reader opened: one discreet "Change side ·1 of3" control on the LEFT opens a side list (full accessible recipe names and selected state), selected side reader with own Ingredients/Directions tab and scroll position. "Show cover photo" restores photographic page. Switching side preserves each side's tab/reading position AND main's position. No3-/4-column spread. One shared serving time/cooking plan, not per-reader cooking sessions. Keep the approved spread reader-first: no heavy dark header/footer or giant plan CTA; coordinated cooking remains available through the established cooking flow.

Two-recipe Build20 pairs map naturally to a main+one side. Removed side selects next available side or photo; no dangling reader. Deleted recipe uses A3 missing-dinner state rather than silently cooking the remainder.

The Change side control wraps at large text and opens a full readable list; do not shrink text. If two readable columns cannot fit, offer focused single-recipe reader with "Viewing: [recipe]" selection; preserve positions across folding. Secondary dishes remain accessible rather than disappearing behind a photo-only fallback. Do not infer supported devices from landscape alone; preserve A3 supported presentation detection.

## 5. Week plan
One planned day holds same meal membership/order/main and serving time. Collapsed row: main name plus "+2 dishes" and serving time, expanded view lists all names/timing states. Removing from that day doesn't delete cookbook recipes or alter another day's dinner. Copy changes and active-cook confirmation follow store semantics; no new calendar system.

## 6. Themes, AX3 and acceptance
- Cover/card geometry follows approved Tonight; compact mockups illustrate hierarchy, not replacement dimensions. AX3 dark board shows the scrolled dish-list region, NOT a request to remove cover/photo.
- Classic cream remains cream even under OS Dark appearance, per existing theme choice. Charcoal uses warm dark surfaces and readable ivory text. Preserve theme overrides and test status-bar transitions in both.
- Dynamic Type: no fixed card heights, clipped names, hidden remove actions or footer over Notes/dish rows. Use scroll content insets matching actual pinned actions; all actions >=44pt and measured contrast checks at runtime.
- VoiceOver: name, main/side role, timing state, duration and dish options have coherent labels/order; selected side exposes selected state. No color-only identity. Respect Reduce Motion.
- Approval applies to hierarchy/interaction, not generated hardware, recipe text, timer values, stock icons or pixel measurements.
- A1 matrix: iPhone/iPad/Duo, cream/charcoal, standard/AX3;2/3/4 dishes, limit/duplicate, unchecked timing, missing/deleted dish, add/remove/main/reorder, restart, fold/unfold, confirmation cancel and confirm. Check chicken/potatoes40min offset and actual common finish; warning names correct dishes.
- Joe's approved simpler Duo layout may proceed under A3 ownership. Treat any material departures from that approved direction as new design decisions; model/testing preparation continues under A3/A1 ownership.

— A2


## Approved Duo refinement — October15,06:27 Denver
Joe approved the latest simpler cookbook mockup. Use cream reading pages; modest rounded cover thumbnails beside serif titles; simple underlined Ingredients/Directions tabs; olive numbered steps; hairline separators; and generous whitespace. Main stays RIGHT, selected side stays LEFT. Keep the full-bleed main-photo alternative and Show cover photo action.

Replace the prominent multi-side pill strip with a quiet Change side selector. Selecting another side preserves every reader's position and never changes dinner membership or timers. For a single side, avoid an unnecessary picker; for no sides, show the photographic left page. Count labels appear only when useful.

One small terracotta outline leaf sprig belongs in the upper-right page corner, decorative and excluded from VoiceOver. It must not replace or compete with the existing overflow menu: reserve separate space, keep overflow's accessible tap target, and hide the sprig before compressing controls at AX3. Do not use the leaf as a button.

These controls remain available despite omissions in generated imagery: Back, overflow/edit actions, recipe timing review and established coordinated-cooking entry. No invisible control removal from a visual mockup. Reader pages keep classic cream when that theme is selected; Charcoal is separately supported. Native readability, scroll reachability and fold/unfold continuity still require A1/A3 evidence.
