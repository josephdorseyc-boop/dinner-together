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

/// Three gradient stops, top to bottom. A deep palette is dark enough for
/// light text on every stop; a pale one (a pastel photo — Joe's meringues,
/// build 11) is light enough for the classic page's dark text, so the page
/// takes the photo's wash instead of a slate it never had.
struct RecipePalette: Equatable {
    enum Tone { case deep, pale }

    let colors: [RGB]
    let tone: Tone

    /// Luminance ceilings for the top, middle and bottom stops. 0.06 is about
    /// where Apple News's warm recipe gradients sit, and it keeps the app's
    /// muted caption color (dark-mode `Theme.muted`) above 4.5:1.
    static let ceilings: [Double] = [0.06, 0.045, 0.03]
    /// Luminance floors for a pale page's stops: `PaleText.muted` stays
    /// above 4.5:1 on the deepest, ink above 7:1.
    static let floors: [Double] = [0.76, 0.73, 0.70]

    /// The dimmest text on this page.
    var mutedText: RGB { tone == .deep ? PageText.muted : PaleText.muted }
    /// The body text this page draws with.
    var inkText: RGB { tone == .deep ? PageText.ink : PaleText.ink }
    /// Every color body text may use on this page.
    var textColors: [(name: String, color: RGB)] { tone == .deep ? PageText.all : PaleText.all }

    struct Preset: Identifiable { let id: String; let name: String; let palette: RecipePalette }

    private static func make(_ id: String, _ name: String, _ hexes: [UInt32]) -> Preset {
        let stops: [RGB] = hexes.map { RGB(hex: $0) }
        return Preset(id: id, name: name, palette: RecipePalette(tuning: stops))
    }

    static let presets: [Preset] = [
        make("cider", "Cider", [0x8A4A22, 0x6B3A24, 0x3B2A22]),
        make("tomato", "Tomato", [0x9C3A2A, 0x7A2B22, 0x3A1E1A]),
        make("olive", "Olive", [0x5C6B3A, 0x45522E, 0x262B1E]),
        make("saffron", "Saffron", [0xA0701E, 0x7D5418, 0x3D2C14]),
        make("plum", "Plum", [0x6E3A5C, 0x532C47, 0x2A1A26]),
        make("lagoon", "Lagoon", [0x2F6670, 0x254F57, 0x15292E]),
        make("charcoal", "Charcoal", [0x4A4642, 0x35322F, 0x1C1B1A]),
    ]

    static func preset(_ id: String) -> RecipePalette? { presets.first { $0.id == id }?.palette }

    /// Applies the ceilings to any three colors: a deep page.
    init(tuning stops: [RGB]) {
        let s = stops + Array(repeating: stops.last ?? RGB(0.2, 0.2, 0.2), count: max(0, 3 - stops.count))
        colors = zip(s.prefix(3), Self.ceilings).map { Self.toned($0, maxLuminance: $1) }
        tone = .deep
    }

    /// Applies the floors to any three colors: a pale page.
    init(lightening stops: [RGB]) {
        let s = stops + Array(repeating: stops.last ?? RGB(0.9, 0.9, 0.9), count: max(0, 3 - stops.count))
        colors = zip(s.prefix(3), Self.floors).map { Self.lifted($0, minLuminance: $1) }
        tone = .pale
    }

    /// The same hue as a wash: saturation kept visible but soft, brightness
    /// raised until the luminance floor is met, then saturation given up
    /// until it is.
    static func lifted(_ c: RGB, minLuminance: Double) -> RGB {
        var (h, s, b) = c.hsb
        if s > 0.06 { s = min(0.28, max(0.12, s)) }   // greys stay grey
        var out = RGB(h: h, s: s, b: b)
        var guardrail = 0
        while out.luminance < minLuminance && b < 1 && guardrail < 200 {
            b = min(1, b * 1.03); out = RGB(h: h, s: s, b: b); guardrail += 1
        }
        while out.luminance < minLuminance && s > 0 && guardrail < 400 {
            s = max(0, s - 0.01); out = RGB(h: h, s: s, b: b); guardrail += 1
        }
        return out
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
        // A pastel photo — its color is light and most of it is light — gets
        // a pale page. The cider's orange on white marble stays deep: the
        // orange itself is dark.
        let total = Double(clusters.reduce(0) { $0 + $1.count })
        let lightShare = Double(clusters.filter { $0.center.luminance > 0.5 }.reduce(0) { $0 + $1.count }) / max(1, total)
        if first.luminance > 0.40 && lightShare > 0.6 {
            return RecipePalette(lightening: [first, second, RGB(h: first.hsb.h, s: min(1, first.hsb.s * 1.3), b: first.hsb.b)])
        }
        return RecipePalette(tuning: [first, second, RGB(h: first.hsb.h, s: first.hsb.s, b: first.hsb.b * 0.45)])
    }

    /// Deterministic k-means: seeds at luminance quantiles, so the same photo
    /// always yields the same page.
    static func kMeans(_ pixels: [RGB], k: Int, iterations: Int) -> [(center: RGB, count: Int)] {
        let sorted: [RGB] = pixels.sorted { $0.luminance < $1.luminance }
        var centers: [RGB] = []
        for i in 0..<k {
            let quantile: Int = (sorted.count * (2 * i + 1)) / (2 * k)
            centers.append(sorted[min(sorted.count - 1, quantile)])
        }
        var counts = Array(repeating: 0, count: k)
        for _ in 0..<iterations {
            var sums = Array(repeating: (0.0, 0.0, 0.0), count: k)
            counts = Array(repeating: 0, count: k)
            for p in pixels {
                var best = 0, bestD = Double.infinity
                for (i, c) in centers.enumerated() {
                    let dr: Double = p.r - c.r, dg: Double = p.g - c.g, db: Double = p.b - c.b
                    let d: Double = dr * dr + dg * dg + db * db
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

/// The light text a colored page draws with. Theme.swift takes its Dark Mode
/// values from here, so the contrast tests cover exactly what the screen shows.
enum PageText {
    static let ink = RGB(0.965, 0.945, 0.890)
    static let muted = RGB(0.730, 0.710, 0.650)
    static let olive = RGB(0.690, 0.760, 0.560)
    static let warning = RGB(0.950, 0.740, 0.430)
    /// Timer chips and step labels on a colored page. `Theme.tomato`'s Dark
    /// Mode value measures 3.9:1 on the deepest preset stop — under AA — so a
    /// colored page uses this apricot instead (6.3:1 at worst).
    static let accent = RGB(1.0, 0.780, 0.580)
    /// Every color body text may use on a colored page.
    static let all: [(name: String, color: RGB)] = [
        ("ink", ink), ("muted", muted), ("olive", olive), ("warning", warning), ("accent", accent),
    ]
}

/// The dark text a pale page (and the classic cream page) draws with.
/// Theme.swift takes its Light Mode values from here, so the contrast tests
/// cover exactly what the screen shows.
enum PaleText {
    static let ink = RGB(0.188, 0.169, 0.145)
    /// Darker than the muted caption used to be (0.431, 0.404, 0.369): a
    /// pale page's deepest stop is tinted, not cream, and 4.5:1 there needs
    /// this (5.9:1 on cream, up from 4.9:1).
    static let muted = RGB(0.390, 0.370, 0.340)
    static let olive = RGB(0.282, 0.337, 0.224)
    static let warning = RGB(0.510, 0.300, 0.090)
    /// Timer chips and step labels: the classic page's tomato.
    static let accent = RGB(0.659, 0.220, 0.153)
    static let all: [(name: String, color: RGB)] = [
        ("ink", ink), ("muted", muted), ("olive", olive), ("warning", warning), ("accent", accent),
    ]
}

extension RecipePalette {
    /// Frosted cards: the system's thin material, then this much black, so a
    /// card is never lighter than the page behind it (text only gains contrast).
    static let glassShade = 0.16
    /// The selected tab: this much white over the page.
    static let selectedLift = 0.14

    private static let black = RGB(0, 0, 0)
    /// The classic page's paper card, which a pale page's selected tab uses.
    static let paper = RGB(0.999, 0.992, 0.973)

    /// What the frosted cards are shaded with: black on a deep page (a card
    /// is never lighter than the page), white on a pale one (never darker).
    var glassTint: RGB { tone == .deep ? Self.black : RGB.white }

    /// Reduce Transparency / Increase Contrast: cards are this solid color.
    var solidCard: RGB { glassTint.over(colors[1], alpha: 0.3) }

    /// Every flat color text can sit on, modeled without blur (the blur of a
    /// smooth gradient is the gradient). Mixing stops in sRGB never raises
    /// luminance above the brighter stop (nor lowers it below the darker), so
    /// the stops bound the blended page.
    var textSurfaces: [RGB] {
        colors + colors.map { glassTint.over($0, alpha: Self.glassShade) } + [solidCard]
    }

    /// Selected-tab capsules: white lifted over each stop on a deep page; the
    /// paper card on a pale one.
    var selectedSurfaces: [RGB] {
        tone == .deep ? colors.map { RGB.white.over($0, alpha: Self.selectedLift) } : [Self.paper]
    }

    /// "#RRGGBB", for logs and test messages.
    var hexStops: [String] {
        colors.map { c in
            let parts: [Int] = [c.r, c.g, c.b].map { Int(($0 * 255).rounded()) }
            return "#" + parts.map { String(format: "%02X", $0) }.joined()
        }
    }
}

extension Recipe {
    /// What this recipe's page is painted with: nil means the classic cream
    /// page. Automatic (nil style) follows the photo when there is one; a
    /// chosen preset wins over the photo; "match photo" without a photo, or
    /// a preset this version doesn't know, falls back the same way automatic does.
    func resolvedPalette(photo: RecipePalette?) -> RecipePalette? {
        switch pageStyle {
        case .none, .some(.matchPhoto): return photo
        case .some(.classic): return nil
        case .some(.preset(let id)): return RecipePalette.preset(id) ?? photo
        }
    }
}
