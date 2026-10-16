import CryptoKit
import Foundation
import SwiftUI
#if canImport(AlarmKit)
import AlarmKit
#endif

/// Timers that ring like the Clock app's (build 22; Joe, October 15: "the
/// times don't ring any alarms on the phone, just a notification"). On iOS
/// 26.1 and later, once the cook allows it, every timer reminder — a kitchen
/// timer's or a cooking step's — is a system alarm: it sounds through the
/// ring switch and Focus, on the Lock Screen with Stop, app open or not.
/// Without that permission (or on an older iOS) the build 21 behaviour
/// stays: the chime notification, and the in-app chime while the app is open.
///
/// Alert-only alarms at a fixed time; no countdown presentation, so no
/// widget extension is needed for this part (Apple: an extension is expected
/// only for countdown presentations). The countdown on the Lock Screen and
/// the Duo's tent mode come with the Live Activity (#24).
@MainActor
final class SystemAlarms {
    static let shared = SystemAlarms()

    /// Timer reminders ring as system alarms now.
    private(set) var enabled = false
    /// What this launch has handed the system, by reminder key — and so
    /// what is covered: a reminder not here (its schedule call failed) gets
    /// the notification instead (A2's review, #24, October 16).
    private var scheduled: [String: Date] = [:]
    /// Alarms whose cancel call failed: tried again on every reconcile,
    /// so a stopped timer can't leave a stray alarm behind for good.
    private var cancelling: Set<UUID> = []
    /// Alarms left with the system by an earlier launch are only trusted
    /// once checked against what is wanted now (and the check itself has
    /// to succeed to count).
    private var checkedSystemList = false

    /// This reminder rings as a system alarm: nothing else needs to.
    func covers(_ key: String) -> Bool { scheduled[key] != nil }

    /// The alarm's ID for a reminder: the same key always gives the same
    /// ID, so a relaunch or a moved deadline finds and replaces its alarm.
    nonisolated static func alarmID(for key: String) -> UUID {
        var b = Array(SHA256.hash(data: Data(("dinner-together-alarm:" + key).utf8)).prefix(16))
        b[6] = (b[6] & 0x0F) | 0x50   // name-based, version 5 style
        b[8] = (b[8] & 0x3F) | 0x80   // RFC 4122 variant
        return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
                           b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
    }

    /// Reads the permission as it is now (it can change in Settings).
    func refresh() {
        #if canImport(AlarmKit)
        if #available(iOS 26.1, *) {
            enabled = AlarmManager.shared.authorizationState == .authorized
            return
        }
        #endif
        enabled = false
    }

    /// Asks once, the first time a timer starts; afterwards reads the answer.
    func requestAuthorization() async -> Bool {
        #if canImport(AlarmKit)
        if #available(iOS 26.1, *) {
            let manager = AlarmManager.shared
            if manager.authorizationState == .notDetermined {
                _ = try? await manager.requestAuthorization()
            }
            enabled = manager.authorizationState == .authorized
            return enabled
        }
        #endif
        return false
    }

    /// Brings the system's alarms in line with the wanted reminders: new or
    /// moved ones scheduled, gone ones cancelled. Past deadlines are left
    /// alone (an alarm that has rung is the system's until Stop). Returns
    /// the keys that now have a system alarm; the caller gives the rest a
    /// notification, so a schedule call that fails never leaves a timer
    /// with nothing to ring it.
    @discardableResult
    func reconcile(_ wanted: [String: (title: String, deadline: Date)], now: Date = Date()) async -> Set<String> {
        #if canImport(AlarmKit)
        guard #available(iOS 26.1, *), enabled else { return [] }
        let manager = AlarmManager.shared
        let wantedIDs = Set(wanted.keys.map(Self.alarmID(for:)))
        if !checkedSystemList, let existing = try? manager.alarms {
            checkedSystemList = true
            for alarm in existing where !wantedIDs.contains(alarm.id) { cancelling.insert(alarm.id) }
        }
        for key in scheduled.keys where wanted[key] == nil {
            cancelling.insert(Self.alarmID(for: key))
            scheduled[key] = nil
        }
        for (key, reminder) in wanted where reminder.deadline > now && scheduled[key] != reminder.deadline {
            let id = Self.alarmID(for: key)
            // The old deadline cannot cover the wanted reminder. Invalidate
            // it before cancelling: a failed cancel may succeed in the
            // tombstone pass below without scheduling the replacement.
            // Keep that key uncovered so notifications/chime can fall back.
            scheduled[key] = nil
            // A moved deadline replaces its alarm; a cancel that fails is
            // retried below, before the new schedule.
            cancelling.insert(id)
            if cancel(id, manager: manager) {
                do {
                    _ = try await manager.schedule(id: id, configuration: Self.configuration(title: reminder.title, deadline: reminder.deadline))
                    scheduled[key] = reminder.deadline
                } catch {
                    scheduled[key] = nil // the notification covers it; the next reconcile tries again
                }
            }
        }
        // Whatever still couldn't be cancelled: once more now, and on every
        // reconcile until the system agrees.
        for id in cancelling { _ = cancel(id, manager: manager) }
        return Set(scheduled.keys)
        #else
        return []
        #endif
    }

    #if canImport(AlarmKit)
    /// Cancels, and forgets the tombstone only once the system agreed.
    @available(iOS 26.1, *)
    private func cancel(_ id: UUID, manager: AlarmManager) -> Bool {
        do {
            try manager.cancel(id: id)
            cancelling.remove(id)
            return true
        } catch {
            return false
        }
    }
    #endif

    #if canImport(AlarmKit)
    @available(iOS 26.1, *)
    private static func configuration(title: String, deadline: Date) -> AlarmManager.AlarmConfiguration<DinnerAlarmMetadata> {
        let alert = AlarmPresentation.Alert(title: LocalizedStringResource(stringLiteral: title),
                                            secondaryButton: nil, secondaryButtonBehavior: nil)
        let attributes = AlarmAttributes<DinnerAlarmMetadata>(presentation: AlarmPresentation(alert: alert),
                                                              metadata: nil, tintColor: Theme.tomato)
        return .alarm(schedule: .fixed(deadline), attributes: attributes,
                      stopIntent: nil, secondaryIntent: nil, sound: .named(TimerAlarm.soundFile))
    }
    #endif
}

#if canImport(AlarmKit)
/// Nothing extra rides on the alarm yet; the Live Activity (tent mode) will
/// carry the dish and step here.
@available(iOS 26.0, *)
struct DinnerAlarmMetadata: AlarmMetadata {}
#endif
