import Foundation
@testable import DinnerTogether

/// Engine test fixtures: the sample menus (DebugSampleMenus.swift) behind a
/// store that resolves them, with "steak" as tonight's dinner — what every
/// pre-recipe test assumed by default.
extension SampleMenus {
    @MainActor
    static func store(fileURL: URL, notifications: NotificationService) -> SessionStore {
        let store = SessionStore(fileURL: fileURL, notifications: notifications, menuProvider: Provider())
        if store.session.menuID.isEmpty { store.session.menuID = "steak" }
        return store
    }

    final class Provider: MenuProviding {
        func menu(id: String) -> DinnerMenu? { SampleMenus.menu(id: id) }
    }
}
