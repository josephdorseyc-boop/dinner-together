import CoreGraphics

/// Pure geometry for the UI test scroll helpers' "small window" mode.
/// Extracted so the rule itself is unit-testable on Linux (no UIKit).
/// (A1, #15)
enum ScrollGeometry {
    /// Whether a window is small enough that the "comfortably visible" model
    /// (whole element inside the comfort zone) breaks down. Geometry-driven,
    /// not device-driven: the Duo's cover display (466x678) qualifies;
    /// iPhones (short side < 400pt) and iPads (short side > 500pt) do not.
    static func isSmallWindow(width: CGFloat, height: CGFloat) -> Bool {
        let short = min(width, height)
        return short >= 400 && short < 500
    }

    /// Is the element's top inside the zone with a 44pt margin at the bottom?
    /// On a small window this is what "on screen" means — the zone is too
    /// tight to expect the whole element to fit.
    static func isTopInZone(frame f: CGRect, zoneTop: CGFloat, zoneBottom: CGFloat) -> Bool {
        f.minY >= zoneTop && f.minY <= zoneBottom - 44
    }
}
