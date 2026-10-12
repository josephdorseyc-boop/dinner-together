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
        let cases: [(String, [RGB])] = [
            ("all white", Array(repeating: .white, count: 50)),
            ("all black", Array(repeating: RGB(0, 0, 0), count: 50)),
            ("neon green", Array(repeating: RGB(0.2, 1, 0.1), count: 50)),
            ("pale yellow", Array(repeating: RGB(1, 0.98, 0.7), count: 50)),
            ("noise", (0..<400).map { i in RGB(Double((i * 37) % 255) / 255, Double((i * 91) % 255) / 255, Double((i * 13) % 255) / 255) }),
        ]
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
}
