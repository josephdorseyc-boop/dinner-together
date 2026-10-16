import Foundation  // CGRect and CGFloat on Linux too (no CoreGraphics there)

/// Pure geometry for the UI test scroll helpers' "small window" mode.
/// Extracted so the rule itself is unit-testable on Linux (no UIKit).
/// (A1, #15)
enum ScrollGeometry {
    /// Whether a window is small enough that the "comfortably visible" model
    /// (whole element inside the comfort zone) breaks down. Geometry-driven,
    /// not device-driven: short side under 500 pt *and* near-square (short /
    /// long ≥ 0.6) — the Duo's cover display (466 × 678) qualifies; tall
    /// iPhones don't, including the 402- and 440-wide Pros (A3: a short-side
    /// band alone caught the CI iPhone 17 Pro, 402 × 874); iPads and the
    /// opened Duo (short side ≥ 600) don't.
    static func isSmallWindow(width: CGFloat, height: CGFloat) -> Bool {
        let short = min(width, height), long = max(width, height)
        guard short > 0, long > 0 else { return false }
        return short < 500 && short / long >= 0.6
    }

    /// Is the element's top inside the zone with a 44pt margin at the bottom?
    /// On a small window this is what "on screen" means — the zone is too
    /// tight to expect the whole element to fit.
    static func isTopInZone(frame f: CGRect, zoneTop: CGFloat, zoneBottom: CGFloat) -> Bool {
        f.minY >= zoneTop && f.minY <= zoneBottom - 44
    }
}
