import SwiftUI
import UIKit

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
                        Text("Move dinner to \(Scheduling.formatMoment(proposal.newServeAt))?")
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
                        Button("Move dinner to \(Scheduling.formatMoment(proposal.newServeAt))") {
                            store.moveDinnerToEstimatedReadiness(now: timers.now)
                            dismiss()
                        }
                        .buttonStyle(BigButtonStyle())
                        Button("Keep \(Scheduling.formatMoment(report.serveAt)) for now") { dismiss() }
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
            Text(Scheduling.formatMoment(time, relativeTo: timers.now))
                .font(.system(.title, design: .rounded).weight(.medium))
                .monospacedDigit()
                .foregroundStyle(emphasized ? Theme.warning : Theme.ink)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(Scheduling.formatMoment(time, relativeTo: timers.now))")
    }
}

// MARK: - Review a duration estimate before committing

/// Edits are local until Save: repeated taps create one undoable change.
struct DurationEditorView: View {
    let step: CookingStep
    let initialMinutes: Int
    /// What saving does here. Tonight's plan (catalog menus) updates at once;
    /// a library recipe only changes for future dinners (A1 PR #5 copy).
    let note: String
    /// Returns nil on success, or the message to show when the save failed.
    var onSave: (Int) -> String?
    @Environment(\.dismiss) private var dismiss
    @State private var minutes: Int
    @State private var saveError: String?

    static let planNote = "The plan updates when you save. Started timers keep their original deadline."
    static let recipeNote = "Save this estimate to your recipe. Any timers already running keep their deadlines."

    init(step: CookingStep, initialMinutes: Int, note: String = DurationEditorView.planNote,
         onSave: @escaping (Int) -> String?) {
        self.step = step
        self.initialMinutes = initialMinutes
        self.note = note
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
                        Text(Scheduling.formatMinutes(minutes))
                            .font(.system(.largeTitle, design: .rounded).weight(.medium))
                            .monospacedDigit()
                        Stepper("Adjust minutes", value: $minutes, in: 1...480)
                            .accessibilityValue("\(minutes) minutes")
                        Button("Use original estimate (\(Scheduling.formatMinutes(step.minutes)))") {
                            minutes = step.minutes
                        }.buttonStyle(QuietButtonStyle())
                    }.dtCard()
                    if let saveError {
                        Text(saveError)
                            .font(.subheadline).foregroundStyle(Theme.warning)
                            .accessibilityIdentifier("estimate-save-error")
                    }
                    Text(note)
                        .font(.subheadline).foregroundStyle(Theme.muted)
                }.padding(24)
            }
            .foregroundStyle(Theme.ink)
            .background(Theme.cream)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button("Save estimate") {
                    // A2 S3: a failed save keeps the editor and the entered
                    // value. The cook can retry or Cancel; nothing is lost.
                    if let error = onSave(minutes) {
                        saveError = error
                    } else {
                        dismiss()
                    }
                }
                .buttonStyle(BigButtonStyle())
                .disabled(minutes == initialMinutes)
                .padding(.horizontal, 24).padding(.vertical, 12)
                .background(Theme.cream)
            }
            .navigationTitle("Timing estimate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - The recipe's own total time

/// When an import found no total time, the cook can enter it here (Joe,
/// build 11). Hours and minutes, saved to the recipe; Clear removes it.
struct RecipeTimeSheet: View {
    let recipeID: UUID
    let initialMinutes: Int?
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var hours: Int
    @State private var minutes: Int
    @State private var saveError: String?

    init(recipeID: UUID, initialMinutes: Int?) {
        self.recipeID = recipeID
        self.initialMinutes = initialMinutes
        let total = initialMinutes ?? 0
        _hours = State(initialValue: total / 60)
        _minutes = State(initialValue: total % 60)
    }

    private var total: Int { hours * 60 + minutes }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(initialMinutes == nil
                         ? "The import found no total time. Enter the recipe’s own time so the plan can be checked against it."
                         : "The recipe’s own total time, as written. The plan on the Timing tab is compared with it.")
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 16) {
                        Text(total == 0 ? "No time" : Scheduling.formatMinutes(total))
                            .font(.system(.largeTitle, design: .rounded).weight(.medium))
                            .monospacedDigit()
                            .accessibilityIdentifier("recipe-time-value")
                        // No identifiers on the steppers: one collapses the
                        // stepper into a single element and its Increment /
                        // Decrement buttons disappear from the hierarchy
                        // (run 38365885474). Tests find them by label.
                        Stepper("Hours: \(hours)", value: $hours, in: 0...24)
                        Stepper("Minutes: \(minutes)", value: $minutes, in: 0...55, step: 5)
                    }.dtCard()
                    if let saveError {
                        Text(saveError)
                            .font(.subheadline).foregroundStyle(Theme.warning)
                            .accessibilityIdentifier("recipe-time-save-error")
                    }
                    Text("This is the recipe’s number, not the plan’s. Step estimates are edited on the Timing tab.")
                        .font(.subheadline).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    if initialMinutes != nil {
                        Button("Clear the recipe time") { save(nil) }
                            .buttonStyle(QuietButtonStyle())
                            .accessibilityIdentifier("recipe-time-clear")
                    }
                }.padding(24)
            }
            .foregroundStyle(Theme.ink)
            .background(Theme.cream)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button("Save recipe time") { save(total) }
                    .buttonStyle(BigButtonStyle())
                    .disabled(total == 0 || total == initialMinutes)
                    .accessibilityIdentifier("recipe-time-save")
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(Theme.cream)
            }
            .navigationTitle("Recipe time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .presentationDetents([.large])
    }

    private func save(_ value: Int?) {
        if library.setTotalMinutes(recipeID: recipeID, minutes: value) {
            dismiss()
        } else {
            saveError = library.saveError ?? "The recipe time couldn’t be saved. Try again."
        }
    }
}

/// Edit a recipe's title and yield: swipe → Edit in Your Recipes, or ••• →
/// Edit title and yield on its page (Joe, build 12). Saves through the
/// library's rollback; a failed save keeps the sheet open with the edit.
struct RecipeEditSheet: View {
    let recipeID: UUID
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var yield: String
    @State private var saveError: String?
    private let originalTitle: String
    private let originalYield: String

    init(recipe: Recipe) {
        recipeID = recipe.id
        originalTitle = recipe.title
        originalYield = recipe.yield ?? ""
        _title = State(initialValue: recipe.title)
        _yield = State(initialValue: recipe.yield ?? "")
    }

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var changed: Bool {
        trimmedTitle != originalTitle || yield.trimmingCharacters(in: .whitespacesAndNewlines) != originalYield
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Change the title or yield. Review timing or remove steps on the Timing tab.")
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    field("TITLE", text: $title, prompt: "Recipe title", identifier: "recipe-edit-title")
                    if trimmedTitle.isEmpty {
                        Text("A recipe needs a title.")
                            .font(.subheadline).foregroundStyle(Theme.warning)
                    }
                    field("YIELD", text: $yield, prompt: "Optional — for example, 4 servings", identifier: "recipe-edit-yield")
                    if let saveError {
                        Text(saveError)
                            .font(.subheadline).foregroundStyle(Theme.warning)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("recipe-edit-error")
                    }
                }
                .padding(24)
            }
            .foregroundStyle(Theme.ink)
            .background(Theme.cream)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button("Save changes") { save() }
                    .buttonStyle(BigButtonStyle())
                    .disabled(trimmedTitle.isEmpty || !changed)
                    .accessibilityIdentifier("recipe-edit-save")
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(Theme.cream)
            }
            .navigationTitle("Title and yield")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .presentationDetents([.large])
    }

    private func field(_ label: String, text: Binding<String>, prompt: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: label)
            HStack(alignment: .top, spacing: 8) {
                TextField(prompt, text: text, axis: .vertical)
                    .font(.title3)
                    .lineLimit(1...4)
                    .accessibilityLabel(label.capitalized)
                    .accessibilityIdentifier(identifier)
                if !text.wrappedValue.isEmpty {
                    // Clearing and retyping is quicker than editing a title
                    // full of status-bar debris.
                    Button { text.wrappedValue = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.muted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear \(label.lowercased())")
                    .accessibilityIdentifier(identifier + "-clear")
                }
            }
            .padding(14)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 1))
        }
    }

    private func save() {
        guard library.rename(recipeID: recipeID, title: title, yield: yield) else {
            saveError = "Your changes couldn’t be saved. The recipe is unchanged. Try saving again."
            UIAccessibility.post(notification: .announcement, argument: saveError)
            return
        }
        dismiss()
    }
}
