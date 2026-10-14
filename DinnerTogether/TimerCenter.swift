import Combine
import Foundation
import SwiftUI

/// Publishes "now" every second so countdowns stay live. All countdowns derive
/// from absolute deadlines stored on the step record, so they remain accurate
/// across backgrounding and relaunch — nothing here counts down by ticks.
@MainActor
final class TimerCenter: ObservableObject {
    @Published var now = Date()
    private var cancellable: AnyCancellable?

    init() {
        cancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in self?.now = date }
    }

    func remaining(until deadline: Date) -> TimeInterval {
        deadline.timeIntervalSince(now)
    }
}
