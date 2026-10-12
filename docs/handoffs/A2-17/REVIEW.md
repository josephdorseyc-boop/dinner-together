# A2-17 — page-color render review and listing handoff

October 12, 2026. Product/design review for Agent 3; engineering verification remains with Agent 1.

## Evidence and baselines

Reviewed all 19 PNGs in `Dinner_Together_Page_Colors_Review_1.zip`: ten iPhone captures and nine iPad captures, r14–r16 plus r09. The package README identifies native run **38298547276**, photographed commit **f3463258e7c2b04bece309d65d171d0aa61dd0d9**, iPhone 17 / iPad (A16), light appearance and default text. This package was available instead of the separately named 1a/1b ZIPs.

This is **simulator rendering**, not physical-device, VoiceOver, or notification testing. The package's run was not green (two Cooking alert failures); this design review does not certify build 10. No new S1 finding from these static captures. Follow later CI results separately.

The proposed documentation delta in `A2-17-listing-recipe-import.patch` is against **main cb28c050723ca3db7f5d327bc7a7f4769d83a1bd**. It changes only proposed store/privacy documentation, supplied as a patch for A3 to integrate. No app source is changed. Palette observations refer to the photographed f346325 state; recheck on **wip/recipe-palette 9fffb57** before implementing a UI fix. Applied A2-14/A2-16 are not repeated; #10 is superseded and already closed.

## Ranked findings

### S2 — store/privacy copy still describes the preset-only, network-free app

**Evidence tier: source review.** On main cb28c05, `docs/store/LISTING.md` says importing custom menus is unavailable, says nine dinners, and its reviewer notes say “No network” / “Start cooking.” `docs/privacy.html` says only the dinner session is saved and no network connections occur. `DinnerCatalog.swift` actually contains ten preset guides including Thanksgiving; `RecipeViews.swift` offers Link / Screenshots / Text; `RecipeLibrary.swift` stores recipes/photos and fetches pages, redirects and available recipe images; `PlanView.swift` uses “Build my cooking plan” or “Build plan for <time>.”

Reproduce by comparing those documents with the named source files at cb28c05. The false network/storage description misinforms the cook about import and handling their recipes. **Action:** integrate the supplied documentation patch, then A1/Joe verify submission-field answers for the chosen binary. The draft keeps preset multi-dish scheduling separate from cooking a saved recipe; it does not promise a custom multi-recipe menu composer. It also does not advertise build 10's colors in a build 9 listing.

The old Content Rights answer should not be carried over to imported publisher recipes/photos without owner reconciliation. Apple's guidance requires permission or another lawful basis for third-party content. The proposed privacy label is still an owner verification item: network access alone does not decide collection under Apple's definition. Reference: https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/ and https://developer.apple.com/app-store/app-privacy-details/ (official guidance checked October 12). This review does not certify permissions or the final App Store questionnaire.

### S3 — colored body palette does not ensure readable system chrome

**Evidence tier: simulator rendering.** Open `iphone/r14a-photo-colors.png` and `iphone/r15c-typed-plum.png` in light appearance. The black status clock/icons sit over dark brown/plum. The selected Recipes tab's colored text is also weak against the tinted capsule. The status issue is visible in the corresponding iPad renders too; the tab observation is specifically iPhone.

**Evidence tier: supplemental check.** Pixel samples from the original iPhone PNGs, using solid interior foreground colors rather than antialias fringes: black status text against sampled brown/plum backgrounds is about **2.14:1 / 2.18:1**. Selected Recipes label samples are about **3.22:1 / 2.25:1**. These are local raster samples, not a whole-screen contrast audit or proof of all material states. Sampled background RGBs: status (92,60,45)/(100,53,84); tab (156,128,115)/(90,69,85); dominant tab foreground (119,0,0)/(213,91,82). Ratios use standard sRGB relative luminance.

**Action for A3:** make status content and selected-tab styling readable on a colored recipe page independently of PageText. Retain native chrome; ensure an appropriate foreground/background pairing. Preserve other tabs and Classic cream behavior. Re-photograph top and scrolled Directions views in light/dark appearance; do not treat a body-color unit test as closing this render finding. No speculative SwiftUI patch is supplied.

### S3 — picker copy should explain immediate save instead of promising every color is readable

**Evidence tier: simulator rendering**, r14c/r15b. Selection indicators and Done read well. Replace the helper copy with:

- With a photo: **“Match the photo, or choose a color.”**
- Without a photo: **“Choose a color for this recipe.”**
- Shared second sentence: **“Changes save as you select.”**

Keep Done and the selection checkmark. The supplied README describes immediate save/rollback, and r16 shows the retained selection on failure. There is no Apply/Cancel transaction to imply. Retire the broad “Text stays easy to read on every color” claim, especially while chrome contrast remains open.

### S3 — failed style/delete messages do not name the failed action

**Evidence tier: simulator rendering**, `iphone/r16-page-color-save-failed.png` and r09 on both devices. The problem is visible; r16 keeps Classic selected and the page cream. Preserve that inline placement and rollback presentation. Suggested operation-specific text:

- Page color: **“The page color couldn’t be saved. Your previous color is still selected. Tap a color to try again.”**
- Delete: **“This recipe couldn’t be deleted. It’s still in your recipes. Try deleting it again.”**

Wire the wording to the failed operation; do not globally replace the library's generic save error. These are copy suggestions, not a claim that the screenshots execute a retry or that a dedicated Retry button exists. A1 should confirm repeat-selection/delete recovery.

## Design decisions

All below are **simulator-rendering judgments**, scoped to the provided light/default captures.

| Question | Decision |
|---|---|
| Seven presets | Keep Cider, Tomato, Olive, Saffron, Plum, Lagoon, Charcoal; keep Match photo / Classic cream. No hue/saturation retune requested. Only photo-brown and Plum have full-page captures here; other presets are seen as swatches, so full-page approval is conditional. |
| Soft pools | Keep current strength. They add depth on iPad and stay restrained on iPhone. Do not brighten them behind directions. |
| Apricot STEP / timer accent | Keep. It reads clearly on the photographed brown/Plum pages. Request one Tomato Directions render for the warm-on-warm case before universal signoff. |
| Hero transition / reading layout | Keep the restrained fade, title on a stable background, and spacious directions. The fixture is synthetic: this approves composition, not real-food photography or photo-palette extraction quality. |
| iPad composition | Keep two columns and the subtle system sidebar tint. No separate decorative treatment needed. |
| Delete | Keep **“Delete this recipe”**, trash icon, modest end-of-page action and confirmation. Keep red on Classic and a legible destructive accent on colored pages; do not turn it into a large primary CTA or add a card just for Delete. Separate it from the pinned cooking action. |

Delete is clearly visible in the iPad captures. The iPhone r09 error capture is at the page top, so it does not settle the resting end-of-page button's spacing on iPhone. Capture that moment once when exercising the existing flow.

The sampled-body/material tests are not equivalent to a rendered glass audit. The current default body/cards look readable, but actual system material tint, bright photos and accessibility settings still need renders. Retain the solid-card fallback described in the package.

## Next captures — reuse existing flows, do not build another harness

Priority order for A3/A1:

1. **iPhone AX3 and Dark Mode:** r14a/b/c and r15b/c/d, plus the r16 failure state at AX3. Show the estimate, selected option, Done, and any error without clipping or losing actions. Verify the presented sheet itself receives AX3; changing only its parent environment is insufficient evidence.
2. **iPad AX3:** photo and typed Directions, each picker; **iPad Dark Mode:** representative r14a and r15c. Judge sidebar/detail balance and system chrome as well as body text.
3. One **Tomato Directions** page, and one bright food-photo/card case with **Reduce Transparency**, then **Increase Contrast**. Keep settings separately identifiable so a failed pairing is attributable. Include the toolbar/tab/status region in the shots.
4. In the existing delete flow, take one iPhone capture **at the end-of-page Delete button before tapping**, and its confirmation dialog. Confirm Cancel preserves the recipe and failure permits a later retry through assertions; static photographs alone cannot prove those transitions.

Avoid duplicating A1's engine/alert investigation. This request is for design evidence; A1 continues owning state and retry assertions. Read the new durable `ui-review-evidence-<run_id>` artifact when the next run lands rather than depending on old force-pushed ci-results SHAs.

## Screenshot story / store handoff

Keep five existing timing-focused frames. Replace frame 5's preset count with **“Your recipes. Your timing.”** using an actual Recipes/detail render and an original/licensed sample photo and recipe. The patch records this as a requested asset update, not as an already-generated frame. Avoid consumer screenshots using the synthetic test cover. Show page colors only when build 10 is the submitted build.

The patch fixes the description, keyword mix, review instructions and factual privacy-page language. Verified public-field lengths and patch applicability are recorded in VALIDATION.md. It does not modify the live App Store listing, privacy manifest, release pricing, signing, or app source. A3 remains integration owner.
