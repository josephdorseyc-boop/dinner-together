# A2-22 — Joe's Build 11 meringue import feedback

Device feedback supplied October 12 evening (Denver). Ten original JPEGs inspected directly. A2 did not run the app on the device, perform Vision OCR, or change app source.

**Evidence tier: supplemental check — side-by-side comparison of Joe's reported Build 11 device screenshots.** These are not simulator renders. Input identity is recorded in INPUT_MANIFEST.tsv; original photographs/screenshots were not edited or uploaded to the public repository. EXPECTED_PREFIX.json is a human transcription/acceptance contract, not actual Vision output or a runnable repro.

## Findings

### S2 — non-instructions become schedulable steps; a real action is missing

| Source / expectation | Observed Dinner, Together result | Evidence |
|---|---|---|
| Recipe title: Lavender-Ginger Meringue Twists | Main title is “0001 -” | IMG_4599.jpeg |
| News step 1: preheat | App step 4 | IMG_4586(1).jpeg vs IMG_4600.jpeg |
| News step 2: prepare parchment-lined pans | App step 5 | IMG_4587(1).jpeg vs IMG_4600/4601.jpeg |
| News step 3: “Set aside.” | No such instruction between pan preparation and stirring; app step 6 is a repeated recipe title | IMG_4588(1).jpeg vs IMG_4601.jpeg |
| News step 4: stir ginger/lavender | App step 7 | IMG_4589(1).jpeg vs IMG_4601.jpeg |
| News step 5: transfer/tint violet portion | App step 8 | IMG_4590(1).jpeg vs IMG_4601.jpeg |
| Title, story teaser, News navigation are metadata/chrome | App steps 1–3 contain these, including the title twice and Today News+ Audio Following Search | IMG_4600.jpeg |

This is more than a visual numbering mismatch: timing a repeated title or story paragraph adds false work to the plan, while omitting “Set aside” removes genuine work. Do not treat fourteen estimated durations as proof the directions were imported correctly.

**Scope limits:** only five active News instructions are supplied in full here; the next instruction is visible dimmed/partial. App steps 9–14 are not fully verifiable against this source set. The final visible app instruction ends with a comma. Flag incompleteness for review, but do not invent its ending, a bake time, a full recipe step count, a yield, or a total duration. The first five instructions themselves contain no stated duration; estimated timing for genuine untimed steps is not inherently a bug.

## Current-source caveat — establish the actual import path before another fix

**Evidence tier: source review**, main **e0706fdb2c691ecf6f789c8bf2f612bb4b4da96f**:
- The screenshot parser already classifies the exact News navigation row as chrome. The text parser follows a different path. Seeing it in this saved recipe does not establish a failing fresh screenshot import on the current source.
- Updating the binary does not automatically reconstruct recipes previously saved with bad text. Confirm fresh import versus carried-over recipe, import method (Screenshots / Text / Link), and which images were selected.
- Screenshot title extraction considers top text above the Ingredients/Directions row. These new News pages place the recipe name **below** that row (and show a Step n navigation label on pages 2–5). That is a concrete layout assumption to inspect. It does not prove the origin of the “0001 -” string without the actual recognized lines.
- ScreenshotReader currently returns string/position/height but does not preserve the Vision candidate's confidence in OCRLine. The mixed-script cleanup can discard content without recording an import warning (the earlier A2 S2 remains relevant). A3 should distinguish unrecognized/filtered instructions from a deliberate metadata removal.

A3 owns importer integration. No competing importer patch supplied.

## A1/A3 reproduction and acceptance

1. Confirm whether Joe made a new import in Build 11 and its source mode. Reproduce with the **same selected original input set**; the five source screenshots attached here may be only part of that set.
2. On a Mac/native harness, capture actual Vision strings, boxes, recognition confidence and image order, then the parser output. Keep source-image recognition separate from modelled OCRLine fixtures. Investigate where “Set aside” disappears and where “0001 -” enters.
3. Add regression coverage for the accepted first-five prefix in EXPECTED_PREFIX.json: title correct; no title/teaser/News chrome as instructions; the short imperative survives; overlap/context from adjacent pages does not duplicate a step.
4. Include a case with the recipe title below tabs and Step n navigation labels above the body, a cover/editorial page without time/yield labels, and a heading whose body could not be read. Preserve an uncertainty warning or require repair rather than quietly reassigning/deleting a numbered action.
5. Do not remove short untimed instructions based on length. Do not globally discard prose merely because it is not recognized as a cooking verb; valid recipes use many verbs and styles.
6. Compare the fresh import in the app after integration. Existing malformed recipes need an explicit repair/re-import path; do not silently overwrite edits, completed progress, or timer state.

Acceptance for the **visible prefix**: preheat → parchment preparation → set aside → stir ginger/lavender → tint violet portion. No known metadata before/between these. Confirm missing-input/source truncation separately; this fixture is deliberately not a full recipe.

## S3 — photo-match result is too dark for Joe's preferred aesthetic

**Evidence tier: supplemental check**, IMG_4599–4603 versus News references: the app page is a fairly flat deep slate; Joe asks for a gentler treatment. The imported hero also includes the original recipe-title lettering in the pixels. That text should be excluded by the cover crop; it is not a second semantic title to remove from the UI.

**Evidence tier: source review**, RecipePalette at e0706fdb: every photo palette is forced into luminance ceilings [0.06, 0.045, 0.03], designed for light body/caption text, and neutral near-white clusters are downweighted. A pale icing photograph can therefore become a deep blue/slate page. A screenshot crop that includes the source's dark page area may also influence sampling; that influence is an inference, not a measured result from the unavailable original cover input.

**Design direction for A3:** favor a softer photo-matched blue/lavender treatment for this image, with more separation between the top/middle/bottom, and quieter glass. If using a lighter page/card surface, pair it with appropriate dark ink or a separately verified light-text surface. Do not blindly raise ceilings while retaining the existing muted light text; do not weaken the contrast contract just to make this image brighter. Test the real pale icing image, not only synthetic orange fixtures.

Keep the established presets available. The old seven-preset approval was scoped to their observed hues/swatches, not universal approval of every automatic photo result. User preference for a lighter auto treatment is new steering.

For the immediate Build 11 workaround, Classic cream is an available visual choice; it does not repair corrupted instructions. Content correctness is the priority before scheduling this saved import.

## Handoff / validation status

No original files changed. All ten JPEGs read from supplied scratch copies. Their source/reference mapping is documented above. JSON fixture parses successfully and contains five expected active instructions. No Swift or Vision execution, no simulator or device reproduction by A2, and no new CI run requested. A1 owns actual OCR/test evidence; A3 owns import/palette implementation; A2 reviews the corrected render.

Fresh-versus-existing import and exact source mode remain questions for Joe/A3. Treat the visible corrupt output as confirmed, while keeping its current-code cause unconfirmed.
