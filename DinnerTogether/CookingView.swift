import SwiftUI
import UIKit

/// The cooking screen. Answers "what do I do right now?" first, then shows
/// running timers, what's up next, attention warnings, and the full timeline
/// with planned-vs-actual times and undo. On iPad the side panel keeps the
/// actionable items visible next to the timeline.
///
/// Blocked steps (predecessor not done, clock time arrived) show their reason
/// and never offer a silent Start — the override is explicit ("Start anyway").
struct CookingView: View {
    @EnvironmentObject private var store: SessionStore
    @EnvironmentObject private var timers: TimerCenter
    @EnvironmentObject private var library: RecipeLibrary
    /// The scroll view's height: a photo strip on RIGHT NOW only when the
    /// screen is tall enough that it cannot push the action down (A2-35).
    @State private var viewportHeight: CGFloat = 0
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Overlap warnings auto-expand when they appear so a mid-cook warning is
    /// never hidden behind a collapsed label. The cook can collapse them; only
    /// a genuinely new warning re-expands.
    @State private var warningsExpanded = false
    @State private var completionFeedback = false

    @State private var showDelayChoice = false
    @State private var delayProposal: DelayProposal?
    /// The readiness review sheet is opened only by the cook, from the
    /// inline notice. Its content is derived live; nothing is cached here.
    @State private var showReadinessReview = false
    @State private var showCompleted = false
    @State private var showResetConfirm = false
    /// Both confirmations go through ONE alert modifier. Two `.alert(item:)`
    /// modifiers on the same view is a known SwiftUI trap (only one of them
    /// reliably presents); the first UI-test execution (CI run 17) tapped
    /// "Review start" on a comfortably visible card and no alert appeared,
    /// while the second modifier's alert worked. One modifier, one state.
    @State private var prompt: CookingPrompt?

    enum CookingPrompt: Identifiable {
        case blocked(BlockedRequest)
        case unstartedCompletion(UnstartedCompleteRequest)
        var id: String {
            switch self {
            case .blocked(let r): return "blocked-" + r.id
            case .unstartedCompletion(let r): return "unstarted-" + r.id
            }
        }
    }
    struct BlockedRequest: Identifiable {
        let id: String
        let stepID: String
        let predecessorTitle: String
        let readyAt: Date
    }
    struct UnstartedCompleteRequest: Identifiable {
        let id: String
        let stepID: String
        let title: String
    }

    private var plan: [PlannedStep] { store.plan }
    private var now: Date { timers.now }

    private func isBlocked(_ item: PlannedStep) -> BlockedInfo? {
        Scheduling.blockedInfo(plan: plan, menu: store.menu,
                               session: store.session, stepID: item.id, now: now)
    }

    private var doNow: [PlannedStep] {
        Scheduling.doThisNow(plan: plan, session: store.session, now: now)
            .filter {
                store.record($0.id).state == .notStarted && isBlocked($0) == nil
            }
    }
    private var onHeat: [PlannedStep] {
        plan.filter { store.record($0.id).state == .cooking }
    }
    private var upNext: [PlannedStep] {
        Scheduling.upNext(plan: plan, session: store.session, now: now)
    }
    private var warnings: [AttentionWarning] {
        Scheduling.attentionWarnings(plan: plan, session: store.session, now: now)
    }
    private var completedSteps: [PlannedStep] {
        plan.filter { store.record($0.id).state == .done }
    }
    private var pendingSteps: [PlannedStep] {
        plan.filter { store.record($0.id).state != .done }
    }
    private var allDone: Bool {
        !plan.isEmpty && completedSteps.count == plan.count
    }
    /// Live drift between the chosen dinner time and the estimated readiness
    /// of unfinished work. Recomputed every tick and after every action, so
    /// the notice can never show an estimate from an earlier session state.
    /// Nil when on schedule or when every step is done (guarded in
    /// `Scheduling.readinessReport`, not here, so the sheet and store agree).
    private var readiness: ReadinessReport? {
        store.readinessReport(now: now)
    }
    /// Drift at or above this many minutes uses the warning tone. Below it,
    /// the notice stays quiet. An initial UX choice, not a correctness rule.
    private static let readinessEmphasisMinutes = 10

    var body: some View {
        ScrollView {
            if !store.hasDinner {
                // Nothing chosen yet (the app starts here, Joe, October 14).
                VStack(alignment: .leading, spacing: 12) {
                    Text("Nothing cooking yet.")
                        .font(.system(.title2, design: .serif).weight(.medium))
                    Text("Choose tonight’s recipe on Tonight and build your plan; the timeline and timers appear here.")
                        .font(.subheadline).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .dtCard()
                .padding(24)
                .accessibilityIdentifier("cooking-empty")
            } else if horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 36) {
                        VStack(alignment: .leading, spacing: 24) { actionColumn }
                            .frame(width: 320)
                        VStack(alignment: .leading, spacing: 24) { timelineColumn }
                            .frame(minWidth: 300, maxWidth: .infinity)
                    }
                    VStack(alignment: .leading, spacing: 28) { actionColumn; timelineColumn }
                }
                .padding(24)
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    actionColumn
                    timelineColumn
                }
                .padding(24)
            }
        }
        .background(Theme.cream)
        .background(GeometryReader { geo in
            Color.clear
                .onAppear { viewportHeight = geo.size.height }
                .onChange(of: geo.size.height) { _, h in viewportHeight = h }
        })
        .navigationTitle(store.hasDinner ? store.menu.title : "Cooking")
        .sensoryFeedback(.success, trigger: completionFeedback)
        .navigationBarTitleDisplayMode(.inline)
        // Observe outside the conditional group, including transitions through
        // an empty list. Removal/reordering must respect the cook's collapse.
        .onChange(of: warnings.map(\.message), initial: true) { oldMessages, newMessages in
            if !Set(newMessages).subtracting(Set(oldMessages)).isEmpty {
                warningsExpanded = true
            } else if newMessages.isEmpty {
                warningsExpanded = false
            }
            // The initial callback supplies equal old/new values.
            if oldMessages == newMessages && !newMessages.isEmpty {
                warningsExpanded = true
            }
        }
        .confirmationDialog(
            "How much extra time?",
            isPresented: $showDelayChoice,
            titleVisibility: .visible
        ) {
            ForEach([5, 10, 15], id: \.self) { minutes in
                Button("Add \(minutes) minutes") {
                    // Hand the proposal to the sheet only after the dialog has
                    // gone: on iPad the dialog is a popover, and a sheet
                    // presented from inside its action can be dropped (first
                    // UI-test execution, run 20). The proposal itself is
                    // computed now, as before.
                    let proposal = store.proposeDelay(minutes: minutes)
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 350_000_000)
                        delayProposal = proposal
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("We'll show exactly what moves before anything changes.")
        }
        .confirmationDialog(
            "Clear cooking progress?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Reset progress", role: .destructive) { store.resetSession() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears all started and finished steps. Undo can bring them back.")
        }
        .sheet(item: $delayProposal) { proposal in
            DelaySheetView(proposal: proposal) {
                store.confirmDelay(proposal)
                delayProposal = nil
            }
            .uiTestTypeSize()
        }
        // Routine lateness never opens a sheet on its own. The cook opens
        // this review from the inline notice; it reads live state.
        .sheet(isPresented: $showReadinessReview) {
            ServingSheetView().uiTestTypeSize()
        }
        // The modern alert API (iOS 15+): the legacy `Alert` value's buttons
        // reached XCUITest as "Button from legacy attributes vs
        // DisclosureTriangle from modern attribute", and XCTest then treated
        // the app's own alert as an interruption and dismissed it itself
        // (test05/test06, runs 38290508810 and 38298547276).
        .alert(Text(prompt.map(Self.title) ?? ""),
               isPresented: Binding(get: { prompt != nil }, set: { if !$0 { prompt = nil } }),
               presenting: prompt) { prompt in
            switch prompt {
            case .blocked(let req):
                Button("Start anyway") {
                    Task { await store.startStep(req.stepID, force: true) }
                }
                Button("Cancel", role: .cancel) {}
            case .unstartedCompletion(let req):
                Button("Mark done") {
                    Task {
                        let result = await store.completeStep(req.stepID, confirmed: true)
                        if case .completed = result { completionFeedback.toggle() }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        } message: { prompt in
            switch prompt {
            case .blocked(let req):
                Text("This step can't start until “\(req.predecessorTitle)” is done (ready around \(Scheduling.formatTime(req.readyAt))). Start it anyway?")
            case .unstartedCompletion:
                Text("It was never marked started, so we won't guess when it began — only that it finished now.")
            }
        }
    }

    private static func title(_ prompt: CookingPrompt) -> String {
        switch prompt {
        case .blocked(let req): return "Waiting on “\(req.predecessorTitle)”"
        case .unstartedCompletion(let req): return "Mark “\(req.title)” done?"
        }
    }

    // MARK: Actions from buttons

    private func startTapped(_ item: PlannedStep) {
        Task {
            let result = await store.startStep(item.id)
            if case .blocked(let predecessorTitle, let readyAt) = result {
                prompt = .blocked(BlockedRequest(id: item.id, stepID: item.id,
                                                 predecessorTitle: predecessorTitle,
                                                 readyAt: readyAt))
            }
        }
    }

    private func doneTapped(_ item: PlannedStep) {
        Task {
            let result = await store.completeStep(item.id)
            if case .completed = result { completionFeedback.toggle() }
            if case .needsStartConfirmation(let title) = result {
                prompt = .unstartedCompletion(UnstartedCompleteRequest(id: item.id,
                                                                       stepID: item.id,
                                                                       title: title))
            }
        }
    }

    // MARK: Action column (do-now, timers, up next, warnings)

    private var urgentTimer: PlannedStep? {
        onHeat.first { (store.record($0.id).timerDeadline ?? $0.end) <= now }
    }
    private var featuredID: String? { urgentTimer?.id ?? doNow.first?.id }

    @ViewBuilder
    private var actionColumn: some View {
        servingCard
        if urgentTimer == nil { readinessNotice }
        if allDone {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "checkmark.seal.fill").font(.title).foregroundStyle(Theme.olive)
                Text("Time to enjoy dinner.").font(.title2.weight(.semibold)).foregroundStyle(Theme.ink)
                Text("Every step is complete.").foregroundStyle(Theme.muted)
            }.dtCard().accessibilityElement(children: .combine)
            // The cook's own photo of the plate becomes the dinner's picture
            // on Tonight and here (Joe, October 14) — never a stock one.
            if let recipe = library.recipe(menuID: store.session.menuID) {
                PlatePhotoCard(recipe: recipe)
            }
        } else {
            // With a hero picture the tag rides on the photo's edge instead.
            if heroHeight == nil || (urgentTimer == nil && doNow.isEmpty) { SectionLabel(text: "RIGHT NOW") }
            if let urgent = urgentTimer {
                heatCard(urgent, featured: true)
            } else if let next = doNow.first {
                doNowCard(next)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: onHeat.isEmpty ? "clock" : "timer")
                        .font(.title2).foregroundStyle(Theme.olive)
                    Text(onHeat.isEmpty ? "A little breathing room." : "Your timers are running.")
                        .font(.title3.weight(.semibold)).foregroundStyle(Theme.ink)
                    if let upcoming = upNext.first {
                        Text("Next: \(upcoming.step.title)").font(.subheadline).foregroundStyle(Theme.ink)
                        Text("Planned for \(Scheduling.formatTime(upcoming.plannedStart)).")
                            .font(.subheadline).foregroundStyle(Theme.muted)
                    } else {
                        Text("Check the timeline for anything waiting on another step.")
                            .font(.subheadline).foregroundStyle(Theme.muted)
                    }
                }.dtCard()
            }
        }
        // Checking food comes before reviewing the dinner-time estimate.
        if urgentTimer != nil { readinessNotice }
        let otherDue = doNow.filter { $0.id != featuredID }
        if !otherDue.isEmpty {
            SectionLabel(text: "ALSO READY TO START")
            ForEach(otherDue) { item in
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.step.title).font(.headline).foregroundStyle(Theme.ink)
                    Text(item.step.dish).font(.caption).foregroundStyle(Theme.muted)
                    Button("Start step") { startTapped(item) }.buttonStyle(SecondaryButtonStyle())
                }.padding(.vertical, 8)
            }
        }
        let otherTimers = onHeat.filter { $0.id != featuredID }
        if !otherTimers.isEmpty {
            SectionLabel(text: "RUNNING TIMERS")
            ForEach(otherTimers) { item in heatCard(item) }
        }
        if !upNext.isEmpty {
            SectionLabel(text: "UP NEXT")
            VStack(alignment: .leading, spacing: 16) {
                ForEach(upNext) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Scheduling.formatTime(item.plannedStart))
                            .font(.caption.weight(.semibold)).monospacedDigit().foregroundStyle(Theme.muted)
                        Text(item.step.title).font(.subheadline).foregroundStyle(Theme.ink)
                    }.accessibilityElement(children: .combine)
                }
            }
        }
        if !warnings.isEmpty {
            DisclosureGroup(isExpanded: $warningsExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(warnings, id: \.message) { warning in
                        Text(warning.message).font(.subheadline).foregroundStyle(Theme.ink)
                    }
                }.padding(.top, 10)
            } label: {
                Label("\(warnings.count) attention overlap\(warnings.count == 1 ? "" : "s")", systemImage: "exclamationmark.triangle")
                    .font(.subheadline.weight(.medium)).foregroundStyle(Theme.warning)
            }.tint(Theme.warning)
        }
    }

    // MARK: Timeline column

    @ViewBuilder
    private var timelineColumn: some View {
        HStack {
            SectionLabel(text: "TIMELINE")
            Spacer()
            // Once per plan, not per step (A2-35).
            if let art = heroArt { DinnerHeroThumbnail(art: art, size: 32) }
        }
        servingProgress

        ForEach(pendingSteps) { item in
            stepCard(item)
        }

        if !completedSteps.isEmpty {
            DisclosureGroup(isExpanded: $showCompleted) {
                VStack(spacing: 12) {
                    ForEach(completedSteps) { item in
                        completedCard(item)
                    }
                }
                .padding(.top, 8)
            } label: {
                Text("Completed (\(completedSteps.count))")
                    .font(.headline)
                    .foregroundStyle(Theme.olive)
            }
            .tint(Theme.olive)
            .padding(.vertical, 12)
        }

        if store.canUndo, let label = store.lastUndoLabel {
            Button { store.undoLast() } label: { Label("Undo last action", systemImage: "arrow.uturn.backward") }
                .accessibilityLabel("Undo: \(label)")
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityHint("Restores the plan exactly as it was before that action.")
        }

        Button("Reset cooking progress", role: .destructive) {
            showResetConfirm = true
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .font(.subheadline)
        .foregroundStyle(Theme.tomato)

        if let error = store.notificationError {
            Text(error).font(.caption).foregroundStyle(Theme.warning)
        }
        if store.notificationsDenied {
            Text("Notifications are off — timers still count down here in the app.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
    }

    // MARK: Cards

    private var servingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "DINNER AT")
                    Button("Adjust time") { showDelayChoice = true }
                        .buttonStyle(QuietButtonStyle()).disabled(allDone)
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack {
                        SectionLabel(text: "DINNER AT")
                            .fixedSize(horizontal: true, vertical: false)
                        Spacer()
                        Button("Adjust time") { showDelayChoice = true }
                            .buttonStyle(QuietButtonStyle()).disabled(allDone)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "DINNER AT")
                        Button("Adjust time") { showDelayChoice = true }
                            .buttonStyle(QuietButtonStyle()).disabled(allDone)
                    }
                }
            }
            Text(store.session.serveAt, format: .dateTime.hour().minute())
                .font(.system(.largeTitle, design: .rounded).weight(.medium))
                .monospacedDigit().foregroundStyle(Theme.ink)
                .accessibilityLabel("Chosen dinner time \(Scheduling.formatTime(store.session.serveAt))")
                .accessibilityIdentifier("serving-time") // UI tests read the DINNER AT value
                // Identity follows the value: after an undo the session was
                // restored (the RIGHT NOW card showed it) while this text
                // kept the moved time — SwiftUI reused the stale view (A1,
                // issue #17, runs 38290508810 and 38399682685).
                .id(store.session.serveAt)
            Text(store.session.serveAt, format: .dateTime.weekday().month().day())
                .font(.caption).foregroundStyle(Theme.muted)
        }.padding(.bottom, 8)
    }

    /// Routine timing drift, stated inline and left alone: the chosen dinner
    /// time stays put, the estimate is derived live, and the only control
    /// opens an explicit review. No modal, no dismissal to manage.
    @ViewBuilder
    private var readinessNotice: some View {
        if let report = readiness {
            let emphasized = report.driftMinutes >= Self.readinessEmphasisMinutes
            let tone = emphasized ? Theme.warning : Theme.muted
            let chosen = Scheduling.formatMoment(report.serveAt, relativeTo: now)
            let ready = Scheduling.formatMoment(report.estimatedReadyAt, relativeTo: now)
            // A floored estimate (expired timer still cooking) is a lower
            // bound; say so instead of predicting.
            // A lower bound may only claim the whole minutes it supports
            // (rounded down); "about" keeps nearest rounding. (A2-1)
            let headline = report.estimateIsLowerBound
                ? "At least \(Scheduling.formatMinutes(report.lowerBoundMinutes)) behind"
                : "Running about \(Scheduling.formatMinutes(report.driftMinutes)) behind"
            let detail = report.estimateIsLowerBound
                ? "Dinner is set for \(chosen). Unfinished steps can't finish before \(ready)."
                : "Dinner is set for \(chosen). Unfinished steps are estimated to finish around \(ready)."
            // At accessibility text sizes the full notice filled the first
            // screen and pushed RIGHT NOW below the fold (CI run 4 screenshots).
            // Show the headline, one compact times line and the button; the
            // reason stays in the review sheet. VoiceOver still gets the full
            // label below.
            let compact = dynamicTypeSize.isAccessibilitySize
            let compactLine = "Dinner \(chosen) · \(report.estimateIsLowerBound ? "earliest" : "estimated") \(ready)"
            let readinessLabel = report.estimateIsLowerBound ? "Earliest readiness" : "Estimated readiness"
            let laterPhrase = report.estimateIsLowerBound
                ? "at least \(Scheduling.formatMinutes(report.lowerBoundMinutes)) later"
                : "about \(Scheduling.formatMinutes(report.driftMinutes)) later"
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tone)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(headline)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(emphasized ? Theme.warning : Theme.ink)
                        if compact {
                            Text(compactLine)
                                .font(.caption).monospacedDigit().foregroundStyle(Theme.muted)
                        } else {
                            Text(detail)
                                .font(.caption).monospacedDigit().foregroundStyle(Theme.muted)
                            Text(report.reason)
                                .font(.caption).foregroundStyle(Theme.muted)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Timing update. Chosen dinner time \(chosen). \(readinessLabel) \(ready), \(laterPhrase). \(report.reason)")
                Button("Review dinner time") { showReadinessReview = true }
                    .buttonStyle(QuietButtonStyle())
                    .accessibilityHint("Shows the estimate and lets you move dinner to it. Nothing changes until you choose.")
            }
            .padding(compact ? 12 : 16)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(tone.opacity(emphasized ? 0.5 : 0.25), lineWidth: 1)
            )
            .padding(.bottom, 4)
        }
    }

    private var servingProgress: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(
                value: Double(completedSteps.count),
                total: Double(max(plan.count, 1))
            )
            .tint(Theme.olive)
            .accessibilityLabel("\(completedSteps.count) of \(plan.count) steps complete")
            Text("\(completedSteps.count) of \(plan.count) steps complete")
                .font(.caption)
                .foregroundStyle(Theme.olive)
        }
    }

    /// Tonight's dinner as a picture (Joe, October 13, A2's Duo mock): the
    /// recipe's plate photo, else its cover; nothing otherwise. Cached by file
    /// name, so the timer's ticks never decode it again. None at
    /// accessibility sizes: text first (A2-35).
    private var heroArt: DinnerHeroArt? {
        guard !dynamicTypeSize.isAccessibilitySize else { return nil }
        return DinnerHeroArt.of(store.session.menuID, library: library)
    }

    /// The RIGHT NOW hero: about 140 pt on a phone or the Duo's outer
    /// display, 220 pt on a wide, tall screen. Kept for an expired timer too
    /// (Joe's call) — but on a short screen it becomes a header thumbnail
    /// first, so the primary action never drops below the fold.
    private var heroHeight: CGFloat? {
        guard heroArt != nil, viewportHeight >= 620 else { return nil }
        if horizontalSizeClass == .regular && viewportHeight >= 760 { return 220 }
        // An expired timer's card is taller (countdown, deadline, the check
        // note): a shorter photo keeps "Mark done after checking" on the
        // first screen of a phone.
        return urgentTimer != nil ? 110 : 140
    }

    /// The featured card's frame: the hero picture with the RIGHT NOW tag on
    /// its bottom edge, then the card's content on its opaque surface — no
    /// text over food.
    @ViewBuilder
    private func rightNowShell<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if let height = heroHeight, let art = heroArt {
            VStack(alignment: .leading, spacing: 0) {
                DinnerHero(art: art, height: height)
                    .overlay(alignment: .bottomLeading) {
                        Text("RIGHT NOW")
                            .font(.caption.weight(.bold)).tracking(1.2)
                            .foregroundStyle(Theme.tomato)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .padding(.leading, 18).padding(.bottom, 10)
                            .accessibilityAddTraits(.isHeader)
                    }
                content().padding(22)
            }
            .background(Theme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        } else {
            content().dtCard()
        }
    }

    /// The header thumbnail when the hero does not fit.
    private var heroThumbnail: DinnerHeroArt? { heroHeight == nil ? heroArt : nil }

    /// The featured card is the expired timer demanding attention right now —
    /// its "Mark done" is the primary action. Other running timers keep the
    /// quieter control.
    @ViewBuilder
    private func heatCard(_ item: PlannedStep, featured: Bool = false) -> some View {
        if featured {
            rightNowShell { heatContent(item, featured: true) }
        } else {
            heatContent(item, featured: false).dtCard()
        }
    }

    private func heatContent(_ item: PlannedStep, featured: Bool) -> some View {
        let record = store.record(item.id)
        let deadline = record.timerDeadline ?? item.end
        let remaining = timers.remaining(until: deadline)
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                if !featured, !dynamicTypeSize.isAccessibilitySize {
                    DishThumbnail(step: item.step, menuID: store.session.menuID, size: 36)
                }
                Label(item.step.dish, systemImage: "timer").font(.caption.weight(.semibold))
                Spacer()
                Text(remaining <= 0 ? "Check the food" : "Running").font(.caption.weight(.medium))
                if featured, let art = heroThumbnail { DinnerHeroThumbnail(art: art, size: 44) }
            }.foregroundStyle(remaining <= 0 ? Theme.warning : Theme.muted)
            Text(item.step.title).font(.headline).foregroundStyle(Theme.ink)
            Text(Scheduling.formatCountdown(remaining: remaining))
                .font(.system(.largeTitle, design: .rounded).weight(.medium))
                .monospacedDigit().foregroundStyle(remaining <= 0 ? Theme.warning : Theme.ink)
                .accessibilityLabel("Timer \(Scheduling.formatCountdown(remaining: remaining))")
            Text("Ends \(Scheduling.formatTime(deadline))").font(.caption).foregroundStyle(Theme.muted)
                .accessibilityLabel("Timer deadline \(Scheduling.formatTime(deadline))")
            if remaining <= 0 {
                // Expiry is a prompt to check, never a completion. No actual
                // end is recorded until the cook says so.
                Text("The timer ended; the food may not have. Check it before marking this step done.")
                    .font(.caption).foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // RIGHT NOW's action comes before the timing details, so it stays
            // on the first screen of a short window too (the Duo upright,
            // 466 × 678: below the tab bar in run 38733138966).
            if featured {
                Button { doneTapped(item) } label: {
                    Label(remaining <= 0 ? "Mark done after checking" : "Mark done", systemImage: "checkmark")
                }
                    .buttonStyle(BigButtonStyle()).accessibilityLabel("Mark \(item.step.title) done")
                    .accessibilityHint(remaining <= 0 ? "The timer ended. Confirm the food is ready before marking this step done." : "")
            }
            DisclosureGroup("Timing details") {
                VStack(alignment: .leading, spacing: 5) {
                    if let start = record.actualStart { Text("Started \(Scheduling.formatTime(start))") }
                    Text("Planned \(Scheduling.formatRange(start: item.plannedStart, end: item.plannedEnd))")
                }.font(.caption).foregroundStyle(Theme.muted).padding(.top, 5)
            }.font(.caption).tint(Theme.muted)
            if !featured {
                Button { doneTapped(item) } label: { Label("Mark done", systemImage: "checkmark") }
                    .buttonStyle(QuietButtonStyle()).accessibilityLabel("Mark \(item.step.title) done")
            }
        }
    }

    private func doNowCard(_ item: PlannedStep) -> some View {
        rightNowShell { doNowContent(item, thumbnail: heroThumbnail) }
    }

    private func doNowContent(_ item: PlannedStep, thumbnail: DinnerHeroArt?) -> some View {
        let overdue = now.timeIntervalSince(item.plannedStart) >= 60
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(item.step.dish).font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                Spacer()
                Label("\(Scheduling.formatMinutes(item.minutes))", systemImage: item.step.handsOn ? "hand.raised" : "timer")
                    .font(.caption).foregroundStyle(Theme.muted)
                if let thumbnail { DinnerHeroThumbnail(art: thumbnail, size: 44) }
            }
            Text(item.step.title).font(.title2.weight(.semibold)).foregroundStyle(Theme.ink)
            Text(item.step.handsOn ? "Needs your attention" : "Hands-off after you start")
                .font(.subheadline).foregroundStyle(Theme.muted)
            if overdue {
                Label("About \(Scheduling.formatMinutes(max(1, Int(now.timeIntervalSince(item.plannedStart) / 60)))) late to start", systemImage: "clock.badge.exclamationmark")
                    .font(.caption.weight(.medium)).foregroundStyle(Theme.warning)
            }
            Button { startTapped(item) } label: { Label("Start this step", systemImage: "play.fill") }
                .buttonStyle(BigButtonStyle()).accessibilityLabel("Start \(item.step.title)")
        }
    }

    private func stepCard(_ item: PlannedStep) -> some View {
        let record = store.record(item.id)
        let isCooking = record.state == .cooking
        let blocked = isCooking ? nil : isBlocked(item)
        return HStack(alignment: .top, spacing: 14) {
            Image(systemName: isCooking ? "circle.inset.filled" : "circle")
                .font(.caption).foregroundStyle(isCooking ? Theme.tomato : Theme.muted)
                .frame(width: 18).padding(.top, 4).accessibilityHidden(true)
            // The dish, as in A2's mock: its illustration, or the recipe's cover.
            if !dynamicTypeSize.isAccessibilitySize {
                DishThumbnail(step: item.step, menuID: store.session.menuID, size: 40).padding(.top, 2)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text(isCooking
                     ? "Timer deadline \(Scheduling.formatTime(item.end))"
                     : "Planned \(Scheduling.formatRange(start: item.plannedStart, end: item.plannedEnd))")
                    .font(.caption.weight(.medium)).monospacedDigit().foregroundStyle(Theme.muted)
                Text(item.step.title).font(.headline).foregroundStyle(Theme.ink)
                HStack(spacing: 8) {
                    stateBadge(record.state)
                    Text(item.step.handsOn ? "Hands-on" : "Hands-off")
                        .font(.caption).foregroundStyle(Theme.muted)
                }
                if isCooking, let deadline = record.timerDeadline {
                    Text("Timer: \(Scheduling.formatCountdown(remaining: timers.remaining(until: deadline)))")
                        .font(.subheadline.weight(.medium)).monospacedDigit().foregroundStyle(Theme.ink)
                }
                if !isCooking, blocked == nil, now.timeIntervalSince(item.plannedStart) >= 60 {
                    Text("About \(Scheduling.formatMinutes(max(1, Int(now.timeIntervalSince(item.plannedStart) / 60)))) late to start")
                        .font(.caption).foregroundStyle(Theme.warning)
                }
                if let blocked = blocked {
                    Label("Waiting for \(blocked.predecessorTitle)", systemImage: "hourglass")
                        .font(.caption).foregroundStyle(Theme.warning)
                }
                DisclosureGroup("Notes & details") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.step.detail)
                        if let start = record.actualStart { Text("Actually started \(Scheduling.formatTime(start))") }
                        if let blocked = blocked { Text("Expected ready around \(Scheduling.formatTime(blocked.readyAt)).") }
                    }.font(.subheadline).foregroundStyle(Theme.muted).padding(.top, 6)
                }.font(.caption).tint(Theme.muted)
                HStack {
                    if isCooking {
                        Button("Mark done") { doneTapped(item) }.buttonStyle(QuietButtonStyle())
                    } else {
                        Button(blocked == nil ? "Start step" : "Review start") { startTapped(item) }
                            .buttonStyle(QuietButtonStyle())
                            .accessibilityHint(blocked == nil ? "Starts this step, checking dependencies first." : "Reviews the unfinished prerequisite before starting.")
                    }
                    Spacer()
                }
            }
        }.padding(.vertical, 18)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 0.5) }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("timeline-step-\(item.id)") // UI tests scope taps to one step card
    }

    private func completedCard(_ item: PlannedStep) -> some View {
        let record = store.record(item.id)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.step.dish.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.olive)
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.olive)
            }
            Text(item.step.title)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
            if let end = record.actualEnd {
                if let start = record.actualStart {
                    Text("Done \(Scheduling.formatTime(start)) – \(Scheduling.formatTime(end))")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                } else {
                    Text("Done \(Scheduling.formatTime(end)) · start not recorded")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
            }
            Button("Start over") { store.correctStep(item.id) }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.tomato)
                .frame(minHeight: 44)
                .accessibilityLabel("Reopen \(item.step.title), clearing its timer")
        }
        .padding(12)
        .background(Theme.cream, in: RoundedRectangle(cornerRadius: 14))
    }

    private func stateBadge(_ state: StepState) -> some View {
        let text: String
        let color: Color
        switch state {
        case .notStarted: text = "Not started"; color = Theme.muted
        case .cooking: text = "Cooking"; color = Theme.ink
        case .done: text = "Done"; color = Theme.olive
        }
        return Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
            .accessibilityLabel("Status: \(text)")
    }
}

extension DelayProposal: Identifiable {
    var id: String { "\(minutes)-\(newServeAt.timeIntervalSince1970)" }
}
