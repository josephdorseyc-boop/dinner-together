import SwiftUI
import UIKit

// Timers full screen (build 22; Joe, October 16: "I want the timers to be
// full screen in tent mode and nightstand mode"; A2's board 01, revised).
//
// While the app is open, the running timers fill the display edge to edge:
// the lead timer's ring and countdown with its dish and step, every other
// timer listed with its own countdown. It opens on its own when the folded
// Duo's cover is stood sideways (tent) or an iPhone lies on its side while
// charging (nightstand), and by hand from Cooking or the Timers page. It
// keeps the screen awake while a timer shows, so the phone doesn't lock
// over it. At night it goes dark and dim (Joe, October 16, 8:19 AM: "I'd
// like it to change dark/dim at nighttime"): when the phone is in Dark
// Mode, or between 9 PM and 6 AM whatever the phone says — the only page
// besides Tonight that does. Locked or closed, the Live Activity is the system's version of
// this (StandBy fills the screen with it) and AlarmKit rings; neither is
// drawn here. Nothing on this page starts, restarts or completes anything:
// Stop and Dismiss end a kitchen timer, and a cooking step is marked done
// on Cooking.

/// One countdown on the page: a kitchen timer or a cooking step's timer.
struct FullScreenTimerEntry: Identifiable, Equatable {
    enum Kind: Equatable {
        case kitchen(String)
        case step(String)
    }
    let kind: Kind
    let dish: String
    let step: String
    let startedAt: Date
    let deadline: Date

    var id: String {
        switch kind {
        case .kitchen(let id): return "q" + id
        case .step(let id): return "s" + id
        }
    }
    func isOver(at now: Date) -> Bool { deadline <= now }
    var isKitchen: Bool { if case .kitchen = kind { return true } else { return false } }
    var label: String { step.isEmpty ? dish : "\(step) · \(dish)" }

    /// The kitchen timer's own ring, for either kind: the ring needs only
    /// the label, the start, the deadline and the length.
    var ring: QuickTimer {
        QuickTimer(id: id, recipeID: nil, dish: dish, stepTitle: step, durationText: "",
                   seconds: max(1, Int(deadline.timeIntervalSince(startedAt).rounded())),
                   startedAt: startedAt, deadline: deadline)
    }

    /// Every kitchen timer and every cooking step's timer — running or up.
    /// A timer that's up leads (it wants attention), then the soonest.
    @MainActor
    static func all(now: Date, quick: [QuickTimer], store: SessionStore) -> [FullScreenTimerEntry] {
        var entries = quick.map {
            FullScreenTimerEntry(kind: .kitchen($0.id), dish: $0.dish, step: $0.stepTitle,
                                 startedAt: $0.startedAt, deadline: $0.deadline)
        }
        let cooking = store.session.records.filter { $0.value.state == .cooking && $0.value.timerDeadline != nil }
        if !cooking.isEmpty {
            let plan = Dictionary(store.plan.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            for (id, record) in cooking {
                guard let deadline = record.timerDeadline else { continue }
                let planned = plan[id]
                entries.append(FullScreenTimerEntry(kind: .step(id), dish: planned?.step.dish ?? store.menu.title,
                                                    step: planned?.step.title ?? "",
                                                    startedAt: record.actualStart ?? planned?.start ?? deadline,
                                                    deadline: deadline))
            }
        }
        return entries.sorted { a, b in
            let ao = a.isOver(at: now), bo = b.isOver(at: now)
            if ao != bo { return ao }
            return a.deadline != b.deadline ? a.deadline < b.deadline : a.id < b.id
        }
    }
}

/// Opens and closes the page, decides tent and nightstand, and keeps the
/// screen awake while it shows a timer. Presented by UIKit over whatever
/// is on screen — a sheet included — so nothing can hold it back.
@MainActor
final class FullScreenTimers {
    static let shared = FullScreenTimers()

    enum Mode: Equatable {
        case byHand, tent, nightstand
    }

    /// Ordinary iPhones are upright-only; while the page shows, they turn
    /// (AppDelegate reads this; a plain flag so its rule stays simple).
    nonisolated(unsafe) static var allowsLandscape = false

    private(set) var mode: Mode?
    /// The page, with the app's stores, from the root (FullScreenTimersDriver).
    var makePage: (() -> AnyView)?

    private weak var host: FullScreenTimersHost?
    private var presentedAt: Date?
    /// Done while still in tent or on the nightstand: not again until that
    /// pose ends (picked up, unplugged, turned upright, opened).
    private var declinedPose = false
    private var poseTicks = 0
    private var offTicks = 0
    private var emptyTicks = 0

    private init() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        UIDevice.current.isBatteryMonitoringEnabled = true
    }

    /// Night: the phone in Dark Mode (its own schedule or the cook's
    /// choice), or 9 PM to 6 AM by the clock. UI tests force it with
    /// -dt-appearance dark.
    nonisolated static func isNight(at now: Date = Date(), calendar: Calendar = .current) -> Bool {
        let hour = calendar.component(.hour, from: now)
        return hour >= 21 || hour < 6
    }

    static var night: Bool {
        if let forced = LaunchOptions.forcedColorScheme { return forced == .dark }
        return isNight() || UIScreen.main.traitCollection.userInterfaceStyle == .dark
    }

    /// By hand, from Cooking or the Timers page.
    func open() { present(.byHand) }

    /// Done, or Go to Cooking. Closed while posed — opened by the pose or
    /// by hand — it stays closed until the pose ends. `toRoot`: Go to
    /// Cooking also closes whatever the page was opened over (the Timers
    /// sheet, a recipe's), so Cooking is what's left (A2's review, #24).
    func close(toRoot: Bool = false) {
        if currentPose() != nil { declinedPose = true }
        dismiss(toRoot: toRoot)
    }

    /// Every second, from the root, with what's running.
    func tick(now: Date, quick: [QuickTimer], store: SessionStore, active: Bool) {
        let hasTimers = !quick.isEmpty || store.session.records.values.contains { $0.state == .cooking && $0.timerDeadline != nil }
        // Knocked off screen by something else (a sheet under it closing):
        // forget it, so the page can come back.
        if mode != nil, let presentedAt, now.timeIntervalSince(presentedAt) > 2,
           host?.viewIfLoaded?.window == nil {
            declinedPose = true
            reset()
        }
        let pose = currentPose()
        poseTicks = pose == nil ? 0 : poseTicks + 1
        offTicks = pose == nil ? offTicks + 1 : 0
        emptyTicks = hasTimers ? 0 : emptyTicks + 1
        if pose == nil { declinedPose = false }

        switch mode {
        case nil:
            // About two seconds in the pose, so turning the phone in hand
            // doesn't flash the page.
            if let pose, poseTicks >= 2, hasTimers, active, !declinedPose, LaunchOptions.fullScreenAuto {
                present(pose)
            }
        case .byHand?:
            break
        case .tent?, .nightstand?:
            // Leaves with the pose, or once no timer is left.
            if offTicks >= 2 || emptyTicks >= 2 { dismiss() }
        }
        let awake = mode != nil && hasTimers
        if UIApplication.shared.isIdleTimerDisabled != awake {
            UIApplication.shared.isIdleTimerDisabled = awake
        }
        // Night falls (or Dark Mode switches) while it's up.
        if let host {
            let style: UIUserInterfaceStyle = Self.night ? .dark : .light
            if host.overrideUserInterfaceStyle != style { host.overrideUserInterfaceStyle = style }
        }
    }

    /// Tent: the folded Duo's cover turned sideways — a window that turns
    /// on its own (near-square screen) lying landscape with its short side
    /// under 600 pt, the same rule as This Week. Nightstand: a phone on its
    /// side while charging.
    private func currentPose() -> Mode? {
        guard UIDevice.current.userInterfaceIdiom == .phone, let window = Self.keyWindow() else { return nil }
        let size = window.bounds.size
        let short = min(size.width, size.height)
        if size.width > size.height, short > 0, short < 600, AppDelegate.turnsOnItsOwn(window) {
            return .tent
        }
        if UIDevice.current.orientation.isLandscape, Self.charging {
            return .nightstand
        }
        return nil
    }

    private static var charging: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-dt-assume-charging") { return true }
        #endif
        let state = UIDevice.current.batteryState
        return state == .charging || state == .full
    }

    private func present(_ next: Mode) {
        guard mode == nil, let page = makePage?(), let top = Self.topViewController(),
              !(top is UIAlertController) else { return }
        mode = next
        Self.allowsLandscape = true
        presentedAt = Date()
        let host = FullScreenTimersHost(rootView: page)
        // Over, not instead of, the screen beneath: the app underneath stays
        // live (its alarm and Live Activity ticks keep running) and is
        // exactly as it was when the page closes. It fills the window, so
        // it decides which way the phone turns.
        host.modalPresentationStyle = .overFullScreen
        host.modalPresentationCapturesStatusBarAppearance = true
        host.modalTransitionStyle = .crossDissolve
        host.overrideUserInterfaceStyle = Self.night ? .dark : .light // cream by day; dark at night
        self.host = host
        top.present(host, animated: true) {
            host.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }

    private func dismiss(toRoot: Bool = false) {
        guard mode != nil else { return }
        let presenter = host?.presentingViewController
        reset()
        let root = Self.keyWindow()?.rootViewController
        (toRoot ? root : presenter)?.dismiss(animated: true) {
            presenter?.setNeedsUpdateOfSupportedInterfaceOrientations()
            root?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }

    private func reset() {
        mode = nil
        host = nil
        presentedAt = nil
        Self.allowsLandscape = false
        poseTicks = 0
        if UIApplication.shared.isIdleTimerDisabled { UIApplication.shared.isIdleTimerDisabled = false }
    }

    static func keyWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        return scene?.keyWindow ?? scene?.windows.first
    }

    private static func topViewController() -> UIViewController? {
        var top = keyWindow()?.rootViewController
        while let next = top?.presentedViewController, !next.isBeingDismissed { top = next }
        return top
    }
}

/// The page's own controller: turns any way on a phone, no status bar, the
/// home indicator out of the way.
final class FullScreenTimersHost: UIHostingController<AnyView> {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
}

/// Hands the page the app's stores and runs the once-a-second check. Its
/// own small view, like the alarm's, so the ticks don't re-render the root.
struct FullScreenTimersDriver: View {
    @ObservedObject var alarm: TimerAlarm
    let openCooking: () -> Void
    @EnvironmentObject private var timers: TimerCenter
    @EnvironmentObject private var quickTimers: QuickTimerStore
    @EnvironmentObject private var store: SessionStore
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear { install() }
            .onChange(of: timers.now) { _, now in
                FullScreenTimers.shared.tick(now: now, quick: quickTimers.timers, store: store,
                                             active: scenePhase == .active)
            }
    }

    private func install() {
        let center = self.timers, kitchen = self.quickTimers, session = self.store
        let ringing = self.alarm, goCooking = self.openCooking
        FullScreenTimers.shared.makePage = {
            AnyView(FullScreenTimersView(alarm: ringing, openCooking: goCooking)
                .environmentObject(center)
                .environmentObject(kitchen)
                .environmentObject(session)
                .uiTestTypeSize())
        }
    }
}

/// "Full screen" — on Cooking's bar and the Timers page, while any timer
/// runs or is up.
struct FullScreenTimersButton: View {
    var body: some View {
        Button { FullScreenTimers.shared.open() } label: {
            Label("Full screen", systemImage: "arrow.up.left.and.arrow.down.right")
        }
        .accessibilityLabel("Timers full screen")
        .accessibilityHint("Shows every running timer across the whole screen and keeps it awake.")
        .accessibilityIdentifier("timers-fullscreen")
    }
}

/// The page itself (board 01): cream to every edge. Landscape — the lead
/// ring on the left, its dish and step beside it, the other timers in a
/// column; upright — the same, stacked. Tap a listed timer to bring it to
/// the front, where its actions are.
struct FullScreenTimersView: View {
    @ObservedObject var alarm: TimerAlarm
    let openCooking: () -> Void
    @EnvironmentObject private var timers: TimerCenter
    @EnvironmentObject private var quickTimers: QuickTimerStore
    @EnvironmentObject private var store: SessionStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedID: String?

    var body: some View {
        let now = timers.now
        let night = FullScreenTimers.night
        let entries = FullScreenTimerEntry.all(now: now, quick: quickTimers.timers, store: store)
        let lead = entries.first { $0.id == selectedID } ?? entries.first
        let others = entries.filter { $0.id != lead?.id }
        GeometryReader { g in
            let landscape = g.size.width > g.size.height
            VStack(spacing: 0) {
                topBar
                if let lead {
                    if dynamicTypeSize.isAccessibilitySize {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                leadBlock(lead, others: others, now: now, ring: min(g.size.width, g.size.height) * 0.62, centered: false)
                                otherList(others, now: now)
                            }
                            .padding(.bottom, 24)
                        }
                    } else if landscape {
                        // Board 01: ring, words, then the other timers —
                        // about a third of the width each.
                        let usable = g.size.width - 64
                        HStack(alignment: .center, spacing: 28) {
                            leadBlock(lead, others: others, now: now,
                                      ring: min(g.size.height * 0.64, usable * (others.isEmpty ? 0.42 : 0.30)), centered: false)
                            if !others.isEmpty {
                                Rectangle().fill(Theme.line).frame(width: 1).padding(.vertical, 24).accessibilityHidden(true)
                                otherList(others, now: now)
                                    .frame(width: min(300, usable * 0.30))
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VStack(spacing: 20) {
                            leadBlock(lead, others: others, now: now,
                                      ring: min(g.size.width * 0.72, g.size.height * (others.isEmpty ? 0.46 : 0.36)), centered: true)
                            if !others.isEmpty {
                                Rectangle().fill(Theme.line).frame(height: 1).accessibilityHidden(true)
                                otherList(others, now: now)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    empty
                }
            }
            .padding(.horizontal, landscape ? 32 : 24)
            .padding(.bottom, 12)
        }
        // At night the whole page is dim as well as dark: a nightstand
        // isn't read at arm's length in full contrast.
        .opacity(night ? 0.72 : 1)
        .background(Theme.cream.ignoresSafeArea())
        .foregroundStyle(Theme.ink)
        .overlay(alignment: .top) {
            TimerAlarmBanner(alarm: alarm)
                .padding(.top, 8)
                .animation(.easeOut(duration: 0.25), value: alarm.ringing)
        }
        .environment(\.colorScheme, night ? .dark : .light)
        .animation(.easeInOut(duration: 0.6), value: night)
        .tint(Theme.tomato)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fullscreen-timers")
        .accessibilityValue(night ? "Night" : "Day")
        .onChange(of: entries.map(\.id)) { _, ids in
            if let selectedID, !ids.contains(selectedID) { self.selectedID = nil }
        }
    }

    private var topBar: some View {
        HStack {
            Button { FullScreenTimers.shared.close() } label: {
                Label("Done", systemImage: "chevron.down")
                    .font(.headline)
                    .padding(.horizontal, 14).frame(minHeight: 44)
                    .background(Theme.ink.opacity(0.05), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Done")
            .accessibilityHint("Closes the full-screen timers. They keep running.")
            .accessibilityIdentifier("fullscreen-timers-done")
            Spacer()
            Image(systemName: "leaf")
                .font(.title2)
                .rotationEffect(.degrees(-35))
                .foregroundStyle(Theme.tomato.opacity(0.85))
                .accessibilityHidden(true)
        }
        .padding(.top, 8)
    }

    private func leadBlock(_ lead: FullScreenTimerEntry, others: [FullScreenTimerEntry], now: Date,
                           ring: CGFloat, centered: Bool) -> some View {
        let over = lead.isOver(at: now)
        let size = max(140, ring)
        let words = VStack(alignment: centered ? .center : .leading, spacing: 8) {
            SectionLabel(text: over ? "TIME’S UP" : (others.isEmpty ? "ONE TIMER" : "NEXT TO FINISH"))
            Text(lead.dish)
                .font(.system(.title, design: .serif).weight(.medium))
                .multilineTextAlignment(centered ? .center : .leading)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                .minimumScaleFactor(0.7)
            if !lead.step.isEmpty {
                Text(lead.step)
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(centered ? .center : .leading)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            }
            if over {
                Text(lead.isKitchen ? "Check the food, then dismiss the timer." : "Check the food. Mark the step done on Cooking.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.warning)
                    .multilineTextAlignment(centered ? .center : .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            actions(lead, over: over)
                .padding(.top, 8)
        }
        return Group {
            if centered {
                VStack(spacing: 16) {
                    TimerRing(timer: lead.ring, now: now, size: size, lineWidth: max(10, size * 0.05))
                    words
                }
            } else if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 16) {
                    TimerRing(timer: lead.ring, now: now, size: size, lineWidth: max(10, size * 0.05))
                    words
                }
            } else {
                HStack(alignment: .center, spacing: 28) {
                    TimerRing(timer: lead.ring, now: now, size: size, lineWidth: max(10, size * 0.05))
                    words.frame(maxWidth: 380, alignment: .leading)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fullscreen-lead")
    }

    @ViewBuilder
    private func actions(_ lead: FullScreenTimerEntry, over: Bool) -> some View {
        switch lead.kind {
        case .kitchen(let id):
            Button { quickTimers.stop(id) } label: {
                Label(over ? "Dismiss" : "Stop timer", systemImage: over ? "checkmark" : "stop.fill")
            }
            .buttonStyle(SecondaryButtonStyle())
            .frame(maxWidth: 260)
            .accessibilityLabel(over ? "Dismiss the \(lead.label) timer" : "Stop the \(lead.label) timer")
            .accessibilityIdentifier("fullscreen-stop")
        case .step:
            Button {
                FullScreenTimers.shared.close(toRoot: true)
                openCooking()
            } label: {
                Label("Go to Cooking", systemImage: "frying.pan")
            }
            .buttonStyle(SecondaryButtonStyle())
            .frame(maxWidth: 260)
            .accessibilityHint("Closes the full-screen timers and opens Cooking, where steps are marked done.")
            .accessibilityIdentifier("fullscreen-cooking")
        }
    }

    private func otherList(_ others: [FullScreenTimerEntry], now: Date) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(others) { entry in
                    let over = entry.isOver(at: now)
                    Button { selectedID = entry.id } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.dish)
                                    .font(.system(.headline, design: .serif))
                                    .foregroundStyle(Theme.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                if !entry.step.isEmpty {
                                    Text(entry.step)
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.muted)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Spacer(minLength: 8)
                            Text(over ? "Time’s up" : QuickTimer.countdown(entry.deadline.timeIntervalSince(now)))
                                .font(.title3.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(over ? Theme.warning : Theme.ink)
                        }
                        .padding(.vertical, 10)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(entry.label), \(over ? "time’s up" : QuickTimer.countdown(entry.deadline.timeIntervalSince(now)) + " remaining")")
                    .accessibilityHint("Shows this timer large.")
                    .accessibilityIdentifier("fullscreen-row")
                    if entry.id != others.last?.id {
                        Rectangle().fill(Theme.line).frame(height: 1).accessibilityHidden(true)
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Text("No timers running.")
                .font(.system(.title, design: .serif).weight(.medium))
            Text("Start one from a recipe’s directions or a cooking step.")
                .font(.subheadline).foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("fullscreen-empty")
    }
}
