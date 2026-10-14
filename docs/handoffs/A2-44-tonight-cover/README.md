# A2-44 — Tonight photo cover: Joe's approved direction

October 14, 2026. A2 design support → A3 integration / A1 verification.
Source baseline reviewed: `wip/own-recipes` at `99983330509fcb82a1c3cbc378cc465d1a805357`.

## The directive Joe asked A2 to convey

Use **option 2, the photo-led cover**, with Joe's subsequent changes. Keep
the cozy cookbook character, cream / olive / tomato palette, serif titles,
and a slightly modern finish. The cookbook is principally the user's own
recipes. Thanksgiving remains the separately approved planning card.

Tonight must look inviting before the user adds a recipe or photo. The
olive linen / open notebook / olive sprigs photograph is the permanent,
bundled default. It is decorative cookbook imagery, never a sample recipe.

The cover follows the **recipe explicitly selected for tonight**:

| Current state | Tonight photograph | Content below the cover |
| --- | --- | --- |
| Empty cookbook | Notebook default | “Your recipes, together”; first-recipe action |
| Recipes saved, nothing selected | Notebook default | Choose tonight's recipe |
| Selected recipe has a saved plate photo | That recipe's plate photo | The selected recipe's actual title and timing |
| Selected recipe has no plate photo, but has a readable cover photo | That recipe's cover photo | The selected recipe's actual title and timing |
| Selected recipe has no usable photo | Notebook default | The selected recipe's actual title and timing |
| A photo cannot be decoded / found on a fresh load | Notebook default | Preserve the selected recipe and its title |

Adding/importing a recipe alone does not select it for tonight. Selecting a
recipe with no photo must clear the previous recipe's hero. Removing a photo
uses the next available photo in the table, then the default. The default is
not saved into a recipe's image field and does not determine its page palette.

## Composition for build 18

- Rounded photo cover inset 12 pt from the screen edge; keep the status bar
  on the ordinary page surface. This is A3's practical adaptation of the mock.
- “Dinner, Together” / “Tonight” sits over the upper photo with a dark scrim.
- Keep **the full dinner-time card**, including time, day, start-by guidance,
  too-soon warning / Use action, and date/time pickers. Joe requested frosted
  glass. Retain a solid fallback for Reduce Transparency / Increase Contrast.
- Name the selected recipe prominently beneath the cover on a stable surface.
- **One selected recipe per dinner.** The mock's “2 dishes” and “Add a dish”
  are not part of this delivery.
- Accessibility text may expand the cover/card vertically. Actions, warnings,
  and pickers must stay reachable; the decorative photo can yield space.
- Cooking keeps its readable cream workspace and its existing functional
  state. The notebook default belongs to Tonight; it is not a dish/step photo.

## Asset and upload status

The existing bundled photo is already present at
`DinnerTogether/Assets.xcassets/TonightCover.imageset/tonight-cover.jpg`
in baseline `9998333`; the imageset resolves as `UIImage(named: "TonightCover")`.
That completes the app-side default-photo upload Joe was waiting for.

This handoff also supplies `tonight-cover-master-v2.png`, a lossless PNG
generated from the existing approved JPEG as a separate reference/master
candidate. It preserves the notebook composition and bottom cream dissolve.
It is **1024 × 1536**, not a larger native source. An attempted 2048 × 3072
request still returned 1024 × 1536; do not label it high resolution or stretch
it and claim extra detail. A3 may keep the existing JPEG; no app asset is
overwritten by this handoff. The complete production prompt is in `PROMPT.md`.

## Acceptance checks for A1 / A3

1. Fresh install: notebook visible, no sample dinner selected, first-recipe
   action works; Cooking has the intended empty state.
2. Import without selecting: Tonight retains the notebook and no selected dinner.
3. Select recipe A with photo, then B without photo: B's actual title plus
   notebook; no photo from A. Switch back to A and verify A's photo.
4. For a selected recipe, add/replace/remove its cover and plate photo. Confirm
   plate → cover → notebook priority and persistence after relaunch.
5. Fresh-load missing/corrupt file: notebook fallback; recipe text stays intact.
6. iPhone light/dark and AX3; iPad compact/regular: full card reachable, long
   titles wrap, cover bounded, no horizontal scroll. Preserve running timers
   when navigating and changing size class.
7. Check text contrast over the notebook, pale/white food photo, and dark food
   photo. Evaluate the rendered material, not just the tint opacity. Verify
   Reduce Transparency / Increase Contrast solid surfaces and VoiceOver order.

## Evidence and limits

**Source review:** `PlanView.coverImage` already implements selected recipe
hero → `TonightCover`; `RecipePhotos.hero` implements plate → cover. The card
keeps timing/feasibility controls and has transparency/contrast fallbacks.

**Supplemental asset check:** existing JPEG and supplied PNG dimensions were
decoded locally; generated photo visually inspected against the reference.

**Native validation:** run `38584992551` on `9998333` ended in failure at the
required validation gate. Linux engine and JS/harness jobs succeeded. No
build-18 simulator/device signoff is claimed here. A3 owns the app integration
and rerun; A1 owns test verification. This commit only adds handoff files.

The compiler log identifies the `RecipesView` argument-order error; the
separate A2-45 handoff supplies the minimal proposed fix.
