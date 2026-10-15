import Foundation
import SwiftUI

enum StaleStatus {
    case fresh
    case stale
}

enum StartResult: Equatable {
    case started
    case blocked(predecessorTitle: String, readyAt: Date)
    case noOp
}

enum CompleteResult: Equatable {
    case completed
    /// The step was never started: confirm before recording a completion with
    /// an unknown start time. The app never fabricates an actual start.
    case needsStartConfirmation(title: String)
    case noOp
}

/// Owns one dinner: the session value, undo history, persistence, and every
/// action the UI can take. Mutations push an undo frame first; undo restores
/// the exact prior session, so timers are never silently restarted.
///
/// Notification continuations check the particular run identity after awaiting
/// authorization. Unrelated cooking actions must not invalidate live reminders.
@MainActor
final class SessionStore: ObservableObject {
    @Published var session = DinnerSession()
    @Published var undoStack: [UndoFrame] = []
    @Published var saveError: String?
    @Published var needsStaleChoice = false
    @Published var notificationsDenied = false
    @Published var notificationError: String?
    // NOTE (recovery candidate): the cached `pendingServingProposal` was
    // removed. Timing drift is now derived on demand via `readinessReport`,
    // so there is no stored estimate to go stale after undo, reset, menu
    // change, delay confirmation, another completion, or a return from
    // background. Moving dinner remains an explicit, undoable action.

    let notifications: NotificationService
    /// Resolves menu ids beyond the catalog (the cook's own recipes). Nil
    /// means catalog only, which is what every pre-recipe test constructs.
    let menuProvider: MenuProviding?
    private let fileURL: URL
    private let maxUndo = 25

    init(fileURL: URL? = nil, notifications: NotificationService? = nil, menuProvider: MenuProviding? = nil) {
        let resolvedURL = fileURL ?? URL.documentsDirectory.appending(path: "dinner-together-v2.json")
        self.fileURL = resolvedURL
        self.notifications = notifications ?? NotificationManager()
        self.menuProvider = menuProvider
        if let data = try? Data(contentsOf: resolvedURL),
           let loaded = try? JSONDecoder().decode(DinnerSession.self, from: data),
           Self.resolve(loaded.menuID, provider: menuProvider) != nil
        {
            session = loaded
        }
        self.notifications.onStatusChange = { [weak self] denied, error in
            self?.notificationsDenied = denied
            self?.notificationError = error
        }
        if staleStatus() == .stale {
            needsStaleChoice = true
        } else {
            session.lastOpenedAt = Date()
        }
    }

    // MARK: Derived

    private static func resolve(_ id: String, provider: MenuProviding?) -> DinnerMenu? {
        if id.isEmpty { return .unchosen }
        if let m = provider?.menu(id: id) { return m }
        return DinnerCatalog.menu(id: id)
    }

    /// The menu this session cooks — `.unchosen` until the cook chooses one, and
    /// again when a recipe that was tonight's dinner no longer exists;
    /// `menuIsMissing` lets the UI say so instead of pretending.
    var menu: DinnerMenu { Self.resolve(session.menuID, provider: menuProvider) ?? .unchosen }
    var menuIsMissing: Bool { Self.resolve(session.menuID, provider: menuProvider) == nil }
    /// Whether there is a dinner to time at all.
    var hasDinner: Bool { !menu.isUnchosen }
    var plan: [PlannedStep] { Scheduling.plan(menu: menu, session: session) }

    func record(_ id: String) -> StepRecord {
        session.records[id] ?? StepRecord()
    }

    var hasProgress: Bool {
        session.records.values.contains { $0.state != .notStarted }
    }

    // MARK: Persistence

    func save() {
        do {
            try JSONEncoder().encode(session).write(to: fileURL, options: .atomic)
            saveError = nil
        } catch {
            saveError = "Your changes couldn't be saved. Keep the app open and try again."
        }
    }

    // MARK: Undo

    private func pushUndo(_ label: String) {
        undoStack.append(UndoFrame(label: label, session: session))
        if undoStack.count > maxUndo { undoStack.removeFirst() }
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var lastUndoLabel: String? { undoStack.last?.label }

    /// Restores the exact session from before the last action — including timer
    /// deadlines. Nothing is recomputed or restarted.
    func undoLast() {
        guard let frame = undoStack.popLast() else { return }
        session = frame.session
        resyncNotifications()
        session.history.append(HistoryEvent(text: "Undid: \(frame.label)."))
        save()
    }

    // MARK: Step actions

    /// Explicit user action: starts the step NOW with a timer for its confirmed
    /// duration. A step whose predecessor isn't done is blocked unless `force`
    /// is set — the UI gets `.blocked` and must ask explicitly ("Start anyway?").
    func startStep(_ id: String, force: Bool = false, now: Date = Date()) async -> StartResult {
        guard let planned = plan.first(where: { $0.id == id }),
              record(id).state == .notStarted
        else { return .noOp }
        if !force,
           let blocked = Scheduling.dependencyInfo(
               plan: plan, menu: menu, session: session, stepID: id)
        {
            return .blocked(predecessorTitle: blocked.predecessorTitle, readyAt: blocked.readyAt)
        }
        pushUndo("Started “\(planned.step.title)”")
        var rec = StepRecord()
        rec.runID = UUID()
        rec.state = .cooking
        rec.actualStart = now
        rec.confirmedMinutes = planned.minutes
        rec.timerDeadline = now.addingTimeInterval(Double(planned.minutes) * 60)
        session.records[id] = rec
        session.history.append(HistoryEvent(at: now, text:
            "Started “\(planned.step.title)” at \(Scheduling.formatTime(now)) — \(planned.minutes) min timer."))
        save()

        // The authorization prompt suspends here. Revalidate everything after:
        // same run identity (no replacement of this step), still
        // cooking, same deadline. Otherwise drop the reminder silently.
        let myDeadline = rec.timerDeadline!
        let runID = rec.runID
        let actualStart = rec.actualStart
        let granted = await notifications.ensureAuthorization()
        notificationsDenied = notifications.denied
        guard granted,
              let current = session.records[id],
              current.runID == runID,
              current.actualStart == actualStart,
              current.state == .cooking,
              current.timerDeadline == myDeadline
        else { return .started }
        notifications.schedule(stepID: id, title: planned.step.title, deadline: myDeadline)
        return .started
    }

    /// Explicit user action: marks done NOW and records the actual end.
    /// A step that was never started needs explicit confirmation — the app
    /// records "start unknown" rather than fabricating an actual start.
    /// Dependents reposition automatically via the dependency-aware plan. The
    /// chosen dinner time is never changed here: timing drift is reported by
    /// the cooking screen through `readinessReport`, and moving dinner is a
    /// separate explicit action.
    func completeStep(_ id: String, confirmed: Bool = false, now: Date = Date()) async -> CompleteResult {
        guard let planned = plan.first(where: { $0.id == id }),
              record(id).state != .done
        else { return .noOp }
        let rec = record(id)
        if rec.actualStart == nil && !confirmed {
            return .needsStartConfirmation(title: planned.step.title)
        }
        pushUndo("Finished “\(planned.step.title)”")
        let oldPlan = plan
        var newRec = rec
        newRec.state = .done
        newRec.actualEnd = now
        // actualStart stays nil when unknown — never fabricated.
        session.records[id] = newRec
        notifications.cancel(stepID: id)

        let effects = Scheduling.completeStepEffects(
            session: session, menu: menu, stepID: id, now: now, oldPlan: oldPlan)
        let startNote = newRec.actualStart == nil ? " (start not recorded)" : ""
        session.history.append(HistoryEvent(at: now, text:
            "Finished “\(planned.step.title)” at \(Scheduling.formatTime(now))\(startNote)."))
        for shift in effects.affectedSteps {
            if let title = plan.first(where: { $0.id == shift.stepID })?.step.title {
                session.history.append(HistoryEvent(at: now, text:
                    "“\(title)” moved later — it waits on a late finish."))
            }
        }
        if effects.proposedServeAt != nil, let note = effects.explanation.last {
            // Recorded, not presented: the cooking screen shows live drift
            // inline, and nothing here touches `serveAt`.
            session.history.append(HistoryEvent(at: now, text: note))
        }
        save()
        return .completed
    }

    /// Explicit correction: returns the step to Not Started and clears its
    /// actuals and timer. Nothing restarts on its own.
    func correctStep(_ id: String) {
        guard let planned = plan.first(where: { $0.id == id }),
              record(id).state != .notStarted
        else { return }
        pushUndo("Reopened “\(planned.step.title)”")
        session.records[id] = StepRecord()
        notifications.cancel(stepID: id)
        session.history.append(HistoryEvent(text: "Reopened “\(planned.step.title)” — timer cleared."))
        save()
    }

    // MARK: Delay

    func proposeDelay(minutes: Int) -> DelayProposal {
        Scheduling.proposeDelay(session: session, menu: menu, minutes: minutes)
    }

    /// Applies a proposal the user has already reviewed and confirmed.
    func confirmDelay(_ proposal: DelayProposal) {
        pushUndo("Added \(proposal.minutes) min to dinner")
        session = Scheduling.applyDelay(session: session, proposal: proposal)
        // Running deadlines are untouched by construction; nothing to reschedule.
        save()
    }

    // MARK: Readiness (derived, never cached)

    /// Live timing drift for the cooking screen, or nil when unfinished work
    /// is estimated to finish within a minute of the chosen dinner time, or
    /// when every step is done. Pure and cheap; the UI recomputes it as time
    /// and state move.
    func readinessReport(now: Date = Date()) -> ReadinessReport? {
        Scheduling.readinessReport(menu: menu, session: session, now: now)
    }

    /// The proposal an explicit move would apply right now, built from the
    /// report's rounded-up minutes so the new dinner time is never before
    /// the estimate. The review sheet previews exactly this.
    func readinessMoveProposal(now: Date = Date()) -> DelayProposal? {
        guard let report = readinessReport(now: now) else { return nil }
        return Scheduling.proposeDelay(session: session, menu: menu, minutes: report.moveMinutes)
    }

    /// Explicit decision from the review sheet: moves the chosen dinner time
    /// by the drift measured at THIS instant, through the same reviewed delay
    /// path as "Adjust time". Applies once — the next report derives from
    /// the new time — is undoable, and never touches actual timestamps or
    /// timer deadlines. Returns the applied proposal, or nil when there was
    /// nothing to move (on schedule, or every step already done).
    @discardableResult
    func moveDinnerToEstimatedReadiness(now: Date = Date()) -> DelayProposal? {
        guard let report = readinessReport(now: now),
              let proposal = readinessMoveProposal(now: now)
        else { return nil }
        pushUndo("Moved dinner to \(Scheduling.formatTime(proposal.newServeAt))")
        session = Scheduling.applyDelay(session: session, proposal: proposal)
        session.history.append(HistoryEvent(at: now, text:
            "Matched dinner to the estimated readiness (\(Scheduling.formatTime(report.estimatedReadyAt)))."))
        save()
        return proposal
    }

    // MARK: Planning

    func setServeAt(_ date: Date) {
        guard !hasProgress else { return }
        pushUndo("Changed dinner time")
        session.serveAt = date
        session.history.append(HistoryEvent(text:
            "Set dinner time to \(Scheduling.formatTime(date))."))
        save()
    }

    func setDuration(stepID: String, minutes: Int) {
        // Match the planning UI: estimates are frozen once cooking starts.
        guard !hasProgress, let planned = plan.first(where: { $0.id == stepID }),
              record(stepID).state == .notStarted
        else { return }
        let confirmedMinutes = max(1, min(480, minutes))
        guard confirmedMinutes != planned.minutes else { return }
        pushUndo("Changed “\(planned.step.title)” estimate")
        session.durationOverrides[stepID] = confirmedMinutes
        session.history.append(HistoryEvent(text:
            "Set “\(planned.step.title)” estimate to \(session.durationOverrides[stepID]!) min."))
        save()
    }

    /// Changing menu starts a fresh session — and it IS undoable.
    func chooseMenu(_ id: String, now: Date = Date()) {
        pushUndo("Changed menu")
        var fresh = DinnerSession()
        fresh.menuID = id
        // An hour from now, unless the menu needs longer: then the earliest
        // time it can reach the table, on a 5-minute mark (Joe, build 8: a
        // 4-hour recipe started at "dinner in an hour" and couldn't be planned).
        fresh.serveAt = now.addingTimeInterval(3600)
        let menu = Self.resolve(id, provider: menuProvider) ?? .unchosen
        if case .startsInPast(let earliest) = Scheduling.checkFeasibility(menu: menu, serveAt: fresh.serveAt, durations: [:], now: now) {
            fresh.serveAt = Scheduling.roundUp(earliest, toMinutes: 5)
        }
        session = fresh
        notifications.cancelAll()
        save()
    }

    /// Tonight has no dinner (the recipe was deleted, or the cook cleared
    /// it). Undoable like any menu change.
    func clearDinner() { chooseMenu("") }

    /// A deleted recipe leaves tonight's dinner: the other dishes stay when
    /// it was a side; the main gone means no dinner (build 21).
    func dishDeleted(_ recipeID: UUID) {
        if let smaller = WholeMeal.removing(recipeID, from: session.menuID) { changeDishes(to: smaller) }
        else { clearDinner() }
    }

    /// Whether this recipe is one of tonight's dishes — alone, or in a
    /// whole meal (build 21).
    func isTonightsDish(_ recipeID: UUID) -> Bool {
        WholeMeal.recipeIDs(session.menuID)?.contains(recipeID) ?? false
    }

    /// Tonight's dinner with a dish added or taken away (Joe, build 21: a
    /// whole meal of up to four recipes, ready together). The dinner time
    /// stays — the cook set it — unless the bigger dinner can no longer
    /// reach it, when it moves to the earliest 5-minute mark it can. A fresh
    /// session otherwise, as choosing a menu is: the plan is new. Undoable.
    func changeDishes(to id: String, now: Date = Date()) {
        let serveAt = session.serveAt
        chooseMenu(id, now: now)
        guard serveAt > now else { return }
        let menu = Self.resolve(id, provider: menuProvider) ?? .unchosen
        if case .startsInPast(let earliest) = Scheduling.checkFeasibility(menu: menu, serveAt: serveAt, durations: [:], now: now) {
            session.serveAt = Scheduling.roundUp(earliest, toMinutes: 5)
        } else {
            session.serveAt = serveAt
        }
        save()
    }

    func resetSession() {
        pushUndo("Reset cooking progress")
        let menuID = session.menuID
        let serveAt = session.serveAt
        session = DinnerSession()
        session.menuID = menuID
        session.serveAt = serveAt
        notifications.cancelAll()
        save()
    }

    // MARK: Stale plans

    func staleStatus(now: Date = Date()) -> StaleStatus {
        // Nothing chosen: nothing can be stale.
        if !hasDinner { return .fresh }
        let calendar = Calendar.current
        let lastDay = calendar.startOfDay(for: session.lastOpenedAt)
        let today = calendar.startOfDay(for: now)
        if hasProgress {
            if lastDay < today || session.serveAt < now.addingTimeInterval(-3600) {
                return .stale
            }
        } else if lastDay < today && session.serveAt < now {
            // Picked yesterday, never started, serving time already passed.
            return .stale
        }
        return .fresh
    }

    /// Explicit resume-or-start-fresh choice for a stale plan.
    /// Interactive dismissal is disabled in the UI — this always runs.
    func resolveStale(resume: Bool) {
        if resume {
            if !hasProgress {
                // Keep the menu and estimates; re-anchor dinner to a fresh time.
                session.serveAt = Date().addingTimeInterval(3600)
            }
            session.lastOpenedAt = Date()
            session.history.append(HistoryEvent(text: "Resumed this plan."))
        } else {
            let menuID = session.menuID
            session = DinnerSession()
            session.menuID = menuID
            notifications.cancelAll()
        }
        undoStack = []
        needsStaleChoice = false
        resyncNotifications()
        save()
    }

    func refreshNotificationSettings() async {
        await notifications.refreshAuthorization()
        notificationsDenied = notifications.denied
        // Authorization has already been decided for restored running steps.
        if !notificationsDenied && !needsStaleChoice { resyncNotifications() }
    }

    // MARK: Notifications

    /// Rebuilds reminders from the current session (after undo). Each
    /// scheduled reminder revalidates the captured run identity, so stale
    /// tasks from an earlier resync can never restore obsolete reminders.
    private func resyncNotifications() {
        notifications.cancelAll()
        let now = Date()
        for step in menu.steps {
            guard let rec = session.records[step.id],
                  rec.state == .cooking,
                  let deadline = rec.timerDeadline,
                  deadline > now
            else { continue }
            Task {
                let granted = await self.notifications.ensureAuthorization()
                self.notificationsDenied = self.notifications.denied
                guard granted,
                      let current = self.session.records[step.id],
                      current.runID == rec.runID,
                      current.actualStart == rec.actualStart,
                      current.state == .cooking,
                      current.timerDeadline == deadline
                else { return }
                self.notifications.schedule(stepID: step.id, title: step.title, deadline: deadline)
            }
        }
    }
}
