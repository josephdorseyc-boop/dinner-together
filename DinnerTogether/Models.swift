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
