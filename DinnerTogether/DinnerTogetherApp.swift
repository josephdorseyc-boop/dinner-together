import SwiftUI

@main
struct DinnerTogetherApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = SessionStore(notifications: LaunchOptions.notificationService())
    @StateObject private var timers = TimerCenter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(timers)
                .task { await store.refreshNotificationSettings() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await store.refreshNotificationSettings() } }
                }
        }
    }
}

// MARK: - Debug launch options (simulator screenshots, UI tests)

/// Launch arguments honored only in DEBUG builds. Release builds ignore
/// them entirely: every accessor below is a constant `false`/`nil` there.
///
///   -dt-open-cooking      open on the Cooking screen instead of Tonight
///   -dt-inert-reminders   use a reminder service that never prompts or
///                         schedules, so no system alert covers the screen
///
/// Used by native-validation/screenshots.sh. Nothing here changes cooking
/// behavior: the inert service only replaces the permission/scheduling
/// layer, and the store's timers still run from their absolute deadlines.
enum LaunchOptions {
    #if DEBUG
    private static let arguments = Set(ProcessInfo.processInfo.arguments)
    static var openCooking: Bool { arguments.contains("-dt-open-cooking") }
    static var inertReminders: Bool { arguments.contains("-dt-inert-reminders") }
    #else
    static var openCooking: Bool { false }
    static var inertReminders: Bool { false }
    #endif

    /// nil means "the real NotificationManager".
    static func notificationService() -> NotificationService? {
        #if DEBUG
        return inertReminders ? InertNotificationService() : nil
        #else
        return nil
        #endif
    }
}

#if DEBUG
/// Grants nothing, schedules nothing, never prompts. Debug only.
@MainActor
final class InertNotificationService: NotificationService {
    private(set) var denied = false
    var onStatusChange: ((Bool, String?) -> Void)?
    func ensureAuthorization() async -> Bool { false }
    func refreshAuthorization() async { }
    func schedule(stepID: String, title: String, deadline: Date) { }
    func cancel(stepID: String) { }
    func cancelAll() { }
}
#endif
