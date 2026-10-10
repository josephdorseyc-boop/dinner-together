import SwiftUI

@main
struct DinnerTogetherApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store: SessionStore
    @StateObject private var timers = TimerCenter()

    init() {
        #if DEBUG
        // UI-test seeding must land before SessionStore reads its file.
        LaunchOptions.writeSeedFileIfPresent()
        #endif
        _store = StateObject(wrappedValue: SessionStore(notifications: LaunchOptions.notificationService()))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(timers)
                #if DEBUG
                // UI-test forced type size (A1-T1); nil unless -dt-type-size
                // was passed, so release and ordinary debug builds are
                // unaffected.
                .transformEnvironment(\.dynamicTypeSize) { size in
                    if let forced = LaunchOptions.forcedTypeSize { size = forced }
                }
                #endif
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
///   -dt-type-size <name>  force a DynamicTypeSize (e.g. accessibility3);
///                         the -UIPreferredContentSizeCategoryName launch
///                         argument is not honored, this is (A1-T1)
///   DT_SEED_JSON          environment variable carrying a dinner-together-v2.json
///                         payload; written to the store's file before
///                         SessionStore is created (see writeSeedFileIfPresent).
///                         UI tests set it on every launch — it is never deleted,
///                         so a stale seed can only leak if a test forgets to set it.
///
/// Used by native-validation/screenshots.sh. Nothing here changes cooking
/// behavior: the inert service only replaces the permission/scheduling
/// layer, and the store's timers still run from their absolute deadlines.
enum LaunchOptions {
    #if DEBUG
    private static let arguments = Set(ProcessInfo.processInfo.arguments)
    static var openCooking: Bool { arguments.contains("-dt-open-cooking") }
    static var inertReminders: Bool { arguments.contains("-dt-inert-reminders") }

    /// Forces a DynamicTypeSize for accessibility-size UI-test renders.
    /// `-UIPreferredContentSizeCategoryName` is not honored by the app;
    /// `-dt-type-size accessibility3` is. nil in release builds.
    static var forcedTypeSize: DynamicTypeSize? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-dt-type-size"), i + 1 < args.count else { return nil }
        switch args[i + 1].lowercased() {
        case "xsmall": return .xSmall
        case "small": return .small
        case "medium": return .medium
        case "large": return .large
        case "xlarge": return .xLarge
        case "xxlarge": return .xxLarge
        case "xxxlarge": return .xxxLarge
        case "accessibility1": return .accessibility1
        case "accessibility2": return .accessibility2
        case "accessibility3": return .accessibility3
        case "accessibility4": return .accessibility4
        case "accessibility5": return .accessibility5
        default: return nil
        }
    }
    #else
    static var openCooking: Bool { false }
    static var inertReminders: Bool { false }
    static var forcedTypeSize: DynamicTypeSize? { nil }
    #endif

    /// nil means "the real NotificationManager". Main-actor isolated because
    /// `InertNotificationService` is; the only caller is `DinnerTogetherApp`'s
    /// initializer, which runs on the main actor (CI run 3: Xcode 16.4
    /// rejected the nonisolated call).
    @MainActor
    static func notificationService() -> NotificationService? {
        #if DEBUG
        return inertReminders ? InertNotificationService() : nil
        #else
        return nil
        #endif
    }

    #if DEBUG
    /// Writes the DT_SEED_JSON payload to the store's file, if the variable
    /// is present. Called from `DinnerTogetherApp.init()` before SessionStore
    /// is created, so a UI test launches straight into its seeded state.
    /// Plain file I/O, deliberately nonisolated. Never deletes: screenshots.sh
    /// writes its own seeds via simctl and launches without the variable.
    static func writeSeedFileIfPresent() {
        guard let json = ProcessInfo.processInfo.environment["DT_SEED_JSON"],
              !json.isEmpty else { return }
        let url = URL.documentsDirectory.appending(path: "dinner-together-v2.json")
        try? json.write(to: url, atomically: true, encoding: .utf8)
    }
    #endif
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
