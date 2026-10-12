import XCTest
import UIKit

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
    func launch(seed: String, extraLaunchArguments: [String] = [], openCooking: Bool = true,
                recipes: [String] = [], heroPhoto: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["DT_SEED_JSON"] = seed
        app.launchEnvironment["DT_SEED_RECIPE_PHOTO"] = heroPhoto ? "landscape" : ""
        // Always set, so recipes from one test never appear in another.
        let recipeData = (try? JSONSerialization.data(withJSONObject: recipes)) ?? Data("[]".utf8)
        app.launchEnvironment["DT_SEED_RECIPE_TEXTS"] = String(decoding: recipeData, as: UTF8.self)
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
    /// Taps a button on the frontmost alert and waits until the alert is gone,
    /// retrying while iOS 26's alert animation is settling. Validation runs
    /// 31–32 on Xcode 26.2: a tap during the morph-in was either swallowed
    /// (test06: alert stayed up) or raced the alert's own re-layout (test05:
    /// "no matches found for Alert" between the existence check and the tap).
    func tapAlertButton(_ label: String, _ message: String,
                        file: StaticString = #filePath, line: UInt = #line) {
        guard app.alerts.firstMatch.waitForExistence(timeout: 5) else {
            XCTFail("\(message): no alert to tap “\(label)” on", file: file, line: line); return
        }
        usleep(600_000) // let the presentation animation finish
        for _ in 0..<3 {
            let alert = app.alerts.firstMatch
            if !alert.exists { return }
            let button = alert.buttons[label]
            // Don't ask isHittable mid-animation: XCTest records "Failed to
            // determine hittability" as a failure (build-7 run, test06). Wait
            // for a real on-screen frame and tap its centre instead.
            if button.waitForExistence(timeout: 2), waitForOnScreenFrame(button) {
                button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
                                                 object: app.alerts.firstMatch)
            if XCTWaiter().wait(for: [gone], timeout: 3) == .completed { return }
        }
        XCTFail("\(message): the alert is still showing after tapping “\(label)” three times", file: file, line: line)
    }

    /// A frame XCTest can actually tap: every component finite. Alert and
    /// popover buttons can report infinite frames mid-animation or mid-layout;
    /// tapping those coordinates throws NSInternalInconsistencyException
    /// ("point.x != INFINITY && point.y != INFINITY").
    func isFiniteFrame(_ f: CGRect) -> Bool {
        f.origin.x.isFinite && f.origin.y.isFinite && f.size.width.isFinite && f.size.height.isFinite
    }

    /// True once the element has a finite, non-empty frame whose centre is
    /// inside the window — the condition for a coordinate tap to land on it.
    @discardableResult
    func waitForOnScreenFrame(_ element: XCUIElement, timeout: TimeInterval = 3) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            let f = element.frame, w = app.windows.firstMatch.frame
            if element.exists, isFiniteFrame(f), !f.isEmpty,
               w.contains(CGPoint(x: f.midX, y: f.midY)) { return true }
            usleep(150_000)
        } while Date() < deadline
        return false
    }

    /// Taps a control pinned outside the scroll content (a bottom bar): it
    /// never scrolls, so scrollAndTap's comfortable-visibility rule can't apply.
    func tapPinned(_ element: XCUIElement, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        waitForExistence(element, timeout: 5, message, file: file, line: line)
        XCTAssertTrue(waitForOnScreenFrame(element), "\(message): on screen", file: file, line: line)
        element.tap()
    }

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
        } else if waitForOnScreenFrame(element, timeout: 3) {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        } else {
            XCTFail("no finite on-screen frame for coordinate tap: \(element)", file: file, line: line)
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
        scrollToTop()
        photograph("01-after-undo")  // before asserting: the failure state is evidence too (A2)
        waitForServingTimeValue(before)
        waitForExistence(app.buttons["Review dinner time"], timeout: 10, "the notice returns after undo")
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
        waitForExistence(choice, timeout: 10, "delay choice dialog offers Add 10 minutes")
        Thread.sleep(forTimeInterval: 1.0)          // let the dialog finish presenting
        photograph("03-delay-choice-dialog")        // the dialog itself, both devices
        let isPad = app.frame.width > 700
        if isPad { attachHierarchy("03-delay-choice-dialog-hierarchy") }
        tapEvenInPopover(choice)   // iPad presents the dialog as a popover
        let delaySheet = app.navigationBars["Before we shift things"]
        if isPad && !delaySheet.waitForExistence(timeout: 6) {
            // iPad, runs 20–22: the popover's content reports unlaid-out frames
            // to XCUITest, the taps land outside it and dismiss it, and no
            // sheet follows. Documented, surfaced in the result bundle as an
            // expected failure (never hidden), and the delay sheet itself is
            // tapped through on iPhone. Non-strict: passes outright when fixed.
            photograph("03-after-dialog-tap")
            attachHierarchy("03-after-dialog-tap-hierarchy")
            XCTExpectFailure("iPad: confirmation-dialog popover not tappable through XCUITest (frames unlaid out); delay sheet covered on iPhone", options: .nonStrict()) {
                XCTAssertTrue(delaySheet.exists, "delay sheet opened (iPad popover)")
            }
            return
        }
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
        scrollToTop()
        photograph("03-after-undo")  // before asserting: the failure state is evidence too (A2)
        waitForServingTimeValue(before)
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

        tapAlertButton("Cancel", "Cancel dismisses the alert")
        XCTAssertTrue(card.buttons["Review start"].waitForExistence(timeout: 5),
                      "Cancel changed nothing: the step is still blocked")

        scrollAndTap(card.buttons["Review start"], "Review start again")
        waitForExistence(app.alerts.firstMatch, timeout: 5, "blocked-start alert again")
        tapAlertButton("Start anyway", "Start anyway dismisses the alert")
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

        tapAlertButton("Mark done", "confirmation dismissed")
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
        // -UIPreferredContentSizeCategoryName is not honored by the app;
        // -dt-type-size forces DynamicTypeSize via LaunchOptions (A1-T1).
        launch(seed: UISeed.latePrep(now: Date()), extraLaunchArguments: [
            "-dt-type-size", "accessibility3",
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

// MARK: - Recipe flows (A2 capture contract, October 11, 2026)

/// Agent 2's R5 scheduling fixtures — test data, not tested cooking recipes.
enum RecipeFixtureText {
    static let frozenBerry = """
        Frozen berry drink with lime and a three-hour freezer stage
        Yield: 2 tall glasses, or 4 small tasting portions
        Total time: 187 minutes

        Ingredients
        2 cups berry juice
        1 lime

        Directions
        1. Mix the juice and lime and fill an ice tray for 5 minutes.
        2. Freeze the mixture for 3 hours; check that it is solid before continuing.
        3. Blend and pour the frozen drink for 2 minutes.
        """
    static let beanSpread = """
        Bean spread with an untimed step
        Yield: 2 snack portions

        Ingredients
        1 can beans
        1 tablespoon olive oil
        1 lemon

        Directions
        1. Drain the beans and prepare the lemon for 5 minutes.
        2. Warm the beans until hot.
        3. Mash and season the spread for 8-10 minutes.
        4. Finish plating for 30 seconds.
        """
    static let frozenBerryTitle = "Frozen berry drink with lime and a three-hour freezer stage"
    static let beanSpreadTitle = "Bean spread with an untimed step"
}

/// How a recipe flow is rendered. Each variant is verified on screen before
/// it is photographed: a file name alone is not evidence (A2 capture contract).
struct RecipeCapture {
    var suffix = ""
    var typeSize: String?
    var dark = false
    /// Extra launch flags, e.g. the solid-card rendering of Reduce Transparency.
    var extra: [String] = []
    static let standard = RecipeCapture()
    static let ax3 = RecipeCapture(suffix: "-ax3", typeSize: "accessibility3")
    static let darkMode = RecipeCapture(suffix: "-dark", dark: true)
    static let solidCards = RecipeCapture(suffix: "-solid", extra: ["-dt-solid-cards"])

    var launchArguments: [String] {
        (typeSize.map { ["-dt-type-size", $0] } ?? []) + (dark ? ["-dt-appearance", "dark"] : ["-dt-appearance", "light"]) + extra
    }
}

extension DinnerTogetherUITestCase {
    private func launchRecipes(_ recipes: [String], _ capture: RecipeCapture, extra: [String] = [], heroPhoto: Bool = false) {
        launch(seed: UISeed.tonight(now: Date()), extraLaunchArguments: capture.launchArguments + extra,
               openCooking: false, recipes: recipes, heroPhoto: heroPhoto)
    }

    private func openRecipesLibrary() {
        scrollAndTap(app.buttons["open-recipes"], "Choose from Recipes")
        waitForExistence(app.buttons["add-recipe"], timeout: 5, "Recipes collection")
    }

    private func openRecipe(_ title: String) {
        openRecipesLibrary()
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
        scrollAndTap(row, "the recipe row for “\(title)”")
        waitForExistence(app.staticTexts["recipe-title"], timeout: 10, "the recipe page for “\(title)”")
    }

    /// Proves the forced type size took effect: at accessibility sizes the
    /// recipe tabs stack vertically (A2-R2), at default size they sit in a row.
    private func verifyTypeSize(_ capture: RecipeCapture, file: StaticString = #filePath, line: UInt = #line) {
        let a = app.buttons["recipe-tab-ingredients"], b = app.buttons["recipe-tab-directions"]
        guard a.waitForExistence(timeout: 5), b.exists else { return XCTFail("recipe tabs not found", file: file, line: line) }
        // Stacked = the second tab starts below the first one's middle. (Left
        // edges differ by the selected tab's capsule padding — 28 vs 38 pt in
        // run 38259705494 — so they aren't compared.)
        let stacked = b.frame.minY > a.frame.midY
        if capture.typeSize != nil {
            XCTAssertTrue(stacked, "AX3 forced: tabs stack vertically (\(a.frame) / \(b.frame))", file: file, line: line)
        } else {
            XCTAssertFalse(stacked, "default type size: tabs share a row", file: file, line: line)
        }
    }

    /// Proves Dark Mode took effect by measuring the screen: mean luminance of
    /// the screenshot is low in dark, high in light (cream background).
    private func verifyAppearance(_ capture: RecipeCapture, file: StaticString = #filePath, line: UInt = #line) {
        let luminance = Self.meanLuminance(app.screenshot().image)
        if capture.dark {
            XCTAssertLessThan(luminance, 0.35, "Dark Mode forced: screen luminance \(luminance)", file: file, line: line)
        } else {
            XCTAssertGreaterThan(luminance, 0.6, "light appearance: screen luminance \(luminance)", file: file, line: line)
        }
    }

    static func meanLuminance(_ image: UIImage) -> Double {
        guard let cg = image.cgImage else { return -1 }
        let w = 24, h = 48
        var px = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return -1 }
        ctx.interpolationQuality = .medium
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        var total = 0.0
        for i in stride(from: 0, to: px.count, by: 4) {
            total += 0.2126 * Double(px[i]) + 0.7152 * Double(px[i + 1]) + 0.0722 * Double(px[i + 2])
        }
        return total / Double(w * h) / 255
    }

    /// Mean luminance of the bare page in the gap just below the recipe tabs
    /// (the track ends 4 pt below the buttons; content starts 22 pt later).
    /// The same spot in every layout, so the iPad sidebar, the tab bar, the
    /// cook bar and the hero photo never count.
    func pageLuminance(file: StaticString = #filePath, line: UInt = #line) -> Double {
        let first = app.buttons["recipe-tab-ingredients"], last = app.buttons["recipe-tab-timing"]
        guard first.waitForExistence(timeout: 5), last.exists else {
            XCTFail("recipe tabs not found", file: file, line: line); return -1
        }
        // Bring the tabs to the upper middle, clear of the cook bar.
        let screen = app.frame
        for _ in 0..<3 where first.frame.maxY > screen.height * 0.6 || first.frame.minY < screen.minY + 100 {
            let delta = max(-screen.height * 0.45, min(screen.height * 0.45, first.frame.midY - screen.midY))
            let startY = delta >= 0 ? 0.70 : 0.30
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
                .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY - Double(delta / screen.height))),
                       withVelocity: .default, thenHoldForDuration: 0.3)
            Thread.sleep(forTimeInterval: 0.4)
        }
        Thread.sleep(forTimeInterval: 0.5) // let a sheet dismissal or color change finish
        let shot = app.screenshot().image
        guard let cg = shot.cgImage, screen.width > 0 else { return -1 }
        let scale = CGFloat(cg.width) / screen.width
        let x0 = first.frame.minX, x1 = last.frame.maxX, y0 = first.frame.maxY + 9
        let rect = CGRect(x: x0 * scale, y: y0 * scale, width: (x1 - x0) * scale, height: 10 * scale).integral
        guard let strip = cg.cropping(to: rect) else { return -1 }
        return Self.meanLuminance(UIImage(cgImage: strip))
    }

    private func onRecipePage(_ capture: RecipeCapture) {
        verifyTypeSize(capture)
        verifyAppearance(capture)
    }

    /// r01 — the Recipes destination with an empty library.
    func flowRecipeLibraryEmpty() {
        launchRecipes([], .standard)
        openRecipesLibrary()
        let add = app.buttons["add-recipe"]
        scrollTo(add)
        XCTAssertTrue(app.staticTexts["Cook your own recipes, on time."].exists, "empty state explains the feature")
        photograph("r01-library-empty")
    }

    /// r02, r04, r04b, r05 — unreviewed page, cook gate, duration editor
    /// (Save pinned, disabled until changed, Cancel discards), confirmation.
    func flowRecipeReviewGate(_ capture: RecipeCapture = .standard) {
        launchRecipes([RecipeFixtureText.frozenBerry], capture)
        XCTAssertTrue(app.staticTexts["Selected: Steak night"].waitForExistence(timeout: 10), "seeded dinner")
        openRecipe(RecipeFixtureText.frozenBerryTitle)
        onRecipePage(capture)
        XCTAssertTrue(app.buttons["timing-review-banner"].exists, "an imported recipe asks for a timing check")
        photograph("r02-recipe-unreviewed" + capture.suffix)

        let cook = app.buttons["cook-this-recipe"]
        XCTAssertTrue(cook.label.contains("Check timing"), "the primary action asks for the check first: \(cook.label)")
        cook.tap()
        let confirm = app.buttons["timing-looks-right"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "the cook action opened the Timing tab")
        XCTAssertTrue(app.buttons["recipe-tab-timing"].isSelected, "Timing is the selected tab")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'This is tonight'")).firstMatch.exists,
                       "opening Timing did not change tonight’s dinner")

        let freezer = app.buttons.matching(NSPredicate(format: "label CONTAINS '180 minutes'")).firstMatch
        scrollAndTap(freezer, "the three-hour freezer step’s minutes")
        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "the duration editor opened")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '3 hr' OR label CONTAINS '180'")).firstMatch.exists,
                      "it shows the three-hour freezer time")
        // A2-R7: Save is pinned in view, disabled until the value changes,
        // and Cancel discards a change.
        let save = app.buttons["Save estimate"]
        XCTAssertTrue(save.exists && save.isHittable, "Save is visible without scrolling")
        XCTAssertFalse(save.isEnabled, "nothing to save yet")
        photograph("r04-duration-180" + capture.suffix)
        app.steppers.firstMatch.buttons["Increment"].tap()
        XCTAssertTrue(save.isEnabled, "a changed estimate can be saved")
        photograph("r04b-duration-181" + capture.suffix)
        cancel.tap()
        waitForDisappearance(cancel, "editor closed")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS '180 minutes'")).firstMatch.exists,
                      "Cancel discarded the change")

        tapPinned(app.buttons["timing-looks-right"], "Timing looks right (pinned footer, A2-R8)")
        waitForDisappearance(app.buttons["timing-looks-right"], "the review is recorded")
        let cookNow = app.buttons["cook-this-recipe"]
        XCTAssertTrue(cookNow.label.contains("Cook this for dinner"), "after review the recipe can be cooked: \(cookNow.label)")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'This is tonight'")).firstMatch.exists,
                       "confirming did not choose the recipe as tonight’s dinner")
        photograph("r05-timing-confirmed" + capture.suffix)
        tapPinned(cookNow, "Choose the reviewed recipe for dinner")
        XCTAssertTrue(app.staticTexts["Selected: \(RecipeFixtureText.frozenBerryTitle)"].waitForExistence(timeout: 5),
                      "choosing a recipe routes to Tonight without starting cooking")
        XCTAssertTrue(app.buttons["open-recipes"].exists, "Tonight keeps the Recipes shortcut")

        // Tonight names the recipe (Joe, build 10) — the card opens its page,
        // and "Back to Tonight" from there lands on Tonight, not the collection.
        let card = app.buttons["tonight-recipe"]
        scrollTo(card)
        XCTAssertTrue(card.label.hasPrefix(RecipeFixtureText.frozenBerryTitle), "Tonight shows which recipe is being made: \(card.label)")
        photograph("r17-tonight-recipe" + capture.suffix)
        card.tap()
        waitForExistence(app.staticTexts["recipe-title"], timeout: 10, "the card opened the recipe page")
        let back = app.buttons["cook-this-recipe"]
        XCTAssertTrue(back.label.contains("Back to Tonight"), "tonight’s recipe offers the way back: \(back.label)")
        tapPinned(back, "Back to Tonight")
        XCTAssertTrue(app.staticTexts["Selected: \(RecipeFixtureText.frozenBerryTitle)"].waitForExistence(timeout: 5),
                      "Back to Tonight shows Tonight")
        XCTAssertFalse(app.buttons["add-recipe"].exists, "…not the recipe collection")
    }

    /// r03 — an untimed step stays marked as an estimate.
    func flowRecipeEstimate(_ capture: RecipeCapture = .standard) {
        launchRecipes([RecipeFixtureText.beanSpread], capture)
        openRecipe(RecipeFixtureText.beanSpreadTitle)
        onRecipePage(capture)
        app.buttons["recipe-tab-timing"].tap()
        let estimated = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Estimated time'")).firstMatch
        scrollTo(estimated)
        XCTAssertTrue(estimated.exists, "the untimed step stays marked as an estimate")
        photograph("r03-timing-estimate" + capture.suffix)
        let confirm = app.buttons["timing-looks-right"]
        XCTAssertTrue(confirm.exists && confirm.isHittable, "the confirmation is reachable on Timing (pinned footer)")
    }

    /// r02 and r03 in another appearance, each from a fresh launch.
    func flowRecipePageAndEstimate(_ capture: RecipeCapture) {
        launchRecipes([RecipeFixtureText.frozenBerry], capture)
        openRecipe(RecipeFixtureText.frozenBerryTitle)
        onRecipePage(capture)
        photograph("r02-recipe-unreviewed" + capture.suffix)
        flowRecipeEstimate(capture)
    }

    /// r06 — an Apple News link explains itself and switches to Screenshots.
    func flowAppleNewsLink(_ capture: RecipeCapture = .standard) {
        launchRecipes([], capture, extra: ["-dt-stub-apple-news"])
        openRecipesLibrary()
        scrollAndTap(app.buttons["add-recipe"], "Add a recipe")
        let field = app.textFields["recipe-link"]
        waitForExistence(field, timeout: 5, "the link field")
        field.tap()
        field.typeText("https://apple.news/KHuRjSBKDOACcBIjqE6y9tg")
        let importButton = app.buttons["import-recipe"]
        if !importButton.isHittable { scrollTo(importButton) }
        importButton.tap()
        let error = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Apple News'")).firstMatch
        XCTAssertTrue(error.waitForExistence(timeout: 10), "the Apple News explanation appears")
        XCTAssertTrue(app.descendants(matching: .any)["choose-screenshots"].exists, "the sheet switched to Screenshots and stayed open")
        if capture.typeSize != nil { scrollTo(error) }
        photograph("r06-apple-news-link" + capture.suffix)
    }

    /// r07 — a confirmation that can’t be saved says so and stays unreviewed.
    func flowTimingSaveFailure() {
        launchRecipes([RecipeFixtureText.frozenBerry], .standard, extra: ["-dt-fail-recipe-saves"])
        openRecipe(RecipeFixtureText.frozenBerryTitle)
        app.buttons["recipe-tab-timing"].tap()
        tapPinned(app.buttons["timing-looks-right"], "Timing looks right (pinned footer, A2-R8)")
        let problem = app.descendants(matching: .any)["recipe-save-error"]
        XCTAssertTrue(problem.waitForExistence(timeout: 5), "the save problem is shown")
        XCTAssertTrue(app.buttons["timing-looks-right"].exists, "the recipe is still unreviewed and the action is still reachable")
        scrollToTop()
        photograph("r07-save-error")
    }

    /// r08 — the Thanksgiving card on Tonight.
    func flowThanksgivingCard() {
        launchRecipes([], .standard)
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Thanksgiving, together'")).firstMatch
        scrollTo(card)
        XCTAssertTrue(card.exists, "the holiday menu is on Tonight")
        photograph("r08-thanksgiving")
    }

    /// r09 — a delete that can’t be saved keeps the recipe and says so.
    /// Delete is a button at the end of the page (not a ••• item: a dialog
    /// from a closing menu was dropped on iPhone in every CI run).
    func flowDeleteFailure() {
        launchRecipes([RecipeFixtureText.frozenBerry], .standard, extra: ["-dt-fail-recipe-saves"])
        openRecipe(RecipeFixtureText.frozenBerryTitle)
        XCTAssertFalse(app.buttons["Delete recipe"].exists, "Delete is no longer a menu item")
        let deleteButton = app.buttons["delete-recipe"]
        scrollTo(deleteButton)
        photograph("r09a-delete-button")   // the resting end-of-page action (A2-17)
        deleteButton.tap()
        let question = app.staticTexts["Delete this recipe?"]
        waitForExistence(question, timeout: 5, "the delete confirmation")
        photograph("r09b-delete-dialog")
        // Cancel keeps the recipe and the page (A2-17).
        tapEvenInPopover(app.buttons.matching(NSPredicate(format: "label == 'Cancel'")).firstMatch)
        waitForDisappearance(question, "Cancel closed the confirmation")
        XCTAssertTrue(app.staticTexts["recipe-title"].exists, "Cancel: still on the recipe page")
        XCTAssertFalse(app.descendants(matching: .any)["recipe-save-error"].exists, "Cancel: nothing to explain")
        scrollAndTap(deleteButton, "Delete this recipe, again")
        waitForExistence(question, timeout: 5, "the delete confirmation, again")
        let confirmDelete = app.buttons.matching(NSPredicate(format: "label == 'Delete recipe'")).firstMatch
        tapEvenInPopover(confirmDelete)
        waitForDisappearance(question, "the confirmation closed")
        XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout: 5), "still on the recipe page: nothing was deleted")
        let problem = app.descendants(matching: .any)["recipe-save-error"]
        XCTAssertTrue(problem.waitForExistence(timeout: 5), "the failure is explained")
        XCTAssertTrue(problem.label.contains("couldn’t be deleted"), "…in words about deleting: \(problem.label)")
        scrollToTop()
        photograph("r09-delete-failed")
    }

    /// r10 — a landscape hero photo stays screen-width; the page can’t scroll sideways.
    func flowHeroPhoto(_ capture: RecipeCapture = .standard) {
        launchRecipes([RecipeFixtureText.frozenBerry], capture, heroPhoto: true)
        openRecipe(RecipeFixtureText.frozenBerryTitle)
        let title = app.staticTexts["recipe-title"]
        let window = app.windows.firstMatch.frame
        XCTAssertLessThanOrEqual(title.frame.maxX, window.maxX + 1, "the title fits the screen")
        let before = title.frame.minX
        title.swipeLeft()
        XCTAssertEqual(title.frame.minX, before, accuracy: 1, "the page does not scroll sideways")
        photograph("r10-hero-landscape" + capture.suffix)
    }

    // MARK: Cover crop (A2-13). Agent 1's PR #8 flows, run inside the main
    // classes with the -dt-stub-screenshots source (two drawn screenshots:
    // a text page read by the real on-device recognizer, and a food photo).

    private func startScreenshotImport(_ extra: [String]) {
        launchRecipes([], .standard, extra: ["-dt-stub-screenshots"] + extra)
        openRecipesLibrary()
        scrollAndTap(app.buttons["add-recipe"], "Add a recipe")
        let segment = app.buttons["Screenshots"]
        waitForExistence(segment, timeout: 5, "the Screenshots option")
        segment.tap()
        waitForExistence(app.descendants(matching: .any)["choose-screenshots"], timeout: 5, "the stubbed screenshots")
    }

    private func chooseCoverCrop() {
        scrollAndTap(app.buttons["choose-cover"], "Choose a cover from screenshots")
        let source = app.descendants(matching: .any)["cover-source"]
        waitForExistence(source, timeout: 10, "the cover source picker")
        // The food photo is the second stubbed screenshot.
        tapEvenInPopover(source)
        let second = app.buttons["Screenshot 2"].firstMatch
        if second.waitForExistence(timeout: 5) { tapEvenInPopover(second) }
        XCTAssertTrue(app.images["cover-preview"].waitForExistence(timeout: 5), "crop preview")
        XCTAssertTrue(app.sliders["cover-zoom"].exists && app.sliders["cover-horizontal"].exists && app.sliders["cover-vertical"].exists,
                      "zoom and position sliders")
        app.sliders["cover-zoom"].adjust(toNormalizedSliderPosition: 0.3)
        photograph("r11-cover-crop")
        tapPinned(app.buttons["use-cover-crop"], "Use this crop")
        XCTAssertTrue(app.images["Selected recipe cover"].waitForExistence(timeout: 5), "the cover shows in the form")
    }

    /// r11/r12 — screenshots → cover crop → Add → the recipe page shows the
    /// text the recognizer read and the cover as its hero.
    func flowCoverCropHappyPath() {
        startScreenshotImport([])
        chooseCoverCrop()
        let add = app.buttons["import-recipe"]
        XCTAssertTrue(add.label.contains("Add recipe"), "not in the retry state: \(add.label)")
        scrollAndTap(add, "Add recipe")
        let title = app.staticTexts["recipe-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 30), "the recipe page opens after on-device text recognition")
        XCTAssertTrue(title.label.contains("Cider"), "the recognizer read the title: \(title.label)")
        XCTAssertTrue(app.descendants(matching: .any)["recipe-hero"].exists, "the crop is the recipe’s hero")
        photograph("r12-cover-hero")
        app.buttons["recipe-tab-directions"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Freeze until solid'")).firstMatch.waitForExistence(timeout: 5),
                      "STEP 2 was read from the screenshot")
    }

    /// r13 — the recipe saves, the cover doesn’t: retry or continue, no duplicate.
    func flowCoverSaveFailureRetry() {
        startScreenshotImport(["-dt-fail-cover-saves"])
        chooseCoverCrop()
        scrollAndTap(app.buttons["import-recipe"], "Add recipe")
        let retry = app.buttons["import-recipe"]
        let relabeled = NSPredicate(format: "label CONTAINS 'Retry cover save'")
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: relabeled, object: retry)], timeout: 30), .completed,
                       "the button offers a retry, not a second add: \(retry.label)")
        XCTAssertTrue(app.buttons["continue-without-cover"].exists, "continue without cover is offered")
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'recipe is saved'")).firstMatch.exists,
                      "the error says the recipe itself is safe")
        photograph("r13-cover-retry")
        app.buttons["continue-without-cover"].tap()
        XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout: 10), "continuing opens the saved recipe")
        XCTAssertFalse(app.descendants(matching: .any)["recipe-hero"].exists, "no cover was attached")
    }

    // MARK: Page colors (Joe, Oct 12): photo colors, a chosen color, frosted cards.

    private func openPageColorFromMenu() {
        let more = app.buttons["More"]
        waitForExistence(more, timeout: 5, "the recipe’s More menu")
        let sheetDone = app.buttons["page-style-done"]
        // iPad: the menu is a popover and a tap can be swallowed while it
        // animates (same retry as the delete flow).
        for attempt in 0..<2 where !sheetDone.exists {
            tapEvenInPopover(more)
            let item = app.buttons["Page color"].firstMatch
            if item.waitForExistence(timeout: 5) { tapEvenInPopover(item) }
            if sheetDone.waitForExistence(timeout: attempt == 0 ? 5 : 8) { break }
        }
        waitForExistence(sheetDone, timeout: 1, "the Page color sheet")
    }

    private func closePageColorSheet() {
        let done = app.buttons["page-style-done"]
        done.tap()
        waitForDisappearance(done, "the Page color sheet closed")
    }

    private func swatch(_ id: String) -> XCUIElement { app.buttons["page-style-\(id)"] }

    /// Back to the top of a recipe page (the luminance check scrolls), so a
    /// photograph shows the page as it opens: hero first.
    private func scrollRecipeToTop() {
        let title = app.staticTexts["recipe-title"]
        for _ in 0..<6 {
            let before = title.frame.minY
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)))
            Thread.sleep(forTimeInterval: 0.4)
            if abs(title.frame.minY - before) < 1 { break }
        }
    }

    /// r14 — a photo recipe’s page takes the photo’s colors with frosted
    /// cards; ••• → Page color offers Match photo, seven colors and Classic
    /// cream, and Classic brings the light page back.
    func flowPhotoPageColors(_ capture: RecipeCapture = .standard) {
        launchRecipes([RecipeFixtureText.frozenBerry], capture, heroPhoto: true)
        openRecipe(RecipeFixtureText.frozenBerryTitle)
        XCTAssertTrue(app.descendants(matching: .any)["recipe-hero"].exists, "the photo is the hero")
        verifyTypeSize(capture)
        photograph("r14a-photo-colors" + capture.suffix)   // as it opens: the photo dissolving into the page
        let colored = pageLuminance()
        XCTAssertLessThan(colored, 0.35, "the page took the photo’s deep colors, not cream: luminance below the tabs \(colored)")
        app.buttons["recipe-tab-directions"].tap()
        XCTAssertTrue(app.staticTexts["STEP 1"].waitForExistence(timeout: 5), "directions on the colored page")
        photograph("r14b-photo-colors-directions" + capture.suffix)

        openPageColorFromMenu()
        verifySheetTypeSize(capture)
        XCTAssertTrue(swatch("match-photo").isSelected, "automatic shows as Match photo")
        for id in ["cider", "tomato", "olive", "saffron", "plum", "lagoon", "charcoal", "classic"] {
            XCTAssertTrue(swatch(id).exists, "the \(id) option is offered")
        }
        photograph("r14c-page-color-sheet" + capture.suffix)
        scrollAndTapSwatch("classic")
        XCTAssertTrue(swatch("classic").waitForSelection(), "Classic cream is now selected")
        closePageColorSheet()
        let cream = pageLuminance()
        if capture.dark {
            XCTAssertLessThan(cream, colored - 0.05, "Classic in Dark Mode: the dark cream page, darker than the photo's colors: \(cream) vs \(colored)")
        } else {
            XCTAssertGreaterThan(cream, 0.6, "Classic cream: the light page is back: luminance below the tabs \(cream)")
        }
        scrollRecipeToTop()
        photograph("r14d-photo-classic" + capture.suffix)
    }

    /// The sheet itself renders at the forced type size (A2-17): the helper
    /// text wraps to several large lines at AX3 and two small ones otherwise.
    private func verifySheetTypeSize(_ capture: RecipeCapture, file: StaticString = #filePath, line: UInt = #line) {
        let help = app.staticTexts["page-style-help"]
        guard help.waitForExistence(timeout: 5) else { return XCTFail("the sheet's helper text", file: file, line: line) }
        if capture.typeSize != nil {
            XCTAssertGreaterThan(help.frame.height, 90, "AX3 inside the sheet: helper text height \(help.frame.height)", file: file, line: line)
        } else {
            XCTAssertLessThan(help.frame.height, 70, "default type inside the sheet: helper text height \(help.frame.height)", file: file, line: line)
        }
    }

    /// At AX3 the grid is taller than the half-height sheet; scroll within it.
    private func scrollAndTapSwatch(_ id: String) {
        let target = swatch(id)
        for _ in 0..<6 where !(target.exists && target.isHittable) {
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
            from.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)),
                       withVelocity: .default, thenHoldForDuration: 0.3)
            Thread.sleep(forTimeInterval: 0.4)
        }
        tapEvenInPopover(target)
    }

    /// r15 — a typed recipe (no photo) picks a color from the page’s own
    /// button; the timer chips and step labels switch to the light accent.
    func flowTypedPageColor(_ capture: RecipeCapture = .standard, preset: String = "plum") {
        launchRecipes([RecipeFixtureText.beanSpread], capture)
        openRecipe(RecipeFixtureText.beanSpreadTitle)
        let button = app.buttons["page-color-button"]
        waitForExistence(button, timeout: 5, "the Page color button on a typed recipe")
        verifyTypeSize(capture)
        photograph("r15a-typed-cream" + capture.suffix)
        let start = pageLuminance()
        if capture.dark {
            XCTAssertLessThan(start, 0.35, "a typed recipe starts on the (dark) cream page: \(start)")
        } else {
            XCTAssertGreaterThan(start, 0.6, "a typed recipe starts on the cream page: \(start)")
        }
        scrollRecipeToTop()
        button.tap()
        waitForExistence(app.buttons["page-style-done"], timeout: 5, "the Page color sheet")
        verifySheetTypeSize(capture)
        XCTAssertFalse(swatch("match-photo").exists, "no Match photo without a photo")
        XCTAssertTrue(swatch("classic").isSelected, "automatic without a photo shows as Classic cream")
        scrollAndTapSwatch(preset)
        XCTAssertTrue(swatch(preset).waitForSelection(), "\(preset) is now selected")
        photograph("r15b-\(preset)-sheet" + capture.suffix)
        closePageColorSheet()
        let colored = pageLuminance()
        XCTAssertLessThan(colored, 0.35, "the page is \(preset): \(colored)")
        if capture.dark {
            XCTAssertGreaterThan(colored, start + 0.05, "\(preset) in Dark Mode is brighter than the dark cream page: \(colored) vs \(start)")
        }
        scrollRecipeToTop()
        photograph("r15c-typed-\(preset)" + capture.suffix)
        app.buttons["recipe-tab-directions"].tap()
        XCTAssertTrue(app.staticTexts["STEP 1"].waitForExistence(timeout: 5), "directions on the \(preset) page")
        photograph("r15d-typed-\(preset)-directions" + capture.suffix)
    }

    /// r16 — a color that can’t be saved says so and the page stays as it was.
    func flowPageColorSaveFailure(_ capture: RecipeCapture = .standard) {
        launchRecipes([RecipeFixtureText.beanSpread], capture, extra: ["-dt-fail-recipe-saves"])
        openRecipe(RecipeFixtureText.beanSpreadTitle)
        let button = app.buttons["page-color-button"]
        waitForExistence(button, timeout: 5, "the Page color button")
        button.tap()
        waitForExistence(app.buttons["page-style-done"], timeout: 5, "the Page color sheet")
        scrollAndTapSwatch("lagoon")
        let problem = app.descendants(matching: .any)["page-style-error"]
        XCTAssertTrue(problem.waitForExistence(timeout: 5), "the save problem is shown in the sheet")
        XCTAssertTrue(problem.label.contains("page color couldn’t be saved"), "…in words about the page color: \(problem.label)")
        if capture.typeSize == nil { XCTAssertTrue(problem.isHittable, "…and it is visible without scrolling the sheet") }
        XCTAssertFalse(swatch("lagoon").isSelected, "the failed choice is not shown as chosen")
        XCTAssertTrue(swatch("classic").isSelected, "the page’s real color stays selected")
        photograph("r16-page-color-save-failed" + capture.suffix)
        closePageColorSheet()
        XCTAssertGreaterThan(pageLuminance(), 0.6, "the page stayed cream")
    }
}

extension XCUIElement {
    /// Selection updates after the save and re-render; poll briefly.
    func waitForSelection(timeout: TimeInterval = 3) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if exists && isSelected { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return exists && isSelected
    }
}
