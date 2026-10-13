# A2-32 — store frame 5 and import-flow wording

Proposed patch against wip/share-extension fa04aa0. This branch changes handoff files only.

S2 / source review: the reviewer notes currently say imported content is reviewed before saving. AddRecipeSheet saves then opens the saved recipe for review. Both public and reviewer wording now follow that actual order. The listing is explicitly a build 13 draft; use only after selecting and validating the submission build.

Design decision: frame 5 is “Your recipes. Your timing.” / “Bring a recipe. Check the steps. Make a plan.” Standard typed-recipe Plum capture r15c, fallback r15d, replaces the dated nine-menu frame. Verify sample provenance and actual capture before publication. No publisher photograph is needed.

Supplemental check: exact default filename wins over AX variants; if only AX exists, this frame declines it rather than silently using it. The composer selection checks pass. git apply --check passes against isolated fa04aa0. Description is 2,196 characters. No new store-assets workflow run, composed-frame rendering, native test, or upload was executed by A2. A3 integrates and runs the existing asset flow; A2 reviews the resulting frames.
