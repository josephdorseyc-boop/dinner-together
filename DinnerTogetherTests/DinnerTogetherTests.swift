import XCTest
@testable import DinnerTogether

// MARK: - Helpers

private let t0 = Date(timeIntervalSince1970: 1_760_000_000) // fixed reference instant

private func makeTestMenu() -> DinnerMenu {
    let dishA = [
        CookingStep(id: "a1", dish: "A", title: "Prep A", minutes: 10, detail: "", handsOn: true),
        CookingStep(id: "a2", dish: "A", title: "Cook A", minutes: 20, detail: "", handsOn: true),
        CookingStep(id: "a3", dish: "A", title: "Rest A", minutes: 10, detail: "", handsOn: false),
    ]
    let dishB = [
        CookingStep(id: "b1", dish: "B", title: "Prep B", minutes: 5, detail: "", handsOn: true),
        CookingStep(id: "b2", dish: "B", title: "Cook B", minutes: 15, detail: "", handsOn: false),
    ]
    return DinnerMenu(id: "test", title: "Test", subtitle: "", symbol: "flame",
                      dishes: [dishA, dishB])
}

private func sessionFor(menuID: String = "test", serveAt: Date) -> DinnerSession {
    var s = DinnerSession()
    s.menuID = menuID
    s.serveAt = serveAt
    return s
}

@MainActor
final class MockNotifications: NotificationService {
    var denied = false
    var grant = true
    var authDelay: TimeInterval = 0
    private(set) var scheduled: [(id: String, deadline: Date)] = []
    private(set) var cancelled: [String] = []
    var cancelAllCount = 0

    func ensureAuthorization() async -> Bool {
        if authDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(authDelay * 1_000_000_000))
        }
        denied = !grant
        return grant
    }

    func schedule(stepID: String, title: String, deadline: Date) {
        scheduled.append((stepID, deadline))
    }

    func cancel(stepID: String) { cancelled.append(stepID) }
    func cancelAll() { cancelAllCount += 1 }
}

// MARK: - Planning

final class PlanningTests: XCTestCase {

    func testBackwardPlanConverges() {
        let menu = makeTestMenu()
        let serveAt = t0.addingTimeInterval(3600)
        let plan = Scheduling.plan(menu: menu, session: sessionFor(serveAt: serveAt))
        XCTAssertEqual(plan.count, 5)
        for dish in menu.dishes {
            let chain = dish.map { step in plan.first(where: { $0.id == step.id })! }
            XCTAssertEqual(chain.last!.plannedEnd, serveAt)
            for i in 1..<chain.count {
                XCTAssertEqual(chain[i - 1].plannedEnd, chain[i].plannedStart)
            }
        }
    }

    func testPlanRespectsDurationOverrides() {
        let menu = makeTestMenu()
        var session = sessionFor(serveAt: t0.addingTimeInterval(3600))
        session.durationOverrides = ["a2": 30]
        let plan = Scheduling.plan(menu: menu, session: session)
        let cook = plan.first(where: { $0.id == "a2" })!
        XCTAssertEqual(cook.minutes, 30)
        XCTAssertEqual(cook.plannedEnd.timeIntervalSince(cook.plannedStart), 1800)
    }

    func testFeasibilityFlagsPastStart() {
        let menu = makeTestMenu() // longest dish: 40 min
        let now = t0
        let result = Scheduling.checkFeasibility(
            menu: menu, serveAt: now.addingTimeInterval(1800), durations: [:], now: now)
        guard case .startsInPast(let earliest) = result else {
            return XCTFail("expected startsInPast")
        }
        XCTAssertEqual(earliest, now.addingTimeInterval(2400))
        XCTAssertEqual(Scheduling.checkFeasibility(
            menu: menu, serveAt: now.addingTimeInterval(3600), durations: [:], now: now), .ok)
    }

    func testDateRollover() {
        let menu = makeTestMenu()
        let serveAt = t0.addingTimeInterval(20 * 60)
        let plan = Scheduling.plan(menu: menu, session: sessionFor(serveAt: serveAt))
        XCTAssertEqual(plan.count, 5)
        XCTAssertLessThan(plan.map(\.plannedStart).min()!, serveAt)
        let proposal = Scheduling.proposeDelay(
            session: sessionFor(serveAt: serveAt), menu: menu, minutes: 10)
        let applied = Scheduling.applyDelay(
            session: sessionFor(serveAt: serveAt), proposal: proposal)
        XCTAssertEqual(applied.serveAt, serveAt.addingTimeInterval(600))
    }

    /// Issue 3: a running predecessor's deadline pushes its dependent.
    /// Cook starts 6:40 with a 7:00 deadline; rest must plan at 7:00, not 6:50.
    func testRunningPredecessorPushesDependent() {
        let menu = makeTestMenu()
        let serveAt = t0 // 7:00
        var session = sessionFor(serveAt: serveAt)
        var cooking = StepRecord()
        cooking.state = .cooking
        cooking.actualStart = t0.addingTimeInterval(-20 * 60) // 6:40
        cooking.confirmedMinutes = 20
        cooking.timerDeadline = t0 // 7:00
        session.records["a2"] = cooking

        let plan = Scheduling.plan(menu: menu, session: session)
        let rest = plan.first(where: { $0.id == "a3" })!
        XCTAssertEqual(rest.plannedStart, t0,
                       "dependent rest must wait for the 7:00 deadline, not the 6:50 clock time")
        // …while the running step keeps its pinned display interval…
        let cook = plan.first(where: { $0.id == "a2" })!
        XCTAssertEqual(cook.start, t0.addingTimeInterval(-20 * 60))
        XCTAssertEqual(cook.end, t0)
        // …and its original planned interval stays visible separately.
        XCTAssertEqual(cook.plannedStart, t0.addingTimeInterval(-30 * 60))
    }

    /// "Due by the clock" is not "ready to start".
    func testBlockedInfo() {
        let menu = makeTestMenu()
        var session = sessionFor(serveAt: t0)
        var cooking = StepRecord()
        cooking.state = .cooking
        cooking.actualStart = t0.addingTimeInterval(-20 * 60)
        cooking.confirmedMinutes = 20
        cooking.timerDeadline = t0
        session.records["a2"] = cooking
        let plan = Scheduling.plan(menu: menu, session: session)

        // Before the dependent's planned start: upcoming, not blocked.
        XCTAssertNil(Scheduling.blockedInfo(
            plan: plan, menu: menu, session: session, stepID: "a3",
            now: t0.addingTimeInterval(-15 * 60)))
        // After it, with the predecessor still cooking: blocked, with a reason.
        let blocked = Scheduling.blockedInfo(
            plan: plan, menu: menu, session: session, stepID: "a3",
            now: t0.addingTimeInterval(5 * 60))
        XCTAssertNotNil(blocked)
        XCTAssertEqual(blocked?.predecessorTitle, "Cook A")
        XCTAssertEqual(blocked?.readyAt, t0)
        // First steps are never blocked.
        XCTAssertNil(Scheduling.blockedInfo(
            plan: plan, menu: menu, session: session, stepID: "a1",
            now: t0.addingTimeInterval(5 * 60)))
    }
}

// MARK: - Delay behavior

final class DelayTests: XCTestCase {

    /// The acceptance example: step starts 6:30 with a 20-min timer; at 6:35
    /// dinner is delayed 10 min. Actual start stays 6:30, deadline stays 6:50.
    func testDelayPreservesRunningStep() {
        let menu = makeTestMenu()
        let start630 = t0
        let serveAt = t0.addingTimeInterval(80 * 60)
        var session = sessionFor(serveAt: serveAt)

        var done = StepRecord(); done.state = .done
        done.actualStart = start630.addingTimeInterval(-20 * 60)
        done.actualEnd = start630.addingTimeInterval(-10 * 60)
        session.records["a1"] = done
        var cooking = StepRecord(); cooking.state = .cooking
        cooking.actualStart = start630
        cooking.confirmedMinutes = 20
        cooking.timerDeadline = start630.addingTimeInterval(20 * 60)
        session.records["a2"] = cooking

        let proposal = Scheduling.proposeDelay(session: session, menu: menu, minutes: 10)
        XCTAssertEqual(proposal.newServeAt, serveAt.addingTimeInterval(600))

        let applied = Scheduling.applyDelay(session: session, proposal: proposal)
        let rec = applied.records["a2"]!
        XCTAssertEqual(rec.actualStart, start630, "actual start must not move")
        XCTAssertEqual(rec.timerDeadline, start630.addingTimeInterval(20 * 60),
                       "timer deadline must not move")
        XCTAssertEqual(applied.records["a1"]?.actualEnd,
                       start630.addingTimeInterval(-10 * 60), "completed history preserved")

        let newPlan = Scheduling.plan(menu: menu, session: applied)
        let oldPlan = Scheduling.plan(menu: menu, session: session)
        let a3 = newPlan.first(where: { $0.id == "a3" })!
        let oldA3 = oldPlan.first(where: { $0.id == "a3" })!
        XCTAssertEqual(a3.plannedStart, oldA3.plannedStart.addingTimeInterval(600))
        XCTAssertFalse(proposal.earlyFinishNotes.isEmpty,
                       "6:50 finish vs. moved dinner must be flagged, not extended")
        XCTAssertFalse(proposal.explanation.isEmpty, "explanation precedes application")
        // Review r4 A2-2: a timer deadline is not food readiness.
        XCTAssertTrue(proposal.earlyFinishNotes.allSatisfy { $0.contains("timer deadline") && $0.contains("Check the food") })
        XCTAssertFalse(proposal.earlyFinishNotes.contains { $0.contains("will be ready") })
    }

    func testRepeatedDelaysAccumulate() {
        let menu = makeTestMenu()
        var session = sessionFor(serveAt: t0.addingTimeInterval(3600))
        var cooking = StepRecord(); cooking.state = .cooking
        cooking.actualStart = t0; cooking.confirmedMinutes = 20
        cooking.timerDeadline = t0.addingTimeInterval(1200)
        session.records["a2"] = cooking

        let oldPlan = Scheduling.plan(menu: menu, session: session)
        for minutes in [5, 10, 15] {
            let proposal = Scheduling.proposeDelay(session: session, menu: menu, minutes: minutes)
            session = Scheduling.applyDelay(session: session, proposal: proposal)
        }
        XCTAssertEqual(session.serveAt, t0.addingTimeInterval(3600 + 1800))
        XCTAssertEqual(session.records["a2"]?.timerDeadline, t0.addingTimeInterval(1200))
        let newPlan = Scheduling.plan(menu: menu, session: session)
        let oldA3 = oldPlan.first(where: { $0.id == "a3" })!
        let newA3 = newPlan.first(where: { $0.id == "a3" })!
        XCTAssertEqual(newA3.plannedStart, oldA3.plannedStart.addingTimeInterval(1800))
    }
}

// MARK: - Late completion (incl. the issue-2 regression)

final class LateCompletionTests: XCTestCase {

    func testLateCompletionMovesDependents() {
        let menu = makeTestMenu()
        var session = sessionFor(serveAt: t0.addingTimeInterval(3600))
        let oldPlan = Scheduling.plan(menu: menu, session: session)
        let a1End = oldPlan.first(where: { $0.id == "a1" })!.plannedEnd

        var done = StepRecord(); done.state = .done
        done.actualStart = a1End.addingTimeInterval(-600)
        done.actualEnd = a1End.addingTimeInterval(7 * 60) // 7 min late
        session.records["a1"] = done

        let effects = Scheduling.completeStepEffects(
            session: session, menu: menu, stepID: "a1",
            now: a1End.addingTimeInterval(7 * 60), oldPlan: oldPlan)
        XCTAssertEqual(effects.affectedSteps.count, 2)
        for shift in effects.affectedSteps {
            XCTAssertEqual(shift.to.timeIntervalSince(shift.from), 7 * 60, accuracy: 0.5)
        }
    }

    /// Full flow regression (issue 2): complete → proposal → accept must not
    /// apply the same delay twice. a3 must end at +67, not +74.
    func testCompletionProposalAcceptanceDoesNotDoubleApply() {
        let menu = makeTestMenu()
        let serveAt = t0.addingTimeInterval(3600) // +60
        var session = sessionFor(serveAt: serveAt)
        let oldPlan = Scheduling.plan(menu: menu, session: session)
        let a1End = oldPlan.first(where: { $0.id == "a1" })!.plannedEnd

        var done = StepRecord(); done.state = .done
        done.actualStart = a1End.addingTimeInterval(-600)
        done.actualEnd = a1End.addingTimeInterval(7 * 60)
        session.records["a1"] = done

        let effects = Scheduling.completeStepEffects(
            session: session, menu: menu, stepID: "a1",
            now: a1End.addingTimeInterval(7 * 60), oldPlan: oldPlan)
        XCTAssertNotNil(effects.proposedServeAt)
        XCTAssertEqual(effects.proposedServeAt!.timeIntervalSince(serveAt), 7 * 60, accuracy: 1)

        // Accept the proposal: serving time moves to +67.
        session.serveAt = effects.proposedServeAt!
        let finalPlan = Scheduling.plan(menu: menu, session: session)
        let a3End = finalPlan.first(where: { $0.id == "a3" })!.plannedEnd
        XCTAssertEqual(a3End.timeIntervalSince(serveAt), 7 * 60, accuracy: 1,
                       "a3 must end at +67 (single application), not +74 (double)")
        // Dependents stay consistent with the recorded actual end.
        let a2Start = finalPlan.first(where: { $0.id == "a2" })!.plannedStart
        XCTAssertEqual(a2Start, done.actualEnd!)
    }

    func testOnTimeCompletionChangesNothing() {
        let menu = makeTestMenu()
        var session = sessionFor(serveAt: t0.addingTimeInterval(3600))
        let oldPlan = Scheduling.plan(menu: menu, session: session)
        let a1End = oldPlan.first(where: { $0.id == "a1" })!.plannedEnd
        var done = StepRecord(); done.state = .done
        done.actualStart = a1End.addingTimeInterval(-600)
        done.actualEnd = a1End
        session.records["a1"] = done
        let effects = Scheduling.completeStepEffects(
            session: session, menu: menu, stepID: "a1", now: a1End, oldPlan: oldPlan)
        XCTAssertTrue(effects.affectedSteps.isEmpty)
        XCTAssertNil(effects.proposedServeAt)
    }
}

// MARK: - Attention

final class AttentionTests: XCTestCase {

    func testOverlappingHandsOnStepsWarn() {
        let menu = DinnerCatalog.menus[0] // steak night pileup
        let session = sessionFor(menuID: "steak", serveAt: t0.addingTimeInterval(3600))
        let plan = Scheduling.plan(menu: menu, session: session)
        let warnings = Scheduling.attentionWarnings(plan: plan, session: session, now: t0)
        XCTAssertFalse(warnings.isEmpty)
    }

    func testNoWarningWithoutOverlap() {
        let step = CookingStep(id: "x1", dish: "X", title: "Solo", minutes: 10,
                               detail: "", handsOn: true)
        let menu = DinnerMenu(id: "solo", title: "Solo", subtitle: "", symbol: "flame",
                              dishes: [[step]])
        let session = sessionFor(menuID: "solo", serveAt: t0.addingTimeInterval(3600))
        let plan = Scheduling.plan(menu: menu, session: session)
        XCTAssertTrue(Scheduling.attentionWarnings(plan: plan, session: session, now: t0).isEmpty)
    }

    func testDoThisNowHandsOnFirst() {
        let menu = makeTestMenu()
        let session = sessionFor(serveAt: t0.addingTimeInterval(3600))
        let plan = Scheduling.plan(menu: menu, session: session)
        let firstStart = plan.map(\.start).min()!
        let doing = Scheduling.doThisNow(plan: plan, session: session,
                                         now: firstStart.addingTimeInterval(60))
        XCTAssertFalse(doing.isEmpty)
        XCTAssertTrue(doing.first!.step.handsOn)
    }
}

// MARK: - Store: actions, undo, persistence, stale, notifications

@MainActor
final class StoreTests: XCTestCase {

    private func tempURL() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "dinnertogether-test-\(UUID().uuidString).json")
    }

    private func store(notifications: MockNotifications? = nil) -> (SessionStore, MockNotifications) {
        let mock = notifications ?? MockNotifications()
        return (SessionStore(fileURL: tempURL(), notifications: mock), mock)
    }

    func testUndoRestoresExactSession() async {
        let (store, _) = store()
        let id = DinnerCatalog.menus[0].steps[0].id
        let result = await store.startStep(id, now: t0)
        XCTAssertEqual(result, .started)
        XCTAssertEqual(store.record(id).state, .cooking)
        XCTAssertNotNil(store.record(id).timerDeadline)

        store.undoLast()
        XCTAssertEqual(store.record(id).state, .notStarted)
        XCTAssertNil(store.record(id).timerDeadline)
        XCTAssertNil(store.record(id).actualStart)
    }

    func testUndoRestoresDelay() async {
        let (store, _) = store()
        let before = store.session.serveAt
        let proposal = store.proposeDelay(minutes: 10)
        store.confirmDelay(proposal)
        XCTAssertEqual(store.session.serveAt, before.addingTimeInterval(600))
        store.undoLast()
        XCTAssertEqual(store.session.serveAt, before)
    }

    func testChooseMenuIsUndoable() async {
        let (store, _) = store()
        XCTAssertEqual(store.session.menuID, "steak")
        store.chooseMenu("pasta")
        XCTAssertEqual(store.session.menuID, "pasta")
        XCTAssertTrue(store.canUndo)
        store.undoLast()
        XCTAssertEqual(store.session.menuID, "steak")
    }

    func testStartBlockedWithoutForce() async {
        let (store, _) = store()
        // Push dinner into the past so the dependent is due by the clock
        // while its predecessor was never started.
        store.session.serveAt = Date().addingTimeInterval(-1800)
        let s2 = DinnerCatalog.menus[0].dishes[0][1].id // "Cook the steak"
        let blocked = await store.startStep(s2, now: Date())
        guard case .blocked(let predecessor, _) = blocked else {
            return XCTFail("expected .blocked, got \(blocked)")
        }
        XCTAssertEqual(predecessor, "Prep the steak & sauce ingredients")
        XCTAssertEqual(store.record(s2).state, .notStarted)

        // The explicit override path works.
        let forced = await store.startStep(s2, force: true, now: Date())
        XCTAssertEqual(forced, .started)
        XCTAssertEqual(store.record(s2).state, .cooking)
    }

    func testCompleteUnstartedNeedsConfirmationAndPreservesUnknown() async {
        let (store, _) = store()
        let id = DinnerCatalog.menus[0].steps[0].id
        let first = await store.completeStep(id, now: t0)
        guard case .needsStartConfirmation = first else {
            return XCTFail("expected .needsStartConfirmation, got \(first)")
        }
        XCTAssertEqual(store.record(id).state, .notStarted)

        let second = await store.completeStep(id, confirmed: true, now: t0)
        XCTAssertEqual(second, .completed)
        XCTAssertEqual(store.record(id).state, .done)
        XCTAssertEqual(store.record(id).actualEnd, t0)
        XCTAssertNil(store.record(id).actualStart, "never fabricate an actual start")
    }

    /// Issue-2 flow at the store level: complete late → live readiness report
    /// → explicit move → dependents end exactly once-late, not twice.
    /// (Recovery candidate: the cached proposal became a derived report; the
    /// single-application outcome this regression protects is unchanged.)
    func testStoreCompletionProposalAcceptanceFlow() async {
        let (store, _) = store()
        let serveAt = t0.addingTimeInterval(3600)
        store.session.serveAt = serveAt
        let steak = DinnerCatalog.menus[0]
        let s1 = steak.dishes[0][0].id, p1 = steak.dishes[1][0].id, p2 = steak.dishes[1][1].id
        // Keep the mash on schedule so the steak's late prep is the only drift:
        // p1 done on time, p2 cooking to its planned deadline.
        let p1Plan = store.plan.first(where: { $0.id == p1 })!
        _ = await store.startStep(p1, now: p1Plan.plannedStart)
        _ = await store.completeStep(p1, now: p1Plan.plannedEnd)
        _ = await store.startStep(p2, now: p1Plan.plannedEnd)

        let planned = store.plan.first(where: { $0.id == s1 })!
        _ = await store.startStep(s1, now: planned.plannedStart)
        let lateEnd = planned.plannedEnd.addingTimeInterval(7 * 60)
        let result = await store.completeStep(s1, now: lateEnd)
        XCTAssertEqual(result, .completed)

        guard let report = store.readinessReport(now: lateEnd) else {
            return XCTFail("expected a readiness report")
        }
        XCTAssertEqual(report.estimatedReadyAt.timeIntervalSince(serveAt), 7 * 60, accuracy: 1)
        XCTAssertEqual(report.driftMinutes, 7)
        XCTAssertEqual(store.session.serveAt, serveAt, "completion never moves dinner on its own")

        XCTAssertNotNil(store.moveDinnerToEstimatedReadiness(now: lateEnd))
        let s3 = steak.dishes[0][2].id
        let s3End = store.plan.first(where: { $0.id == s3 })!.plannedEnd
        XCTAssertEqual(s3End.timeIntervalSince(serveAt), 7 * 60, accuracy: 1)
        XCTAssertNil(store.readinessReport(now: lateEnd), "applied once: no residual drift")
    }

    func testPersistenceRoundTrip() async throws {
        let url = tempURL()
        let store = SessionStore(fileURL: url, notifications: MockNotifications())
        let id = DinnerCatalog.menus[0].steps[0].id
        var rec = StepRecord()
        rec.state = .done
        rec.actualStart = nil // unknown start persists as unknown
        rec.actualEnd = t0.addingTimeInterval(600)
        store.session.records[id] = rec
        store.session.durationOverrides = [id: 12]
        store.save()

        let loaded = try JSONDecoder().decode(DinnerSession.self, from: Data(contentsOf: url))
        XCTAssertEqual(loaded.records[id]?.state, .done)
        XCTAssertNil(loaded.records[id]?.actualStart)
        XCTAssertEqual(loaded.records[id]?.actualEnd, t0.addingTimeInterval(600))
        XCTAssertEqual(loaded.durationOverrides[id], 12)
    }

    func testStaleDetection() async {
        let (store, _) = store()
        XCTAssertEqual(store.staleStatus(now: t0), .fresh)
        var rec = StepRecord(); rec.state = .done; rec.actualEnd = t0
        store.session.records["s1"] = rec
        store.session.lastOpenedAt = t0.addingTimeInterval(-86400)
        XCTAssertEqual(store.staleStatus(now: t0), .stale)
        store.resolveStale(resume: false)
        XCTAssertTrue(store.session.records.isEmpty)
        XCTAssertEqual(store.staleStatus(now: t0), .fresh)
    }

    func testStaleNoProgressReanchors() async {
        let (store, _) = store()
        store.session.lastOpenedAt = t0.addingTimeInterval(-86400)
        store.session.serveAt = t0.addingTimeInterval(-3600) // yesterday's dinner time
        XCTAssertEqual(store.staleStatus(now: t0), .stale)

        store.resolveStale(resume: true)
        XCTAssertEqual(store.session.menuID, "steak", "menu is kept")
        XCTAssertTrue(store.session.serveAt > Date(), "dinner re-anchored to a fresh time")
        XCTAssertFalse(store.needsStaleChoice)
    }

    // MARK: Notification safety (issue 4)

    func testNoStaleReminderAfterUndoDuringPendingAuth() async {
        let mock = MockNotifications()
        mock.authDelay = 0.3
        let store = SessionStore(fileURL: tempURL(), notifications: mock)
        let id = DinnerCatalog.menus[0].steps[0].id

        let task = Task { await store.startStep(id, now: t0) }
        try? await Task.sleep(nanoseconds: 50_000_000) // let auth stay pending
        store.undoLast() // step is notStarted again before auth resolves
        let result = await task.value

        XCTAssertEqual(result, .started)
        XCTAssertTrue(mock.scheduled.isEmpty,
                      "no obsolete reminder after undo during pending authorization")
    }

    func testNoStaleReminderAfterResetDuringPendingAuth() async {
        let mock = MockNotifications()
        mock.authDelay = 0.3
        let store = SessionStore(fileURL: tempURL(), notifications: mock)
        let id = DinnerCatalog.menus[0].steps[0].id

        let task = Task { await store.startStep(id, now: t0) }
        try? await Task.sleep(nanoseconds: 50_000_000)
        store.resetSession()
        _ = await task.value

        XCTAssertTrue(mock.scheduled.isEmpty,
                      "no obsolete reminder after reset during pending authorization")
    }

    func testReminderScheduledWhenUndisturbed() async {
        let (store, mock) = store()
        let id = DinnerCatalog.menus[0].steps[0].id // 10-min step
        let result = await store.startStep(id, now: t0)
        XCTAssertEqual(result, .started)
        XCTAssertEqual(mock.scheduled.count, 1)
        XCTAssertEqual(mock.scheduled[0].id, id)
        XCTAssertEqual(mock.scheduled[0].deadline, t0.addingTimeInterval(600))
    }

    func testDeniedAuthorizationSchedulesNothing() async {
        let mock = MockNotifications()
        mock.grant = false
        let store = SessionStore(fileURL: tempURL(), notifications: mock)
        let id = DinnerCatalog.menus[0].steps[0].id
        _ = await store.startStep(id, now: t0)
        XCTAssertTrue(mock.scheduled.isEmpty)
        XCTAssertTrue(store.notificationsDenied)
        // …but the timer itself still runs in-app.
        XCTAssertEqual(store.record(id).state, .cooking)
        XCTAssertNotNil(store.record(id).timerDeadline)
    }
}

// MARK: - v0.2.2 review regressions (written; require Xcode to execute)
final class ReadinessRegressionTests: XCTestCase {
    func testFinalCompletionUsesActualEnd() {
        let menu = makeTestMenu()
        var s = sessionFor(serveAt: t0.addingTimeInterval(3600))
        var a1 = StepRecord(); a1.state = .done; a1.actualEnd = t0.addingTimeInterval(1800)
        var a2 = StepRecord(); a2.state = .done; a2.actualEnd = t0.addingTimeInterval(3600)
        s.records["a1"] = a1; s.records["a2"] = a2
        let old = Scheduling.plan(menu: menu, session: s)
        var a3 = StepRecord(); a3.state = .done
        a3.actualStart = t0.addingTimeInterval(3600)
        a3.actualEnd = t0.addingTimeInterval(3840)
        s.records["a3"] = a3
        let effects = Scheduling.completeStepEffects(session: s, menu: menu, stepID: "a3",
            now: a3.actualEnd!, oldPlan: old)
        XCTAssertEqual(effects.proposedServeAt, a3.actualEnd)
        var b2 = StepRecord(); b2.state = .cooking
        b2.actualStart = t0.addingTimeInterval(3000); b2.timerDeadline = t0.addingTimeInterval(4800)
        s.records["b2"] = b2
        XCTAssertEqual(Scheduling.expectedMealEnd(menu: menu, session: s), b2.timerDeadline)
    }

    func testUnchangedDependentIsNotClaimedAsShifted() {
        let menu = makeTestMenu()
        var s = sessionFor(serveAt: t0.addingTimeInterval(3600))
        var a2 = StepRecord(); a2.state = .cooking
        a2.actualStart = t0.addingTimeInterval(3000); a2.timerDeadline = t0.addingTimeInterval(4200)
        s.records["a2"] = a2
        let proposal = Scheduling.proposeDelay(session: s, menu: menu, minutes: 5)
        XCTAssertFalse(proposal.shifts.contains { $0.stepID == "a3" })
        XCTAssertTrue(proposal.shifts.allSatisfy { $0.from != $0.to })
    }

    func testCompletedMiddleStepDoesNotEraseEarlierPrerequisite() {
        let menu = makeTestMenu()
        var s = sessionFor(serveAt: t0.addingTimeInterval(3600))
        var a2 = StepRecord(); a2.state = .done; a2.actualEnd = t0.addingTimeInterval(3000)
        s.records["a2"] = a2
        let blocked = Scheduling.dependencyInfo(plan: Scheduling.plan(menu: menu, session: s),
            menu: menu, session: s, stepID: "a3")
        XCTAssertEqual(blocked?.predecessorTitle, "Prep A")
    }
}

@MainActor
final class ReminderAndEarlyStartRegressionTests: XCTestCase {
    private func makeStore(_ mock: MockNotifications) -> SessionStore {
        SessionStore(fileURL: URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "dinner-review-\(UUID().uuidString).json"), notifications: mock)
    }

    func testEarlyStartRequiresPrerequisiteConfirmation() async {
        let store = makeStore(MockNotifications())
        store.session.serveAt = t0.addingTimeInterval(7200)
        let id = store.menu.dishes[0][1].id
        let result = await store.startStep(id, now: t0)
        guard case .blocked = result else { return XCTFail("early start bypassed prerequisite") }
        XCTAssertEqual(store.record(id).state, .notStarted)
    }

    func testIndependentStartsKeepBothReminders() async {
        let mock = MockNotifications(); mock.authDelay = 0.1
        let store = makeStore(mock)
        let a = store.menu.dishes[0][0].id, b = store.menu.dishes[1][0].id
        let first = Task { await store.startStep(a, now: t0) }
        let second = Task { await store.startStep(b, now: t0) }
        _ = await first.value; _ = await second.value
        XCTAssertEqual(Set(mock.scheduled.map { $0.id }), Set([a, b]))
    }

    func testDelayDuringAuthorizationKeepsRunningReminder() async {
        let mock = MockNotifications(); mock.authDelay = 0.1
        let store = makeStore(mock)
        let id = store.menu.steps[0].id
        let task = Task { await store.startStep(id, now: t0) }
        try? await Task.sleep(nanoseconds: 20_000_000)
        let deadline = store.record(id).timerDeadline
        store.confirmDelay(store.proposeDelay(minutes: 10))
        _ = await task.value
        XCTAssertEqual(mock.scheduled.map { $0.id }, [id])
        XCTAssertEqual(store.record(id).timerDeadline, deadline)
    }

    func testActiveSessionCannotUseFullMenuServingTimeEdit() async {
        let store = makeStore(MockNotifications())
        _ = await store.startStep(store.menu.steps[0].id, now: t0)
        let before = store.session.serveAt
        store.setServeAt(before.addingTimeInterval(7200))
        XCTAssertEqual(store.session.serveAt, before)
    }
}

// MARK: - v0.2.5 edit and session transition regressions (Xcode execution pending)
@MainActor
final class PlanningEditRegressionTests: XCTestCase {
    private func makeStore() -> SessionStore {
        SessionStore(fileURL: URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "dinner-edit-\(UUID().uuidString).json"),
            notifications: MockNotifications())
    }

    func testUnchangedEstimateDoesNotCreateUndoOrHistory() async {
        let store = makeStore()
        let step = store.menu.steps[0]
        store.setDuration(stepID: step.id, minutes: step.minutes)
        XCTAssertTrue(store.undoStack.isEmpty)
        XCTAssertTrue(store.session.history.isEmpty)
        XCTAssertNil(store.session.durationOverrides[step.id])
    }

    func testSavedEstimateIsOneReversibleAction() async {
        let store = makeStore()
        let step = store.menu.steps[0]
        let before = store.plan.first { $0.id == step.id }!.minutes
        store.setDuration(stepID: step.id, minutes: before + 5)
        XCTAssertEqual(store.undoStack.count, 1)
        XCTAssertEqual(store.plan.first { $0.id == step.id }!.minutes, before + 5)
        store.undoLast()
        XCTAssertEqual(store.plan.first { $0.id == step.id }!.minutes, before)
    }

    /// Recovery candidate: drift is derived, so a session transition cannot
    /// leave an old estimate behind — the report follows the new session.
    func testResetAndMenuChangeClearOldServingProposal() async {
        let store = makeStore()
        let serveAt = t0.addingTimeInterval(3600)
        store.session.serveAt = serveAt
        let s1 = DinnerCatalog.menus[0].dishes[0][0].id
        let planned = store.plan.first(where: { $0.id == s1 })!
        _ = await store.startStep(s1, now: planned.plannedStart)
        let lateEnd = planned.plannedEnd.addingTimeInterval(7 * 60)
        _ = await store.completeStep(s1, now: lateEnd)
        XCTAssertNotNil(store.readinessReport(now: lateEnd))

        store.resetSession()
        // Fresh progress, same dinner time, evaluated before the first planned start.
        XCTAssertNil(store.readinessReport(now: planned.plannedStart))

        _ = await store.startStep(s1, now: planned.plannedStart)
        _ = await store.completeStep(s1, now: lateEnd)
        XCTAssertNotNil(store.readinessReport(now: lateEnd))
        store.chooseMenu(DinnerCatalog.menus[1].id)
        XCTAssertNil(store.readinessReport(now: Date()), "a new menu starts with no drift")
    }
}

final class OutOfOrderReadinessTests: XCTestCase {
    func testEarlyFinalCompletionDoesNotHideRunningMiddleStep() {
        let menu = makeTestMenu()
        var s = sessionFor(serveAt: t0.addingTimeInterval(3600))
        var first = StepRecord(); first.state = .done; first.actualEnd = t0.addingTimeInterval(1500)
        var middle = StepRecord(); middle.state = .cooking
        middle.actualStart = t0.addingTimeInterval(3300)
        middle.timerDeadline = t0.addingTimeInterval(4500)
        s.records["a1"] = first; s.records["a2"] = middle
        let oldPlan = Scheduling.plan(menu: menu, session: s)
        var last = StepRecord(); last.state = .done; last.actualEnd = t0.addingTimeInterval(3000)
        s.records["a3"] = last
        XCTAssertEqual(Scheduling.expectedMealEnd(menu: menu, session: s), middle.timerDeadline)
        let effects = Scheduling.completeStepEffects(session: s, menu: menu, stepID: "a3",
            now: last.actualEnd!, oldPlan: oldPlan)
        XCTAssertEqual(effects.proposedServeAt, middle.timerDeadline)
    }

    func testEarlyFinalCompletionDoesNotHidePendingMiddleStep() {
        let menu = makeTestMenu()
        var s = sessionFor(serveAt: t0.addingTimeInterval(3600))
        var first = StepRecord(); first.state = .done; first.actualEnd = t0.addingTimeInterval(1500)
        var last = StepRecord(); last.state = .done; last.actualEnd = t0.addingTimeInterval(3000)
        s.records["a1"] = first; s.records["a3"] = last
        s.durationOverrides["a2"] = 90
        XCTAssertGreaterThan(Scheduling.expectedMealEnd(menu: menu, session: s), s.serveAt)
    }
}

@MainActor
final class SessionPolicyRegressionTests: XCTestCase {
    private func makeStore() -> SessionStore {
        SessionStore(fileURL: URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "dinner-policy-\(UUID().uuidString).json"),
            notifications: MockNotifications())
    }

    func testDurationEditIsRejectedDuringCooking() async {
        let store = makeStore()
        _ = await store.startStep(store.menu.dishes[0][0].id, now: t0)
        let pendingID = store.menu.dishes[1][0].id
        let before = store.plan.first { $0.id == pendingID }!.minutes
        let undoCount = store.undoStack.count
        store.setDuration(stepID: pendingID, minutes: before + 5)
        XCTAssertEqual(store.plan.first { $0.id == pendingID }!.minutes, before)
        XCTAssertEqual(store.undoStack.count, undoCount)
    }

    /// Recovery candidate: stale resolution leaves nothing cached. "Start
    /// fresh" has no drift; "keep menu, fresh time" re-anchors dinner so the
    /// derived report is clear; resuming WITH progress keeps the old dinner
    /// time, so any drift it reports is real and current, not remembered.
    func testStaleResolutionClearsOldServingProposal() async {
        // Yesterday's plan, never started, dinner time long past.
        let fresh = makeStore()
        fresh.needsStaleChoice = true
        fresh.session.serveAt = Date().addingTimeInterval(-7200)
        XCTAssertNotNil(fresh.readinessReport(now: Date()), "past dinner with pending work is behind")
        fresh.resolveStale(resume: true)
        XCTAssertNil(fresh.readinessReport(now: Date()), "re-anchored dinner has no drift")
        XCTAssertFalse(fresh.needsStaleChoice)

        let discard = makeStore()
        discard.needsStaleChoice = true
        var rec = StepRecord(); rec.state = .done; rec.actualEnd = Date().addingTimeInterval(-3600)
        discard.session.records[discard.menu.steps[0].id] = rec
        discard.session.serveAt = Date().addingTimeInterval(-7200)
        discard.resolveStale(resume: false)
        XCTAssertTrue(discard.session.records.isEmpty)
        XCTAssertNil(discard.readinessReport(now: discard.session.serveAt.addingTimeInterval(-3600)),
                     "fresh session evaluated before its first start reports nothing")
        XCTAssertFalse(discard.needsStaleChoice)
    }
}

// MARK: - Recovery candidate: derived readiness notice (written on Linux; NOT executed)
//
// These cover AGENT_PROMPT §6 scenarios 2–8 for routine lateness. They use
// the pure `Scheduling.projectedReadiness` / `readinessReport` functions and
// the store's `moveDinnerToEstimatedReadiness`. Nothing here asserts source
// structure; every assertion is an observable outcome.

final class RecoveryNoticeTests: XCTestCase {

    /// On schedule: no report, including at the exact first planned start.
    func testOnTimePlanReportsNothing() {
        let menu = makeTestMenu()
        let serveAt = t0.addingTimeInterval(3600)
        let session = sessionFor(serveAt: serveAt)
        let firstStart = Scheduling.plan(menu: menu, session: session).map(\.plannedStart).min()!
        XCTAssertNil(Scheduling.readinessReport(menu: menu, session: session, now: t0))
        XCTAssertNil(Scheduling.readinessReport(menu: menu, session: session, now: firstStart))
        XCTAssertEqual(Scheduling.projectedReadiness(menu: menu, session: session, now: firstStart), serveAt)
    }

    /// Scenario 2: a small late completion shows drift and names the cause,
    /// while the chosen dinner time is untouched and the plan-anchored
    /// readiness invariant is unchanged.
    func testLateCompletionReportsDriftWithoutMovingDinner() {
        let menu = makeTestMenu()
        let serveAt = t0.addingTimeInterval(3600)            // +60
        var session = sessionFor(serveAt: serveAt)
        var done = StepRecord(); done.state = .done
        done.actualStart = t0.addingTimeInterval(20 * 60)
        done.actualEnd = t0.addingTimeInterval(37 * 60)       // planned end +30 → 7 late
        session.records["a1"] = done
        let now = done.actualEnd!

        let report = Scheduling.readinessReport(menu: menu, session: session, now: now)
        XCTAssertNotNil(report)
        XCTAssertEqual(report?.serveAt, serveAt)
        XCTAssertEqual(report?.estimatedReadyAt, serveAt.addingTimeInterval(7 * 60))
        XCTAssertEqual(report?.driftMinutes, 7)
        XCTAssertEqual(report?.moveMinutes, 7)
        XCTAssertEqual(report?.estimateIsLowerBound, false)
        XCTAssertEqual(report?.criticalStepID, "a3")
        XCTAssertTrue(report?.reason.contains("Prep A") == true, "reason names the late finish")
        XCTAssertEqual(session.serveAt, serveAt)
        XCTAssertEqual(Scheduling.expectedMealEnd(menu: menu, session: session),
                       serveAt.addingTimeInterval(7 * 60), "plan-anchored readiness unchanged")
    }

    /// Work nobody has started cannot be "ready on time" once its planned
    /// start has passed: the estimate moves with the clock, the plan does not.
    func testPendingWorkLateToStartProjectsForward() {
        let menu = makeTestMenu()
        let serveAt = t0.addingTimeInterval(3600)
        let session = sessionFor(serveAt: serveAt)
        let firstStart = Scheduling.plan(menu: menu, session: session)
            .first(where: { $0.id == "a1" })!.plannedStart             // +20
        let now = firstStart.addingTimeInterval(8 * 60)                 // 8 min late, nothing started

        XCTAssertEqual(Scheduling.projectedReadiness(menu: menu, session: session, now: now),
                       serveAt.addingTimeInterval(8 * 60))
        let report = Scheduling.readinessReport(menu: menu, session: session, now: now)
        XCTAssertEqual(report?.driftMinutes, 8)
        XCTAssertEqual(report?.criticalStepID, "a3")
        XCTAssertTrue(report?.reason.contains("late to start") == true)
        // The derived plan itself does not creep: planned starts are unchanged.
        XCTAssertEqual(Scheduling.plan(menu: menu, session: session)
            .first(where: { $0.id == "a1" })!.plannedStart, firstStart)
        XCTAssertEqual(Scheduling.expectedMealEnd(menu: menu, session: session), serveAt)
    }

    /// A running timer's pinned deadline flows into the estimate for its
    /// dependents; the reason names the timer.
    func testRunningDeadlinePushesEstimate() {
        let menu = makeTestMenu()
        let serveAt = t0.addingTimeInterval(3600)
        var session = sessionFor(serveAt: serveAt)
        var cooking = StepRecord(); cooking.state = .cooking
        cooking.actualStart = t0.addingTimeInterval(40 * 60)
        cooking.confirmedMinutes = 20
        cooking.timerDeadline = t0.addingTimeInterval(60 * 60)        // ends AT dinner time
        session.records["a2"] = cooking
        var done = StepRecord(); done.state = .done; done.actualEnd = t0.addingTimeInterval(40 * 60)
        session.records["a1"] = done

        let report = Scheduling.readinessReport(menu: menu, session: session, now: t0.addingTimeInterval(45 * 60))
        XCTAssertEqual(report?.estimatedReadyAt, serveAt.addingTimeInterval(10 * 60))
        XCTAssertEqual(report?.driftMinutes, 10)
        XCTAssertEqual(report?.criticalStepID, "a3")
        XCTAssertTrue(report?.reason.contains("Cook A") == true)
        XCTAssertTrue(report?.reason.contains("ends at") == true)
    }

    /// Scenario 7: an expired timer keeps the step Cooking with no actual
    /// end. The estimate floors at "now" and the reason says to check.
    func testExpiredTimerStaysCookingAndFloorsAtNow() {
        let menu = makeTestMenu()
        let deadline = t0
        let serveAt = t0.addingTimeInterval(10 * 60)                    // rest a3 planned t0..+10
        var session = sessionFor(serveAt: serveAt)
        var done = StepRecord(); done.state = .done; done.actualEnd = t0.addingTimeInterval(-20 * 60)
        session.records["a1"] = done
        var cooking = StepRecord(); cooking.state = .cooking
        cooking.actualStart = t0.addingTimeInterval(-20 * 60)
        cooking.confirmedMinutes = 20
        cooking.timerDeadline = deadline
        session.records["a2"] = cooking
        var b1 = StepRecord(); b1.state = .done; b1.actualEnd = t0.addingTimeInterval(-10 * 60)
        var b2 = StepRecord(); b2.state = .done; b2.actualEnd = t0
        session.records["b1"] = b1; session.records["b2"] = b2

        let now = deadline.addingTimeInterval(5 * 60)
        XCTAssertEqual(session.records["a2"]?.state, .cooking)
        XCTAssertNil(session.records["a2"]?.actualEnd, "no fabricated actual end")
        XCTAssertEqual(session.records["a2"]?.timerDeadline, deadline, "deadline stays pinned")
        XCTAssertEqual(Scheduling.projectedReadiness(menu: menu, session: session, now: now),
                       now.addingTimeInterval(10 * 60), "rest can start no earlier than now")
        let report = Scheduling.readinessReport(menu: menu, session: session, now: now)
        XCTAssertEqual(report?.driftMinutes, 5)
        XCTAssertEqual(report?.estimateIsLowerBound, true, "floored at now: a lower bound, not a prediction")
        XCTAssertTrue(report?.reason.contains("timer ended") == true)
        XCTAssertTrue(report?.reason.contains("check the food") == true)
        XCTAssertFalse(report?.reason.contains("mark it done") == true, "expiry must not imply readiness")
    }

    /// Review r4 A2-1: a lower-bound headline may only claim the whole minutes
    /// the estimate supports. 5 m 40 s behind → "At least 5", "about 6", move 6.
    func testLowerBoundMinutesRoundDown() {
        let menu = makeTestMenu()
        let serveAt = t0.addingTimeInterval(10 * 60)
        var session = sessionFor(serveAt: serveAt)
        var done = StepRecord(); done.state = .done; done.actualEnd = t0.addingTimeInterval(-20 * 60)
        session.records["a1"] = done
        var cooking = StepRecord(); cooking.state = .cooking
        cooking.actualStart = t0.addingTimeInterval(-20 * 60); cooking.confirmedMinutes = 20; cooking.timerDeadline = t0
        session.records["a2"] = cooking
        var b1 = StepRecord(); b1.state = .done; b1.actualEnd = t0.addingTimeInterval(-10 * 60)
        var b2 = StepRecord(); b2.state = .done; b2.actualEnd = t0
        session.records["b1"] = b1; session.records["b2"] = b2

        let now = t0.addingTimeInterval(5 * 60 + 40)                      // drift = 340 s
        let report = Scheduling.readinessReport(menu: menu, session: session, now: now)
        XCTAssertEqual(report?.estimateIsLowerBound, true)
        XCTAssertEqual(report?.estimatedReadyAt, now.addingTimeInterval(10 * 60))
        XCTAssertEqual(report?.lowerBoundMinutes, 5, "floor: the only figure 'at least' may claim")
        XCTAssertEqual(report?.driftMinutes, 6, "nearest, for 'about'")
        XCTAssertEqual(report?.moveMinutes, 6, "up, for the move")
    }

    /// Scenario 5: a final step confirmed done early while a middle step is
    /// still cooking beyond dinner time. The running step sets the estimate.
    func testEarlyFinalCompletionStillCountsRunningMiddleStep() {
        let menu = makeTestMenu()
        let serveAt = t0.addingTimeInterval(3600)
        var s = sessionFor(serveAt: serveAt)
        var first = StepRecord(); first.state = .done; first.actualEnd = t0.addingTimeInterval(1500)
        var middle = StepRecord(); middle.state = .cooking
        middle.actualStart = t0.addingTimeInterval(3300)
        middle.timerDeadline = t0.addingTimeInterval(4500)             // +75
        var last = StepRecord(); last.state = .done; last.actualEnd = t0.addingTimeInterval(3000)
        s.records["a1"] = first; s.records["a2"] = middle; s.records["a3"] = last
        var b1 = StepRecord(); b1.state = .done; b1.actualEnd = t0.addingTimeInterval(2700)
        var b2 = StepRecord(); b2.state = .done; b2.actualEnd = t0.addingTimeInterval(3600)
        s.records["b1"] = b1; s.records["b2"] = b2

        let report = Scheduling.readinessReport(menu: menu, session: s, now: t0.addingTimeInterval(3400))
        XCTAssertEqual(report?.estimatedReadyAt, middle.timerDeadline)
        XCTAssertEqual(report?.criticalStepID, "a2")
        XCTAssertEqual(report?.driftMinutes, 15)
    }

    /// Scenario 6: a final step done early while a prerequisite is pending.
    /// The pending work still sets the estimate.
    func testEarlyFinalCompletionStillCountsPendingPrerequisite() {
        let menu = makeTestMenu()
        let serveAt = t0.addingTimeInterval(3600)
        var s = sessionFor(serveAt: serveAt)
        var first = StepRecord(); first.state = .done; first.actualEnd = t0.addingTimeInterval(1500)
        var last = StepRecord(); last.state = .done; last.actualEnd = t0.addingTimeInterval(3000)
        s.records["a1"] = first; s.records["a3"] = last
        s.durationOverrides["a2"] = 90

        let now = t0.addingTimeInterval(3000)
        let report = Scheduling.readinessReport(menu: menu, session: s, now: now)
        XCTAssertNotNil(report)
        XCTAssertEqual(report?.criticalStepID, "a2")
        XCTAssertGreaterThanOrEqual(report?.estimatedReadyAt ?? .distantPast, now.addingTimeInterval(90 * 60))
    }

    /// Review finding 2: a finished dinner has no unfinished work to report,
    /// however late it finished. The guard lives in the pure function so the
    /// screen, the sheet, and the store cannot disagree.
    func testFinishedDinnerReportsNothingEvenIfLate() {
        let menu = makeTestMenu()
        let serveAt = t0.addingTimeInterval(3600)
        var s = sessionFor(serveAt: serveAt)
        for id in ["a1", "a2", "b1"] {
            var r = StepRecord(); r.state = .done; r.actualEnd = t0.addingTimeInterval(3000)
            s.records[id] = r
        }
        var b2 = StepRecord(); b2.state = .done; b2.actualEnd = serveAt
        s.records["b2"] = b2
        var a3 = StepRecord(); a3.state = .done; a3.actualEnd = serveAt.addingTimeInterval(6 * 60)
        s.records["a3"] = a3
        let now = serveAt.addingTimeInterval(6 * 60)
        XCTAssertEqual(Scheduling.projectedReadiness(menu: menu, session: s, now: now),
                       a3.actualEnd, "history is still honest about when it finished")
        XCTAssertNil(Scheduling.readinessReport(menu: menu, session: s, now: now))
    }

    /// Review finding 1: a step completed out of order must not pull a later
    /// step ahead of an earlier, still-unfinished prerequisite. a1 pending,
    /// a2 done at +40, a3 pending, now +55: a1 can't end before +65, so a3
    /// can't end before +75 — not +65.
    func testOutOfOrderCompletionKeepsDependencyCarry() {
        let menu = makeTestMenu()
        let serveAt = t0.addingTimeInterval(3600)
        var s = sessionFor(serveAt: serveAt)
        var a2 = StepRecord(); a2.state = .done
        a2.actualStart = t0.addingTimeInterval(20 * 60); a2.actualEnd = t0.addingTimeInterval(40 * 60)
        s.records["a2"] = a2
        var b1 = StepRecord(); b1.state = .done; b1.actualEnd = t0.addingTimeInterval(45 * 60)
        var b2 = StepRecord(); b2.state = .cooking
        b2.actualStart = t0.addingTimeInterval(45 * 60); b2.timerDeadline = t0.addingTimeInterval(60 * 60)
        s.records["b1"] = b1; s.records["b2"] = b2
        let now = t0.addingTimeInterval(55 * 60)

        let ends = Scheduling.projectedEnds(menu: menu, session: s, now: now)
        XCTAssertEqual(ends["a1"], t0.addingTimeInterval(65 * 60), "late to start: now + 10")
        XCTAssertEqual(ends["a2"], a2.actualEnd, "a done step keeps its own actual end")
        XCTAssertEqual(ends["a3"], t0.addingTimeInterval(75 * 60), "waits for a1, not for a2's earlier end")
        XCTAssertEqual(Scheduling.projectedReadiness(menu: menu, session: s, now: now),
                       t0.addingTimeInterval(75 * 60))
        let report = Scheduling.readinessReport(menu: menu, session: s, now: now)
        XCTAssertEqual(report?.criticalStepID, "a3")
        XCTAssertEqual(report?.driftMinutes, 15)
        // Consistent with start eligibility: a3 is still blocked by a1.
        XCTAssertEqual(Scheduling.dependencyInfo(plan: Scheduling.plan(menu: menu, session: s),
                                                 menu: menu, session: s, stepID: "a3")?.predecessorTitle, "Prep A")
    }

    /// Review finding 1, running variant: a1 running late to +62, a2 done
    /// early at +40, a3 pending. a3 ends no earlier than +62 + 10.
    func testRunningFirstStepCarriesPastCompletedMiddleStep() {
        let menu = makeTestMenu()
        let serveAt = t0.addingTimeInterval(3600)
        var s = sessionFor(serveAt: serveAt)
        var a1 = StepRecord(); a1.state = .cooking
        a1.actualStart = t0.addingTimeInterval(52 * 60); a1.timerDeadline = t0.addingTimeInterval(62 * 60)
        var a2 = StepRecord(); a2.state = .done
        a2.actualStart = t0.addingTimeInterval(20 * 60); a2.actualEnd = t0.addingTimeInterval(40 * 60)
        s.records["a1"] = a1; s.records["a2"] = a2
        var b1 = StepRecord(); b1.state = .done; b1.actualEnd = t0.addingTimeInterval(45 * 60)
        var b2 = StepRecord(); b2.state = .done; b2.actualEnd = t0.addingTimeInterval(60 * 60)
        s.records["b1"] = b1; s.records["b2"] = b2
        let now = t0.addingTimeInterval(55 * 60)

        let ends = Scheduling.projectedEnds(menu: menu, session: s, now: now)
        XCTAssertEqual(ends["a1"], a1.timerDeadline)
        XCTAssertEqual(ends["a2"], a2.actualEnd)
        XCTAssertEqual(ends["a3"], t0.addingTimeInterval(72 * 60))
        XCTAssertGreaterThanOrEqual(ends["a3"] ?? .distantPast, a1.timerDeadline!.addingTimeInterval(10 * 60))
    }

    /// Review r4 (A2 product note): the displayed plan must agree with the
    /// dependency gate. a1 running to +62, a2 done out of order at +40, a3
    /// pending → a3 is planned from +62 (where `dependencyInfo` says it can
    /// start), not from +50.
    func testPlanCarriesRunningPredecessorPastOutOfOrderCompletion() {
        let menu = makeTestMenu()
        let serveAt = t0.addingTimeInterval(3600)
        var s = sessionFor(serveAt: serveAt)
        var a1 = StepRecord(); a1.state = .cooking
        a1.actualStart = t0.addingTimeInterval(52 * 60); a1.timerDeadline = t0.addingTimeInterval(62 * 60)
        var a2 = StepRecord(); a2.state = .done
        a2.actualStart = t0.addingTimeInterval(20 * 60); a2.actualEnd = t0.addingTimeInterval(40 * 60)
        s.records["a1"] = a1; s.records["a2"] = a2

        let plan = Scheduling.plan(menu: menu, session: s)
        let a3 = plan.first(where: { $0.id == "a3" })!
        XCTAssertEqual(a3.plannedStart, t0.addingTimeInterval(62 * 60))
        XCTAssertEqual(a3.plannedEnd, t0.addingTimeInterval(72 * 60))
        let blocked = Scheduling.dependencyInfo(plan: plan, menu: menu, session: s, stepID: "a3")
        XCTAssertEqual(blocked?.predecessorTitle, "Prep A")
        XCTAssertEqual(blocked?.readyAt, a3.plannedStart, "plan and dependency gate agree")
        // In-order chains are unaffected: a done step's early actual end still
        // lets its dependent keep the backward-derived start.
        var inOrder = sessionFor(serveAt: serveAt)
        var early = StepRecord(); early.state = .done; early.actualEnd = t0.addingTimeInterval(25 * 60)
        inOrder.records["a1"] = early
        XCTAssertEqual(Scheduling.plan(menu: menu, session: inOrder).first(where: { $0.id == "a2" })!.plannedStart,
                       t0.addingTimeInterval(30 * 60))
    }

    /// Review finding 4: the explicit move rounds UP, so the new dinner time
    /// is never before the estimate; the headline still rounds to nearest.
    func testMoveMinutesRoundUpWhileDriftDisplaysNearest() {
        let menu = makeTestMenu()
        let serveAt = t0.addingTimeInterval(3600)
        var session = sessionFor(serveAt: serveAt)
        var done = StepRecord(); done.state = .done
        done.actualStart = t0.addingTimeInterval(20 * 60)
        done.actualEnd = t0.addingTimeInterval(37 * 60 + 20)            // 7 m 20 s late
        session.records["a1"] = done
        let report = Scheduling.readinessReport(menu: menu, session: session, now: done.actualEnd!)
        XCTAssertEqual(report?.estimatedReadyAt, serveAt.addingTimeInterval(7 * 60 + 20))
        XCTAssertEqual(report?.driftMinutes, 7, "display: nearest minute")
        XCTAssertEqual(report?.moveMinutes, 8, "move: rounded up")
        XCTAssertGreaterThanOrEqual(serveAt.addingTimeInterval(Double(report?.moveMinutes ?? 0) * 60),
                                    report?.estimatedReadyAt ?? .distantFuture)
        // Exact whole minutes don't over-shoot.
        var exact = session
        exact.records["a1"]?.actualEnd = t0.addingTimeInterval(37 * 60)
        let exactReport = Scheduling.readinessReport(menu: menu, session: exact, now: t0.addingTimeInterval(37 * 60))
        XCTAssertEqual(exactReport?.moveMinutes, 7)
    }
}

@MainActor
final class RecoveryStoreTests: XCTestCase {
    private func makeStore() -> SessionStore {
        SessionStore(fileURL: URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "dinner-recovery-\(UUID().uuidString).json"),
            notifications: MockNotifications())
    }

    /// Steak night with the mash and beans kept on schedule, and the steak
    /// prep finished 7 minutes late at +37. Returns (store, serveAt, lateEnd).
    private func lateSteakPrep() async -> (SessionStore, Date, Date) {
        let store = makeStore()
        let serveAt = t0.addingTimeInterval(3600)
        store.session.serveAt = serveAt
        let steak = DinnerCatalog.menus[0]
        let s1 = steak.dishes[0][0].id, p1 = steak.dishes[1][0].id, p2 = steak.dishes[1][1].id
        let p1Plan = store.plan.first(where: { $0.id == p1 })!
        _ = await store.startStep(p1, now: p1Plan.plannedStart)
        _ = await store.completeStep(p1, now: p1Plan.plannedEnd)
        _ = await store.startStep(p2, now: p1Plan.plannedEnd)
        let s1Plan = store.plan.first(where: { $0.id == s1 })!
        _ = await store.startStep(s1, now: s1Plan.plannedStart)
        let lateEnd = s1Plan.plannedEnd.addingTimeInterval(7 * 60)
        _ = await store.completeStep(s1, now: lateEnd)
        return (store, serveAt, lateEnd)
    }

    /// Scenario 3: the explicit move applies once, a second move is a no-op,
    /// and undo restores the previous session exactly.
    func testMoveDinnerAppliesOnceAndUndoRestores() async {
        let (store, serveAt, lateEnd) = await lateSteakPrep()
        let p2 = DinnerCatalog.menus[0].dishes[1][1].id
        let p2Deadline = store.record(p2).timerDeadline
        XCTAssertEqual(store.readinessReport(now: lateEnd)?.driftMinutes, 7)

        let undoBefore = store.undoStack.count
        XCTAssertNotNil(store.moveDinnerToEstimatedReadiness(now: lateEnd))
        XCTAssertEqual(store.session.serveAt, serveAt.addingTimeInterval(7 * 60))
        XCTAssertEqual(store.undoStack.count, undoBefore + 1)
        XCTAssertNil(store.readinessReport(now: lateEnd))
        XCTAssertNil(store.moveDinnerToEstimatedReadiness(now: lateEnd), "nothing left to move")
        XCTAssertEqual(store.session.serveAt, serveAt.addingTimeInterval(7 * 60), "no double shift")
        XCTAssertEqual(store.undoStack.count, undoBefore + 1, "a no-op adds no undo frame")
        XCTAssertEqual(store.record(p2).timerDeadline, p2Deadline, "running deadline untouched")

        store.undoLast()
        XCTAssertEqual(store.session.serveAt, serveAt)
        XCTAssertEqual(store.readinessReport(now: lateEnd)?.driftMinutes, 7)
        XCTAssertEqual(store.record(p2).timerDeadline, p2Deadline)
    }

    /// Scenario 4: while the notice is visible, state moves on (time passes,
    /// another step starts). The report and the move use the CURRENT
    /// readiness, never the +7 computed at the earlier completion.
    func testReportAndMoveUseCurrentReadinessNotPriorEstimate() async {
        let (store, serveAt, lateEnd) = await lateSteakPrep()
        XCTAssertEqual(store.readinessReport(now: lateEnd)?.estimatedReadyAt,
                       serveAt.addingTimeInterval(7 * 60))

        // Eight minutes later the cook starts the steak; its 20-min timer
        // now ends at +65, so the rest can't finish before +75.
        let s2 = DinnerCatalog.menus[0].dishes[0][1].id
        let later = lateEnd.addingTimeInterval(8 * 60)                 // +45
        XCTAssertEqual(store.readinessReport(now: later)?.estimatedReadyAt,
                       serveAt.addingTimeInterval(15 * 60), "idle time is counted")
        _ = await store.startStep(s2, now: later)
        let report = store.readinessReport(now: later)
        XCTAssertEqual(report?.estimatedReadyAt, serveAt.addingTimeInterval(15 * 60))
        XCTAssertEqual(report?.driftMinutes, 15)

        XCTAssertNotNil(store.moveDinnerToEstimatedReadiness(now: later))
        XCTAssertEqual(store.session.serveAt, serveAt.addingTimeInterval(15 * 60),
                       "applied the current estimate, not the earlier +7")
        XCTAssertNil(store.readinessReport(now: later))
    }

    /// Scenario 8: undo, reset, and a menu change cannot leave a notice that
    /// belongs to an earlier session, because nothing is stored.
    func testDriftNeverOutlivesItsSession() async {
        let (store, _, lateEnd) = await lateSteakPrep()
        XCTAssertNotNil(store.readinessReport(now: lateEnd))

        store.undoLast()                       // un-finish the late prep: steak is cooking to +30
        XCTAssertNil(store.readinessReport(now: lateEnd.addingTimeInterval(-7 * 60)))

        _ = await store.completeStep(DinnerCatalog.menus[0].dishes[0][0].id, now: lateEnd)
        XCTAssertNotNil(store.readinessReport(now: lateEnd))
        store.resetSession()
        XCTAssertNil(store.readinessReport(now: t0.addingTimeInterval(10 * 60)))

        store.chooseMenu(DinnerCatalog.menus[2].id)
        XCTAssertNil(store.readinessReport(now: Date()))
    }

    /// Confirming an explicit "Adjust time" delay recomputes the report too:
    /// a +10 delay covers a +7 drift, so the notice clears.
    func testDelayConfirmationRecomputesDrift() async {
        let (store, serveAt, lateEnd) = await lateSteakPrep()
        XCTAssertEqual(store.readinessReport(now: lateEnd)?.driftMinutes, 7)
        store.confirmDelay(store.proposeDelay(minutes: 10))
        XCTAssertEqual(store.session.serveAt, serveAt.addingTimeInterval(10 * 60))
        XCTAssertNil(store.readinessReport(now: lateEnd))
    }

    /// Completion records drift in history but never changes the dinner time.
    func testCompletionRecordsDriftWithoutChangingServeAt() async {
        let (store, serveAt, _) = await lateSteakPrep()
        XCTAssertEqual(store.session.serveAt, serveAt)
        XCTAssertTrue(store.session.history.contains { $0.text.contains("no longer feasible") })
    }

    /// Review finding 2 at the store boundary: a finished dinner reports
    /// nothing and cannot be moved — no undo frame, no history, no change.
    func testFinishedDinnerCannotBeMoved() async {
        let store = makeStore()
        let serveAt = t0.addingTimeInterval(3600)
        store.session.serveAt = serveAt
        for step in store.menu.steps {
            var r = StepRecord(); r.state = .done
            r.actualStart = t0.addingTimeInterval(1800); r.actualEnd = t0.addingTimeInterval(3600)
            store.session.records[step.id] = r
        }
        let lastID = store.menu.dishes[0][2].id
        store.session.records[lastID]?.actualEnd = serveAt.addingTimeInterval(9 * 60)   // finished late
        let now = serveAt.addingTimeInterval(9 * 60)
        let undoDepth = store.undoStack.count, historyCount = store.session.history.count

        XCTAssertNil(store.readinessReport(now: now))
        XCTAssertNil(store.readinessMoveProposal(now: now))
        XCTAssertNil(store.moveDinnerToEstimatedReadiness(now: now))
        XCTAssertEqual(store.session.serveAt, serveAt)
        XCTAssertEqual(store.undoStack.count, undoDepth)
        XCTAssertEqual(store.session.history.count, historyCount)
    }

    /// Review finding 4 at the store boundary: the preview the sheet shows
    /// and the move the store applies use the same rounded-up minutes, so
    /// the applied dinner time is never before the estimate.
    func testPreviewAndMoveAgreeAndNeverUndershootEstimate() async {
        let store = makeStore()
        let serveAt = t0.addingTimeInterval(3600)
        store.session.serveAt = serveAt
        let steak = DinnerCatalog.menus[0]
        let s1 = steak.dishes[0][0].id, p1 = steak.dishes[1][0].id, p2 = steak.dishes[1][1].id
        let p1Plan = store.plan.first(where: { $0.id == p1 })!
        _ = await store.startStep(p1, now: p1Plan.plannedStart)
        _ = await store.completeStep(p1, now: p1Plan.plannedEnd)
        _ = await store.startStep(p2, now: p1Plan.plannedEnd)
        let s1Plan = store.plan.first(where: { $0.id == s1 })!
        _ = await store.startStep(s1, now: s1Plan.plannedStart)
        let lateEnd = s1Plan.plannedEnd.addingTimeInterval(7 * 60 + 20)           // 7 m 20 s late
        _ = await store.completeStep(s1, now: lateEnd)

        guard let report = store.readinessReport(now: lateEnd),
              let preview = store.readinessMoveProposal(now: lateEnd)
        else { return XCTFail("expected a report and a preview") }
        XCTAssertEqual(report.driftMinutes, 7)
        XCTAssertEqual(report.moveMinutes, 8)
        XCTAssertEqual(preview.newServeAt, serveAt.addingTimeInterval(8 * 60))
        let applied = store.moveDinnerToEstimatedReadiness(now: lateEnd)
        XCTAssertEqual(applied?.newServeAt, preview.newServeAt, "apply matches preview")
        XCTAssertEqual(store.session.serveAt, serveAt.addingTimeInterval(8 * 60))
        XCTAssertGreaterThanOrEqual(store.session.serveAt, report.estimatedReadyAt)
        XCTAssertNil(store.readinessReport(now: lateEnd), "applied once; no residual drift")
    }
}
