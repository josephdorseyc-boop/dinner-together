// EngineTestSupport.swift — NOT part of the Xcode app target.
//
// Compiled only by Package.swift (the `swift test` harness) in place of
// Notifications.swift, so SessionStore can be exercised without the
// UserNotifications framework. The protocol below is a verbatim copy of the
// one in Notifications.swift; keep them identical. NotificationManager here
// is inert — every test injects MockNotifications, so the real manager is
// never constructed in tests on any platform.
//
// If you add this file to the Xcode target by mistake it will collide with
// Notifications.swift. Leave it out of the project.

import Foundation

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

/// Inert stand-in used only when SessionStore is built by the harness and
/// no service is injected. Grants nothing, schedules nothing.
@MainActor
final class NotificationManager: NotificationService {
    private(set) var denied = false
    var onStatusChange: ((Bool, String?) -> Void)?
    func ensureAuthorization() async -> Bool { false }
    func refreshAuthorization() async { }
    func schedule(stepID: String, title: String, deadline: Date) { }
    func cancel(stepID: String) { }
    func cancelAll() { }
}

#if os(Linux)
/// Linux stand-in for the Darwin/iOS 16+ `URL.documentsDirectory` used by the
/// default argument of `SessionStore.init(fileURL:notifications:)`. Every test
/// injects `fileURL:`, so this is never evaluated at test time; it exists so
/// the harness compiles on Linux (Agent 1 finding A1-1, Swift 6.0.3). If a
/// future Linux Foundation adds the real member, this becomes ambiguous and
/// should be deleted.
extension URL {
    static var documentsDirectory: URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("dinner-together-engine-tests", isDirectory: true)
    }
}
#endif
