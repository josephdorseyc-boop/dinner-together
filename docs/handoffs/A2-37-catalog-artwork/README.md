# A2-37 — Catalog artwork and reusable drawing data

Prepared October 13, 2026 for A3's existing build lane. A2 owns this isolated artwork deliverable; A3 owns app integration; A1 owns native verification.

This is an optional support pack, not a change installed into the app. It does not modify navigation, the drawer, cooking sessions, timers, recipes, weekly planning, CI or UI-test helpers.

## Included

- **10 dinner plates** covering every classic, including Thanksgiving's six actual components.
- **25 dish illustrations** covering every distinct label in the inspected DinnerCatalog. Rice, Mash and Green beans reuse one consistent drawing across menus.
- **70 SVGs**: 35 full-detail files and 35 simplified thumbnail files. The assets are original vectors, not food photos; they contain no fonts, embedded raster images, external links or third-party art.
- **A2CatalogArtwork.json**: the same paths, ellipses, colors and layer order in a simple normalized drawing format. This removes the need to hand-convert SVG paths into SwiftUI geometry.
- **manifest.json**: exact menu IDs, exact case-sensitive dish labels, file mappings, palette and inspected source SHA.
- **A2-37-catalog-artwork-adapter.patch**: OPTIONAL add-only proposal for DinnerTogether/A2CatalogIllustration.swift. No existing file, call site, project file or workflow is changed by the patch.
- **previews/classic-plates.png** and **previews/catalog-dishes.png**: contact sheets showing 220-pixel hero artwork and 44-pixel thumbnails on light and dark backgrounds.
- **VALIDATION.json**, generator and renderer/validator scripts, and the source catalog snapshot for repeatable coverage checks.

Baseline: wip/week-plan `cd98223dbb79cd31fff1e1653be638cd7068f9e3`.

## Fastest integration for A3

1. Keep the current photo/illustration priority. Real recipe covers remain first. This pack replaces the classic illustration fallback; it is not a source of recipe photos.
2. Choose the adapter OR convert the SVGs using your existing method. Do not install both just to render the same plate.
3. To use the adapter, apply the separate patch, add its new Swift file to the app target, and add **A2CatalogArtwork.json** to the app target's Copy Bundle Resources with the exact filename. The patch deliberately does not edit your project file or your active WeekPlanViews.swift.
4. Preserve PlateIllustration.colors(menuID) and other backdrop behavior you already added. Swap its drawing body or selected call sites when you are ready:

```swift
A2CatalogIllustration(menuID: menuID)
    .frame(width: size, height: size)

A2CatalogIllustration(dish: "Green beans")
    .frame(width: 44, height: 44)
```

5. Confirm `A2CatalogArtworkStore.loadFailure == nil` and `drawingCount == 35` in the app process. Missing/bad resources expose a diagnostic and neutral fork-and-knife fallback; unknown IDs never show a different dinner's food.
6. Compile Debug and Release, then photograph 44-point and 220-point renders in the actual app. Keep existing menu/dish text, cooking state, selection and accessibility on the surrounding card/row.

The adapter reads the resource once, uses normalized vector coordinates, drops optional details at 64 points and below, is decorative and does not receive taps. It has no network, billing, data persistence, recipe parsing or session mutation. No dependencies are added.

SVG files can be inspected directly. The JSON drawing format has only two layer kinds: ellipse and path. Path commands are absolute M, L, Q, C and Z; strokes use round caps/joins. Each drawing uses a 256×256 viewBox. `detail` layers are excluded in thumbnails. Every layer includes fill/stroke, strokeWidth and opacity. Manifest labels are canonical catalog labels, not a fuzzy importer mapping.

## Coverage

Menus: steak, pasta, salmon, lemon-chicken, turkey-tacos, tofu-bowls, chickpea-curry, gnocchi-greens, pork-supper, thanksgiving.

Dish labels: Steak, Mash, Green beans, Pasta, Salad, Salmon, Rice, Broccoli, Lemon chicken, Couscous, Zucchini, Turkey tacos, Black beans, Crunchy slaw, Roasted tofu, Cucumber slaw, Chickpea curry, Cucumber yogurt, Skillet gnocchi, Lemony salad, Pork tenderloin, Turkey, Stuffing, Gravy, Rolls.

Cranberry was mentioned as an example in the request but is not a dish in this catalog baseline; no fictional menu component was added. New catalog dishes need a deliberate drawing/mapping update. Custom imported recipes keep the existing cover/generic fallback.

## Validation and limits

Evidence tier: **supplemental vector/data checks**, plus manual inspection of the two Inkscape contact sheets. These are not simulator/app/device screenshots.

Passed: complete menu/dish coverage, unique IDs, valid SVG XML, exact SVG/JSON drawing parity, command arity, finite bounded geometry, valid palette values, independent transparent 44/220-pixel exports, and deterministic regeneration. The separate add-only patch passes `git apply --check` in an isolated checkout where its destination does not exist.

**SwiftUI compilation and native display are not verified here.** No Swift/Xcode toolchain is available. The optional adapter needs A3's native compile and A1's relevant app checks, including resource loading, thumbnail detail cutoff and decorative accessibility behavior. Existing app test counts/CI expectations are untouched.

The illustration depicts food identity, not preparation state or doneness. Keep timers and completion indicators separate. Thumbnail/hero sizes in the previews are raster export pixels; native captures must verify the logical-point display. Glass contrast and Duo layout remain part of the separate A2-36 capture contract.

## Rebuild

Use Python 3, Pillow and Inkscape. From the included tools folder:

```bash
python build_artwork.py
python render_and_validate.py
```

The scripts write the pack beside their source snapshot. They are independent tools and are not inserted into the project's test suite or CI. Native adapter API references: Apple's Canvas and GraphicsContext documentation:
https://developer.apple.com/documentation/swiftui/canvas
https://developer.apple.com/documentation/swiftui/graphicscontext

## Next review

A3 integrates when appropriate in the existing hero/plate lane. A1 verifies native compilation and real app rendering; A2 reviews the actual renders. The first Duo shell may continue using current placeholders until this optional pack is integrated. No duplicate layout/navigation work or extra CI run was launched by A2.
