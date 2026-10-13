import XCTest
@testable import DinnerTogether

// The page-color contract: whatever a photo or a preset supplies, light text
// stays readable — white at AAA (7:1), the muted caption color at AA (4.5:1).
final class RecipePaletteTests: XCTestCase {

    private func assertReadable(_ p: RecipePalette, _ label: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(p.colors.count, 3, label, file: file, line: line)
        for (i, c) in p.colors.enumerated() {
            XCTAssertGreaterThanOrEqual(c.contrast(with: .white), 7, "\(label) stop \(i): white text", file: file, line: line)
            XCTAssertGreaterThanOrEqual(c.contrast(with: RecipePalette.mutedText), 4.5, "\(label) stop \(i): muted text", file: file, line: line)
        }
        // Everything text sits on: the stops, frosted cards, solid cards.
        for (i, surface) in p.textSurfaces.enumerated() {
            XCTAssertGreaterThanOrEqual(surface.contrast(with: PageText.ink), 7, "\(label) surface \(i) \(p.hexStops): ink", file: file, line: line)
            for t in PageText.all {
                XCTAssertGreaterThanOrEqual(surface.contrast(with: t.color), 4.5, "\(label) surface \(i) \(p.hexStops): \(t.name)", file: file, line: line)
            }
        }
        // The selected tab's capsule carries ink only (RecipeViews.tabBar:
        // `tab == t ? Theme.ink : Theme.muted`); muted sits on the frosted
        // track, which `textSurfaces` covers. Add a color there and add it here.
        for (i, surface) in p.selectedSurfaces.enumerated() {
            XCTAssertGreaterThanOrEqual(surface.contrast(with: PageText.ink), 4.5, "\(label) selected tab \(i): ink", file: file, line: line)
        }
    }

    func testEveryPresetIsReadable() {
        XCTAssertEqual(RecipePalette.presets.map { $0.id }, ["cider", "tomato", "olive", "saffron", "plum", "lagoon", "charcoal"])
        for p in RecipePalette.presets { assertReadable(p.palette, p.name) }
        XCTAssertNil(RecipePalette.preset("neon"))
    }

    /// Apple News's cider photo, roughly: orange cubes and a glass on white marble.
    func testCiderPhotoGivesAWarmPage() throws {
        var pixels: [RGB] = Array(repeating: RGB(0.93, 0.92, 0.90), count: 300)        // marble
        pixels += Array(repeating: RGB(0.70, 0.36, 0.12), count: 160)                  // cider
        pixels += Array(repeating: RGB(0.55, 0.42, 0.30), count: 60)                   // glass/shadow
        pixels += Array(repeating: RGB(0.95, 0.85, 0.75), count: 40)                   // hand
        let p = try XCTUnwrap(RecipePalette.fromPixels(pixels))
        assertReadable(p, "cider photo")
        let hue = p.colors[0].hsb.h
        XCTAssertTrue((15...45).contains(hue), "the page takes the cider's orange, not the marble: hue \(hue)")
        XCTAssertGreaterThan(p.colors[0].hsb.s, 0.35, "rich, not grey")
    }

    func testExtremePhotosStayReadable() throws {
        // Built up in statements: as one literal, Xcode 27.1's type-checker
        // gave up on it (duo-validation run 38341455566).
        var noise: [RGB] = []
        for i in 0..<400 {
            let r: Double = Double((i * 37) % 255) / 255
            let g: Double = Double((i * 91) % 255) / 255
            let b: Double = Double((i * 13) % 255) / 255
            noise.append(RGB(r, g, b))
        }
        var cases: [(String, [RGB])] = []
        cases.append(("all white", Array(repeating: RGB.white, count: 50)))
        cases.append(("all black", Array(repeating: RGB(0, 0, 0), count: 50)))
        cases.append(("neon green", Array(repeating: RGB(0.2, 1, 0.1), count: 50)))
        cases.append(("pale yellow", Array(repeating: RGB(1, 0.98, 0.7), count: 50)))
        cases.append(("noise", noise))
        for (label, px) in cases { assertReadable(try XCTUnwrap(RecipePalette.fromPixels(px)), label) }
        XCTAssertNil(RecipePalette.fromPixels([]))
    }

    func testSamePhotoSamePage() throws {
        let px = (0..<200).map { i in RGB(Double(i % 7) / 7, 0.3, Double(i % 3) / 3) }
        XCTAssertEqual(RecipePalette.fromPixels(px), RecipePalette.fromPixels(px))
    }

    func testColorMath() {
        XCTAssertEqual(RGB.white.contrast(with: RGB(0, 0, 0)), 21, accuracy: 0.01)
        XCTAssertEqual(RGB(hex: 0xFF8000).r, 1); XCTAssertEqual(RGB(hex: 0xFF8000).g, 128.0 / 255, accuracy: 1e-9)
        let c = RGB(0.7, 0.36, 0.12), back = RGB(h: c.hsb.h, s: c.hsb.s, b: c.hsb.b)
        XCTAssertEqual(back.r, c.r, accuracy: 1e-9); XCTAssertEqual(back.g, c.g, accuracy: 1e-9); XCTAssertEqual(back.b, c.b, accuracy: 1e-9)
    }

    func testPageStyleRoundTripsAndOldRecipesDecode() throws {
        for style in [PageStyle.classic, .matchPhoto, .preset("plum")] {
            XCTAssertEqual(try JSONDecoder().decode(PageStyle.self, from: JSONEncoder().encode(style)), style)
        }
        var r = Recipe(title: "Old")
        let old = try JSONEncoder().encode(r)
        XCTAssertNil(try JSONDecoder().decode(Recipe.self, from: old).pageStyle, "a recipe saved before page colors decodes as automatic")
        r.pageStyle = .preset("lagoon")
        XCTAssertEqual(try JSONDecoder().decode(Recipe.self, from: JSONEncoder().encode(r)).pageStyle, .preset("lagoon"))
    }

    /// Automatic follows the photo; the cook's choice wins; unknown or
    /// impossible choices fall back instead of painting nothing.
    func testWhichPaletteAPagePaintsWith() throws {
        let photo = try XCTUnwrap(RecipePalette.fromPixels(Array(repeating: RGB(0.7, 0.36, 0.12), count: 20)))
        let plum = try XCTUnwrap(RecipePalette.preset("plum"))
        var r = Recipe(title: "Cider")
        XCTAssertEqual(r.resolvedPalette(photo: photo), photo, "automatic + photo: match the photo")
        XCTAssertNil(r.resolvedPalette(photo: nil), "automatic, no photo: classic cream")
        r.pageStyle = .classic
        XCTAssertNil(r.resolvedPalette(photo: photo), "classic stays cream even with a photo")
        r.pageStyle = .preset("plum")
        XCTAssertEqual(r.resolvedPalette(photo: photo), plum, "a chosen color wins over the photo")
        XCTAssertEqual(r.resolvedPalette(photo: nil), plum)
        r.pageStyle = .preset("from-a-newer-version")
        XCTAssertEqual(r.resolvedPalette(photo: photo), photo)
        XCTAssertNil(r.resolvedPalette(photo: nil))
        r.pageStyle = .matchPhoto
        XCTAssertNil(r.resolvedPalette(photo: nil), "match photo after the photo is gone: cream")
    }

    /// Theme.tomato's Dark Mode color is the reason colored pages use their
    /// own accent: record the measurement so nobody "simplifies" it back.
    func testTomatoIsTooDimForColoredPages() throws {
        let darkTomato = RGB(0.950, 0.540, 0.420)
        let worst = RecipePalette.presets.flatMap { $0.palette.colors }.map { $0.contrast(with: darkTomato) }.min() ?? 0
        XCTAssertLessThan(worst, 4.5)
        let accentWorst = RecipePalette.presets.flatMap { $0.palette.colors }.map { $0.contrast(with: PageText.accent) }.min() ?? 0
        XCTAssertGreaterThanOrEqual(accentWorst, 6)
    }
}
