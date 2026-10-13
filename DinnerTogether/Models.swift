import Foundation

// MARK: - Catalog types (the building blocks of a dinner)

/// One step of one dish. `minutes` is a planning estimate, not a tested recipe time.
struct CookingStep: Codable, Identifiable, Hashable {
    let id: String
    let dish: String
    let title: String
    let minutes: Int
    let detail: String
    /// True when the step needs the cook's hands and attention
    /// (vs. passive oven time, resting, or simmering).
    let handsOn: Bool
    /// Imported recipes only: `minutes` was guessed (no time in the text) and
    /// the cook has not confirmed it yet. Optional so older saves decode.
    var estimated: Bool? = nil
}

struct DinnerMenu: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let dishes: [[CookingStep]]

    var steps: [CookingStep] { dishes.flatMap { $0 } }
    var longestDishMinutes: Int { dishes.map { $0.reduce(0) { $0 + $1.minutes } }.max() ?? 0 }
}

// MARK: - Recipes the cook brought in (the "add a recipe" feature)

enum ImportMethod: String, Codable {
    case link, text, photo, manual
}

struct RecipeSource: Codable, Hashable {
    var url: URL?
    var publisher: String?
    var author: String?

    /// "EatingWell · Julia Levy", "EatingWell", "Julia Levy", or nil.
    var byline: String? {
        let parts = [publisher, author].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// A recipe the cook added. Stored on this device only. Its `dishes` reuse
/// `CookingStep`, so a recipe cooks exactly like a catalog menu: one dish
/// normally; a second when the parser found a "meanwhile" section.
struct Recipe: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var source: RecipeSource = RecipeSource()
    /// File name inside the library's image folder, when a photo was saved.
    var imageFilename: String?
    var yield: String?
    /// The recipe's own total time, when it stated one.
    var totalMinutes: Int?
    var ingredients: [String] = []
    /// Directions as written, in order — what the Directions tab shows.
    var directions: [String] = []
    /// Timed steps for the engine (see `RecipeImporter.build`).
    var dishes: [[CookingStep]] = []
    var importedAt: Date = Date()
    var importMethod: ImportMethod = .manual
    /// True until the cook has looked at the Timing tab once.
    var needsTimingReview: Bool = true
    var notes: String?
    /// The cook's page color choice; nil = automatic (photo colors if the
    /// recipe has a photo, else the classic cream page).
    var pageStyle: PageStyle?
    /// What a screenshot import could not establish (unreadable text, step
    /// numbers never seen, a last step cut short); shown with the timing
    /// review until the cook has looked. nil when the import was clean.
    var importWarnings: [String]?

    static let menuIDPrefix = "recipe:"
    var menuID: String { Recipe.menuIDPrefix + id.uuidString }
    var steps: [CookingStep] { dishes.flatMap { $0 } }
    var plannedMinutes: Int { dishes.map { $0.reduce(0) { $0 + $1.minutes } }.max() ?? 0 }
    var estimatedStepCount: Int { steps.filter { $0.estimated == true }.count }

    /// The menu the engine and the screens use. Subtitle shows the source
    /// so a plan built from "Mom's lasagna" still says where it came from.
    var menu: DinnerMenu {
        let timing = plannedMinutes > 0 ? "About \(Scheduling.formatMinutes(plannedMinutes))" : "Timing not set"
        let line = [source.byline, timing].compactMap { $0 }.joined(separator: " · ")
        return DinnerMenu(id: menuID, title: title, subtitle: line, symbol: "book.closed", dishes: dishes)
    }
}

// MARK: - Session types (one dinner: planned + actual)

/// Explicit cooking state for every step. There is no implicit "in progress".
enum StepState: String, Codable {
    case notStarted
    case cooking
    case done
}

struct StepRecord: Codable {
    /// Distinguishes this run from an older start/undo/reset of the same step.
    var runID: UUID?
    var state: StepState = .notStarted
    var actualStart: Date?
    var actualEnd: Date?
    /// Absolute timer deadline. Countdowns derive from this instant, so they
    /// stay accurate across backgrounding, relaunch, and date rollover.
    var timerDeadline: Date?
    /// Minutes the timer was started with (catalog estimate or confirmed value).
    var confirmedMinutes: Int?
}

struct HistoryEvent: Codable, Identifiable {
    let id: UUID
    let at: Date
    let text: String

    init(at: Date = Date(), text: String) {
        self.id = UUID()
        self.at = at
        self.text = text
    }
}

/// Everything about one dinner. Value type so undo is a snapshot restore.
struct DinnerSession: Codable {
    var menuID: String = "steak"
    var serveAt: Date = Date().addingTimeInterval(3600)
    /// Pre-cook duration edits: step id -> minutes.
    var durationOverrides: [String: Int] = [:]
    var records: [String: StepRecord] = [:]
    var history: [HistoryEvent] = []
    var createdAt: Date = Date()
    var lastOpenedAt: Date = Date()
    // NOTE (v0.2.1): the v0.2.0 `stepShifts` field was removed. Pending work is
    // now positioned by a dependency-aware plan calculation instead of
    // accumulated offsets, so serving-time moves can never double-apply.
    // Old saves containing `stepShifts` still decode (unknown keys ignored).
}

/// One undoable action: a label plus the full session before it ran.
struct UndoFrame {
    let label: String
    let session: DinnerSession
}
