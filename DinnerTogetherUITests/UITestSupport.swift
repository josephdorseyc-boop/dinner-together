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
                               lastOpenedAt: Date? = nil,
                               menuID: String = "steak") -> String {
        let payload: [String: Any] = [
            "menuID": menuID,
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

    /// Nothing started and dinner in 20 min: the steak chain (10 + 20 + 10)
    /// puts s1 20 min late and s2 ("Cook the steak") 10 min past its planned
    /// start while s1 is still not started — so s2 is both due and blocked,
    /// which is the only state in which the timeline offers "Review start".
    /// (A3-U-F2; `lateToStart` keeps s2 two minutes in the future.)
    static func blockedStart(now: Date) -> String {
        session(now: now, serveAt: now.addingTimeInterval(20 * 60), records: [:])
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

    /// The planning screen: nothing started, dinner 50 min out (feasible).
    /// Launched without -dt-open-cooking by Flow 9.
    static func tonight(now: Date, menuID: String = "steak") -> String {
        session(now: now, serveAt: now.addingTimeInterval(50 * 60), records: [:], menuID: menuID)
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
    func launch(seed: String, extraLaunchArguments: [String] = [], openCooking: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["DT_SEED_JSON"] = seed
        app.launchArguments += (openCooking ? ["-dt-open-cooking"] : []) + ["-dt-inert-reminders"] + extraLaunchArguments
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

    /// The accessibility hierarchy as text, kept always — readable from the
    /// results branch when a tap "did nothing" and XCTest's own dump is not
    /// exported (iPad, runs 20–21).
    func attachHierarchy(_ name: String) {
        let attachment = XCTAttachment(string: app.debugDescription)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func waitForExistence(_ element: XCUIElement, timeout: TimeInterval = 10, _ message: String,
                          file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), message, file: file, line: line)
    }

    /// Waits for an element to leave the hierarchy. Sheets and alerts
    /// dismiss with an animation, so `exists` checked right after a tap can
    /// still be true (A3-U-F4).
    func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval = 10, _ message: String,
                              file: StaticString = #filePath, line: UInt = #line) {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: timeout), .completed, message, file: file, line: line)
    }

    /// Any element whose accessibility label begins with `prefix`, whatever
    /// its element type. The review sheet's time columns and the cooking
    /// screen's notice are combined accessibility elements; querying
    /// `staticTexts` alone would depend on how SwiftUI reports them (A3-U-F6).
    func element(labelBeginning prefix: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    /// Scrolls the screen until the element is hittable. XCUITest never
    /// scrolls on its own, and on iPhone the timeline — Undo, the Completed
    /// group, a blocked step's card — sits below the first screen (A3-U-F3).
    /// Short controlled drags rather than `swipeUp()`, which overshoots.
    /// "Comfortably on screen": hittable AND clear of the top and bottom
    /// bands where the navigation bar, tab bar and home indicator live.
    /// Run 14: `isHittable` was true for a "Review start" button whose
    /// lower half sat under the tab bar, and the tap did nothing (A3-U-F8).
    func isComfortablyVisible(_ element: XCUIElement) -> Bool {
        guard element.exists, element.isHittable else { return false }
        let screen = app.frame
        let f = element.frame
        // The tab bar only matters when it is actually on top (not under a sheet).
        let tabBar = app.tabBars.firstMatch
        let bottomBand: CGFloat = (tabBar.exists && tabBar.isHittable) ? 130 : 40
        // Top band: the status bar plus a little; a navigation bar that
        // actually covers the element already makes it non-hittable. (iPad's
        // "Adjust time" sits ~100 pt from the top and never scrolls higher —
        // run 16.)
        return f.minY >= screen.minY + 60 && f.maxY <= screen.maxY - bottomBand
    }

    func scrollTo(_ element: XCUIElement, maxDrags: Int = 12,
                  file: StaticString = #filePath, line: UInt = #line) {
        var drags = 0
        while !isComfortablyVisible(element) && drags < maxDrags {
            let screen = app.frame
            // Aim the element at the middle of the screen; if it doesn't exist
            // yet, page downward. A short hold at the end stops the scroll view
            // from decelerating past the target.
            var delta = screen.height * 0.4
            if element.exists {
                delta = element.frame.midY - screen.midY
                delta = max(-screen.height * 0.45, min(screen.height * 0.45, delta))
            }
            let startY = delta >= 0 ? 0.70 : 0.30
            let endY = startY - Double(delta / screen.height)
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
            let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: endY))
            from.press(forDuration: 0.1, thenDragTo: to, withVelocity: .default, thenHoldForDuration: 0.3)
            Thread.sleep(forTimeInterval: 0.4)   // let the scroll view settle before the next query or tap
            drags += 1
        }
        XCTAssertTrue(isComfortablyVisible(element),
                      "element not comfortably on screen after \(drags) scroll(s): \(element)", file: file, line: line)
    }

    /// Taps an element that may sit in a popover (iPad confirmation dialogs
    /// report their buttons as not hittable — run 14, test02 on iPad); falls
    /// back to a tap at the element's center (A3-U-F10).
    func tapEvenInPopover(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        waitForExistence(element, timeout: 10, "element to tap exists: \(element)", file: file, line: line)
        let hittable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: element)
        if XCTWaiter().wait(for: [hittable], timeout: 3) == .completed {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    /// Returns to the top of the screen so a photograph shows the state the
    /// flow is about, not wherever the last tap left the scroll position.
    func scrollToTop(maxDrags: Int = 12) {
        for _ in 0..<maxDrags {
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
            let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            from.press(forDuration: 0.05, thenDragTo: to)
            if app.staticTexts["serving-time"].exists && app.staticTexts["serving-time"].isHittable { break }
        }
    }

    /// Finds, scrolls to and taps a button by its accessibility label.
    func tapButton(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons[name].firstMatch
        waitForExistence(button, timeout: 10, "button '\(name)' not found", file: file, line: line)
        scrollTo(button, file: file, line: line)
        button.tap()
    }

    /// Scrolls to and taps any element (a DisclosureGroup label, a card button).
    func scrollAndTap(_ element: XCUIElement, _ message: String,
                      file: StaticString = #filePath, line: UInt = #line) {
        waitForExistence(element, timeout: 10, message, file: file, line: line)
        scrollTo(element, file: file, line: line)
        element.tap()
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
        waitForServingTimeValue(oneOf: [expected], timeout: timeout, file: file, line: line)
    }

    /// Waits until the DINNER AT readout shows one of the accepted values.
    func waitForServingTimeValue(oneOf accepted: [String], timeout: TimeInterval = 10,
                                 file: StaticString = #filePath, line: UInt = #line) {
        let labels = accepted.map { "Chosen dinner time \($0)" }
        let exp = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label IN %@", labels),
            object: app.staticTexts["serving-time"])
        // XCTestCase.wait(for:timeout:) returns Void; the result-returning
        // variant lives on XCTWaiter (A3-U-F1, compile fix).
        XCTAssertEqual(XCTWaiter().wait(for: [exp], timeout: timeout), .completed,
                       "DINNER AT did not become one of \(accepted) (still '\(servingTimeValue)')",
                       file: file, line: line)
    }

    /// "3:45 AM" -> "3:46 AM", through the same short-style formatter the app uses.
    func plusOneMinute(_ time: String) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        guard let date = formatter.date(from: time) else { return time }
        return formatter.string(from: date.addingTimeInterval(60))
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
        XCTAssertTrue(element(labelBeginning: "Chosen dinner time").waitForExistence(timeout: 5),
                      "sheet shows the chosen dinner time")
        XCTAssertTrue(element(labelBeginning: "Estimated readiness").waitForExistence(timeout: 5),
                      "sheet shows the estimated readiness (not a lower bound)")

        let moveButton = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Move dinner to '")).firstMatch
        XCTAssertTrue(moveButton.waitForExistence(timeout: 5), "Move button present")
        scrollTo(moveButton)   // the sheet opens at its medium detent
        // The sheet is live: the time on the button is recomputed every draw,
        // and a pending step clamped to "now" makes the estimate advance in
        // real time. Read the label immediately before tapping, and accept
        // the minute boundary the proposal may cross between the read and
        // the tap (run 14 on iPad: button said 3:45, applied 3:46) (A3-U-F9).
        let target = moveButton.label.replacingOccurrences(of: "Move dinner to ", with: "")
        XCTAssertNotEqual(target, before, "the move proposes a different time")
        moveButton.tap()

        waitForServingTimeValue(oneOf: [target, plusOneMinute(target)])
        XCTAssertNotEqual(servingTimeValue, before)
        waitForDisappearance(app.buttons["Review dinner time"], "the notice is gone once dinner moves")
        photograph("01-after-move")

        let undo = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Undo: '")).firstMatch
        scrollAndTap(undo, "undo is offered after the move")
        waitForServingTimeValue(before)
        waitForExistence(app.buttons["Review dinner time"], timeout: 10, "the notice returns after undo")
        scrollToTop()
        photograph("01-after-undo")
    }

    /// Flow 2 — Review sheet on a lower-bound estimate: the amber note
    /// appears, and keeping the time changes nothing.
    func flowReviewSheetLowerBound() {
        launch(seed: UISeed.expiredTimer(now: Date()))
        waitForExistence(app.staticTexts["serving-time"], timeout: 10, "cooking screen with DINNER AT")
        let before = servingTimeValue

        // With an expired timer the notice follows the RIGHT NOW card (D1),
        // below the first iPhone screen; tapButton scrolls to it.
        tapButton("Review dinner time")
        waitForExistence(app.navigationBars["Review dinner time"], timeout: 10, "review sheet opened")
        photograph("02-review-sheet-lower-bound")
        XCTAssertTrue(element(labelBeginning: "Earliest readiness").waitForExistence(timeout: 5),
                      "sheet shows the lower-bound label")
        XCTAssertTrue(app.staticTexts["A timer has ended but its step isn't marked done, so this is the earliest the meal could be ready — not a prediction."]
            .waitForExistence(timeout: 5), "amber lower-bound note shown")

        let keep = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Keep '")).firstMatch
        XCTAssertTrue(keep.waitForExistence(timeout: 5), "Keep button present")
        scrollTo(keep)
        keep.tap()
        waitForDisappearance(app.navigationBars["Review dinner time"], "sheet dismissed")
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
        // The confirmation dialog is an action sheet on iPhone and a popover
        // on iPad; its buttons are app descendants either way, and the delay
        // sheet (with its own "Add 10 minutes") is not open yet (A3-U-F5).
        let choice = app.buttons["Add 10 minutes"].firstMatch
        tapEvenInPopover(choice)   // iPad presents the dialog as a popover
        let delaySheet = app.navigationBars["Before we shift things"]
        if !delaySheet.waitForExistence(timeout: 6) {
            // iPad: the popover's content reported zero frames (run 20); record
            // what is on screen, then try once more through the popover query
            // or, if the popover was dismissed, by reopening the dialog.
            photograph("03-after-dialog-tap")
            attachHierarchy("03-after-dialog-tap-hierarchy")
            let inPopover = app.popovers.buttons["Add 10 minutes"].firstMatch
            if inPopover.waitForExistence(timeout: 2) {
                inPopover.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            } else {
                tapButton("Adjust time")
                Thread.sleep(forTimeInterval: 1.5)   // let the popover finish laying out
                let again = app.buttons["Add 10 minutes"].firstMatch
                waitForExistence(again, timeout: 10, "delay choice dialog offers Add 10 minutes (retry)")
                again.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
        }
        waitForExistence(delaySheet, timeout: 10, "delay sheet opened")
        photograph("03-delay-sheet")
        let confirm = app.buttons["Add 10 minutes"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "delay sheet confirms the chosen amount")
        scrollTo(confirm)
        confirm.tap()
        // The displayed times round-trip through the same short-style
        // formatter the app uses; the simulator inherits the host locale.
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        guard let beforeDate = formatter.date(from: before) else {
            XCTFail("could not parse the DINNER AT value '\(before)'"); return
        }
        let expected = formatter.string(from: beforeDate.addingTimeInterval(10 * 60))
        waitForServingTimeValue(expected)
        waitForDisappearance(app.navigationBars["Before we shift things"], "delay sheet dismissed after confirming")
        photograph("03-after-confirm")

        let undo = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Undo: '")).firstMatch
        scrollAndTap(undo, "undo is offered after the delay")
        waitForServingTimeValue(before)
        scrollToTop()
        photograph("03-after-undo")
    }

    /// Flow 4 — Expired timer completion: "Mark Cook the steak done"
    /// (the button's accessibility label) finishes the step and the notice
    /// recomputes.
    func flowExpiredTimerCompletion() {
        launch(seed: UISeed.expiredTimer(now: Date()))
        let markDone = app.buttons["Mark Cook the steak done"]
        waitForExistence(markDone, timeout: 10, "featured expired-timer action")
        scrollTo(markDone)
        photograph("04-expired-featured")

        markDone.tap()
        waitForDisappearance(markDone, "the expired step reached Done")
        XCTAssertTrue(element(labelBeginning: "Completed (").waitForExistence(timeout: 10),
                      "the step is in the Completed group")
        photograph("04-after-completion")
    }

    /// Flow 5 — Blocked start: "Review start" explains the unfinished
    /// prerequisite; Cancel changes nothing; "Start anyway" starts the step.
    func flowBlockedStartAnyway() {
        // Needs a seed where s2 is already due: "Review start" (and the
        // blocked alert) only appear once now >= plannedStart
        // (Scheduling.blockedInfo). The late-to-start screenshot seed
        // (dinner in 32 min) leaves s2 two minutes in the future (A3-U-F2).
        launch(seed: UISeed.blockedStart(now: Date()))
        let card = app.descendants(matching: .any)["timeline-step-s2"]
        waitForExistence(card, timeout: 10, "s2 timeline card")
        let reviewStart = card.buttons["Review start"]
        XCTAssertTrue(reviewStart.waitForExistence(timeout: 5), "blocked step offers Review start")
        scrollTo(reviewStart)
        photograph("05-timeline-blocked")
        reviewStart.tap()
        photograph("05-after-review-start-tap")   // evidence of what the tap did, alert or not

        let alert = app.alerts.firstMatch
        if !alert.waitForExistence(timeout: 4) {
            // One retry: a tap that lands while a scroll view is still settling
            // can be swallowed. The second tap is at the button's center.
            reviewStart.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        waitForExistence(alert, timeout: 5, "blocked-start alert")
        photograph("05-blocked-alert")
        XCTAssertTrue(alert.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Prep the steak'"))
            .firstMatch.exists, "the alert names the unfinished prerequisite")

        alert.buttons["Cancel"].tap()
        waitForDisappearance(app.alerts.firstMatch, "Cancel dismisses the alert")
        XCTAssertTrue(card.buttons["Review start"].waitForExistence(timeout: 5),
                      "Cancel changed nothing: the step is still blocked")

        scrollAndTap(card.buttons["Review start"], "Review start again")
        waitForExistence(app.alerts.firstMatch, timeout: 5, "blocked-start alert again")
        app.alerts.firstMatch.buttons["Start anyway"].tap()
        // A cooking step appears in RUNNING TIMERS with a heat card whose button
        // is labeled "Mark <step> done" — unique to the cooking state. (The
        // timeline card's own "Mark done" was visible in run 20's render but did
        // not resolve under the card container; this label does not depend on it.)
        let heat = app.buttons["Mark Cook the steak done"]
        if !heat.waitForExistence(timeout: 10) { attachHierarchy("05-after-start-anyway-hierarchy") }
        XCTAssertTrue(heat.exists, "Start anyway started the step despite the unfinished prerequisite")
        XCTAssertTrue(app.staticTexts["Status: Cooking"].firstMatch.waitForExistence(timeout: 5)
                      || app.staticTexts["Cooking"].firstMatch.exists,
                      "the step's badge reads Cooking")
        scrollTo(card)
        photograph("05-after-start-anyway")
    }

    /// Flow 6 — Unstarted completion: marking done without a recorded start
    /// asks first, then completes with "start not recorded" — the start is
    /// never fabricated.
    func flowUnstartedCompletion() {
        launch(seed: UISeed.cookingWithoutStart(now: Date()))
        let markDone = app.buttons["Mark Prep the steak & sauce ingredients done"]
        scrollAndTap(markDone, "running step with no recorded start")

        let alert = app.alerts.firstMatch
        waitForExistence(alert, timeout: 5, "unstarted-completion confirmation")
        photograph("06-confirmation-alert")
        XCTAssertTrue(alert.staticTexts.matching(NSPredicate(format: "label CONTAINS 'never marked started'"))
            .firstMatch.exists, "the alert is honest about the unknown start")

        alert.buttons["Mark done"].tap()
        waitForDisappearance(app.alerts.firstMatch, "confirmation dismissed")
        let completedGroup = element(labelBeginning: "Completed (")
        scrollAndTap(completedGroup, "the step reached the Completed group")
        let note = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS 'start not recorded'")).firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 10), "completion does not fabricate a start time")
        scrollTo(note)
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
        waitForDisappearance(app.staticTexts["Welcome back."], "the sheet dismissed after resume")
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
        waitForDisappearance(app.staticTexts["Welcome back."], "the sheet dismissed")
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
        XCTAssertTrue(element(labelBeginning: "Estimated readiness").waitForExistence(timeout: 5),
                      "estimate readable at accessibility text size")
    }

    /// Flow 9 — Tonight (planning) screen with nine menus: the selection
    /// footer names the chosen dinner and stays reachable without scrolling
    /// past every card (A2-S3); choosing a meat-free menu updates it; the
    /// primary action opens the cooking screen.
    func flowTonightNineMenus() {
        launch(seed: UISeed.tonight(now: Date()), openCooking: false)
        let action = app.buttons["Build my cooking plan"].firstMatch
        waitForExistence(action, timeout: 10, "planning screen with its primary action")
        XCTAssertTrue(action.isHittable, "the primary action is on screen before any scrolling (bottom inset)")
        XCTAssertTrue(app.staticTexts["Selected: Steak night"].waitForExistence(timeout: 5),
                      "the footer names the seeded selection")
        photograph("09-tonight-top")

        let tofu = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Crisp tofu, cozy bowls'")).firstMatch
        scrollAndTap(tofu, "a new meat-free menu card is reachable")
        photograph("09-tonight-after-tap")
        let footer = app.staticTexts["Selected: Crisp tofu, cozy bowls"]
        if !footer.waitForExistence(timeout: 4) {
            attachHierarchy("09-tonight-after-tap-hierarchy")
            // iPad (runs 17–21): two taps at the card's center changed nothing,
            // the same card works on iPhone. Try the title text and a short press.
            let title = app.staticTexts["Crisp tofu, cozy bowls"].firstMatch
            if title.exists { title.press(forDuration: 0.08) } else { tofu.press(forDuration: 0.08) }
            if !footer.waitForExistence(timeout: 3) {
                tofu.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5)).tap()
            }
        }
        XCTAssertTrue(footer.waitForExistence(timeout: 5), "choosing a menu updates the footer")
        XCTAssertTrue(action.isHittable, "the primary action is still on screen after scrolling the list")
        photograph("09-tonight-menus")

        action.tap()
        waitForExistence(app.staticTexts["serving-time"], timeout: 10, "cooking screen after Build my cooking plan")
        photograph("09-tonight-into-cooking")
    }
}
