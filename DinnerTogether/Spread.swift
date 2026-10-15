import Foundation

/// The cookbook spread (Joe and A2, October 14, for the iPhone Duo): with
/// the phone open like a book, the recipe page becomes two pages — RIGHT
/// the main recipe, exactly the single page; LEFT the cover photo edge to
/// edge, or, when the cook asks, a second recipe to read alongside (a side
/// dish). One recipe per dinner stays: the left page is read, never cooked.
///
/// Decided from the window's geometry, never from the device (Apple's
/// guidance for the Duo): a phone-idiom window wide enough for two
/// comfortable pages once the rail, gutter and padding are taken out, and
/// tall enough for a page. The Duo runs so far were all on its COVER
/// display, folded (466 × 678; the simulator boots closed — A1, October 15).
/// The cover is one page in either orientation (Joe approved, October 15,
/// 10:32 and 10:45 AM): 678 × 466 sideways is too little for two. Opened,
/// the inner display is reported at 951 × 669 (pending our own capture),
/// and the spread opens there. Ordinary iPhones never qualify; iPad keeps
/// its layout.
enum SpreadLayout {
    /// Two readable pages after the rail, gutter and page padding (A2,
    /// October 15: a starting floor, to be checked against real inner-display
    /// captures; 600 let the sideways cover split into ~290 pt pages).
    static let minimumWidth: Double = 800
    /// …and a page's worth of height (an iPhone on its side is 430–440).
    static let minimumHeight: Double = 450

    /// `accessibilitySize`: Dynamic Type at an accessibility size — the main
    /// recipe needs the whole width then, so it is the single page.
    static func showsSpread(width: Double, height: Double, phoneIdiom: Bool, accessibilitySize: Bool) -> Bool {
        phoneIdiom && !accessibilitySize && width >= minimumWidth && height >= minimumHeight
    }

    /// How the recipe page is laid out (Joe, October 15):
    /// - `.spread`: two cookbook pages side by side (wide enough: the Duo
    ///   opened);
    /// - `.book`: one full-width cookbook page with a quiet Main / Side
    ///   switch — a near-square phone screen: the Duo's cover display either
    ///   way up (466 × 678 or 678 × 466), or the opened Duo held upright;
    /// - `.single`: the page as on every iPhone and iPad.
    enum Mode: Equatable { case single, book, spread }

    static func mode(width: Double, height: Double, phoneIdiom: Bool, accessibilitySize: Bool) -> Mode {
        if showsSpread(width: width, height: height, phoneIdiom: phoneIdiom, accessibilitySize: accessibilitySize) { return .spread }
        let short = min(width, height), long = max(width, height)
        return phoneIdiom && long > 0 && short / long >= 0.6 ? .book : .single
    }
}

/// What the LEFT page shows.
enum SpreadLeftPage: Equatable {
    /// The main recipe's cover photo, edge to edge (the default).
    case cover
    /// Another of the cook's recipes, to read alongside.
    case recipe(UUID)

    /// The page after the cookbook changed: a second recipe that is no
    /// longer there (deleted) gives way to the cover.
    func settled(available: (UUID) -> Bool) -> SpreadLeftPage {
        if case .recipe(let id) = self, !available(id) { return .cover }
        return self
    }

    var secondRecipeID: UUID? {
        if case .recipe(let id) = self { return id }
        return nil
    }
}
