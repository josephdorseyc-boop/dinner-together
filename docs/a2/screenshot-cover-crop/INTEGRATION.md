# A2 screenshot cover-photo increment

Baseline: main `aca699b882dc3bc8635d59b05e7dc80c0c3c7625`.
Related: design issue #4 and navigation/reading patch PR #6.

Apply `A2-13-screenshot-cover-crop.patch`. This PR supplies handoff files only;
merging them does not apply the source implementation. No existing source branch
was modified by A2.

## Cook-facing flow

1. In Add a recipe / Screenshots, select the screenshots needed for text import.
2. Optionally choose a cover from those screenshots. The sheet loads local images,
   offers a numbered source picker, a 4:3 preview, and accessible sliders for zoom,
   horizontal position and vertical position. Cancel leaves any prior chosen crop alone.
3. Use this crop returns a bounded JPEG to the import form. Adjust or remove it there.
   Changing the selected screenshots clears the previous cover to avoid a stale association.
4. Add recipe runs the existing OCR/parser and saves the recipe, then the cover.
   Import remains usable without a photo. Source attribution and instruction text are untouched.

The flow crops existing pixels. It neither identifies food automatically nor generates an
image. The full selected screenshots are temporary; only the selected crop is stored.
There is no step-photo association or existing-recipe photo editor in this increment.

## Failure handling and image replacement

Source review found that saveImage previously overwrote the fixed recipe image filename
before committing its reference and ignored update's Bool. The patch writes a new uniquely
named image, commits its reference, and only then removes the previous cover. If the
metadata save fails, it returns nil, removes the new file and retains the prior recipe/photo.
Cleanup is best effort; an interrupted process can leave an unreferenced file, but the
previous image is not deliberately overwritten before commit.

If cover saving fails after a successful recipe add, the form explicitly says the recipe
is saved and offers Retry cover save or Continue without cover. Retry reuses the saved
recipe ID and pending JPEG rather than importing a duplicate recipe. The toolbar changes
from Cancel to Done because the recipe has already been saved. Dismissing this acknowledged
photo error clears it before navigating to the recipe; a failed recipe add still stays open.

## Validation supplied

- Supplemental check: standalone git apply --check and actual isolated application pass.
- Supplemental check: A2-12 then A2-13, and the reverse order, both apply; combined source
  files are byte-identical across the two orders.
- Four new Swift XCTest methods supplied in the already-registered RecipeTests.swift:
  crop bounds/aspect ratio across portrait/landscape and zoom/position extremes; invalid
  geometry/clamping; failed replacement preserving old bytes/reference across reload and
  successful retry; failed first-image metadata commit leaving no reference/file.
- Existing image-storage test now checks a recipe-prefixed JPEG filename rather than a
  fixed filename. Existing library readers continue to use the stored filename.
- No new Xcode file registration is needed. Retain dynamic test-count gates (+4 methods).
- Swift compilation, XCTest execution, Photos picker behavior, crop rendering and device
  memory/latency have NOT been tested by A2. CI on this handoff-only PR tests unchanged source.

## Required native acceptance pass

- Apply alongside the chosen integration branch and compile app/unit/UI targets. Preserve
  newer PR #5 editor fixes and A3 changes; the successful two-order check covers A2-12 only.
- Import without a cover; import with a portrait screenshot cover; switch source images;
  move to all crop boundaries; zoom; cancel; adjust; remove; change selected screenshots.
- Check a landscape photo and orientation-tagged image. Preview and saved/reloaded cover
  should show the same crop with no stretching or unwanted text/status-bar pixels.
- Capture the crop sheet on iPhone default/AX3/dark and iPad; ensure Use this crop remains
  reachable and sliders have useful VoiceOver labels. Physical VoiceOver remains untested.
- Verify a failed recipe add produces no success state. Separately induce a photo-metadata
  failure AFTER a successful add: retry must keep the same recipe ID and Continue without
  cover must not leave a stale error. The existing global fail-recipe-saves launch flag
  fails the add first, so it does not alone exercise this UI branch; use a targeted test hook.
- Execute the four new tests on Linux and both native simulator targets. The byte fixtures
  in persistence tests verify file transactions, not JPEG decoding or the crop UI.

## Practical limits

The picker loads up to the existing 12 selected screenshots, normalizing each to at most
1600 pixels on its longest edge. The exported cover is 1200 by 900; it cannot recover detail
absent from the original screenshot. Inspect memory and interaction latency on a device.
