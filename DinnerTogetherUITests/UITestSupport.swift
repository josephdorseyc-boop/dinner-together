import XCTest

// MARK: - Seeds

/// Seed payloads for the UI tests, built in-test with fresh timestamps on
/// every run. The JSON shape is exactly what SessionStore decodes
/// (DinnerSession via synthesized Codable: Dates as seconds since
/// 2001-01-01 UTC, optionals omitted when nil) — the same scenarios as
/// native-validation/seed-sessions.py, plus the stale-plan variants and
/// the cooking-without-start edge case. Do not invent new seed formats.
enum UISeed {
    private static func swiftDate(_ date: Date) -> Double {
        date.timeIntervalSinceReferenceDate
    }

    private static func done(_ start: Date?, _ end: Date) -> [String: Any] {
        var rec: [String: Any] = ["state": "done", "actualEnd": swiftDate(end)]
        if let start { rec["actualStart"] = swiftDate(start) }
        return rec
    }

    private static func cooking(_ start: Date, minutes: Int, deadline: Date) -> [String: Any] {
        ["runID": UUID().uuidString.uppercased(), "state": "cooking",
         "actualStart": swiftDate(start), "confirmedMinutes": minutes,
         "timerDeadline": swiftDate(deadline)]
    }

    /// A cooking record with no recorded start. The only way to reach the
    /// "Mark done?" confirmation for an unstarted step: startStep always
    /// records actualStart, and the store refuses to fabricate one.
    private static func cookingUnstarted(minutes: Int, deadline: Date) -> [String: Any] {
        ["runID": UUID().uuidString.uppercased(), "state": "cooking",
         "confirmedMinutes": minutes, "timerDeadline": swiftDate(deadline)]
    }

    private static func session(now: Date, serveAt: Date,
                               records: [String: [String: Any]],
                               lastOpenedAt: Date? = nil) -> String {
        let payload: [String: Any] = [
            "menuID": "steak",
            "serveAt": swiftDate(serveAt),
            "durationOverrides": [String: Int](),
            "records": records,
            "history": [[String: Any]](),
            "createdAt": swiftDate(now.addingTimeInterval(-3600)),
            "lastOpenedAt": swiftDate(lastOpenedAt ?? now),
        ]
        let data = try! JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        return String(data: data, encoding: .utf8)!
    }

    /// Steak prep finished 7 min late; notice "Running about 7 min behind".
    static func latePrep(now: Date) -> String {
        session(now: now, serveAt: now.addingTimeInterval(23 * 60), records: [
            "s1": done(now.addingTimeInterval(-17 * 60), now),
            "p1": done(now.addingTimeInterval(-12 * 60), now.addingTimeInterval(-2 * 60)),
            "p2": cooking(now.addingTimeInterval(-2 * 60), minutes: 20,
                          deadline: now.addingTimeInterval(18 * 60)),
        ])
    }

    /// Steak cook timer ended 5 min ago; lower-bound estimate.
    static func expiredTimer(now: Date) -> String {
        session(now: now, serveAt: now.addingTimeInterval(5 * 60), records: [
            "s1": done(now.addingTimeInterval(-35 * 60), now.addingTimeInterval(-25 * 60)),
            "s2": cooking(now.addingTimeInterval(-25 * 60), minutes: 20,
                          deadline: now.addingTimeInterval(-5 * 60)),
            "p1": done(now.addingTimeInterval(-40 * 60), now.addingTimeInterval(-30 * 60)),
            "p2": done(now.addingTimeInterval(-30 * 60), now.addingTimeInterval(-10 * 60)),
            "p3": done(now.addingTimeInterval(-10 * 60), now.addingTimeInterval(-5 * 60)),
            "b1": done(now.addingTimeInterval(-20 * 60), now.addingTimeInterval(-15 * 60)),
            "b2": done(now.addingTimeInterval(-15 * 60), now.addingTimeInterval(-5 * 60)),
        ])
    }

    /// Steak prep cooking on plan; nothing late.
    static func onSchedule(now: Date) -> String {
        session(now: now, serveAt: now.addingTimeInterval(38 * 60), records: [
            "s1": cooking(now.addingTimeInterval(-2 * 60), minutes: 10,
                          deadline: now.addingTimeInterval(8 * 60)),
        ])
    }

    /// Nothing started; dependents blocked on unfinished prerequisites.
    static func lateToStart(now: Date) -> String {
        session(now: now, serveAt: now.addingTimeInterval(32 * 60), records: [:])
    }

    /// s1 cooking with no recorded start — reaches the unstarted-completion
    /// confirmation and the "start not recorded" completed card.
    static func cookingWithoutStart(now: Date) -> String {
        session(now: now, serveAt: now.addingTimeInterval(38 * 60), records: [
            "s1": cookingUnstarted(minutes: 10, deadline: now.addingTimeInterval(8 * 60)),
        ])
    }

    /// Opened yesterday, progress made, dinner time passed.
    static func staleWithProgress(now: Date) -> String {
        let yesterday = now.addingTimeInterval(-26 * 3600)
        return session(now: now, serveAt: yesterday.addingTimeInterval(-3600), records: [
            "s1": done(yesterday.addingTimeInterval(-3600), yesterday.addingTimeInterval(-1800)),
            "p1": done(yesterday.addingTimeInterval(-3600), yesterday.addingTimeInterval(-2400)),
        ], lastOpenedAt: yesterday)
    }

    /// Opened yesterday, never started, dinner time passed.
    static func staleNoProgress(now: Date) -> String {
        session(now: now, serveAt: now.addingTimeInterval(-3 * 3600), records: [:],
                lastOpenedAt: now.addingTimeInterval(-26 * 3600))
    }
}

// MARK: - Base class

/// Shared base for the Dinner, Together UI tests: seeded launch, named
/// keep-always screenshots, and the flow implementations exercised on both
/// device classes. Assertions prefer the app's existing accessibility
/// labels; identifiers are used only where labels are ambiguous
/// ("serving-time", "timeline-step-<id>").
class DinnerTogetherUITestCase: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Launches the app into a seeded state. Every test sets DT_SEED_JSON
    /// explicitly: the app never deletes a seed file, so an unset variable
    /// would leak the previous test's seed into this one.
    @discardableResult
    func launch(seed: String, extraLaunchArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["DT_SEED_JSON"] = seed
        app.launchArguments += ["-dt-open-cooking", "-dt-inert-reminders"] + extraLaunchArguments
        app.launch()
        self.app = app
        return app
    }

    /// Keep-always screenshot, named by flow and step. The harness exports
    /// these from the .xcresult into results/ui-screenshots/<device>/.
    func photograph(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func waitForExistence(_ element: XCUIElement, timeout: TimeInterval = 10, _ message: String,
                          file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), message, file: file, line: line)
    }

    func tapButton(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons[name].firstMatch
        waitForExistence(button, timeout: 10, "button '\(name)' not found", file: file, line: line)
        button.tap()
    }

    /// The DINNER AT readout's accessibility label, e.g. "Chosen dinner time 6:23 PM".
    var servingTimeLabel: String { app.staticTexts["serving-time"].label }

    /// The DINNER AT value without its label prefix, e.g. "6:23 PM".
    var servingTimeValue: String {
        servingTimeLabel.replacingOccurrences(of: "Chosen dinner time ", with: "")
    }

    /// Waits until the DINNER AT readout shows the expected value.
    func waitForServingTimeValue(_ expected: String, timeout: TimeInterval = 10,
                                 file: StaticString = #filePath, line: UInt = #line) {
        let exp = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Chosen dinner time \(expected)"),
            object: app.staticTexts["serving-time"])
        XCTAssertEqual(wait(for: [exp], timeout: timeout), .completed,
                       "DINNER AT did not become '\(expected)' (still '\(servingTimeValue)')",
                       file: file, line: line)
    }

    // MARK: Flows (each test method calls one)

    /// Flow 1 — Review dinner time from a late-prep notice: open the sheet,
    /// move dinner to the displayed time, undo restores everything.
    func flowReviewDinnerTimeLatePrep() {
        launch(seed: UISeed.latePrep(now: Date()))
        waitForExistence(app.staticTexts["serving-time"], timeout: 10, "cooking screen with DINNER AT")
        let before = servingTimeValue

        tapButton("Review dinner time")
        waitForExistence(app.navigationBars["Review dinner time"], timeout: 10, "review sheet opened")
        photograph("01-review-sheet")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Chosen dinner time'"))
            .firstMatch.waitForExistence(timeout: 5), "sheet shows the chosen dinner time")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Estimated readiness'"))
            .firstMatch.waitForExistence(timeout: 5), "sheet shows the estimated readiness (not a lower bound)")

        let moveButton = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Move dinner to '")).firstMatch
        XCTAssertTrue(moveButton.waitForExistence(timeout: 5), "Move button present")
        let target = moveButton.label.replacingOccurrences(of: "Move dinner to ", with: "")
        XCTAssertNotEqual(target, before, "the move proposes a different time")
        moveButton.tap()

        waitForServingTimeValue(target)
        XCTAssertNotEqual(servingTimeValue, before)
        photograph("01-after-move")
        XCTAssertFalse(app.buttons["Review dinner time"].exists, "the notice is gone once dinner moves")

        let undo = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Undo: '")).firstMatch
        XCTAssertTrue(undo.waitForExistence(timeout: 5), "undo is offered after the move")
        undo.tap()
        waitForServingTimeValue(before)
        waitForExistence(app.buttons["Review dinner time"], timeout: 10, "the notice returns after undo")
        photograph("01-after-undo")
    }

    /// Flow 2 — Review sheet on a lower-bound estimate: the amber note
    /// appears, and keeping the time changes nothing.
    func flowReviewSheetLowerBound() {
        launch(seed: UISeed.expiredTimer(now: Date()))
        waitForExistence(app.staticTexts["serving-time"], timeout: 10, "cooking screen with DINNER AT")
        let before = servingTimeValue

        tapButton("Review dinner time")
        waitForExistence(app.navigationBars["Review dinner time"], timeout: 10, "review sheet opened")
        photograph("02-review-sheet-lower-bound")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Earliest readiness'"))
            .firstMatch.waitForExistence(timeout: 5), "sheet shows the lower-bound label")
        XCTAssertTrue(app.staticTexts["A timer has ended but its step isn't marked done, so this is the earliest the meal could be ready — not a prediction."]
            .waitForExistence(timeout: 5), "amber lower-bound note shown")

        let keep = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Keep '")).firstMatch
        XCTAssertTrue(keep.waitForExistence(timeout: 5), "Keep button present")
        keep.tap()
        XCTAssertFalse(app.navigationBars["Review dinner time"].exists, "sheet dismissed")
        XCTAssertEqual(servingTimeValue, before, "keeping the time changes nothing")
    }

    /// Flow 3 — Adjust time from the serving card: the delay sheet explains
    /// before anything changes; confirming moves DINNER AT 10 minutes; undo
    /// restores it.
    func flowAdjustTimeOnSchedule() {
        launch(seed: UISeed.onSchedule(now: Date()))
        waitForExistence(app.staticTexts["serving-time"], timeout: 10, "cooking screen with DINNER AT")
        let before = servingTimeValue

        tapButton("Adjust time")
        let dialog = app.sheets.firstMatch
        waitForExistence(dialog, timeout: 10, "delay choice dialog")
        dialog.buttons["Add 10 minutes"].firstMatch.tap()

        waitForExistence(app.navigationBars["Before we shift things"], timeout: 10, "delay sheet opened")
        photograph("03-delay-sheet")
        XCTAssertTrue(app.buttons["Add 10 minutes"].firstMatch.waitForExistence(timeout: 5),
                      "delay sheet confirms the chosen amount")

        app.buttons["Add 10 minutes"].firstMatch.tap()
        // The displayed times round-trip through the same short-style
        // formatter the app uses; the simulator inherits the host locale.
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        guard let beforeDate = formatter.date(from: before) else {
            XCTFail("could not parse the DINNER AT value '\(before)'"); return
        }
        let expected = formatter.string(from: beforeDate.addingTimeInterval(10 * 60))
        waitForServingTimeValue(expected)
        photograph("03-after-confirm")

        let undo = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Undo: '")).firstMatch
        XCTAssertTrue(undo.waitForExistence(timeout: 5), "undo is offered after the delay")
        undo.tap()
        waitForServingTimeValue(before)
        photograph("03-after-undo")
    }

    /// Flow 4 — Expired timer completion: "Mark Cook the steak done"
    /// (the button's accessibility label) finishes the step and the notice
    /// recomputes.
    func flowExpiredTimerCompletion() {
        launch(seed: UISeed.expiredTimer(now: Date()))
        let markDone = app.buttons["Mark Cook the steak done"]
        waitForExistence(markDone, timeout: 10, "featured expired-timer action")
        photograph("04-expired-featured")

        markDone.tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: markDone)
        XCTAssertEqual(wait(for: [gone], timeout: 10), .completed, "the expired step reached Done")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Completed ('"))
            .firstMatch.waitForExistence(timeout: 10), "the step is in the Completed group")
        photograph("04-after-completion")
    }

    /// Flow 5 — Blocked start: "Review start" explains the unfinished
    /// prerequisite; Cancel changes nothing; "Start anyway" starts the step.
    func flowBlockedStartAnyway() {
        launch(seed: UISeed.lateToStart(now: Date()))
        let card = app.descendants(matching: .any)["timeline-step-s2"]
        waitForExistence(card, timeout: 10, "s2 timeline card")
        photograph("05-timeline-blocked")

        let reviewStart = card.buttons["Review start"]
        XCTAssertTrue(reviewStart.waitForExistence(timeout: 5), "blocked step offers Review start")
        reviewStart.tap()

        let alert = app.alerts.firstMatch
        waitForExistence(alert, timeout: 5, "blocked-start alert")
        photograph("05-blocked-alert")
        XCTAssertTrue(alert.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Prep the steak'"))
            .firstMatch.exists, "the alert names the unfinished prerequisite")

        alert.buttons["Cancel"].tap()
        XCTAssertFalse(app.alerts.firstMatch.exists, "Cancel dismisses the alert")
        XCTAssertTrue(card.buttons["Review start"].waitForExistence(timeout: 5),
                      "Cancel changed nothing: the step is still blocked")

        card.buttons["Review start"].tap()
        waitForExistence(app.alerts.firstMatch, timeout: 5, "blocked-start alert again")
        app.alerts.firstMatch.buttons["Start anyway"].tap()
        XCTAssertTrue(card.buttons["Mark done"].waitForExistence(timeout: 10),
                      "Start anyway started the step despite the unfinished prerequisite")
        photograph("05-after-start-anyway")
    }

    /// Flow 6 — Unstarted completion: marking done without a recorded start
    /// asks first, then completes with "start not recorded" — the start is
    /// never fabricated.
    func flowUnstartedCompletion() {
        launch(seed: UISeed.cookingWithoutStart(now: Date()))
        let markDone = app.buttons["Mark Prep the steak & sauce ingredients done"]
        waitForExistence(markDone, timeout: 10, "running step with no recorded start")
        markDone.tap()

        let alert = app.alerts.firstMatch
        waitForExistence(alert, timeout: 5, "unstarted-completion confirmation")
        photograph("06-confirmation-alert")
        XCTAssertTrue(alert.staticTexts.matching(NSPredicate(format: "label CONTAINS 'never marked started'"))
            .firstMatch.exists, "the alert is honest about the unknown start")

        alert.buttons["Mark done"].tap()
        let completedGroup = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Completed ('")).firstMatch
        XCTAssertTrue(completedGroup.waitForExistence(timeout: 10), "the step reached the Completed group")
        completedGroup.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'start not recorded'"))
            .firstMatch.waitForExistence(timeout: 10), "completion does not fabricate a start time")
        photograph("06-after-completion")
    }

    /// Flow 7a — Stale plan with progress: the non-dismissable sheet offers
    /// "Resume this plan".
    func flowStalePlanWithProgress() {
        launch(seed: UISeed.staleWithProgress(now: Date()))
        waitForExistence(app.staticTexts["Welcome back."], timeout: 10, "stale-plan sheet on launch")
        photograph("07a-stale-sheet")
        XCTAssertTrue(app.buttons["Resume this plan"].exists, "resume offered when there is progress")

        app.buttons["Resume this plan"].tap()
        XCTAssertFalse(app.staticTexts["Welcome back."].exists, "the sheet dismissed after resume")
        waitForExistence(app.staticTexts["serving-time"], timeout: 10, "cooking screen visible after resume")
        photograph("07a-after-resume")
    }

    /// Flow 7b — Stale plan without progress: "Keep menu, fresh time".
    func flowStalePlanNoProgress() {
        launch(seed: UISeed.staleNoProgress(now: Date()))
        waitForExistence(app.staticTexts["Welcome back."], timeout: 10, "stale-plan sheet on launch")
        photograph("07b-stale-sheet")
        XCTAssertTrue(app.buttons["Keep menu, fresh time"].exists, "fresh time offered with no progress")

        app.buttons["Keep menu, fresh time"].tap()
        XCTAssertFalse(app.staticTexts["Welcome back."].exists, "the sheet dismissed")
        waitForExistence(app.staticTexts["serving-time"], timeout: 10, "cooking screen visible with a fresh time")
        photograph("07b-after-keep")
    }

    /// Flow 8 — Flow 1 at accessibility text size.
    func flowReviewDinnerTimeAXTextSize() {
        launch(seed: UISeed.latePrep(now: Date()), extraLaunchArguments: [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge",
        ])
        waitForExistence(app.staticTexts["serving-time"], timeout: 10, "cooking screen with DINNER AT")
        tapButton("Review dinner time")
        waitForExistence(app.navigationBars["Review dinner time"], timeout: 10, "review sheet opened")
        photograph("08-ax-review-sheet")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Estimated readiness'"))
            .firstMatch.waitForExistence(timeout: 5), "estimate readable at accessibility text size")
    }
}
