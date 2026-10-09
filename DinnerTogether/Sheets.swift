import SwiftUI

// MARK: - Stale plan: resume or start fresh

/// Shown on launch when a stale plan is detected. An explicit choice — the
/// app never silently resumes or discards, and the sheet can't be swiped away.
struct StalePlanView: View {
    @EnvironmentObject private var store: SessionStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Welcome back.")
                .font(.largeTitle.weight(.semibold))
            if store.hasProgress {
                Text("Your \(store.menu.title.lowercased()) plan from before is still here, with \(store.session.records.count) step\(store.session.records.count == 1 ? "" : "s") already started.")
                    .foregroundStyle(Theme.muted)
            } else {
                Text("You picked \(store.menu.title.lowercased()) earlier but never started cooking — and that dinner time has passed. Keep the menu with a fresh time, or start over.")
                    .foregroundStyle(Theme.muted)
            }
            Button(store.hasProgress ? "Resume this plan" : "Keep menu, fresh time") {
                store.resolveStale(resume: true)
                dismiss()
            }
            .buttonStyle(BigButtonStyle())
            Button("Start fresh") {
                store.resolveStale(resume: false)
                dismiss()
            }
            .buttonStyle(SecondaryButtonStyle())
            Spacer()
        }
        .padding(24)
        .background(Theme.cream)
    }
}

// MARK: - Delay: explain before applying

/// Shows exactly what a delay will move BEFORE anything changes.
/// Running timers are never touched; early finishes are flagged, not hidden.
struct DelaySheetView: View {
    let proposal: DelayProposal
    var onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Take a little more time.")
                        .font(.largeTitle.weight(.semibold))
                    ForEach(proposal.explanation, id: \.self) { line in
                        Label(line, systemImage: "info.circle")
                            .font(.subheadline)
                            .foregroundStyle(Theme.ink)
                    }
                    if !proposal.earlyFinishNotes.isEmpty {
                        Text("Worth knowing before you decide:")
                            .font(.headline)
                            .foregroundStyle(Theme.warning)
                            .padding(.top, 4)
                        ForEach(proposal.earlyFinishNotes, id: \.self) { note in
                            Label(note, systemImage: "clock.badge.exclamationmark")
                                .font(.subheadline)
                                .foregroundStyle(Theme.ink)
                        }
                    }
                    Button("Add \(proposal.minutes) minutes") {
                        onConfirm()
                        dismiss()
                    }
                    .buttonStyle(BigButtonStyle())
                    Button("Not yet", role: .cancel) { dismiss() }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(Theme.muted)
                }
                .padding(24)
            }
            .background(Theme.cream)
            .navigationTitle("Before we shift things")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Review dinner time against the estimated readiness

/// Opened only by the cook, from the inline readiness notice. It reads the
/// live estimate each time it draws, so the time on the button is the time
/// that will be applied — never a cached proposal. The chosen dinner time
/// and the estimate are labeled separately: they are different things.
/// Moving dinner goes through the same reviewed delay path as "Adjust time",
/// so early-finish notes for running timers appear here too.
struct ServingSheetView: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var timers: TimerCenter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let report = store.readinessReport(now: timers.now),
                       let proposal = store.readinessMoveProposal(now: timers.now) {
                        let readinessLabel = report.estimateIsLowerBound ? "Earliest readiness" : "Estimated readiness"
                        Text("Move dinner to \(Scheduling.formatTime(proposal.newServeAt))?")
                            .font(.largeTitle.weight(.semibold))
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .top, spacing: 28) {
                                timeColumn("Chosen dinner time", report.serveAt)
                                timeColumn(readinessLabel, report.estimatedReadyAt, emphasized: true)
                            }
                            VStack(alignment: .leading, spacing: 12) {
                                timeColumn("Chosen dinner time", report.serveAt)
                                timeColumn(readinessLabel, report.estimatedReadyAt, emphasized: true)
                            }
                        }
                        Text(report.reason)
                            .font(.subheadline)
                            .foregroundStyle(Theme.ink)
                        if report.estimateIsLowerBound {
                            Text("A timer has ended but its step isn't marked done, so this is the earliest the meal could be ready — not a prediction.")
                                .font(.caption)
                                .foregroundStyle(Theme.warning)
                        }
                        Text("Dinner moves in whole minutes, so the new time is never earlier than the estimate.")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                        ForEach(proposal.explanation, id: \.self) { line in
                            Label(line, systemImage: "info.circle")
                                .font(.subheadline)
                                .foregroundStyle(Theme.ink)
                        }
                        if !proposal.earlyFinishNotes.isEmpty {
                            Text("Worth knowing before you decide:")
                                .font(.headline)
                                .foregroundStyle(Theme.warning)
                                .padding(.top, 4)
                            ForEach(proposal.earlyFinishNotes, id: \.self) { note in
                                Label(note, systemImage: "clock.badge.exclamationmark")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.ink)
                            }
                        }
                        Button("Move dinner to \(Scheduling.formatTime(proposal.newServeAt))") {
                            store.moveDinnerToEstimatedReadiness(now: timers.now)
                            dismiss()
                        }
                        .buttonStyle(BigButtonStyle())
                        Button("Keep \(Scheduling.formatTime(report.serveAt)) for now") { dismiss() }
                            .buttonStyle(SecondaryButtonStyle())
                        Text("Keeping the time changes nothing. The estimate stays on the cooking screen while steps run late, and you can come back here any time.")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    } else {
                        Text("Back on schedule.")
                            .font(.largeTitle.weight(.semibold))
                        Text("Unfinished steps are estimated to finish by your chosen dinner time.")
                            .foregroundStyle(Theme.muted)
                        Button("Done") { dismiss() }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                }
                .padding(24)
            }
            .background(Theme.cream)
            .navigationTitle("Review dinner time")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private func timeColumn(_ label: String, _ time: Date, emphasized: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel(text: label.uppercased())
            Text(time, format: .dateTime.hour().minute())
                .font(.system(.title, design: .rounded).weight(.medium))
                .monospacedDigit()
                .foregroundStyle(emphasized ? Theme.warning : Theme.ink)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(Scheduling.formatTime(time))")
    }
}

// MARK: - Review a duration estimate before committing

/// Edits are local until Save: repeated taps create one undoable change.
struct DurationEditorView: View {
    let step: CookingStep
    let initialMinutes: Int
    var onSave: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var minutes: Int

    init(step: CookingStep, initialMinutes: Int, onSave: @escaping (Int) -> Void) {
        self.step = step
        self.initialMinutes = initialMinutes
        self.onSave = onSave
        _minutes = State(initialValue: max(1, min(480, initialMinutes)))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SectionLabel(text: step.dish.uppercased())
                    Text(step.title).font(.title2.weight(.semibold))
                    Text("How long does this take in your kitchen?")
                        .foregroundStyle(Theme.muted)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("\(minutes) min")
                            .font(.system(.largeTitle, design: .rounded).weight(.medium))
                            .monospacedDigit()
                        Stepper("Adjust minutes", value: $minutes, in: 1...480)
                            .accessibilityValue("\(minutes) minutes")
                        Button("Use original estimate (\(step.minutes) min)") {
                            minutes = step.minutes
                        }.buttonStyle(QuietButtonStyle())
                    }.dtCard()
                    Text("The plan updates when you save. Started timers keep their original deadline.")
                        .font(.subheadline).foregroundStyle(Theme.muted)
                    Button("Save estimate") {
                        onSave(minutes)
                        dismiss()
                    }.buttonStyle(BigButtonStyle())
                    .disabled(minutes == initialMinutes)
                }.padding(24)
            }
            .foregroundStyle(Theme.ink)
            .background(Theme.cream)
            .navigationTitle("Timing estimate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
