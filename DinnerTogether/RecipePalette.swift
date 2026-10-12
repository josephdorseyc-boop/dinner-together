import Foundation

// Page colors for recipe pages (Joe, October 12: "the background color adjusts
// to match the photo… if you enter it via text there's an option to pick the
// color… almost like frosted glass").
//
// Pure math, no UIKit: the Linux harness tests every guarantee here.
// The contract: every color a recipe page can be painted with is dark enough
// that the app's light text passes WCAG contrast on it — white body text at
// AAA (7:1), the muted caption color at AA (4.5:1). Photos supply the hue;
// this file decides the brightness.

/// An sRGB color, components 0…1.
struct RGB: Codable, Hashable {
    var r: Double
    var g: Double
    var b: Double

    init(_ r: Double, _ g: Double, _ b: Double) {
        self.r = min(1, max(0, r)); self.g = min(1, max(0, g)); self.b = min(1, max(0, b))
    }

    init(hex: UInt32) {
        self.init(Double((hex >> 16) & 0xFF) / 255, Double((hex >> 8) & 0xFF) / 255, Double(hex & 0xFF) / 255)
    }

    static let white = RGB(1, 1, 1)

    /// WCAG 2 relative luminance.
    var luminance: Double {
        func lin(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    func contrast(with other: RGB) -> Double {
        let a = luminance, b = other.luminance
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    /// Hue in degrees 0…360, saturation and brightness 0…1.
    var hsb: (h: Double, s: Double, b: Double) {
        let mx = max(r, g, b), mn = min(r, g, b), d = mx - mn
        var h = 0.0
        if d > 0 {
            if mx == r { h = 60 * ((g - b) / d).truncatingRemainder(dividingBy: 6) }
            else if mx == g { h = 60 * ((b - r) / d + 2) }
            else { h = 60 * ((r - g) / d + 4) }
        }
        if h < 0 { h += 360 }
        return (h, mx == 0 ? 0 : d / mx, mx)
    }

    init(h: Double, s: Double, b: Double) {
        let c = b * s, hp = (h.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 60
        let x = c * (1 - abs(hp.truncatingRemainder(dividingBy: 2) - 1)), m = b - c
        let (r1, g1, b1): (Double, Double, Double)
        switch hp {
        case ..<1: (r1, g1, b1) = (c, x, 0)
        case ..<2: (r1, g1, b1) = (x, c, 0)
        case ..<3: (r1, g1, b1) = (0, c, x)
        case ..<4: (r1, g1, b1) = (0, x, c)
        case ..<5: (r1, g1, b1) = (x, 0, c)
        default:   (r1, g1, b1) = (c, 0, x)
        }
        self.init(r1 + m, g1 + m, b1 + m)
    }

    /// Simple alpha composite of `self` over `under`, in sRGB (how the
    /// renderer blends translucent fills).
    func over(_ under: RGB, alpha: Double) -> RGB {
        RGB(r * alpha + under.r * (1 - alpha), g * alpha + under.g * (1 - alpha), b * alpha + under.b * (1 - alpha))
    }
}

/// How a recipe page is painted. Stored on the recipe only when the cook
/// chooses; nil means automatic (match the photo if there is one, else classic).
enum PageStyle: Codable, Hashable {
    case classic
    case matchPhoto
    case preset(String)
}

/// Three gradient stops, top to bottom, each dark enough for light text.
struct RecipePalette: Equatable {
    let colors: [RGB]

    /// Luminance ceilings for the top, middle and bottom stops. 0.06 is about
    /// where Apple News's warm recipe gradients sit, and it keeps the app's
    /// muted caption color (dark-mode `Theme.muted`) above 4.5:1.
    static let ceilings: [Double] = [0.06, 0.045, 0.03]

    /// Dark-mode `Theme.muted` (Theme.swift), the dimmest text on a page.
    static let mutedText = RGB(0.730, 0.710, 0.650)

    struct Preset: Identifiable { let id: String; let name: String; let palette: RecipePalette }

    static let presets: [Preset] = [
        ("cider", "Cider", [0x8A4A22, 0x6B3A24, 0x3B2A22]),
        ("tomato", "Tomato", [0x9C3A2A, 0x7A2B22, 0x3A1E1A]),
        ("olive", "Olive", [0x5C6B3A, 0x45522E, 0x262B1E]),
        ("saffron", "Saffron", [0xA0701E, 0x7D5418, 0x3D2C14]),
        ("plum", "Plum", [0x6E3A5C, 0x532C47, 0x2A1A26]),
        ("lagoon", "Lagoon", [0x2F6670, 0x254F57, 0x15292E]),
        ("charcoal", "Charcoal", [0x4A4642, 0x35322F, 0x1C1B1A]),
    ].map { Preset(id: $0.0, name: $0.1, palette: RecipePalette(tuning: $0.2.map { RGB(hex: $0) })) }

    static func preset(_ id: String) -> RecipePalette? { presets.first { $0.id == id }?.palette }

    /// Applies the ceilings to any three colors.
    init(tuning stops: [RGB]) {
        let s = stops + Array(repeating: stops.last ?? RGB(0.2, 0.2, 0.2), count: max(0, 3 - stops.count))
        colors = zip(s.prefix(3), Self.ceilings).map { Self.toned($0, maxLuminance: $1) }
    }

    /// The same hue, saturation kept rich but not neon, brightness lowered
    /// until the luminance ceiling is met.
    static func toned(_ c: RGB, maxLuminance: Double) -> RGB {
        var (h, s, b) = c.hsb
        if s > 0.12 { s = min(0.85, max(0.35, s)) }   // greys stay grey
        var out = RGB(h: h, s: s, b: b)
        var guardrail = 0
        while out.luminance > maxLuminance && guardrail < 200 {
            b *= 0.97; out = RGB(h: h, s: s, b: b); guardrail += 1
        }
        return out
    }

    /// The photo's character in three stops: its dominant colorful region,
    /// a second distinct color if it has one, and a deep version of the first.
    /// Near-white and near-black regions (plates, marble, shadows) only count
    /// when the photo has nothing else. Nil for an empty image.
    static func fromPixels(_ pixels: [RGB]) -> RecipePalette? {
        guard !pixels.isEmpty else { return nil }
        let clusters = kMeans(pixels, k: 5, iterations: 10)
        func score(_ c: (center: RGB, count: Int)) -> Double {
            let l = c.center.luminance, s = c.center.hsb.s
            let neutral = l > 0.75 || l < 0.012 || s < 0.10
            return Double(c.count) * pow(0.15 + s, 1.5) * (neutral ? 0.08 : 1)
        }
        let ranked = clusters.filter { $0.count > 0 }.sorted { score($0) > score($1) }
        guard let first = ranked.first?.center else { return nil }
        let second = ranked.dropFirst().first { other in
            let a = first.hsb, b = other.center.hsb
            let dh = min(abs(a.h - b.h), 360 - abs(a.h - b.h))
            return dh > 20 || abs(first.luminance - other.center.luminance) > 0.08
        }?.center ?? RGB(h: first.hsb.h + 14, s: first.hsb.s, b: first.hsb.b * 0.8)
        return RecipePalette(tuning: [first, second, RGB(h: first.hsb.h, s: first.hsb.s, b: first.hsb.b * 0.45)])
    }

    /// Deterministic k-means: seeds at luminance quantiles, so the same photo
    /// always yields the same page.
    static func kMeans(_ pixels: [RGB], k: Int, iterations: Int) -> [(center: RGB, count: Int)] {
        let sorted = pixels.sorted { $0.luminance < $1.luminance }
        var centers = (0..<k).map { i in sorted[min(sorted.count - 1, (sorted.count * (2 * i + 1)) / (2 * k))] }
        var counts = Array(repeating: 0, count: k)
        for _ in 0..<iterations {
            var sums = Array(repeating: (0.0, 0.0, 0.0), count: k)
            counts = Array(repeating: 0, count: k)
            for p in pixels {
                var best = 0, bestD = Double.infinity
                for (i, c) in centers.enumerated() {
                    let d = (p.r - c.r) * (p.r - c.r) + (p.g - c.g) * (p.g - c.g) + (p.b - c.b) * (p.b - c.b)
                    if d < bestD { bestD = d; best = i }
                }
                sums[best].0 += p.r; sums[best].1 += p.g; sums[best].2 += p.b; counts[best] += 1
            }
            for i in 0..<k where counts[i] > 0 {
                let n = Double(counts[i])
                centers[i] = RGB(sums[i].0 / n, sums[i].1 / n, sums[i].2 / n)
            }
        }
        return zip(centers, counts).map { ($0, $1) }
    }
}
