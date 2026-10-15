import Foundation

/// The cookbook spread (Joe and A2, October 14, for the iPhone Duo): with
/// the phone open like a book, the recipe page becomes two pages — RIGHT
/// the main recipe, exactly the single page; LEFT the cover photo edge to
/// edge, or, when the cook asks, a second recipe to read alongside (a side
/// dish). One recipe per dinner stays: the left page is read, never cooked.
///
/// Decided from the window's geometry, never from the device (Apple's
/// guidance for the Duo): a phone-idiom window wide enough for two pages of
/// at least 300 pt and tall enough for a page. The Duo's inner display came
/// up 466 × 678 in its first run (October 15), upright: one page there; the
/// app turns with the Duo held like a book (678 wide), and the spread opens.
/// Ordinary iPhones stay upright, so never qualify; iPad keeps its layout.
enum SpreadLayout {
    /// Two readable pages of 300 pt or more.
    static let minimumWidth: Double = 600
    /// …and a page's worth of height (an iPhone on its side is 430–440).
    static let minimumHeight: Double = 450

    /// `accessibilitySize`: Dynamic Type at an accessibility size — the main
    /// recipe needs the whole width then, so it is the single page.
    static func showsSpread(width: Double, height: Double, phoneIdiom: Bool, accessibilitySize: Bool) -> Bool {
        phoneIdiom && !accessibilitySize && width >= minimumWidth && height >= minimumHeight
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
