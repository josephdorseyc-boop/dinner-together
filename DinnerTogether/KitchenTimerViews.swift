import SwiftUI

// The kitchen timers' faces (Joe, October 15, 1:51 PM: "I like 1 and 3" of
// A2-64): a warm cream page, an olive ring draining clockwise around a large
// centered countdown, the dish above and the step below. One timer gets a
// generous ring; with several, the next to finish — or one that's up — leads,
// the others beside it, each named. Time's up is said plainly and never
// marks food or a step done. Build 22's tent mode shows the same timers.

/// The ring: a faint track, the remaining fraction in olive, draining
/// clockwise from the top; amber outline once it's up (attention, not
/// progress). The countdown sits inside, from the stored deadline.
struct TimerRing: View {
    let timer: QuickTimer
    let now: Date
    var size: CGFloat = 220
    var lineWidth: CGFloat = 12
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var remaining: TimeInterval { timer.remaining(at: now) }
    private var fraction: Double { timer.seconds > 0 ? max(0, min(1, remaining / Double(timer.seconds))) : 0 }
    private var over: Bool { timer.isOver(at: now) }

    var body: some View {
        ZStack {
            Circle().stroke(Theme.line, lineWidth: lineWidth)
            if over {
                Circle().stroke(Theme.warning, lineWidth: lineWidth)
            } else {
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(Theme.olive, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .linear(duration: 1), value: fraction)
            }
            VStack(spacing: size > 120 ? 4 : 0) {
                Text(over ? "00:00" : QuickTimer.countdown(remaining))
                    .font(.system(size: size * (size > 120 ? 0.26 : 0.24), weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5).lineLimit(1)
                    .foregroundStyle(over ? Theme.warning : Theme.ink)
                Text(over ? "Time’s up" : "remaining")
                    .font(size > 120 ? .subheadline : .caption2)
                    .foregroundStyle(over ? Theme.warning : Theme.muted)
            }
            .padding(lineWidth + 8)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(timer.label), \(over ? "time’s up" : QuickTimer.countdown(remaining) + " remaining")")
    }
}

/// The compact strip on Cooking and Directions while timers run (A2-64):
/// "3 timers · Next: Green beans 02:10", a timer that's up first. Opens the
/// timers page.
struct RunningTimersStrip: View {
    @EnvironmentObject private var quickTimers: QuickTimerStore
    @EnvironmentObject private var timers: TimerCenter
    @State private var showing = false

    var body: some View {
        let now = timers.now
        let all = quickTimers.sorted(at: now)
        if let lead = all.first {
            let over = all.filter { $0.isOver(at: now) }
            Button { showing = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: over.isEmpty ? "timer" : "bell.fill")
                        .foregroundStyle(over.isEmpty ? Theme.olive : Theme.warning)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(over.isEmpty
                             ? "\(all.count == 1 ? "1 timer" : "\(all.count) timers") · Next: \(lead.dish) \(QuickTimer.countdown(lead.remaining(at: now)))"
                             : "Time’s up: \(over.map(\.dish).joined(separator: ", "))")
                            .font(.subheadline.weight(.semibold)).monospacedDigit()
                            .foregroundStyle(over.isEmpty ? Theme.ink : Theme.warning)
                            .lineLimit(2)
                        Text(lead.stepTitle.isEmpty ? "Kitchen timers" : lead.stepTitle)
                            .font(.caption).foregroundStyle(Theme.muted).lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Text("View timers").font(.caption.weight(.semibold)).foregroundStyle(Theme.olive)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .frame(minHeight: 44)
                .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(over.isEmpty ? Theme.line : Theme.warning.opacity(0.6)))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(over.isEmpty
                                ? "\(all.count) kitchen timers. Next: \(lead.label), \(QuickTimer.countdown(lead.remaining(at: now)))"
                                : "Time’s up: \(over.map(\.label).joined(separator: "; "))")
            .accessibilityHint("Opens the timers.")
            .accessibilityIdentifier("running-timers")
            .sheet(isPresented: $showing) { KitchenTimersView().uiTestTypeSize() }
        }
    }
}

/// A direction's timers on Cooking's cream pages (the opened Duo's
/// Directions tab): the same timers as the recipe page — keyed by recipe,
/// step and duration, so one started on either shows on both — on the
/// paper card the cream page uses. "Start 15 minutes"; while it runs, the
/// countdown (opens the timers) and its own Stop.
struct CookingDirectionTimers: View {
    let recipe: Recipe
    let stepIndex: Int
    let line: String
    @EnvironmentObject private var quickTimers: QuickTimerStore
    @EnvironmentObject private var timers: TimerCenter
    @State private var showing = false

    var body: some View {
        let durations = TimedText.durations(in: line)
        if !durations.isEmpty {
            let stepTitle = recipe.steps.indices.contains(stepIndex) ? recipe.steps[stepIndex].title : "Step \(stepIndex + 1)"
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { ForEach(durations, id: \.self) { button(stepTitle: stepTitle, duration: $0) } }
                VStack(alignment: .leading, spacing: 8) { ForEach(durations, id: \.self) { button(stepTitle: stepTitle, duration: $0) } }
            }
            .sheet(isPresented: $showing) { KitchenTimersView().uiTestTypeSize() }
        }
    }

    private func card<S: InsettableShape>(_ shape: S) -> some View {
        shape.fill(Theme.paper).overlay(shape.strokeBorder(Theme.line))
    }

    @ViewBuilder
    private func button(stepTitle: String, duration: String) -> some View {
        let now = timers.now
        if let running = quickTimers.timer(recipeID: recipe.id, stepTitle: stepTitle, durationText: duration) {
            let over = running.isOver(at: now)
            HStack(spacing: 6) {
                Button { showing = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: over ? "bell.fill" : "timer")
                        Text(over ? "Time’s up" : QuickTimer.countdown(running.remaining(at: now))).monospacedDigit()
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14).frame(minHeight: 44)
                    .foregroundStyle(.white)
                    .background(Capsule().fill(over ? Theme.warning : Theme.olive))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(stepTitle), \(duration) timer: \(over ? "time’s up" : QuickTimer.countdown(running.remaining(at: now)) + " remaining")")
                .accessibilityHint("Opens the timers.")
                .accessibilityIdentifier("cooking-timer-running")
                Button { quickTimers.stop(running.id) } label: {
                    Image(systemName: over ? "checkmark" : "stop.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(Theme.olive)
                        .background(card(Circle()))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(over ? "Dismiss the \(stepTitle) timer" : "Stop the \(stepTitle) \(duration) timer")
                .accessibilityIdentifier("cooking-stop-timer")
            }
        } else {
            Button {
                if let seconds = TimedText.seconds(in: duration) {
                    quickTimers.start(recipeID: recipe.id, dish: recipe.title, stepTitle: stepTitle, durationText: duration, seconds: seconds)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                    Text("Start \(duration)")
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14).frame(minHeight: 44)
                .foregroundStyle(Theme.olive)
                .background(card(Capsule()))
            }
            .buttonStyle(.plain)
            .disabled(TimedText.seconds(in: duration) == nil)
            .accessibilityLabel("Start a \(duration) timer for \(stepTitle), \(recipe.title)")
            .accessibilityHint("Counts down and tells you when it’s up.")
            .accessibilityIdentifier("cooking-start-timer")
        }
    }
}

/// Every kitchen timer, as rings: one big; several with the next to finish
/// (or one that's up) leading and the rest named beside it; at large text
/// or on a narrow screen, readable rows instead of small dials. Stop is its
/// own 44 pt button per timer. Nothing here completes a step.
struct KitchenTimersView: View {
    @EnvironmentObject private var quickTimers: QuickTimerStore
    @EnvironmentObject private var timers: TimerCenter
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let now = timers.now
        let all = quickTimers.sorted(at: now)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if all.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No timers running.").font(.system(.title3, design: .serif).weight(.medium))
                            Text("Tap a time in any recipe’s directions to start one.")
                                .font(.subheadline).foregroundStyle(Theme.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .dtCard()
                        .accessibilityIdentifier("timers-empty")
                    } else if let lead = all.first {
                        if all.count == 1 || dynamicTypeSize.isAccessibilitySize {
                            ForEach(all) { t in bigTimer(t, now: now, size: all.count == 1 ? 240 : 160) }
                        } else {
                            ViewThatFits(in: .horizontal) {
                                HStack(alignment: .top, spacing: 28) {
                                    bigTimer(lead, now: now, size: 240)
                                    Rectangle().fill(Theme.line).frame(width: 1).accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 16) {
                                        ForEach(all.dropFirst()) { t in smallTimer(t, now: now) }
                                    }
                                    .frame(minWidth: 260)
                                }
                                VStack(alignment: .leading, spacing: 20) {
                                    bigTimer(lead, now: now, size: 220)
                                    ForEach(all.dropFirst()) { t in smallTimer(t, now: now) }
                                }
                            }
                        }
                        if all.contains(where: { $0.isOver(at: now) }) {
                            Button("Clear finished timers") { quickTimers.dismissOver(at: now) }
                                .buttonStyle(QuietButtonStyle())
                                .accessibilityIdentifier("clear-finished-timers")
                        }
                        Text("A timer ending doesn’t mark a step done — check the food, then carry on.")
                            .font(.caption).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(24)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.cream)
            .foregroundStyle(Theme.ink)
            .navigationTitle(all.count > 1 ? "Timers" : "Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.accessibilityIdentifier("timers-done") }
                if !all.isEmpty {
                    ToolbarItem(placement: .topBarLeading) { FullScreenTimersButton() }
                }
            }
        }
        .tint(Theme.tomato)
    }

    private func bigTimer(_ t: QuickTimer, now: Date, size: CGFloat) -> some View {
        VStack(spacing: 12) {
            HStack {
                SectionLabel(text: t.isOver(at: now) ? "TIME’S UP" : (quickTimers.timers.count > 1 ? "NEXT TO FINISH" : "ONE TIMER"))
                Spacer()
                Image(systemName: "leaf").rotationEffect(.degrees(-35)).foregroundStyle(Theme.tomato.opacity(0.85)).accessibilityHidden(true)
            }
            Text(t.dish).font(.system(.title2, design: .serif).weight(.medium)).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            TimerRing(timer: t, now: now, size: size)
            if !t.stepTitle.isEmpty {
                Text(t.stepTitle).font(.system(.headline, design: .serif)).foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
            Button { quickTimers.stop(t.id) } label: {
                Label(t.isOver(at: now) ? "Dismiss" : "Stop timer", systemImage: t.isOver(at: now) ? "checkmark" : "stop.fill")
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityLabel(t.isOver(at: now) ? "Dismiss the \(t.label) timer" : "Stop the \(t.label) timer")
            .accessibilityIdentifier("timer-stop")
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("timer-big")
    }

    private func smallTimer(_ t: QuickTimer, now: Date) -> some View {
        HStack(spacing: 14) {
            TimerRing(timer: t, now: now, size: 84, lineWidth: 7)
            VStack(alignment: .leading, spacing: 2) {
                Text(t.dish).font(.system(.headline, design: .serif)).foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if !t.stepTitle.isEmpty {
                    Text(t.stepTitle).font(.subheadline).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            Button { quickTimers.stop(t.id) } label: {
                Image(systemName: t.isOver(at: now) ? "checkmark" : "stop.fill")
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.muted)
            .accessibilityLabel(t.isOver(at: now) ? "Dismiss the \(t.label) timer" : "Stop the \(t.label) timer")
            .accessibilityIdentifier("timer-stop")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("timer-small")
    }
}
