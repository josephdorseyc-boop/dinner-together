import AVFoundation
import SwiftUI
import UIKit

/// Timers ring (Joe, October 15: "the times don't ring any alarms on the
/// phone, just a notification"). While the app is open, a kitchen timer or a
/// cooking step's timer that ends plays the chime — through the ring switch,
/// since the cook is using the app — with a buzz, until Stop, until that timer
/// is stopped or its step marked done, or for about fifty seconds. In the
/// background the notification plays the same chime (Notifications.swift).
/// Ringing never stops a timer, dismisses it or marks anything done.
/// Build 22 brings system alarms (AlarmKit) that ring through silent mode
/// and Focus with the app closed.
@MainActor
final class TimerAlarm: ObservableObject {
    /// In the app bundle; the notification sound uses it too (≤ 30 s).
    static let soundFile = "timer-chime.wav"
    /// Two plays of the 25-second chime.
    static let ringSeconds: TimeInterval = 50
    /// A timer that ended longer ago than this (the app was away) doesn't
    /// ring on return: its notification already did.
    private static let freshSeconds: TimeInterval = 120

    /// What's ringing, by name ("Green beans · Simmer"), for the banner.
    @Published private(set) var ringing: [String] = []

    private var ringingKeys: [String] = []
    private var labels: [String: String] = [:]
    /// Every ended timer already rung (or ended while away): never again.
    private var rung: Set<String> = []
    private var primed = false
    private var active = true
    private var startedAt: Date?
    private var lastBuzz: Date?
    private var player: AVAudioPlayer?

    /// Called every second with what's running.
    func tick(now: Date, quick: [QuickTimer], store: SessionStore) {
        guard active else { return }
        var over: [String: Date] = [:]
        var quickByKey: [String: QuickTimer] = [:]
        var stepByKey: [String: String] = [:]
        for t in quick where t.isOver(at: now) {
            let key = "quick-" + t.id
            over[key] = t.deadline
            quickByKey[key] = t
        }
        for (id, record) in store.session.records where record.state == .cooking {
            guard let deadline = record.timerDeadline, deadline <= now else { continue }
            let key = "step-\(id)-\(Int(deadline.timeIntervalSince1970))"
            over[key] = deadline
            stepByKey[key] = id
        }
        // Whatever had already ended when the app opened (or came back) was
        // the notification's to ring.
        guard primed else {
            rung.formUnion(over.keys)
            primed = true
            return
        }
        // Stopped, dismissed or marked done: that one stops ringing.
        ringingKeys.removeAll { over[$0] == nil }
        let fresh = over.filter { !rung.contains($0.key) && now.timeIntervalSince($0.value) < Self.freshSeconds }
            .sorted { $0.value < $1.value }
        rung.formUnion(over.keys)
        if !fresh.isEmpty {
            var steps: [String: String] = [:]
            if fresh.contains(where: { stepByKey[$0.key] != nil }) {
                for item in store.plan { steps[item.id] = item.step.title }
            }
            for (key, _) in fresh {
                if let t = quickByKey[key] {
                    labels[key] = t.label
                } else if let id = stepByKey[key] {
                    labels[key] = steps[id] ?? "A cooking step"
                }
                ringingKeys.append(key)
            }
            startSound(now: now, announce: fresh.compactMap { labels[$0.key] })
        }
        if ringingKeys.isEmpty {
            stopSound()
        } else if let startedAt, now.timeIntervalSince(startedAt) > Self.ringSeconds {
            silence()
        } else if let lastBuzz, now.timeIntervalSince(lastBuzz) >= 5 {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            self.lastBuzz = now
        }
        let names = ringingKeys.compactMap { labels[$0] }
        if names != ringing { ringing = names }
    }

    /// Stop: quiet now. The timers stay as they are ("Time's up" on their
    /// faces until dismissed); nothing is marked done.
    func silence() {
        ringingKeys.removeAll()
        stopSound()
        if !ringing.isEmpty { ringing = [] }
    }

    /// Away (background, another app): quiet, and whatever ends meanwhile is
    /// the notification's. Back: anything already over doesn't ring again.
    func setActive(_ isActive: Bool) {
        guard isActive != active else { return }
        active = isActive
        if !isActive {
            silence()
            primed = false
        }
    }

    private func startSound(now: Date, announce: [String]) {
        startedAt = now
        lastBuzz = now
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        if !announce.isEmpty {
            UIAccessibility.post(notification: .announcement, argument: "Time’s up: " + announce.joined(separator: "; "))
        }
        if let player, player.isPlaying { player.currentTime = 0; return }
        guard let url = Bundle.main.url(forResource: "timer-chime", withExtension: "wav") else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            // Playback plays with the ring switch on silent; others duck.
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
            let next = try AVAudioPlayer(contentsOf: url)
            next.numberOfLoops = 1
            next.play()
            player = next
        } catch {
            player = nil // the buzz and the banner still say it
        }
    }

    private func stopSound() {
        startedAt = nil
        lastBuzz = nil
        guard let player else { return }
        player.stop()
        self.player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

/// Drives the alarm from the one-second clock and the app's state. Its own
/// small view, so the second-by-second updates don't re-render the root.
struct TimerAlarmDriver: View {
    @ObservedObject var alarm: TimerAlarm
    @EnvironmentObject private var timers: TimerCenter
    @EnvironmentObject private var quickTimers: QuickTimerStore
    @EnvironmentObject private var store: SessionStore
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onChange(of: timers.now) { _, now in
                alarm.tick(now: now, quick: quickTimers.timers, store: store)
            }
            .onChange(of: scenePhase) { _, phase in
                // Inactive (Control Center, the app switcher) still rings;
                // only the background hands over to the notification.
                alarm.setActive(phase != .background)
            }
    }
}

/// While it rings: what's up, and Stop — on every screen, so the cook can
/// quiet it from wherever they are. Stop only silences.
struct TimerAlarmBanner: View {
    @ObservedObject var alarm: TimerAlarm

    var body: some View {
        if let first = alarm.ringing.first {
            HStack(spacing: 12) {
                Image(systemName: "bell.fill")
                    .foregroundStyle(Theme.warning)
                    .symbolEffect(.bounce, options: .repeating)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Time’s up").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.warning)
                    Text(alarm.ringing.count > 1 ? "\(first) · and \(alarm.ringing.count - 1) more" : first)
                        .font(.subheadline).foregroundStyle(Theme.ink)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Button { alarm.silence() } label: {
                    Text("Stop").font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 18).frame(minHeight: 44)
                        .foregroundStyle(.white)
                        .background(Capsule().fill(Theme.tomato))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop the alarm")
                .accessibilityHint("Quiets it. The timer stays until you dismiss it.")
                .accessibilityIdentifier("timer-alarm-stop")
            }
            .padding(.leading, 16).padding(.trailing, 8).padding(.vertical, 8)
            .frame(maxWidth: 520)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.warning.opacity(0.6)))
            .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
            .padding(.horizontal, 16)
            .environment(\.colorScheme, .light)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("timer-alarm")
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
