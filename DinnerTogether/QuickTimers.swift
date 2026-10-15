import Foundation
import SwiftUI

/// The kitchen timers started from directions (Joe, October 15), kept
/// across relaunches by their deadlines, each with a notification when it
/// ends. Separate from the cooking plan: a timer here is the cook's own
/// "15 minutes", whether or not dinner is being timed.
@MainActor
final class QuickTimerStore: ObservableObject {
    @Published private(set) var timers: [QuickTimer] = []
    private let fileURL: URL
    private let notifications: NotificationService

    init(fileURL: URL? = nil, notifications: NotificationService) {
        self.fileURL = fileURL ?? URL.documentsDirectory.appending(path: "dinner-together-timers.json")
        self.notifications = notifications
        if let data = try? Data(contentsOf: self.fileURL),
           let loaded = try? JSONDecoder().decode([QuickTimer].self, from: data) {
            // Timers long over are of no use after a relaunch.
            timers = loaded.filter { $0.remaining(at: Date()) > -3600 }
        }
    }

    /// Running first, soonest first; over ones after, until dismissed.
    func sorted(at now: Date) -> [QuickTimer] {
        timers.sorted { a, b in
            let ra = a.remaining(at: now), rb = b.remaining(at: now)
            if (ra > 0) != (rb > 0) { return ra > 0 }
            return ra > 0 ? ra < rb : a.deadline > b.deadline
        }
    }

    func running(at now: Date) -> [QuickTimer] { sorted(at: now).filter { !$0.isOver(at: now) } }

    /// The timer for this step's duration, if one is going.
    func timer(recipeID: UUID?, stepTitle: String, durationText: String) -> QuickTimer? {
        timers.first { $0.recipeID == recipeID && $0.stepTitle == stepTitle && $0.durationText == durationText }
    }

    @discardableResult
    func start(recipeID: UUID?, dish: String, stepTitle: String, durationText: String, seconds: Int, now: Date = Date()) -> QuickTimer? {
        guard let timer = QuickTimer.make(recipeID: recipeID, dish: dish, stepTitle: stepTitle,
                                          durationText: durationText, seconds: seconds, now: now) else { return nil }
        timers.append(timer)
        save()
        Task { _ = await notifications.ensureAuthorization() }
        notifications.schedule(stepID: "quick-" + timer.id, title: "\(timer.durationText) is up: \(timer.label)", deadline: timer.deadline)
        return timer
    }

    func stop(_ id: String) {
        timers.removeAll { $0.id == id }
        notifications.cancel(stepID: "quick-" + id)
        save()
    }

    func dismissOver(at now: Date = Date()) {
        for t in timers where t.isOver(at: now) { notifications.cancel(stepID: "quick-" + t.id) }
        timers.removeAll { $0.isOver(at: now) }
        save()
    }

    private func save() {
        try? JSONEncoder().encode(timers).write(to: fileURL, options: .atomic)
    }
}
