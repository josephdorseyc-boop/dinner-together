import Foundation

// MARK: - Scheduling engine (pure logic: no UI, no persistence, no timers)
//
// Every function here is a pure function of its inputs, which is what makes
// the behavior testable. The rules the whole engine obeys:
//
//  1. Planned times are DERIVED from serving time, duration edits, and the
//     recorded actuals of finished/running steps. Nothing is stored per step.
//  2. DEPENDENCY-AWARE: within a dish, a step never plans to start before its
//     predecessor's expected completion (actual end if done, timer deadline
//     if cooking, planned end otherwise). This is structural — delays and
//     late completions cannot double-apply because there is no accumulated
//     offset to fight with a serving-time move.
//  3. Actuals are PINNED. Once a step is cooking, its actual start and timer
//     deadline never move implicitly. Delaying dinner moves the plan around
//     running steps; it never rewrites what the food is doing.
//  4. Planned vs. actual stay DISTINCT. Running steps keep their original
//     planned interval visible alongside what actually happened.

struct PlannedStep: Identifiable, Equatable {
    let step: CookingStep
    let minutes: Int
    /// Display interval. For cooking steps this is pinned to the actual start
    /// and timer deadline; otherwise it equals the planned interval.
    var start: Date
    var end: Date
    /// The plan's interval: backward-derived and dependency-aware. Never
    /// overwritten by actuals — compare with start/end to see drift.
    let plannedStart: Date
    let plannedEnd: Date
    var id: String { step.id }
}

enum Feasibility: Equatable {
    case ok
    /// The first step would have to start in the past.
    case startsInPast(earliestServeAt: Date)
}

struct PlannedShift: Equatable {
    let stepID: String
    let from: Date
    let to: Date
}

struct DelayProposal {
    let minutes: Int
    let newServeAt: Date
    /// Not-started steps that move, with before/after times for the explanation.
    let shifts: [PlannedShift]
    /// Running steps that will finish before the new dinner time.
    let earlyFinishNotes: [String]
    /// Human-readable lines shown BEFORE the user confirms.
    let explanation: [String]
}

struct CompletionEffects {
    /// Dependents whose planned start moved because of this completion
    /// (informational — the plan itself derives this; nothing is stored).
    let affectedSteps: [PlannedShift]
    /// Non-nil when the original serving time is no longer feasible.
    let proposedServeAt: Date?
    let explanation: [String]
}

/// One inspectable overlap between tasks requiring attention.
struct AttentionWarning: Equatable {
    let stepIDs: [String]
    let message: String
}

/// Why a step can't start yet.
struct BlockedInfo {
    let predecessorTitle: String
    /// When the predecessor is expected to finish.
    let readyAt: Date
}

/// One live reading of timing drift: the chosen dinner time next to the
/// estimated readiness of the unfinished work, as of a given instant.
/// Derived on demand and never stored, so it cannot describe an obsolete
/// session. The chosen dinner time is reported, never changed, here.
struct ReadinessReport: Equatable {
    /// The cook's chosen dinner time.
    let serveAt: Date
    /// Earliest the whole meal is estimated to be ready, as of `now`.
    /// An estimate for unfinished cooking, not a guarantee.
    let estimatedReadyAt: Date
    /// Whole minutes between the two, rounded to the nearest minute — for
    /// display ("about N min behind"). Always ≥ 1 for a report.
    let driftMinutes: Int
    /// Whole minutes rounded DOWN — the only figure a lower-bound headline
    /// ("At least N min behind") may claim, since the estimate supports no
    /// more. Always ≥ 1 for a report; ≤ `driftMinutes` ≤ `moveMinutes`.
    let lowerBoundMinutes: Int
    /// Whole minutes to add to `serveAt` so the new dinner time is never
    /// before `estimatedReadyAt` (rounded UP). This is what an explicit move
    /// applies; preview and apply share it. Always ≥ `driftMinutes`.
    let moveMinutes: Int
    /// True when an expired, still-cooking timer sits on the critical path:
    /// its deadline was floored at `now`, so the estimate is a lower bound
    /// ("no earlier than"), not a prediction.
    let estimateIsLowerBound: Bool
    /// The step whose expected end sets the estimate.
    let criticalStepID: String
    /// One short, derived sentence about what is holding things up.
    let reason: String
}

enum Scheduling {

    // MARK: Planning

    static func effectiveMinutes(_ step: CookingStep, durations: [String: Int]) -> Int {
        max(1, min(480, durations[step.id] ?? step.minutes))
    }

    /// Backward plan: each dish is a sequential chain ending at serving time.
    /// A step's planned start is the later of its backward-derived start and
    /// its predecessor's expected completion — so pending dependents can never
    /// be scheduled before the food ahead of them is done.
    static func plan(menu: DinnerMenu, session: DinnerSession) -> [PlannedStep] {
        let durations = session.durationOverrides
        var out: [PlannedStep] = []
        for dish in menu.dishes {
            let total = dish.reduce(0) { $0 + effectiveMinutes($1, durations: durations) }
            var cursor = session.serveAt.addingTimeInterval(-Double(total) * 60)
            var prevEnd: Date? = nil
            for step in dish {
                let m = effectiveMinutes(step, durations: durations)
                let baseStart = cursor
                cursor = cursor.addingTimeInterval(Double(m) * 60)
                let plannedStart = max(baseStart, prevEnd ?? baseStart)
                let plannedEnd = plannedStart.addingTimeInterval(Double(m) * 60)

                let rec = session.records[step.id]
                let dispStart: Date
                let dispEnd: Date
                let expectedEnd: Date
                switch rec?.state ?? .notStarted {
                case .cooking:
                    // Pinned to actuals; the planned interval stays visible separately.
                    dispStart = rec?.actualStart ?? plannedStart
                    dispEnd = rec?.timerDeadline
                        ?? dispStart.addingTimeInterval(Double(rec?.confirmedMinutes ?? m) * 60)
                    expectedEnd = rec?.timerDeadline ?? dispEnd
                case .done:
                    dispStart = plannedStart
                    dispEnd = plannedEnd
                    expectedEnd = rec?.actualEnd ?? plannedEnd
                case .notStarted:
                    dispStart = plannedStart
                    dispEnd = plannedEnd
                    expectedEnd = plannedEnd
                }
                // Running maximum: a step completed out of order (actual end
                // earlier than an unfinished predecessor's expected end) must
                // not pull later steps ahead of that predecessor. This keeps the
                // displayed plan consistent with `dependencyInfo`, which already
                // blocks the start. (Review r4, A2 product note; mirrors
                // `projectedEnds`.)
                prevEnd = max(prevEnd ?? expectedEnd, expectedEnd)
                out.append(PlannedStep(step: step, minutes: m,
                                      start: dispStart, end: dispEnd,
                                      plannedStart: plannedStart, plannedEnd: plannedEnd))
            }
        }
        return out.sorted { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }
    }

    /// Would this serving time require starting in the past?
    static func checkFeasibility(
        menu: DinnerMenu, serveAt: Date, durations: [String: Int], now: Date
    ) -> Feasibility {
        let longest = menu.dishes
            .map { $0.reduce(0) { $0 + effectiveMinutes($1, durations: durations) } }
            .max() ?? 0
        let firstStart = serveAt.addingTimeInterval(-Double(longest) * 60)
        if firstStart < now {
            return .startsInPast(earliestServeAt: now.addingTimeInterval(Double(longest) * 60))
        }
        return .ok
    }

    /// Dependency readiness is independent of the planned clock time. An early
    /// Start must use the same prerequisite checks as an overdue Start.
    static func dependencyInfo(
        plan: [PlannedStep], menu: DinnerMenu, session: DinnerSession, stepID: String
    ) -> BlockedInfo? {
        guard let dish = menu.dishes.first(where: { $0.contains(where: { $0.id == stepID }) }),
              let idx = dish.firstIndex(where: { $0.id == stepID }), idx > 0
        else { return nil }
        // Check every prerequisite: a forced start cannot make earlier work done.
        guard let pred = dish[..<idx].last(where: {
            (session.records[$0.id]?.state ?? .notStarted) != .done
        }) else { return nil }
        let rec = session.records[pred.id]
        let readyAt = rec?.timerDeadline
            ?? plan.first(where: { $0.id == pred.id })?.plannedEnd
            ?? session.serveAt
        return BlockedInfo(predecessorTitle: pred.title, readyAt: readyAt)
    }

    /// Cooking-screen urgency is separate from dependency readiness.
    static func blockedInfo(
        plan: [PlannedStep], menu: DinnerMenu, session: DinnerSession,
        stepID: String, now: Date
    ) -> BlockedInfo? {
        guard let step = plan.first(where: { $0.id == stepID }),
              now >= step.plannedStart else { return nil }
        return dependencyInfo(plan: plan, menu: menu, session: session, stepID: stepID)
    }

    /// Expected completion is actual for finished work, a fixed deadline for
    /// running work, and the derived end for pending work. Completed estimates
    /// cannot push dinner later after the food is actually ready.
    static func expectedMealEnd(menu: DinnerMenu, session: DinnerSession) -> Date {
        // Every step matters: completing a final step out of order must not
        // hide a still-running or pending prerequisite from meal readiness.
        return plan(menu: menu, session: session).map { p -> Date in
            let rec = session.records[p.id]
            switch rec?.state ?? .notStarted {
            case .done: return rec?.actualEnd ?? p.plannedEnd
            case .cooking: return rec?.timerDeadline ?? p.end
            case .notStarted: return p.plannedEnd
            }
        }.max() ?? session.serveAt
    }

    // MARK: Readiness as of now (recovery notice)

    /// Minimum drift before the cooking screen reports an estimate that
    /// differs from the chosen dinner time. Matches the feasibility margin in
    /// `completeStepEffects`. An initial UX choice, not a correctness rule.
    static let readinessNoticeThreshold: TimeInterval = 60

    /// Per-step projected ends as of `now`. This READS the derived plan and
    /// never rewrites it:
    ///  - done steps use their actual end;
    ///  - cooking steps use their pinned deadline, floored at `now` — an
    ///    expired timer means "check the food", not "finished";
    ///  - pending steps keep their derived planned start but cannot start
    ///    before `now` or before every earlier step in the dish is projected
    ///    to finish.
    /// The dependency carry is a running maximum over the dish, so a step
    /// completed out of order (its actual end earlier than an unfinished
    /// prerequisite's projection) cannot pull a later step forward — the
    /// same rule `startStep` applies when it checks every earlier
    /// prerequisite. A done step's own entry keeps its actual end.
    /// `expectedMealEnd` remains the plan-anchored readiness used by
    /// completion effects; this is the now-anchored estimate the cooking
    /// screen shows while work is late to start or still running.
    static func projectedEnds(menu: DinnerMenu, session: DinnerSession, now: Date) -> [String: Date] {
        let byID = Dictionary(uniqueKeysWithValues: plan(menu: menu, session: session).map { ($0.id, $0) })
        var ends: [String: Date] = [:]
        for dish in menu.dishes {
            var dependencyFloor: Date? = nil
            for step in dish {
                guard let p = byID[step.id] else { continue }
                let rec = session.records[step.id]
                let end: Date
                switch rec?.state ?? .notStarted {
                case .done:
                    end = rec?.actualEnd ?? p.plannedEnd
                case .cooking:
                    end = max(rec?.timerDeadline ?? p.end, now)
                case .notStarted:
                    let earliest = max(dependencyFloor ?? now, now)
                    let start = max(p.plannedStart, earliest)
                    end = start.addingTimeInterval(Double(p.minutes) * 60)
                }
                ends[step.id] = end
                dependencyFloor = max(dependencyFloor ?? end, end)
            }
        }
        return ends
    }

    /// Forward, now-aware estimate of when every step will be finished.
    static func projectedReadiness(menu: DinnerMenu, session: DinnerSession, now: Date) -> Date {
        projectedEnds(menu: menu, session: session, now: now).values.max() ?? session.serveAt
    }

    /// The live drift report for the cooking screen, or nil when the meal is
    /// estimated to be ready within `readinessNoticeThreshold` of the chosen
    /// dinner time, or when nothing is left to cook. Pure: callers recompute
    /// it whenever state or time moves.
    static func readinessReport(menu: DinnerMenu, session: DinnerSession, now: Date) -> ReadinessReport? {
        // A finished dinner has no unfinished work to report on, however late
        // it finished. Guarded here so every caller (screen, sheet, store)
        // shares the rule.
        guard menu.steps.contains(where: {
            (session.records[$0.id]?.state ?? .notStarted) != .done
        }) else { return nil }

        let ends = projectedEnds(menu: menu, session: session, now: now)
        func rank(_ id: String) -> Int {
            // Ties prefer the most actionable step: running, then pending, then done.
            switch session.records[id]?.state ?? .notStarted {
            case .cooking: return 2
            case .notStarted: return 1
            case .done: return 0
            }
        }
        guard let critical = ends.max(by: { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value < rhs.value }
            if rank(lhs.key) != rank(rhs.key) { return rank(lhs.key) < rank(rhs.key) }
            return lhs.key > rhs.key
        }) else { return nil }

        let readyAt = critical.value
        let drift = readyAt.timeIntervalSince(session.serveAt)
        guard drift >= readinessNoticeThreshold else { return nil }

        // Lower bound when an expired timer in the critical step's dish is
        // still cooking: its end is unknown, floored at `now`.
        let lowerBound: Bool = {
            guard let dish = menu.dishes.first(where: { $0.contains(where: { $0.id == critical.key }) })
            else { return false }
            return dish.contains { s in
                guard let r = session.records[s.id], r.state == .cooking else { return false }
                return (r.timerDeadline ?? now) <= now
            }
        }()

        let reason = holdUpReason(menu: menu, session: session, now: now,
                                  criticalStepID: critical.key, readyAt: readyAt)
        return ReadinessReport(serveAt: session.serveAt,
                               estimatedReadyAt: readyAt,
                               driftMinutes: max(1, Int((drift / 60).rounded())),
                               lowerBoundMinutes: max(1, Int((drift / 60).rounded(.down))),
                               moveMinutes: max(1, Int((drift / 60).rounded(.up))),
                               estimateIsLowerBound: lowerBound,
                               criticalStepID: critical.key,
                               reason: reason)
    }

    /// One sentence naming what sets the estimate. Derived from state only.
    private static func holdUpReason(
        menu: DinnerMenu, session: DinnerSession, now: Date,
        criticalStepID: String, readyAt: Date
    ) -> String {
        guard let dish = menu.dishes.first(where: { $0.contains(where: { $0.id == criticalStepID }) }),
              let step = dish.first(where: { $0.id == criticalStepID })
        else { return "Some steps are running later than planned." }
        let durations = session.durationOverrides
        let planByID = Dictionary(uniqueKeysWithValues: plan(menu: menu, session: session).map { ($0.id, $0) })
        let rec = session.records[step.id]

        switch rec?.state ?? .notStarted {
        case .done:
            return "“\(step.title)” finished at \(formatTime(readyAt))."
        case .cooking:
            let deadline = rec?.timerDeadline ?? readyAt
            if deadline <= now {
                // Expiry is not readiness: say what to do, not what to record.
                return "The “\(step.title)” timer ended at \(formatTime(deadline)) — check the food; mark this step done when it's ready."
            }
            return "The “\(step.title)” timer ends at \(formatTime(deadline))."
        case .notStarted:
            break
        }

        // The critical step is pending: explain the hold-up upstream of it.
        let pendingMinutes = dish
            .filter { (session.records[$0.id]?.state ?? .notStarted) == .notStarted }
            .reduce(0) { $0 + effectiveMinutes($1, durations: durations) }
        let remaining = "about \(pendingMinutes) min of \(step.dish) steps remain"
        guard let firstIndex = dish.firstIndex(where: {
            (session.records[$0.id]?.state ?? .notStarted) != .done
        }) else { return "About \(pendingMinutes) min of \(step.dish) steps remain." }
        let first = dish[firstIndex]
        let firstRec = session.records[first.id]

        switch firstRec?.state ?? .notStarted {
        case .cooking:
            let deadline = firstRec?.timerDeadline ?? now
            if deadline <= now {
                return "The “\(first.title)” timer ended at \(formatTime(deadline)) — check the food; mark that step done when it's ready. After it, \(remaining)."
            }
            return "The “\(first.title)” timer ends at \(formatTime(deadline)), then \(remaining)."
        case .notStarted:
            let plannedStart = planByID[first.id]?.plannedStart ?? now
            let lateBy = now.timeIntervalSince(plannedStart)
            if lateBy >= 60 {
                return "“\(first.title)” is \(Int(lateBy / 60)) min late to start, and \(remaining)."
            }
            // Not late to start: an earlier step's actual end pushed the chain.
            let lateFinish = dish[..<firstIndex].compactMap { s -> (step: CookingStep, minutes: Int)? in
                guard let r = session.records[s.id], r.state == .done, let end = r.actualEnd,
                      let p = planByID[s.id] else { return nil }
                let late = end.timeIntervalSince(p.plannedEnd)
                return late >= 60 ? (step: s, minutes: Int((late / 60).rounded())) : nil
            }.max { $0.minutes < $1.minutes }
            if let lateFinish = lateFinish {
                return "“\(lateFinish.step.title)” finished \(lateFinish.minutes) min late."
            }
            return "About \(pendingMinutes) min of \(step.dish) steps remain."
        case .done:
            return "About \(pendingMinutes) min of \(step.dish) steps remain."
        }
    }

    // MARK: Delay ("running late")

    /// Proposes a delay WITHOUT applying it. Completed history is untouched,
    /// running steps keep their actual start and timer deadline, and pending
    /// steps shift with the new serving time. Running steps that would finish
    /// before the revised dinner time are flagged — never silently extended.
    static func proposeDelay(
        session: DinnerSession, menu: DinnerMenu, minutes: Int
    ) -> DelayProposal {
        let newServeAt = session.serveAt.addingTimeInterval(Double(minutes) * 60)
        let current = plan(menu: menu, session: session)
        var movedSession = session
        movedSession.serveAt = newServeAt
        let moved = plan(menu: menu, session: movedSession)
        let movedByID = Dictionary(uniqueKeysWithValues: moved.map { ($0.id, $0) })

        var shifts: [PlannedShift] = []
        var earlyNotes: [String] = []
        var doneCount = 0
        var runningCount = 0

        for p in current {
            switch session.records[p.id]?.state ?? .notStarted {
            case .done:
                doneCount += 1
            case .cooking:
                runningCount += 1
                let deadline = session.records[p.id]?.timerDeadline ?? p.end
                // Finishing more than a minute before the new dinner time counts
                // as "too early". We flag it; we never invent a holding period.
                if deadline < newServeAt.addingTimeInterval(-60) {
                    let mins = Int(newServeAt.timeIntervalSince(deadline) / 60)
                    earlyNotes.append(
                        "The “\(p.step.title)” timer deadline is \(formatTime(deadline)) — about " +
                        "\(mins) min before the new dinner time. Check the food to confirm it's ready. " +
                        "We won't guess a safe holding time; check your recipe."
                    )
                }
            case .notStarted:
                if let np = movedByID[p.id], np.plannedStart != p.plannedStart {
                    shifts.append(PlannedShift(stepID: p.id, from: p.plannedStart, to: np.plannedStart))
                }
            }
        }

        var explanation: [String] = [
            "Dinner moves from \(formatTime(session.serveAt)) to \(formatTime(newServeAt)).",
            "\(shifts.count) upcoming step\(shifts.count == 1 ? "" : "s") change\(shifts.count == 1 ? "s" : "") time; dependency constraints may keep other steps in place.",
        ]
        for shift in shifts {
            if let p = current.first(where: { $0.id == shift.stepID }) {
                explanation.append("“\(p.step.title)”: \(formatTime(shift.from)) → \(formatTime(shift.to)).")
            }
        }
        if doneCount > 0 {
            explanation.append("\(doneCount) finished step\(doneCount == 1 ? "" : "s") keep\(doneCount == 1 ? "s" : "") recorded times.")
        }
        if runningCount > 0 {
            explanation.append(
                "\(runningCount) running timer\(runningCount == 1 ? "" : "s") keep\(runningCount == 1 ? "s" : "") " +
                "their deadlines — the food doesn't wait for the plan."
            )
        }

        return DelayProposal(
            minutes: minutes, newServeAt: newServeAt, shifts: shifts,
            earlyFinishNotes: earlyNotes, explanation: explanation
        )
    }

    /// Applies an already-explained proposal. Only the serving time changes;
    /// running steps, history, and dependents are preserved by construction —
    /// the dependency-aware plan recomputes everything from the new time.
    static func applyDelay(session: DinnerSession, proposal: DelayProposal) -> DinnerSession {
        var s = session
        s.serveAt = proposal.newServeAt
        s.history.append(HistoryEvent(text:
            "Added \(proposal.minutes) min — dinner moved to \(formatTime(proposal.newServeAt)). " +
            "\(proposal.shifts.count) upcoming steps shifted; running timers untouched."
        ))
        return s
    }

    // MARK: Late completion

    /// Call AFTER the store has recorded the step done at `now`.
    /// `oldPlan` is the plan from before the completion, used to describe what
    /// moved. No session mutation is needed here: the dependency-aware plan
    /// positions dependents from the recorded actual end on its own. If the
    /// dish can no longer finish by serving time, a new serving time is
    /// proposed — the caller must get explicit confirmation before applying it.
    static func completeStepEffects(
        session: DinnerSession, menu: DinnerMenu, stepID: String, now: Date,
        oldPlan: [PlannedStep]
    ) -> CompletionEffects {
        let newPlan = plan(menu: menu, session: session)
        let oldByID = Dictionary(uniqueKeysWithValues: oldPlan.map { ($0.id, $0) })
        let newByID = Dictionary(uniqueKeysWithValues: newPlan.map { ($0.id, $0) })
        guard let dish = menu.dishes.first(where: { $0.contains(where: { $0.id == stepID }) }),
              let idx = dish.firstIndex(where: { $0.id == stepID })
        else {
            return CompletionEffects(affectedSteps: [], proposedServeAt: nil, explanation: [])
        }

        var affected: [PlannedShift] = []
        if idx + 1 < dish.count {
            for later in dish[(idx + 1)...] {
                guard let o = oldByID[later.id], let n = newByID[later.id],
                      (session.records[later.id]?.state ?? .notStarted) == .notStarted,
                      n.plannedStart > o.plannedStart
                else { continue }
                affected.append(PlannedShift(stepID: later.id, from: o.plannedStart, to: n.plannedStart))
            }
        }

        var explanation: [String] = []
        let completedTitle = oldByID[stepID]?.step.title ?? "The step"
        if !affected.isEmpty {
            let mins = affected
                .map { Int(($0.to.timeIntervalSince($0.from) / 60).rounded()) }
                .max() ?? 0
            explanation.append(
                "“\(completedTitle)” finished late — \(affected.count) following step" +
                "\(affected.count == 1 ? "" : "s") moved about \(mins) min later."
            )
        }

        let effectiveEnd = max(expectedMealEnd(menu: menu, session: session), now)

        var proposed: Date? = nil
        if effectiveEnd > session.serveAt.addingTimeInterval(60) {
            proposed = effectiveEnd
            explanation.append(
                "The \(formatTime(session.serveAt)) serving time is no longer feasible — " +
                "the earliest this meal can finish is \(formatTime(effectiveEnd))."
            )
        }

        return CompletionEffects(affectedSteps: affected, proposedServeAt: proposed,
                                 explanation: explanation)
    }

    // MARK: Attention

    /// Hands-on steps whose windows overlap while still unfinished. Informative
    /// only — the app never claims to resolve equipment or attention conflicts.
    static func attentionWarnings(
        plan: [PlannedStep], session: DinnerSession, now: Date, limit: Int = 4
    ) -> [AttentionWarning] {
        let active = plan.filter {
            $0.step.handsOn
                && (session.records[$0.id]?.state ?? .notStarted) != .done
                && $0.end > now
        }
        var warnings: [AttentionWarning] = []
        for i in active.indices {
            for j in active.indices where j > i {
                let a = active[i], b = active[j]
                if a.start < b.end && b.start < a.end {
                    let overlapStart = max(a.start, b.start)
                    let overlapEnd = min(a.end, b.end)
                    warnings.append(AttentionWarning(
                        stepIDs: [a.id, b.id],
                        message: "“\(a.step.title)” and “\(b.step.title)” both need your hands " +
                            "around \(formatTime(overlapStart))–\(formatTime(overlapEnd)). " +
                            "One cook, two tasks — plan which goes first."
                    ))
                    if warnings.count >= limit { return warnings }
                }
            }
        }
        return warnings
    }

    // MARK: "What do I do right now?"

    /// Steps whose window has arrived and aren't done, hands-on first.
    /// Cooking steps are included (their timers may need checking); callers
    /// typically split them out. Blocked steps are NOT actionable — filter with
    /// `blockedInfo` where "do this now" must mean "can start now".
    static func doThisNow(plan: [PlannedStep], session: DinnerSession, now: Date) -> [PlannedStep] {
        plan.filter {
            (session.records[$0.id]?.state ?? .notStarted) != .done && $0.start <= now
        }.sorted {
            if $0.step.handsOn != $1.step.handsOn { return $0.step.handsOn }
            return $0.start < $1.start
        }
    }

    /// The next few not-started steps after now.
    static func upNext(
        plan: [PlannedStep], session: DinnerSession, now: Date, limit: Int = 3
    ) -> [PlannedStep] {
        plan.filter {
            (session.records[$0.id]?.state ?? .notStarted) == .notStarted && $0.start > now
        }
        .sorted { $0.start < $1.start }
        .prefix(limit)
        .map { $0 }
    }

    // MARK: Formatting

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    static func formatTime(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    static func formatRange(start: Date, end: Date) -> String {
        "\(formatTime(start)) – \(formatTime(end))"
    }

    /// "12:34" countdown, or "Overdue 02:10".
    static func formatCountdown(remaining: TimeInterval) -> String {
        if remaining < 0 {
            let o = Int(-remaining)
            return String(format: "Overdue %02d:%02d", o / 60, o % 60)
        }
        let r = Int(remaining)
        if r >= 3600 { return String(format: "%d:%02d:%02d", r / 3600, (r % 3600) / 60, r % 60) }
        return String(format: "%02d:%02d", r / 60, r % 60)
    }
}
