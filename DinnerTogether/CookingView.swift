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
    /// The opened Duo's cooking layouts (Joe approved A2's boards 5–7,
    /// October 15): each dish page keeps its own Coming up / Directions tab,
    /// the upright page its Main / Side choice, the one-recipe photo card its
    /// glass (the same dial as Tonight's card).
    @State private var duoDirections: Set<UUID> = []
    @State private var duoShowingSide = false
    @State private var duoGlassPanel = false
    @AppStorage(TonightGlass.key) private var duoGlassTint = TonightGlass.standard
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorContrast

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
        prompts(
            GeometryReader { g in
                if let layout = duoLayout(g) {
                    duoBody(layout)
                } else {
                    phoneAndPadBody
                }
            }
            .background(Theme.cream)
            .navigationTitle(store.hasDinner ? store.menu.title : "Cooking")
            .sensoryFeedback(.success, trigger: completionFeedback)
            .navigationBarTitleDisplayMode(.inline)
        )
    }

    private var phoneAndPadBody: some View {
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
    }

    /// The observers, dialogs, sheets and the one alert, on whichever layout shows.
    private func prompts<C: View>(_ content: C) -> some View {
        content
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
            // Kitchen timers from the directions, while any run (A2-64).
            RunningTimersStrip()
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
                        // The dish beside the time on a whole meal (A2-63):
                        // the cook knows which pan the step belongs to.
                        HStack(spacing: 6) {
                            Text(Scheduling.formatTime(item.plannedStart))
                                .font(.caption.weight(.semibold)).monospacedDigit().foregroundStyle(Theme.muted)
                            if WholeMeal.isWholeMeal(store.session.menuID) {
                                Text("·").font(.caption).foregroundStyle(Theme.muted).accessibilityHidden(true)
                                Text(item.step.dish).font(.caption.weight(.semibold)).foregroundStyle(Theme.olive).lineLimit(1)
                            }
                        }
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
            dishSummary
        }.padding(.bottom, 8)
    }

    /// The whole meal's dishes, named, ready together (A2-63, build 21):
    /// "Sunday herb chicken · Mashed potatoes · Green beans". Nothing for a
    /// single recipe or Thanksgiving, whose title already says it.
    @ViewBuilder
    private var dishSummary: some View {
        let dishes = (WholeMeal.recipeIDs(store.session.menuID) ?? []).compactMap { library.recipe(id: $0) }
        if dishes.count > 1 {
            HStack(alignment: .top, spacing: 8) {
                HStack(spacing: -8) {
                    ForEach(dishes.prefix(4)) { dish in
                        if let photo = RecipePhotos.hero(dish, from: library) {
                            RecipeCoverThumbnail(image: photo.image, size: 28)
                                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Theme.cream, lineWidth: 2))
                        }
                    }
                }
                Text(dishes.map(\.title).joined(separator: " · "))
                    .font(.subheadline).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(dishes.count) dishes, ready together: \(dishes.map(\.title).joined(separator: ", "))")
            .accessibilityIdentifier("dish-summary")
        }
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
            // on the first screen of a short window too (the Duo's cover
            // display, 466 × 678: below the tab bar in run 38733138966).
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

// MARK: - The opened Duo's cooking layouts (Joe approved A2's boards 5–7, October 15)

/// Which of the approved layouts the window gets: the Duo open like a book
/// with one recipe (the photo and a glass Right now card left, Coming up /
/// Directions right), with two (side left, main right, each with its own
/// Right now and tabs), or open and held upright with two (one page, a
/// Main / Side switch, the other dish's strip). Three or four dishes keep
/// the iPhone timeline; so does a cover display, an iPad, or large text.
enum DuoCooking {
    case bookOne(Recipe)
    case bookTwo(main: Recipe, side: Recipe)
    case uprightTwo(main: Recipe, side: Recipe)
}

extension CookingView {
    private var dinnerRecipes: [Recipe] {
        (WholeMeal.recipeIDs(store.session.menuID) ?? []).compactMap { library.recipe(id: $0) }
    }

    private func duoLayout(_ g: GeometryProxy) -> DuoCooking? {
        guard UIDevice.current.userInterfaceIdiom == .phone, store.hasDinner, !allDone,
              !dynamicTypeSize.isAccessibilitySize else { return nil }
        let mode = SpreadLayout.mode(
            width: g.size.width + g.safeAreaInsets.leading + g.safeAreaInsets.trailing,
            height: g.size.height + g.safeAreaInsets.top + g.safeAreaInsets.bottom,
            phoneIdiom: true, accessibilitySize: false)
        let recipes = dinnerRecipes
        guard let ids = WholeMeal.recipeIDs(store.session.menuID), recipes.count == ids.count else { return nil }
        switch (mode, recipes.count) {
        case (.spread, 1): return .bookOne(recipes[0])
        case (.spread, 2): return .bookTwo(main: recipes[0], side: recipes[1])
        case (.book, 2): return .uprightTwo(main: recipes[0], side: recipes[1])
        default: return nil
        }
    }

    private func duoBody(_ layout: DuoCooking) -> some View {
        duoPages(layout)
            // The pages carry the dish names; a bar title ran across the
            // fold and kept the photo from the top edge (run 38815612226).
            .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func duoPages(_ layout: DuoCooking) -> some View {
        switch layout {
        case .bookOne(let recipe):
            HStack(spacing: 0) {
                duoPhotoPage(recipe)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Rectangle().fill(Theme.line).frame(width: 1).ignoresSafeArea().accessibilityHidden(true)
                duoDishPage(recipe, label: nil, withRightNow: false)
                    .frame(maxWidth: .infinity)
            }
        case .bookTwo(let main, let side):
            HStack(spacing: 0) {
                duoDishPage(side, label: "SIDE DISH", withRightNow: true)
                    .frame(maxWidth: .infinity)
                Rectangle().fill(Theme.line).frame(width: 1).ignoresSafeArea().accessibilityHidden(true)
                duoDishPage(main, label: "MAIN DISH", withRightNow: true)
                    .frame(maxWidth: .infinity)
            }
        case .uprightTwo(let main, let side):
            let shown = duoShowingSide ? side : main
            let other = duoShowingSide ? main : side
            VStack(spacing: 0) {
                duoSwitch
                duoDishPage(shown, label: duoShowingSide ? "SIDE DISH" : "MAIN DISH", withRightNow: true, otherDish: other)
            }
        }
    }

    // MARK: Pieces

    /// The dish's own steps, in the plan.
    private func items(of recipe: Recipe) -> [PlannedStep] {
        let ids = Set(recipe.steps.map(\.id))
        return plan.filter { ids.contains($0.id) }
    }
    private func urgent(of recipe: Recipe) -> PlannedStep? {
        let ids = Set(recipe.steps.map(\.id))
        return urgentTimer.flatMap { ids.contains($0.id) ? $0 : nil }
            ?? onHeat.first { ids.contains($0.id) && (store.record($0.id).timerDeadline ?? $0.end) <= now }
    }
    private func doNow(of recipe: Recipe) -> PlannedStep? {
        let ids = Set(recipe.steps.map(\.id))
        return doNow.first { ids.contains($0.id) }
    }
    private func running(of recipe: Recipe) -> [PlannedStep] {
        let ids = Set(recipe.steps.map(\.id))
        return onHeat.filter { ids.contains($0.id) }
    }
    private func upNext(of recipe: Recipe) -> [PlannedStep] {
        let ids = Set(recipe.steps.map(\.id))
        return upNext.filter { ids.contains($0.id) }
    }

    /// "Dinner at 7:00 PM · Adjust time", compact, on every Duo layout.
    private var duoServingLine: some View {
        HStack(spacing: 10) {
            SectionLabel(text: "DINNER AT")
            Text(store.session.serveAt, format: .dateTime.hour().minute())
                .font(.system(.title3, design: .rounded).weight(.medium)).monospacedDigit()
                .foregroundStyle(Theme.ink)
                .accessibilityLabel("Chosen dinner time \(Scheduling.formatTime(store.session.serveAt))")
                .accessibilityIdentifier("serving-time")
                .id(store.session.serveAt)
            Spacer(minLength: 8)
            Button("Adjust time") { showDelayChoice = true }
                .buttonStyle(QuietButtonStyle()).disabled(allDone)
        }
    }

    /// Board 5's left page: the dish's photo edge to edge, the glass Right
    /// now card on it (the same dial as Tonight's card: ••• opens it), the
    /// step, its countdown and the one action.
    private func duoPhotoPage(_ recipe: Recipe) -> some View {
        let art = DinnerHeroArt.of(store.session.menuID, library: library)
        let solid = reduceTransparency || colorContrast == .increased || LaunchOptions.solidCards
        return ZStack(alignment: .bottom) {
            if case .cover(let image, _)? = art {
                Color.clear
                    .overlay(Image(uiImage: image).resizable().scaledToFill())
                    .clipped()
                    .accessibilityElement()
                    .accessibilityLabel("Photo of \(recipe.title)")
                    .accessibilityAddTraits(.isImage)
                // Legible text over any photo: a scrim under the title at
                // the top (a pale photo washed it out, run 38820416744) and
                // one at the foot under the card.
                LinearGradient(stops: [.init(color: .black.opacity(0.4), location: 0),
                                       .init(color: .black.opacity(0), location: 0.35),
                                       .init(color: .black.opacity(0), location: 0.55),
                                       .init(color: .black.opacity(0.45), location: 1)],
                               startPoint: .top, endPoint: .bottom)
                    .allowsHitTesting(false)
            } else {
                Theme.cream
            }
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DINNER, TOGETHER").font(.caption2.weight(.semibold)).tracking(1.6)
                            .foregroundStyle(art == nil ? Theme.muted : .white.opacity(0.85))
                        Text(recipe.title)
                            .font(.system(.title, design: .serif).weight(.medium))
                            .foregroundStyle(art == nil ? Theme.ink : .white)
                            .shadow(color: .black.opacity(art == nil ? 0 : 0.45), radius: 6, y: 1)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                .padding(20)
                Spacer(minLength: 0)
                duoGlassCard(recipe, solid: solid)
                    .padding(16)
            }
        }
        .clipped()
        .ignoresSafeArea(edges: .bottom)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("duo-photo-page")
    }

    private func duoGlassCard(_ recipe: Recipe, solid: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("RIGHT NOW").font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(Theme.pageAccent)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button { duoGlassPanel = true } label: {
                    Image(systemName: "ellipsis").font(.body.weight(.bold)).foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white.opacity(0.18)))
                }
                .accessibilityLabel("Card options")
                .accessibilityIdentifier("duo-card-options")
                .popover(isPresented: $duoGlassPanel) {
                    GlassTintPanel(tint: $duoGlassTint, solid: solid) { duoGlassPanel = false }
                        .presentationCompactAdaptation(.popover)
                }
            }
            duoRightNow(recipe, onGlass: true)
        }
        .padding(18)
        .background {
            if solid {
                shape.fill(PlanView.tableSurface)
            } else {
                ZStack {
                    shape.fill(.ultraThinMaterial).environment(\.colorScheme, .dark)
                        .opacity(TonightGlass.blur(duoGlassTint))
                    shape.fill(PlanView.tableSurface.opacity(TonightGlass.tint(duoGlassTint)))
                }
                .overlay(shape.strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
            }
        }
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("duo-right-now-card")
    }

    /// The dish's current thing: an ended timer to check, a step to start, a
    /// running timer, or breathing room — with its one action.
    @ViewBuilder
    private func duoRightNow(_ recipe: Recipe, onGlass: Bool) -> some View {
        if let item = urgent(of: recipe) {
            duoStepLine(item, state: .ended, onGlass: onGlass)
        } else if let item = doNow(of: recipe) {
            duoStepLine(item, state: .ready, onGlass: onGlass)
        } else if let item = running(of: recipe).min(by: { (store.record($0.id).timerDeadline ?? $0.end) < (store.record($1.id).timerDeadline ?? $1.end) }) {
            duoStepLine(item, state: .running, onGlass: onGlass)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("A little breathing room.").font(.headline).foregroundStyle(Theme.ink)
                if let next = upNext(of: recipe).first {
                    Text("Next: \(next.step.title) · \(Scheduling.formatTime(next.plannedStart))")
                        .font(.subheadline).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Nothing waiting for this dish right now.").font(.subheadline).foregroundStyle(Theme.muted)
                }
            }
        }
    }

    private enum DuoStepState { case ended, ready, running }

    private func duoStepLine(_ item: PlannedStep, state: DuoStepState, onGlass: Bool) -> some View {
        let record = store.record(item.id)
        let deadline = record.timerDeadline ?? item.end
        let remaining = timers.remaining(until: deadline)
        return VStack(alignment: .leading, spacing: 10) {
            Text(item.step.title)
                .font(.system(.title2, design: .serif).weight(.medium)).foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            switch state {
            case .ended, .running:
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(Scheduling.formatCountdown(remaining: remaining))
                        .font(.system(size: 40, weight: .medium, design: .rounded)).monospacedDigit()
                        .foregroundStyle(remaining <= 0 ? Theme.warning : Theme.ink)
                        .accessibilityLabel("Timer \(Scheduling.formatCountdown(remaining: remaining))")
                    Text(remaining <= 0 ? "Check the food" : "remaining").font(.caption).foregroundStyle(remaining <= 0 ? Theme.warning : Theme.muted)
                }
                Button { doneTapped(item) } label: {
                    Label(remaining <= 0 ? "Mark done after checking" : "Mark done", systemImage: "checkmark")
                }
                .buttonStyle(BigButtonStyle(onColoredPage: onGlass))
                .accessibilityLabel("Mark \(item.step.title) done")
            case .ready:
                Text(item.step.handsOn ? "Needs your attention · \(Scheduling.formatMinutes(item.minutes))" : "Hands-off after you start · \(Scheduling.formatMinutes(item.minutes))")
                    .font(.subheadline).foregroundStyle(Theme.muted)
                Button { startTapped(item) } label: { Label("Start this step", systemImage: "play.fill") }
                    .buttonStyle(BigButtonStyle(onColoredPage: onGlass))
                    .accessibilityLabel("Start \(item.step.title)")
            }
        }
    }

    /// A cookbook page for one dish: its label and title, its Right now
    /// (unless the photo page has it), then Coming up or Directions, each
    /// page keeping its tab. `otherDish`: the upright page's strip for the
    /// dish not shown (board 7).
    private func duoDishPage(_ recipe: Recipe, label: String?, withRightNow: Bool, otherDish: Recipe? = nil) -> some View {
        let directions = duoDirections.contains(recipe.id)
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                duoServingLine
                if let label {
                    Text(label).font(.caption.weight(.semibold)).tracking(1.6).foregroundStyle(Theme.tomato)
                }
                HStack(alignment: .center, spacing: 14) {
                    // Two dishes: each page shows its dish's photo small
                    // beside the name (Joe, October 15, 5:40 PM: "it would
                    // liven it up"; board 02). One dish has the photo page.
                    if label != nil, !dynamicTypeSize.isAccessibilitySize,
                       let photo = RecipePhotos.hero(recipe, from: library) {
                        RecipeCoverThumbnail(image: photo.image, size: 72)
                            .accessibilityIdentifier("duo-dish-photo")
                    }
                    Text(recipe.title)
                        .font(.system(.title2, design: .serif).weight(.semibold)).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Image(systemName: "leaf").rotationEffect(.degrees(-35)).foregroundStyle(Theme.tomato.opacity(0.85))
                        .accessibilityHidden(true)
                }
                if withRightNow {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "RIGHT NOW")
                        duoRightNow(recipe, onGlass: false)
                    }
                    .dtCard()
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("duo-right-now-\(label == "SIDE DISH" ? "side" : "main")")
                }
                RunningTimersStrip()
                // Coming up | Directions
                HStack(spacing: 22) {
                    duoTab("Coming up", selected: !directions) { duoDirections.remove(recipe.id) }
                    duoTab("Directions", selected: directions) { duoDirections.insert(recipe.id) }
                    Spacer()
                }
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1).accessibilityHidden(true) }
                if directions {
                    duoDirectionsList(recipe)
                } else {
                    duoComingUp(recipe, withRightNow: withRightNow)
                }
                if let otherDish { duoOtherDishStrip(otherDish) }
            }
            .padding(20)
        }
        .background(Theme.cream)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("duo-dish-page-\(label == "SIDE DISH" ? "side" : "main")")
    }

    private func duoTab(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? Theme.ink : Theme.muted)
                .padding(.vertical, 10).frame(minHeight: 44)
                .overlay(alignment: .bottom) { Rectangle().fill(selected ? Theme.olive : .clear).frame(height: 2) }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("duo-tab-\(title.lowercased().replacingOccurrences(of: " ", with: "-"))")
    }

    /// The dish's running timers (beyond the one in Right now), what's ready
    /// to start, and what's coming, each with its planned time.
    @ViewBuilder
    private func duoComingUp(_ recipe: Recipe, withRightNow: Bool) -> some View {
        let featured = withRightNow ? (urgent(of: recipe) ?? doNow(of: recipe) ?? running(of: recipe).first)?.id : nil
        let timersHere = running(of: recipe).filter { $0.id != featured }
        let ready = doNow.filter { Set(recipe.steps.map(\.id)).contains($0.id) && $0.id != featured }
        VStack(alignment: .leading, spacing: 14) {
            if urgentTimer == nil { readinessNotice }
            if !withRightNow, let item = urgent(of: recipe) ?? doNow(of: recipe) {
                // Board 5: the action lives on the photo page; here the same
                // step heads the list so the right page reads complete.
                duoRow(item, state: store.record(item.id).state == .cooking ? "Check the food" : "Ready to start")
            }
            ForEach(timersHere) { item in
                let deadline = store.record(item.id).timerDeadline ?? item.end
                duoRow(item, state: "Running · \(Scheduling.formatCountdown(remaining: timers.remaining(until: deadline)))") {
                    Button("Mark done") { doneTapped(item) }.buttonStyle(QuietButtonStyle())
                }
            }
            ForEach(ready) { item in
                duoRow(item, state: "Ready to start") {
                    Button("Start step") { startTapped(item) }.buttonStyle(SecondaryButtonStyle())
                }
            }
            let coming = upNext(of: recipe)
            if coming.isEmpty && timersHere.isEmpty && ready.isEmpty {
                Text(items(of: recipe).allSatisfy { store.record($0.id).state == .done }
                     ? "Every step of this dish is done." : "Nothing else waiting for this dish.")
                    .font(.subheadline).foregroundStyle(Theme.muted)
            }
            ForEach(coming) { item in
                duoRow(item, state: Scheduling.formatTime(item.plannedStart))
            }
            // The dinner's overlaps, once, on the main dish's page.
            if !warnings.isEmpty && dinnerRecipes.first?.id == recipe.id {
                DisclosureGroup(isExpanded: $warningsExpanded) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(warnings, id: \.message) { warning in
                            Text(warning.message).font(.subheadline).foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }.padding(.top, 8)
                } label: {
                    Label("\(warnings.count) attention overlap\(warnings.count == 1 ? "" : "s")", systemImage: "exclamationmark.triangle")
                        .font(.subheadline.weight(.medium)).foregroundStyle(Theme.warning)
                }
                .tint(Theme.warning)
            }
        }
    }

    private func duoRow<Action: View>(_ item: PlannedStep, state: String, @ViewBuilder action: () -> Action = { EmptyView() }) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(state).font(.caption.weight(.semibold)).monospacedDigit().foregroundStyle(Theme.muted)
                    .frame(minWidth: 64, alignment: .leading)
                Text(item.step.title).font(.subheadline).foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            action()
            Rectangle().fill(Theme.line).frame(height: 1).accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    /// The directions beside the cooking (board 5's right page): olive
    /// numbers, and a kitchen timer for any time a step names, as on the
    /// recipe page. Reading never starts, stops or completes a plan step.
    private func duoDirectionsList(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(recipe.directions.enumerated()), id: \.offset) { i, line in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(i + 1)")
                        .font(.subheadline.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(minWidth: 28, minHeight: 28)
                        .background(Circle().fill(Theme.olive))
                        .accessibilityLabel("Step \(i + 1)")
                    VStack(alignment: .leading, spacing: 10) {
                        TimedText.make(line).font(.body).lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                        CookingDirectionTimers(recipe: recipe, stepIndex: i, line: line)
                    }
                }
                Rectangle().fill(Theme.line).frame(height: 1).accessibilityHidden(true)
            }
            Text("Reading never stops a timer or marks a step done.")
                .font(.caption).foregroundStyle(Theme.muted)
        }
    }

    /// Board 7's strip for the dish not shown: its state or countdown, and
    /// the way to it.
    private func duoOtherDishStrip(_ other: Recipe) -> some View {
        let state: String = {
            if let item = urgent(of: other) { return "\(item.step.title) · check the food" }
            if let item = running(of: other).first {
                let deadline = store.record(item.id).timerDeadline ?? item.end
                return "\(item.step.title) · \(Scheduling.formatCountdown(remaining: timers.remaining(until: deadline)))"
            }
            if let item = doNow(of: other) { return "\(item.step.title) · ready to start" }
            if let next = upNext(of: other).first { return "Next: \(next.step.title) · \(Scheduling.formatTime(next.plannedStart))" }
            return items(of: other).allSatisfy { store.record($0.id).state == .done } ? "Every step done" : "Nothing waiting"
        }()
        let isSide = dinnerRecipes.first?.id != other.id
        return Button { duoShowingSide = isSide } label: {
            HStack(spacing: 12) {
                if let photo = RecipePhotos.hero(other, from: library) {
                    RecipeCoverThumbnail(image: photo.image, size: 44)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(other.title).font(.headline).foregroundStyle(Theme.ink)
                    Text(state).font(.caption).monospacedDigit().foregroundStyle(urgent(of: other) != nil ? Theme.warning : Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Text(isSide ? "View side" : "View main").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.olive)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
            }
            .padding(14)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.line))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(other.title): \(state). \(isSide ? "View side" : "View main")")
        .accessibilityIdentifier("duo-other-dish")
    }

    /// The upright page's Main / Side capsule (the recipe page's, approved
    /// mockup 04).
    private var duoSwitch: some View {
        HStack(spacing: 0) {
            duoSwitchTab("Main", selected: !duoShowingSide, id: "duo-switch-main") { duoShowingSide = false }
            duoSwitchTab("Side", selected: duoShowingSide, id: "duo-switch-side") { duoShowingSide = true }
        }
        .padding(3)
        .background(Capsule().fill(Theme.line.opacity(0.6)))
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }

    private func duoSwitchTab(_ title: String, selected: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? Theme.cream : Theme.ink)
                .padding(.horizontal, 22).frame(minHeight: 44)
                .background(Capsule().fill(selected ? Theme.olive : .clear))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(id)
    }
}
