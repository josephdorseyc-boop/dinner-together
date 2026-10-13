import Foundation
import SwiftUI

// The week's dinners (Joe, October 13): the built-in dinners rotate through
// the coming days with one open "your pick" night a week, and the cook can
// set any day to a classic, one of their recipes, or an open night. Today is
// always the session's own menu — the plan speaks for the days after it, and
// when one of those days arrives its dinner becomes tonight's (unless the cook
// has already chosen today or is cooking).

/// What a day holds in the plan.
enum PlannedDinner: Equatable {
    /// A menu ID: a catalog dinner ("steak") or a recipe ("recipe:<uuid>").
    case menu(String)
    /// An open night: the cook picks on the day.
    case open
}

struct WeekPlan: Codable, Equatable {
    /// "yyyy-MM-dd" → a menu ID, or "" for a night the cook left open.
    /// Days without an entry follow the rotation.
    var assignments: [String: String] = [:]

    /// The day's dinner: the cook's choice if it still exists, else the rotation.
    func dinner(on date: Date, calendar: Calendar = .current, exists: (String) -> Bool = { _ in true }) -> PlannedDinner {
        if let id = assignments[WeekRotation.dayKey(date, calendar: calendar)] {
            if id.isEmpty { return .open }
            if exists(id) { return .menu(id) }
        }
        return WeekRotation.suggestion(for: date, calendar: calendar)
    }

    /// Whether the cook set this day (as opposed to the rotation).
    func isChosen(_ date: Date, calendar: Calendar = .current) -> Bool {
        assignments[WeekRotation.dayKey(date, calendar: calendar)] != nil
    }

    mutating func set(_ dinner: PlannedDinner, on date: Date, calendar: Calendar = .current) {
        let key = WeekRotation.dayKey(date, calendar: calendar)
        switch dinner {
        case .menu(let id): assignments[key] = id
        case .open: assignments[key] = ""
        }
    }

    /// Back to the rotation for that day.
    mutating func clear(_ date: Date, calendar: Calendar = .current) {
        assignments.removeValue(forKey: WeekRotation.dayKey(date, calendar: calendar))
    }

    /// Days more than two weeks past are forgotten.
    mutating func prune(before date: Date, calendar: Calendar = .current) {
        guard let cutoff = calendar.date(byAdding: .day, value: -14, to: calendar.startOfDay(for: date)) else { return }
        let keep = WeekRotation.dayKey(cutoff, calendar: calendar)
        assignments = assignments.filter { $0.key >= keep }
    }

    /// When a planned day arrives: the menu to make tonight's, or nil to leave
    /// the session alone. Only a session chosen before today with nothing
    /// started gives way, and only to a menu that exists and can be cooked.
    static func menuToAdopt(session: DinnerSession, hasProgress: Bool, plan: WeekPlan, now: Date,
                            calendar: Calendar = .current, cookable: (String) -> Bool) -> String? {
        guard !hasProgress, session.createdAt < calendar.startOfDay(for: now) else { return nil }
        guard case .menu(let id) = plan.dinner(on: now, calendar: calendar, exists: cookable),
              id != session.menuID, cookable(id) else { return nil }
        return id
    }
}

enum WeekRotation {
    /// Saturday is the open night (Calendar weekday 7).
    static let openWeekday = 7
    /// The built-in dinners that rotate; Thanksgiving has its own day.
    static var rotation: [String] { DinnerCatalog.menus.map(\.id).filter { $0 != "thanksgiving" } }

    /// "yyyy-MM-dd" in the cook's calendar.
    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// The rotation's dinner for a day: Thanksgiving on US Thanksgiving, an
    /// open night on Saturdays, otherwise the next classic in turn — every
    /// classic comes round before any repeats, and a dinner moves to a new
    /// weekday each time it returns.
    static func suggestion(for date: Date, calendar: Calendar = .current) -> PlannedDinner {
        if isThanksgiving(date, calendar: calendar) { return .menu("thanksgiving") }
        if calendar.component(.weekday, from: date) == openWeekday { return .open }
        let ids = rotation
        guard !ids.isEmpty else { return .open }
        // Count the non-open days from a fixed Sunday, so the order is the
        // same on every device and never depends on when the app was opened.
        let epoch = calendar.date(from: DateComponents(year: 2026, month: 1, day: 4)) ?? Date(timeIntervalSince1970: 0)
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: epoch), to: calendar.startOfDay(for: date)).day ?? 0
        let weeks = Int((Double(days) / 7).rounded(.down))
        let offset = days - weeks * 7           // 0 = Sunday … 6 = Saturday (open)
        let count = weeks * 6 + offset
        let index = ((count % ids.count) + ids.count) % ids.count
        return .menu(ids[index])
    }

    /// The fourth Thursday of November.
    static func isThanksgiving(_ date: Date, calendar: Calendar = .current) -> Bool {
        let c = calendar.dateComponents([.month, .day, .weekday], from: date)
        return c.month == 11 && c.weekday == 5 && (22...28).contains(c.day ?? 0)
    }

    /// Today and the six days after it.
    static func days(from now: Date, count: Int = 7, calendar: Calendar = .current) -> [Date] {
        let start = calendar.startOfDay(for: now)
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
}

/// The plan on disk, next to the session and the recipe library. Same save
/// contract as the library: a failed save changes nothing in memory.
@MainActor
final class WeekPlanStore: ObservableObject {
    @Published private(set) var plan = WeekPlan()
    @Published var saveError: String?
    /// UI tests: every save fails.
    var simulateSaveFailure = false
    private let url: URL

    static let fileName = "week-plan.json"

    init(directory: URL? = nil) {
        let dir = directory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        url = dir.appendingPathComponent(Self.fileName)
        if let data = try? Data(contentsOf: url), let saved = try? JSONDecoder().decode(WeekPlan.self, from: data) {
            plan = saved
        }
    }

    func dinner(on date: Date, exists: (String) -> Bool = { _ in true }) -> PlannedDinner {
        plan.dinner(on: date, exists: exists)
    }

    @discardableResult
    func set(_ dinner: PlannedDinner, on date: Date) -> Bool {
        var next = plan
        next.set(dinner, on: date)
        next.prune(before: Date())
        return commit(next)
    }

    @discardableResult
    func clear(_ date: Date) -> Bool {
        var next = plan
        next.clear(date)
        return commit(next)
    }

    private func commit(_ next: WeekPlan) -> Bool {
        if simulateSaveFailure {
            saveError = "The week plan couldn’t be saved. Your earlier plan is unchanged."
            return false
        }
        do {
            try JSONEncoder().encode(next).write(to: url, options: .atomic)
            plan = next
            saveError = nil
            return true
        } catch {
            saveError = "The week plan couldn’t be saved. Your earlier plan is unchanged."
            return false
        }
    }
}
