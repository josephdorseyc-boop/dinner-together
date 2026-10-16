import ActivityKit
import SwiftUI
import WidgetKit

/// The Live Activity's faces (build 22, #24) in the timer faces' language
/// (A2-64, options 1 and 3): warm cream, the next to finish leading with a
/// large countdown, the others named beside it. A2's board will refine
/// these; the system draws the countdowns from the deadlines.
@main
struct DinnerTimersBundle: WidgetBundle {
    var body: some Widget {
        DinnerTimersLiveActivity()
    }
}

private enum Palette {
    static let cream = Color(red: 0.980, green: 0.965, blue: 0.929)
    static let ink = Color(red: 0.165, green: 0.141, blue: 0.118)
    static let muted = Color(red: 0.420, green: 0.384, blue: 0.341)
    static let olive = Color(red: 0.400, green: 0.443, blue: 0.239)
    static let tomato = Color(red: 0.737, green: 0.247, blue: 0.180)
}

struct DinnerTimersLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DinnerTimersAttributes.self) { context in
            LockScreenTimers(title: context.attributes.dinnerTitle, timers: context.state.timers)
                .activityBackgroundTint(Palette.cream)
                .activitySystemActionForegroundColor(Palette.ink)
        } dynamicIsland: { context in
            let lead = context.state.timers.first
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "timer")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Palette.olive)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let lead {
                        Countdown(timer: lead)
                            .font(.system(.title2, design: .rounded).weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.trailing, 4)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    if let lead {
                        VStack(spacing: 2) {
                            Text(lead.dish).font(.headline).foregroundStyle(.white).lineLimit(1)
                            if !lead.step.isEmpty {
                                Text(lead.step).font(.caption).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                            }
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    let others = Array(context.state.timers.dropFirst().prefix(3))
                    if !others.isEmpty {
                        HStack(spacing: 14) {
                            ForEach(others) { t in
                                VStack(spacing: 1) {
                                    Countdown(timer: t).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                                    Text(t.dish).font(.caption2).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                                }
                            }
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "timer").foregroundStyle(Palette.olive)
            } compactTrailing: {
                if let lead {
                    Countdown(timer: lead)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: 52)
                }
            } minimal: {
                Image(systemName: "timer").foregroundStyle(Palette.olive)
            }
            .keylineTint(Palette.olive)
        }
    }
}

/// A countdown the system keeps current; 0:00 once it's up.
private struct Countdown: View {
    let timer: DinnerTimersAttributes.ContentState.Timer

    var body: some View {
        Text(timerInterval: min(timer.startedAt, timer.deadline)...timer.deadline, countsDown: true)
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
    }
}

/// The Lock Screen, StandBy and — on the folded Duo — the cover in tent
/// mode: the next to finish large, with its dish and step; up to three
/// others named beside it.
private struct LockScreenTimers: View {
    let title: String
    let timers: [DinnerTimersAttributes.ContentState.Timer]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("DINNER, TOGETHER").font(.caption2.weight(.semibold)).tracking(1.4).foregroundStyle(Palette.muted)
                Spacer()
                Image(systemName: "leaf").rotationEffect(.degrees(-35)).foregroundStyle(Palette.tomato.opacity(0.85))
            }
            if let lead = timers.first {
                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lead.dish).font(.system(.title3, design: .serif).weight(.medium)).foregroundStyle(Palette.ink).lineLimit(1)
                        if !lead.step.isEmpty {
                            Text(lead.step).font(.subheadline).foregroundStyle(Palette.muted).lineLimit(1)
                        }
                        ProgressView(timerInterval: min(lead.startedAt, lead.deadline)...lead.deadline, countsDown: true) {
                            EmptyView()
                        } currentValueLabel: {
                            EmptyView()
                        }
                        .tint(Palette.olive)
                        .padding(.top, 4)
                    }
                    Spacer(minLength: 8)
                    Countdown(timer: lead)
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: 140, alignment: .trailing)
                }
            }
            let others = Array(timers.dropFirst().prefix(3))
            if !others.isEmpty {
                HStack(spacing: 16) {
                    ForEach(others) { t in
                        VStack(alignment: .leading, spacing: 1) {
                            Countdown(timer: t).font(.headline).foregroundStyle(Palette.ink)
                            Text(t.dish).font(.caption).foregroundStyle(Palette.muted).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(16)
    }
}
