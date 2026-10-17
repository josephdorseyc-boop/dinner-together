import ActivityKit
import SwiftUI
import WidgetKit

/// The Live Activity's faces (build 22, #24) in the timer faces' language
/// (A2-64, options 1 and 3; board 01): warm cream, the next to finish
/// leading in a ring, the others named beside it. The system draws the
/// countdowns from the deadlines.
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
    static let line = Color(red: 0.902, green: 0.875, blue: 0.824)
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

/// The Lock Screen, StandBy (which enlarges this to fill the screen —
/// nightstand while locked) and the Duo's cover (board 01, A2, October 16):
/// the next to finish in a ring with its countdown, its dish and step
/// beside it, then up to three others with their own countdowns and
/// "+N more" past that. The ring is drawn whole: the system keeps the
/// numbers current, and an arc it can't keep moving would be wrong (A2's
/// rule: a static ring with a system countdown).
private struct LockScreenTimers: View {
    let title: String
    let timers: [DinnerTimersAttributes.ContentState.Timer]

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            if let lead = timers.first {
                ZStack {
                    Circle().stroke(Palette.line, lineWidth: 7)
                    Circle().stroke(Palette.olive, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    Countdown(timer: lead)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Palette.ink)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                }
                .frame(width: 84, height: 84)
                VStack(alignment: .leading, spacing: 2) {
                    Text(lead.dish).font(.system(.title3, design: .serif).weight(.medium))
                        .foregroundStyle(Palette.ink).lineLimit(2).minimumScaleFactor(0.8)
                    if !lead.step.isEmpty {
                        Text(lead.step).font(.subheadline).foregroundStyle(Palette.muted).lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                let others = Array(timers.dropFirst().prefix(3))
                if !others.isEmpty {
                    Rectangle().fill(Palette.line).frame(width: 1).padding(.vertical, 4)
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(others) { t in
                            HStack(spacing: 6) {
                                Text(t.dish).font(.caption).foregroundStyle(Palette.ink).lineLimit(1)
                                Spacer(minLength: 4)
                                Countdown(timer: t).font(.caption.weight(.semibold)).foregroundStyle(Palette.ink)
                                    .frame(maxWidth: 52, alignment: .trailing)
                            }
                        }
                        if timers.count > 4 {
                            Text("+\(timers.count - 4) more").font(.caption2).foregroundStyle(Palette.muted)
                        }
                    }
                    .frame(width: 122)
                }
            } else {
                Text(title).font(.system(.headline, design: .serif)).foregroundStyle(Palette.ink)
            }
        }
        .padding(16)
        // Paint the content surface as well as the system tint: the Lock
        // Screen card must retain the cookbook's cream, not a tinted material.
        .background(Palette.cream)
        .overlay(alignment: .topTrailing) {
            Image(systemName: "leaf").font(.caption).rotationEffect(.degrees(-35))
                .foregroundStyle(Palette.tomato.opacity(0.85))
                .padding(8)
                .accessibilityHidden(true)
        }
    }
}
