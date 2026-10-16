import ActivityKit
import Foundation

/// Keeps the dinner's Live Activity (DinnerTimersAttributes) in step with
/// the running timers — kitchen timers and the plan's step timers — so the
/// Lock Screen, the Dynamic Island, StandBy and the Duo's cover in tent mode
/// show them (build 22, #24). Updates only when the set of running timers
/// changes; the system draws the countdowns. Ends when none is running.
@MainActor
final class LiveDinnerTimers {
    static let shared = LiveDinnerTimers()

    private var activity: Activity<DinnerTimersAttributes>?
    private var adopted = false
    /// The running timers last shown successfully — not merely wanted
    /// (A2, #24: a refused or failed request must be able to try again).
    private var applied: [String] = []
    /// A start that didn't take (Live Activities off, or the request
    /// failed) is retried at most this often, not every second.
    private var lastFailedStart: Date?
    private static let retryInterval: TimeInterval = 30

    /// Called every second with what's running; cheap unless something changed.
    func refresh(now: Date, quick: [QuickTimer], store: SessionStore) {
        // UI tests keep their screens to themselves.
        if LaunchOptions.inertReminders { return }
        if !adopted {
            adopted = true
            activity = Activity<DinnerTimersAttributes>.activities.first
        }
        let runningQuick = quick.filter { $0.deadline > now }
        let runningSteps = store.session.records.compactMap { id, record -> (String, StepRecord, Date)? in
            guard record.state == .cooking, let deadline = record.timerDeadline, deadline > now else { return nil }
            return (id, record, deadline)
        }
        let next = (runningQuick.map { "q\($0.id)@\($0.deadline.timeIntervalSince1970)" }
                    + runningSteps.map { "s\($0.0)@\($0.2.timeIntervalSince1970)" }).sorted()
        // Dismissed from the Lock Screen or ended by the system: nothing is
        // showing, whatever was applied before.
        if let current = activity, current.activityState != .active {
            activity = nil
            applied = []
        }
        if next.isEmpty {
            end()
            applied = []
            lastFailedStart = nil
            return
        }
        if next == applied && activity != nil { return }
        if activity == nil, let lastFailedStart, now.timeIntervalSince(lastFailedStart) < Self.retryInterval { return }

        var timers = runningQuick.map {
            DinnerTimersAttributes.ContentState.Timer(id: "q" + $0.id, dish: $0.dish, step: $0.stepTitle,
                                                      startedAt: $0.startedAt, deadline: $0.deadline)
        }
        if !runningSteps.isEmpty {
            let plan = Dictionary(store.plan.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            for (id, record, deadline) in runningSteps {
                let planned = plan[id]
                timers.append(.init(id: "s" + id, dish: planned?.step.dish ?? store.menu.title,
                                    step: planned?.step.title ?? "",
                                    startedAt: record.actualStart ?? now, deadline: deadline))
            }
        }
        timers.sort { $0.deadline < $1.deadline }
        let content = ActivityContent(state: DinnerTimersAttributes.ContentState(timers: timers),
                                      staleDate: timers.last?.deadline)
        if let current = activity {
            Task { await current.update(content) }
            applied = next
        } else {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { lastFailedStart = now; return }
            let title = store.hasDinner ? store.menu.title : "Kitchen timers"
            do {
                activity = try Activity.request(attributes: DinnerTimersAttributes(dinnerTitle: title),
                                                content: content, pushType: nil)
                applied = next
                lastFailedStart = nil
            } catch {
                lastFailedStart = now
            }
        }
    }

    private func end() {
        guard let current = activity else { return }
        activity = nil
        Task { await current.end(nil, dismissalPolicy: .immediate) }
    }
}
