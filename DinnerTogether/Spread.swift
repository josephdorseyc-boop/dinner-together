import Foundation

/// The cookbook spread (Joe and A2, October 14, for the iPhone Duo): with
/// the phone open like a book, the recipe page becomes two pages — RIGHT
/// the main recipe, exactly the single page; LEFT the cover photo edge to
/// edge, or, when the cook asks, a second recipe to read alongside (a side
/// dish). One recipe per dinner stays: the left page is read, never cooked.
///
/// Decided from the window's geometry, never from the device or its
/// orientation (Apple's guidance for the Duo): a phone-idiom window wide
/// and tall enough for two readable pages. No iPhone shows one today
/// (a Pro Max on its side is 932 × 430); the Duo open does. iPad keeps its
/// own layout, as Joe approved the spread for the Duo first.
enum SpreadLayout {
    /// Two readable pages: an SE-width column each, at least.
    static let minimumWidth: Double = 600
    /// …and a page's worth of height, which rules out a phone on its side.
    static let minimumHeight: Double = 560

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
