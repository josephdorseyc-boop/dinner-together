import ActivityKit
import Foundation

/// The dinner's running timers as one Live Activity (build 22, #24): the
/// Lock Screen, the Dynamic Island and StandBy show each dish's countdown —
/// and so does the iPhone Duo's cover, folded and stood up in tent mode by
/// the stove. Deadlines only: the system counts down, so the app updates
/// the activity when a timer starts, stops or ends, never every second.
/// Compiled into the app and the DinnerTimers widget extension.
struct DinnerTimersAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        struct Timer: Codable, Hashable, Identifiable {
            var id: String
            /// The dish ("Green beans"), and the step ("Steam") when known.
            var dish: String
            var step: String
            var startedAt: Date
            var deadline: Date
        }
        /// Soonest first; the first leads.
        var timers: [Timer]
    }

    /// Tonight's dinner ("Roast chicken + Green beans"), or "Kitchen timers".
    var dinnerTitle: String
}
