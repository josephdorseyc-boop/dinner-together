import Foundation
import UserNotifications

/// Injected service: tests never need to show a real permission prompt.
@MainActor
protocol NotificationService: AnyObject {
    var denied: Bool { get }
    var onStatusChange: ((Bool, String?) -> Void)? { get set }
    func ensureAuthorization() async -> Bool
    func refreshAuthorization() async
    func schedule(stepID: String, title: String, deadline: Date)
    func cancel(stepID: String)
    func cancelAll()
}

extension NotificationService {
    // Lightweight mocks may omit status observation/settings refresh.
    var onStatusChange: ((Bool, String?) -> Void)? {
        get { nil }
        set { }
    }
    func refreshAuthorization() async { }
}

/// Desired reminders are reconciled by ONE asynchronous worker. Calling a
/// synchronous wrapper does not make UNUserNotificationCenter.add synchronous.
/// If cancellation happens while an add is awaiting completion, that worker
/// removes the obsolete request before rebuilding the latest desired set.
@MainActor
final class NotificationManager: NotificationService {
    private(set) var denied = false
    var onStatusChange: ((Bool, String?) -> Void)?
    private let center = UNUserNotificationCenter.current()
    private var authorizationTask: Task<Bool, Never>?
    private struct Reminder: Equatable {
        let stepID: String
        let title: String
        let deadline: Date
    }
    private var desired: [String: Reminder] = [:]
    private var revision = 0
    private var reconciling = false
    private let prefix = "dinnertogether.step."

    private func isAllowed(_ status: UNAuthorizationStatus) -> Bool {
        status == .authorized || status == .provisional || status == .ephemeral
    }

    func refreshAuthorization() async {
        let settings = await center.notificationSettings()
        denied = settings.authorizationStatus == .denied
        onStatusChange?(denied, nil)
    }

    /// Concurrent starts await the same settings check/permission request.
    /// No second caller treats "prompt in progress" as authorization granted.
    func ensureAuthorization() async -> Bool {
        if let task = authorizationTask { return await task.value }
        let task = Task { @MainActor [weak self] () -> Bool in
            guard let self = self else { return false }
            let settings = await self.center.notificationSettings()
            if settings.authorizationStatus != .notDetermined {
                self.denied = settings.authorizationStatus == .denied
                self.onStatusChange?(self.denied, nil)
                return self.isAllowed(settings.authorizationStatus)
            }
            do {
                let granted = try await self.center.requestAuthorization(options: [.alert, .sound])
                self.denied = !granted
                self.onStatusChange?(self.denied, nil)
                return granted
            } catch {
                self.onStatusChange?(self.denied,
                    "Reminder permission couldn't be checked. In-app timers still work.")
                return false
            }
        }
        authorizationTask = task
        let granted = await task.value
        authorizationTask = nil
        return granted
    }

    func schedule(stepID: String, title: String, deadline: Date) {
        let next = Reminder(stepID: stepID, title: title, deadline: deadline)
        guard desired[stepID] != next else { return }
        desired[stepID] = next
        changed()
    }

    func cancel(stepID: String) {
        desired.removeValue(forKey: stepID)
        center.removePendingNotificationRequests(withIdentifiers: [prefix + stepID])
        center.removeDeliveredNotifications(withIdentifiers: [prefix + stepID])
        changed()
    }

    func cancelAll() {
        desired = [:]
        changed()
    }

    private func changed() {
        revision += 1
        guard !reconciling else { return }
        reconciling = true
        Task { await reconcile() }
    }

    private func reconcile() async {
        while true {
            let version = revision
            let snapshot = desired.values.sorted { $0.stepID < $1.stepID }
            let pending = await center.pendingNotificationRequests()
            guard version == revision else { continue }
            // Only this app feature's reminders, never unrelated requests.
            center.removePendingNotificationRequests(withIdentifiers:
                pending.map(\.identifier).filter { $0.hasPrefix(prefix) })
            var failure: String?
            for reminder in snapshot {
                if version != revision { break }
                let interval = reminder.deadline.timeIntervalSinceNow
                guard interval > 0 else { continue } // No instant stale alerts.
                let content = UNMutableNotificationContent()
                content.title = "Dinner, Together"
                content.body = "“\(reminder.title)” timer finished — time to check it."
                content.sound = .default
                let request = UNNotificationRequest(
                    identifier: prefix + reminder.stepID, content: content,
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, interval), repeats: false))
                do { try await center.add(request) }
                catch { failure = "A reminder couldn't be scheduled. Keep the app open to follow its timer." }
                if version != revision {
                    // A cancelled add may have committed AFTER cancellation.
                    // No newer worker/add can race this cleanup: one worker owns adds.
                    center.removePendingNotificationRequests(withIdentifiers: [request.identifier])
                    center.removeDeliveredNotifications(withIdentifiers: [request.identifier])
                    break
                }
            }
            if version != revision { continue }
            onStatusChange?(denied, failure)
            reconciling = false
            return
        }
    }
}
