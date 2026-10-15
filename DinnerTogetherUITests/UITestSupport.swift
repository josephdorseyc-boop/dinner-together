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
                recipes: [String] = [], heroPhoto: Bool = false, photo: String? = nil,
                recipeWarnings: [[String]] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["DT_SEED_JSON"] = seed
        // Always set, like the texts, so warnings never leak between tests.
        let warningData = (try? JSONSerialization.data(withJSONObject: recipeWarnings)) ?? Data("[]".utf8)
        app.launchEnvironment["DT_SEED_RECIPE_WARNINGS"] = String(decoding: warningData, as: UTF8.self)
        // "landscape" (the warm still life) or "pastel" (pale icing); empty = no photo.
        app.launchEnvironment["DT_SEED_RECIPE_PHOTO"] = photo ?? (heroPhoto ? "landscape" : "")
        // Always set, so recipes from one test never appear in another.
        let recipeData = (try? JSONSerialization.data(withJSONObject: recipes)) ?? Data("[]".utf8)
        app.launchEnvironment["DT_SEED_RECIPE_TEXTS"] = String(decoding: recipeData, as: UTF8.self)
        app.launchArguments += (openCooking ? ["-dt-open-cooking"] : []) + ["-dt-inert-reminders", "-dt-sample-menus"] + extraLaunchArguments
        app.launch()
        self.app = app
        return app
    }

    /// Keep-always screenshot, named by flow and step. The harness exports
    /// these from the .xcresult into results/ui-screenshots/<device>/.
    func photograph(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        // Also straight to the results folder when the harness names one
        // (DT_SHOT_DIR): the Duo run's result bundle could not be read, and
        // with it went every capture (run 38723119849).
        if let dir = ProcessInfo.processInfo.environment["DT_SHOT_DIR"], !dir.isEmpty {
            let safe = name.replacingOccurrences(of: "/", with: "-")
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(safe).png"))
        }
    }

    /// The accessibility hierarchy as text, kept always — readable from the
    /// results branch when a tap "did nothing" and XCTest's own dump is not
    /// exported (iPad, runs 20–21).
    func attachHierarchy(_ name: String) {
        let text = app.debugDescription
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["DT_SHOT_DIR"], !dir.isEmpty {
            try? text.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).txt"), atomically: true, encoding: .utf8)
        }
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
    /// The part of the screen an element must sit in to be "on screen":
    /// below the status bar, above the tab bar and any pinned bottom bar.
    func comfortZone(excluding f: CGRect) -> (top: CGFloat, bottom: CGFloat) {
        let screen = app.frame
        // The tab bar only matters when it is actually on top (not under a sheet).
        let tabBar = app.tabBars.firstMatch
        var bottomBand: CGFloat = (tabBar.exists && tabBar.isHittable) ? 130 : 40
        // A pinned bottom bar covers more than that at large type (AX3: the
        // 120 pt cook button plus its caption; run 38335694569 tapped a step
        // that sat under it). Measure the bar instead of assuming it.
        if let barTop = pinnedBarTop(excluding: f), barTop < screen.maxY - bottomBand {
            bottomBand = screen.maxY - barTop + 8
        }
        return (screen.minY + 60, screen.maxY - bottomBand)
    }

    func isComfortablyVisible(_ element: XCUIElement) -> Bool {
        guard element.exists, element.isHittable else { return false }
        let screen = app.frame
        let f = element.frame
        let (zoneTop, zoneBottom) = comfortZone(excluding: f)
        // An element taller than the zone (an AX3 paragraph) can never fit
        // whole; its top inside the zone is what "on screen" can mean.
        if f.height > zoneBottom - zoneTop {
            return f.minY >= zoneTop && f.minY <= zoneBottom - 44
        }
        // Top band: the status bar plus a little; a navigation bar that
        // actually covers the element already makes it non-hittable. (iPad's
        // "Adjust time" sits ~100 pt from the top and never scrolls higher —
        // run 16.)
        return f.minY >= screen.minY + 60 && f.maxY <= zoneBottom
    }

    /// Frame-in-zone without the hittability requirement (A1, issue #22): for
    /// scrollTo callers that only read the element, or tap it by position.
    /// At AX3 XCTest reported Tonight's correctly placed recipe title as not
    /// hittable (runs 38610973412, 38628522264: test18, test42).
    func isFrameInComfortZone(_ element: XCUIElement) -> Bool {
        guard element.exists else { return false }
        let screen = app.frame
        let f = element.frame
        let (zoneTop, zoneBottom) = comfortZone(excluding: f)
        if f.height > zoneBottom - zoneTop {
            return f.minY >= zoneTop && f.minY <= zoneBottom - 44
        }
        return f.minY >= screen.minY + 60 && f.maxY <= zoneBottom
    }

    /// The top edge of whichever pinned bottom control is on screen (the
    /// recipe page's cook action, the editors' Save, Tonight's plan button).
    func pinnedBarTop(excluding target: CGRect) -> CGFloat? {
        let pinned = NSPredicate(format: "identifier IN %@ OR label BEGINSWITH 'Build ' OR label == 'Back to cooking' OR label BEGINSWITH 'Save '",
                                 ["cook-this-recipe", "timing-looks-right", "use-cover-crop", "recipe-time-save"])
        // The captions above the pinned buttons are part of the bar too
        // (at AX3 "Selected: …" is four lines tall — run 38365885474 tapped
        // Tonight's recipe card under it).
        let captions = NSPredicate(format: "label BEGINSWITH 'Selected: ' OR label BEGINSWITH 'This is tonight'")
        let bars = app.buttons.matching(pinned).allElementsBoundByIndex + app.staticTexts.matching(captions).allElementsBoundByIndex
        // A pinned control sits in the bottom quarter and is never the target
        // itself (run 38341383318: the Add sheet's own button counted as a bar).
        let tops = bars.filter { $0.exists && $0.frame.height > 0 && $0.frame.maxY <= app.frame.maxY + 1
                                 && $0.frame.minY > app.frame.maxY * 0.6 && $0.frame != target }.map { $0.frame.minY }
        return tops.min()
    }

    func scrollTo(_ element: XCUIElement, maxDrags: Int = 12, requireHittable: Bool = true,
                  file: StaticString = #filePath, line: UInt = #line) {
        var drags = 0
        let visible = { (e: XCUIElement) -> Bool in
            requireHittable ? self.isComfortablyVisible(e) : self.isFrameInComfortZone(e)
        }
        while !visible(element) && drags < maxDrags {
            let screen = app.frame
            // Aim the element at the middle of the screen; if it doesn't exist
            // yet, page downward. A short hold at the end stops the scroll view
            // from decelerating past the target.
            var delta = screen.height * 0.4
            if element.exists {
                // Aim at the middle of the visible zone, not of the screen:
                // at AX3 Tonight's pinned bar covers the bottom third, and an
                // element centred on the screen still ran under it with a
                // zero-length drag every time (runs 38610973412,
                // 38628522264; A2's read of 38588198150). An element taller
                // than the zone is aimed by its top.
                let f = element.frame
                let zone = comfortZone(excluding: f)
                delta = f.height > zone.bottom - zone.top - 16 ? f.minY - (zone.top + 24)
                                                             : f.midY - (zone.top + zone.bottom) / 2
                delta = max(-screen.height * 0.45, min(screen.height * 0.45, delta))
                if abs(delta) < 4 { delta = delta < 0 ? -12 : 12 } // never a zero-length drag
            }
            // Start above the pinned bottom bar: at AX3 the bar (caption +
            // button + tab bar) reaches up to ~0.68 of the screen, and a drag
            // that starts on it scrolls nothing (run 38330367116, test18:
            // twelve identical drags).
            let start = dragStart(preferring: delta >= 0 ? 0.55 : 0.30)
            let endY = max(0.12, min(0.92, start.dy - Double(delta / screen.height)))
            let from = app.coordinate(withNormalizedOffset: start)
            let to = app.coordinate(withNormalizedOffset: CGVector(dx: start.dx, dy: endY))
            from.press(forDuration: 0.1, thenDragTo: to, withVelocity: .default, thenHoldForDuration: 0.3)
            Thread.sleep(forTimeInterval: 0.4)   // let the scroll view settle before the next query or tap
            drags += 1
        }
        if !visible(element) {
            let zone = element.exists ? comfortZone(excluding: element.frame) : (top: 0, bottom: 0)
            XCTFail("element not comfortably on screen after \(drags) scroll(s): \(element) — frame \(element.exists ? element.frame : .zero), "
                    + "hittable \(element.exists && element.isHittable), zone \(zone.top)…\(zone.bottom), screen \(app.frame)", file: file, line: line)
        }
    }

    /// Taps an element that may sit in a popover (iPad confirmation dialogs
    /// report their buttons as not hittable — run 14, test02 on iPad); falls
    /// back to a tap at the element's center (A3-U-F10).
    func tapEvenInPopover(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        waitForExistence(element, timeout: 10, "element to tap exists: \(element)", file: file, line: line)
        // Never ask isHittable of a menu item or popover button: XCTest records
        // "Failed to determine hittability … Activation point invalid" as a
        // failure while the menu animates (run 38356617072, the cover source
        // menu; the build-7 alert before it). A finite on-screen frame is
        // the condition a coordinate tap needs, so wait for that and tap.
        if waitForOnScreenFrame(element, timeout: 6) {
            usleep(250_000) // let the menu finish animating into place
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

    /// For a photograph only: a few drags until the element's top is in the
    /// middle band of the screen. No assertion — a tall AX3 paragraph at the
    /// end of a sheet can never be "comfortably" visible (run 38399682685).
    func bringIntoView(_ element: XCUIElement) {
        let screen = app.frame
        for _ in 0..<6 {
            guard element.exists else { return }
            let top = element.frame.minY
            if top >= screen.minY + 80 && top <= screen.midY + 40 { return }
            let delta = max(-screen.height * 0.4, min(screen.height * 0.4, top - screen.midY + 60))
            let start = dragStart(preferring: delta >= 0 ? 0.55 : 0.30)
            app.coordinate(withNormalizedOffset: start)
                .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: start.dx, dy: max(0.12, min(0.92, start.dy - Double(delta / screen.height))))),
                       withVelocity: .default, thenHoldForDuration: 0.3)
            Thread.sleep(forTimeInterval: 0.4)
        }
    }

    /// A point to start a drag from that is not on a button: run
    /// 38399682685's recording shows the Apple News AX3 positioning drag
    /// starting on "Choose screenshots" and opening Photos instead of
    /// scrolling (A2-25). Tries the preferred height first, then nearby ones,
    /// at the center column and then to its left where cards have margins.
    func dragStart(preferring y: Double) -> CGVector {
        let screen = app.frame
        let buttons = app.buttons.allElementsBoundByIndex.map { $0.frame }.filter { $0.height > 0 }
        // The center column at other heights before a side column: on iPad a
        // side column can fall outside a form sheet.
        for dx in [0.5, 0.12, 0.88] {
            for dy in [y, y - 0.08, y + 0.08, y - 0.16, y + 0.16] where dy > 0.1 && dy < 0.9 {
                let p = CGPoint(x: screen.minX + screen.width * dx, y: screen.minY + screen.height * dy)
                if !buttons.contains(where: { $0.contains(p) }) { return CGVector(dx: dx, dy: dy) }
            }
        }
        return CGVector(dx: 0.5, dy: y)
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
        waitForStableFrame(element)
        element.tap()
    }

    /// Waits until the element's frame stops moving. After "Move dinner" the
    /// notice leaves and the timeline re-lays out; run 38399682685's event
    /// trace shows the Undo tap landing at the point where Undo had been a
    /// moment earlier, which the Completed disclosure then occupied (A2-25,
    /// issue #17). A tap on a settled frame cannot miss that way.
    @discardableResult
    func waitForStableFrame(_ element: XCUIElement, timeout: TimeInterval = 4) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        var last = element.frame
        while Date() < deadline {
            Thread.sleep(forTimeInterval: 0.25)
            let now = element.frame
            if element.exists, now == last, now.height > 0 { return true }
            last = now
        }
        return false
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

    /// The time-only part of a proposed moment. Across midnight the app's
    /// buttons say "Move dinner to Oct 14, 2026 at 12:14 AM" (formatMoment
    /// qualifies another day), while DINNER AT only ever shows the time —
    /// run 38484344610 compared the two verbatim (A2's read of the log).
    func timeOnly(_ moment: String) -> String {
        if let range = moment.range(of: " at ", options: .backwards) { return String(moment[range.upperBound...]) }
        return moment
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
        let target = timeOnly(moveButton.label.replacingOccurrences(of: "Move dinner to ", with: ""))
        XCTAssertNotEqual(target, before, "the move proposes a different time")
        moveButton.tap()

        waitForServingTimeValue(oneOf: [target, plusOneMinute(target)])
        XCTAssertNotEqual(servingTimeValue, before)
        waitForDisappearance(app.buttons["Review dinner time"], "the notice is gone once dinner moves")
        photograph("01-after-move")

        let undo = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Undo: '")).firstMatch
        scrollAndTap(undo, "undo is offered after the move")
        // The readout is read before anything else moves: a wrong-control
        // tap (the Completed disclosure) shows up here as the unchanged time,
        // with the frame of what was tapped in the failure message.
        // A1 #21: `.id(serveAt)` recreates the DINNER AT element on undo; on
        // iPad under full-run load that can take longer than 10 s. Settle,
        // then wait 15 s there; the expected value is unchanged.
        func restoredNow() -> Bool {
            Thread.sleep(forTimeInterval: 1)
            return XCTWaiter().wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label == %@", "Chosen dinner time \(before)"),
                object: app.staticTexts["serving-time"])], timeout: app.frame.width > 700 ? 15 : 10) == .completed
        }
        var restored = restoredNow()
        if !restored, undo.exists {
            // The undo is still offered, so nothing was undone: the tap
            // missed (run 38484344610's retry: Undo at y 3358 when tapped).
            // One more, from a fresh scroll — recorded so a flake is visible.
            photograph("01-undo-tap-missed")
            scrollAndTap(undo, "undo, second attempt")
            restored = restoredNow()
        }
        scrollToTop()
        photograph("01-after-undo")  // before asserting: the failure state is evidence too (A2)
        XCTAssertTrue(restored, "DINNER AT returned to \(before) right after the Undo tap (still '\(servingTimeValue)'; undo button now \(undo.exists ? "\(undo.frame)" : "gone"))")
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
        // The dinner's picture leads RIGHT NOW, and still the urgent action
        // is on the first screen, unscrolled (Joe and A2-35, October 13).
        photograph("04-expired-hero-first-screen")
        XCTAssertTrue(waitForOnScreenFrame(markDone), "Mark done after checking exists on screen: \(markDone.frame)")
        XCTAssertLessThanOrEqual(markDone.frame.maxY, app.frame.maxY - 90,
                                 "…above the tab bar on the first screen, with the hero: \(markDone.frame) in \(app.frame)")
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

    /// Flow 9 — Tonight on first launch (Joe, October 14: the app brings no
    /// dinners of its own): nothing chosen, the dinner-time card says so, the
    /// footer's action is "Add your first recipe" and opens the Add sheet in
    /// Recipes; Cooking says nothing is cooking yet; the Thanksgiving card
    /// is the one built-in dinner, and choosing it updates the footer and
    /// builds a plan.
    func flowTonightFirstLaunch() {
        launch(seed: UISeed.tonight(now: Date(), menuID: ""), openCooking: false)
        var action = app.buttons["tonight-primary"].firstMatch
        waitForExistence(action, timeout: 10, "Tonight with its primary action")
        XCTAssertTrue(action.isHittable, "the primary action is on screen before any scrolling (bottom inset)")
        XCTAssertTrue(action.label.contains("Add your first recipe"), "an empty cookbook's action: \(action.label)")
        XCTAssertTrue(app.staticTexts["Nothing chosen for tonight yet"].waitForExistence(timeout: 5), "the footer says nothing is chosen")
        XCTAssertTrue(app.descendants(matching: .any)["table-time-no-dinner"].exists, "the dinner-time card asks for a recipe")
        XCTAssertTrue(app.descendants(matching: .any)["empty-cookbook"].exists, "the empty-cookbook card")
        XCTAssertTrue(app.descendants(matching: .any)["tonight-cover"].exists, "A2's default photo is the cover, never a bare page")
        XCTAssertFalse(app.buttons["open-recipes"].exists, "no Choose from Recipes with nothing to choose from")
        XCTAssertFalse(app.staticTexts["ON THE MENU"].exists, "no built-in dinners")
        photograph("09-tonight-first-launch")

        // The footer's action opens Add recipe in Recipes.
        action.tap()
        let importButton = app.buttons["import-recipe"].firstMatch
        waitForExistence(importButton, timeout: 10, "the Add recipe sheet, from Tonight")
        photograph("09-add-recipe-from-tonight")
        let cancel = app.buttons["Cancel"].firstMatch
        if cancel.waitForExistence(timeout: 3) { tapEvenInPopover(cancel) } else { app.swipeDown() }
        waitForDisappearance(importButton, "the Add sheet closed")
        let addButtons = app.buttons.matching(identifier: "add-recipe")
        XCTAssertTrue(addButtons.firstMatch.waitForExistence(timeout: 5), "Recipes offers the first recipe too")
        XCTAssertEqual(addButtons.count, 1, "…with one Add button, not two (Joe, build 18)")
        XCTAssertEqual(addButtons.firstMatch.label, "Add your first recipe")

        // Cooking with nothing chosen (its own launch: the sidebar on iPad
        // is collapsed in portrait, and no flow drives it).
        launch(seed: UISeed.tonight(now: Date(), menuID: ""), openCooking: true)
        waitForExistence(app.descendants(matching: .any)["cooking-empty"], timeout: 10, "Cooking says nothing is cooking yet")
        photograph("09-cooking-empty")

        // Thanksgiving is the one dinner the app brings.
        launch(seed: UISeed.tonight(now: Date(), menuID: ""), openCooking: false)
        action = app.buttons["tonight-primary"].firstMatch
        waitForExistence(action, timeout: 10, "Tonight again")
        let thanksgiving = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Thanksgiving, together'")).firstMatch
        scrollAndTap(thanksgiving, "the Thanksgiving card")
        let footer = app.staticTexts["Selected: Thanksgiving, together"]
        if !footer.waitForExistence(timeout: 4) {
            attachHierarchy("09-thanksgiving-after-tap-hierarchy")
            thanksgiving.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5)).tap()
        }
        XCTAssertTrue(footer.waitForExistence(timeout: 5), "choosing Thanksgiving updates the footer")
        XCTAssertTrue(action.isHittable, "the primary action is still on screen after scrolling")
        XCTAssertTrue(action.label.hasPrefix("Build"), "with a dinner the action builds the plan: \(action.label)")
        photograph("09-tonight-thanksgiving")
        // A second tap unchecks it: no dinner chosen (Joe, build 19); a third
        // chooses it again.
        scrollAndTap(thanksgiving, "the checked Thanksgiving card")
        XCTAssertTrue(app.staticTexts["Nothing chosen for tonight yet"].waitForExistence(timeout: 5), "tapping the checked card unchecks it")
        XCTAssertFalse(thanksgiving.isSelected, "…and it is no longer selected")
        photograph("09-tonight-thanksgiving-unchecked")
        scrollAndTap(thanksgiving, "the Thanksgiving card again")
        XCTAssertTrue(footer.waitForExistence(timeout: 5), "chosen again")
        XCTAssertTrue(action.isHittable, "the primary action is still on screen")
        action.tap()
        waitForExistence(app.staticTexts["serving-time"], timeout: 10, "cooking screen after Build")
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
    /// A2's fixture (PR #16): two visible directions standing for source
    /// steps 1 and 3; the seeded warning says step 2 was not found.
    static let missingTextTitle = "Missing text review"
    static let missingText = """
        Missing text review
        Total time: 3 minutes

        Ingredients
        - 1 cup water

        Directions
        1. Mix for 2 minutes.
        2. Serve for 1 minute.
        """
    static let missingTextWarning = "Source step 2 wasn’t found in the screenshots."

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
    /// No -dt-appearance: the simulator's own setting, as on a real phone
    /// (Joe's black clock on build 18 never showed with a forced appearance).
    var systemAppearance = false
    static let standard = RecipeCapture()
    static let ax3 = RecipeCapture(suffix: "-ax3", typeSize: "accessibility3")
    static let darkMode = RecipeCapture(suffix: "-dark", dark: true)
    static let solidCards = RecipeCapture(suffix: "-solid", extra: ["-dt-solid-cards"])
    static let system = RecipeCapture(suffix: "-system", systemAppearance: true)

    var launchArguments: [String] {
        let appearance = systemAppearance ? [] : (dark ? ["-dt-appearance", "dark"] : ["-dt-appearance", "light"])
        return (typeSize.map { ["-dt-type-size", $0] } ?? []) + appearance + extra
    }
}

extension DinnerTogetherUITestCase {
    private func launchRecipes(_ recipes: [String], _ capture: RecipeCapture, extra: [String] = [], heroPhoto: Bool = false,
                               photo: String? = nil, warnings: [[String]] = []) {
        launch(seed: UISeed.tonight(now: Date()), extraLaunchArguments: capture.launchArguments + extra,
               openCooking: false, recipes: recipes, heroPhoto: heroPhoto, photo: photo, recipeWarnings: warnings)
    }

    private func openRecipesLibrary() {
        let choose = app.buttons["open-recipes"]
        if choose.waitForExistence(timeout: 4) {
            scrollAndTap(choose, "Choose from Recipes")
        } else {
            // An empty cookbook has no "Choose from Recipes" on Tonight
            // (build 18): the Recipes tab on iPhone, the sidebar on iPad.
            let tab = app.tabBars.buttons["Recipes"].firstMatch
            if tab.exists {
                tab.tap()
            } else {
                let row = app.buttons["Recipes"].firstMatch.exists ? app.buttons["Recipes"].firstMatch
                    : app.staticTexts["Recipes"].firstMatch
                waitForExistence(row, timeout: 5, "the Recipes tab or sidebar row")
                row.tap()
            }
        }
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
        // A recipe without a photo is on Classic cream, which is cream in
        // Dark Mode too (Joe, build 19), so the page itself is light either
        // way; Dark Mode still shows in the bars and sheets (r02/r03 -dark).
        let luminance = Self.meanLuminance(app.screenshot().image)
        XCTAssertGreaterThan(luminance, 0.5, "the classic cream page\(capture.dark ? ", in Dark Mode too" : ""): screen luminance \(luminance)")
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
        scrollTo(card, requireHittable: false)  // A1: in place is enough; tapped by position below
        XCTAssertTrue(card.label.hasPrefix(RecipeFixtureText.frozenBerryTitle), "Tonight shows which recipe is being made: \(card.label)")
        photograph("r17-tonight-recipe" + capture.suffix)
        tapEvenInPopover(card)  // a coordinate tap: hittability is unreliable at AX3 (A1)
        waitForExistence(app.staticTexts["recipe-title"], timeout: 10, "the card opened the recipe page")
        let back = app.buttons["cook-this-recipe"]
        XCTAssertTrue(back.label.contains("Back to Tonight"), "tonight’s recipe offers the way back: \(back.label)")
        tapPinned(back, "Back to Tonight")
        XCTAssertTrue(app.staticTexts["Selected: \(RecipeFixtureText.frozenBerryTitle)"].waitForExistence(timeout: 5),
                      "Back to Tonight shows Tonight")
        XCTAssertFalse(app.buttons["add-recipe"].exists, "…not the recipe collection")
    }

    /// The review banner's missing-time cue: the full sentence, or A2-21's
    /// short form at accessibility sizes.
    private func bannerMentionsMissingTime() -> Bool {
        let label = app.buttons["timing-review-banner"].label
        return label.contains("No total time") || label.contains("Add recipe time")
    }

    /// r03 — an untimed step stays marked as an estimate.
    func flowRecipeEstimate(_ capture: RecipeCapture = .standard) {
        launchRecipes([RecipeFixtureText.beanSpread], capture)
        openRecipe(RecipeFixtureText.beanSpreadTitle)
        onRecipePage(capture)
        // No total time came with the text: the stat says so and takes one
        // (Joe, build 11). r18.
        let timeStat = app.buttons["recipe-time"]
        XCTAssertTrue(timeStat.waitForExistence(timeout: 5), "the recipe-time stat is a button")
        XCTAssertTrue(timeStat.label.contains("not stated"), "no total time yet: \(timeStat.label)")
        XCTAssertTrue(bannerMentionsMissingTime(), "the review banner warns about the missing time: \(app.buttons["timing-review-banner"].label)")
        scrollAndTap(timeStat, "Recipe time → Add time")
        let save = app.buttons["recipe-time-save"]
        waitForExistence(save, timeout: 5, "the Recipe time sheet")
        XCTAssertFalse(save.isEnabled, "nothing to save at zero")
        let minutesStepper = app.steppers.matching(NSPredicate(format: "label BEGINSWITH 'Minutes'")).firstMatch
        waitForExistence(minutesStepper, timeout: 5, "the minutes stepper")
        for _ in 0..<9 { minutesStepper.buttons["Increment"].tap() }
        XCTAssertTrue(app.staticTexts["recipe-time-value"].label.contains("45"), "45 minutes entered: \(app.staticTexts["recipe-time-value"].label)")
        photograph("r18-recipe-time-entry" + capture.suffix)
        tapPinned(save, "Save recipe time")
        waitForDisappearance(save, "the sheet closed")
        XCTAssertTrue(timeStat.label.contains("45 min"), "the page shows the entered time: \(timeStat.label)")
        XCTAssertFalse(bannerMentionsMissingTime(), "the warning is gone: \(app.buttons["timing-review-banner"].label)")
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
        // Keyboard down first: at AX3 the Add button sat under it, XCTest
        // still called it hittable, and the tap went to the keyboard
        // (run 38350049136: the sheet never left Link).
        let returnKey = app.keyboards.buttons.matching(NSPredicate(format: "label IN {'return', 'go', 'Return', 'Go', 'done', 'Done'}")).firstMatch
        if returnKey.waitForExistence(timeout: 2) { returnKey.tap() }
        let importButton = app.buttons["import-recipe"]
        scrollAndTap(importButton, "Add recipe")
        // The explanation itself, not the field's "Apple News" hint.
        let error = app.descendants(matching: .any)["import-error"]
        XCTAssertTrue(error.waitForExistence(timeout: 10), "the import explanation appears")
        XCTAssertTrue(error.label.contains("Apple News"), "…and it is about Apple News: \(error.label)")
        // At AX3 the picker sits below a long paragraph; its UIKit-backed
        // button is only exposed once scrolled near (run 38335694569).
        let chooser = app.descendants(matching: .any)["choose-screenshots"]
        for _ in 0..<6 where !chooser.exists {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
                .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)),
                       withVelocity: .default, thenHoldForDuration: 0.3)
            Thread.sleep(forTimeInterval: 0.4)
        }
        if !chooser.exists { attachHierarchy("r06-no-chooser-hierarchy" + capture.suffix); photograph("r06-no-chooser" + capture.suffix) }
        // The segmented control's selected segment is the switch itself; the
        // picker's own element is the usual proof.
        XCTAssertTrue(chooser.exists || app.buttons["Screenshots"].isSelected, "the sheet switched to Screenshots and stayed open")
        if capture.typeSize != nil { bringIntoView(error) }
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
        // Cancel keeps the recipe and the page (A2-17). iOS 26 shows this
        // dialog as a popover-style bubble with no Cancel button on iPhone
        // either (run 38330367116): tapping away is the cancel.
        let cancel = app.buttons.matching(NSPredicate(format: "label == 'Cancel'")).firstMatch
        if cancel.waitForExistence(timeout: 2) {
            tapEvenInPopover(cancel)
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        }
        waitForDisappearance(question, "Cancel (or tapping away) closed the confirmation")
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
        waitForExistence(second, timeout: 5, "Screenshot 2 is offered")
        tapEvenInPopover(second)
        let selectedSecond = NSPredicate { _, _ in
            source.exists && (source.label.contains("Screenshot 2") ||
                              (source.value as? String)?.contains("Screenshot 2") == true)
        }
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: selectedSecond, object: source)], timeout: 5),
                       .completed, "Screenshot 2 is selected, not just offered")
        XCTAssertTrue(app.images["cover-preview"].waitForExistence(timeout: 5), "crop preview")
        XCTAssertTrue(app.sliders["cover-zoom"].exists && app.sliders["cover-horizontal"].exists && app.sliders["cover-vertical"].exists,
                      "zoom and position sliders")
        let zoom = app.sliders["cover-zoom"]
        guard revealCoverZoom(zoom) else { return }
        photograph("r11a-cover-before-zoom")
        let beforeZoom = zoom.value as? String
        zoom.adjust(toNormalizedSliderPosition: 0.3)
        guard zoom.waitForExistence(timeout: 3) else {
            photograph("r11-zoom-unexpected-dismissal")
            attachHierarchy("r11-zoom-unexpected-dismissal-hierarchy")
            return XCTFail("Adjusting Zoom must not close the crop editor")
        }
        XCTAssertNotEqual(zoom.value as? String, beforeZoom, "Zoom actually changed")
        photograph("r11-cover-crop")
        tapPinned(app.buttons["use-cover-crop"], "Use this crop")
        XCTAssertTrue(app.images["Selected recipe cover"].waitForExistence(timeout: 5), "the cover shows in the form")
    }

    /// The slider may exist below a form sheet's visible scroll area. Never
    /// synthesize its gesture across the pinned Use action (Duo run 38448870850).
    private func revealCoverZoom(_ zoom: XCUIElement) -> Bool {
        let use = app.buttons["use-cover-crop"]
        // Descendant containment identifies the crop scroll view, not the
        // recipe form behind it; its frame is already in screen coordinates.
        let scroll = app.scrollViews.containing(.slider, identifier: "cover-zoom").firstMatch
        guard scroll.waitForExistence(timeout: 5), use.waitForExistence(timeout: 5) else {
            attachHierarchy("r11-crop-scroll-missing")
            XCTFail("The crop editor's scroll viewport and Use action must exist")
            return false
        }
        func viewport() -> CGRect {
            var v = scroll.frame.intersection(app.windows.firstMatch.frame)
            if isFiniteFrame(use.frame), use.frame.minY > v.minY {
                v.size.height = min(v.maxY, use.frame.minY - 12) - v.minY
            }
            return v.insetBy(dx: 8, dy: 16)
        }
        func safe() -> Bool {
            let f = zoom.frame, v = viewport()
            return zoom.exists && zoom.isHittable && isFiniteFrame(f) && !f.isEmpty &&
                isFiniteFrame(v) && !v.isEmpty && v.contains(f) && !f.intersects(use.frame)
        }
        for _ in 0..<8 {
            if safe() {
                let before = zoom.frame
                Thread.sleep(forTimeInterval: 0.4)
                if safe(), abs(zoom.frame.midY - before.midY) < 1 { return true }
            }
            let v = viewport()
            guard isFiniteFrame(v), v.width > 40, v.height > 80 else { break }
            // Drag through the scroll content, clear of both pinned controls.
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let towardBottom = zoom.exists && zoom.frame.midY < v.minY
            let high = v.minY + v.height * 0.2, low = v.minY + v.height * 0.8
            origin.withOffset(CGVector(dx: v.midX, dy: towardBottom ? high : low))
                .press(forDuration: 0.1,
                       thenDragTo: origin.withOffset(CGVector(dx: v.midX, dy: towardBottom ? low : high)))
            Thread.sleep(forTimeInterval: 0.4)
        }
        photograph("r11-zoom-not-safely-visible")
        attachHierarchy("r11-zoom-not-safely-visible-hierarchy")
        XCTFail("Zoom must settle fully inside the crop viewport, clear of Use this crop")
        return false
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
        let sheetDone = app.buttons["page-style-done"]
        let item = app.buttons["Page color"].firstMatch
        // A retry can start with the menu already open. Its More trigger is
        // then absent from automation; reopening it is the wrong transition.
        for attempt in 0..<2 {
            if sheetDone.exists { return }
            if !item.exists {
                var more = app.descendants(matching: .any)["recipe-more"].firstMatch
                if !more.waitForExistence(timeout: 3) {
                    scrollRecipeToTop()
                    if !more.waitForExistence(timeout: 3) { more = app.buttons["More"].firstMatch }
                }
                guard more.waitForExistence(timeout: 2) else {
                    attachHierarchy("recipe-more-missing-hierarchy")
                    return XCTFail("The recipe’s More menu must exist before opening it")
                }
                tapEvenInPopover(more)
            }
            guard item.waitForExistence(timeout: 5) else {
                photograph("page-color-menu-item-missing")
                attachHierarchy("page-color-menu-item-missing-hierarchy")
                return XCTFail("The opened More menu must offer Page color")
            }
            tapEvenInPopover(item)
            if sheetDone.waitForExistence(timeout: attempt == 0 ? 5 : 8) { return }
            photograph("page-color-after-menu-tap-\(attempt)")
            attachHierarchy("page-color-after-menu-tap-\(attempt)-hierarchy")
            // iPad (run 38497304286, A2's read): the menu stays open and the
            // item's tap does nothing while the popover is still settling.
            // Close it through More and open it again — the retry that
            // passed on iPad in every run before A2-39.
            let more = app.descendants(matching: .any)["recipe-more"].firstMatch
            if item.exists, more.exists {
                tapEvenInPopover(more)
                waitForDisappearance(item, timeout: 3, "the stale menu closed")
            }
        }
        waitForExistence(sheetDone, timeout: 1, "the Page color sheet")
    }

    private func closePageColorSheet() {
        let done = app.buttons["page-style-done"]
        guard done.waitForExistence(timeout: 3) else {
            photograph("page-color-before-close-done-missing")
            attachHierarchy("page-color-before-close-done-missing-hierarchy")
            return XCTFail("Page color must retain its Done control after a selection")
        }
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
        // Cream in Dark Mode too (Joe, build 19: choosing Classic cream left
        // his page dark).
        XCTAssertGreaterThan(cream, 0.6, "Classic cream: the light page is back\(capture.dark ? ", in Dark Mode too" : ""): luminance below the tabs \(cream)")
        scrollRecipeToTop()
        photograph("r14d-photo-classic" + capture.suffix)
    }

    /// r19 — a pastel photo gives a pale page in its own wash with the
    /// classic dark text (Joe, build 11: the meringues' slate gradient). Its
    /// cards, tabs and cook bar are light; a deep preset still works from it.
    func flowPalePhotoPage(_ capture: RecipeCapture = .standard) {
        launchRecipes([RecipeFixtureText.frozenBerry], capture, photo: "pastel")
        openRecipe(RecipeFixtureText.frozenBerryTitle)
        XCTAssertTrue(app.descendants(matching: .any)["recipe-hero"].exists, "the photo is the hero")
        verifyTypeSize(capture)
        photograph("r19a-pale-page" + capture.suffix)
        let pale = pageLuminance()
        XCTAssertGreaterThan(pale, 0.55, "a pastel photo gives a pale page, not slate: luminance below the tabs \(pale)")
        app.buttons["recipe-tab-directions"].tap()
        XCTAssertTrue(app.staticTexts["STEP 1"].waitForExistence(timeout: 5), "directions on the pale page")
        bringIntoView(app.staticTexts["STEP 1"])   // the render shows step text, not only the header (A2-33)
        photograph("r19b-pale-directions" + capture.suffix)
        app.buttons["recipe-tab-timing"].tap()
        let remove = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'remove-step-'")).firstMatch
        XCTAssertTrue(remove.waitForExistence(timeout: 5), "each step offers Remove (A2 S2)")
        photograph("r19c-pale-timing" + capture.suffix)
        openPageColorFromMenu()
        XCTAssertTrue(swatch("match-photo").isSelected, "automatic shows as Match photo")
        scrollAndTapSwatch("plum")
        XCTAssertTrue(swatch("plum").waitForSelection(), "Plum is now selected")
        closePageColorSheet()
        let plum = pageLuminance()
        XCTAssertLessThan(plum, 0.35, "a deep preset over a pastel photo: \(plum)")
        scrollRecipeToTop()
        photograph("r19d-pale-to-plum" + capture.suffix)
    }

    /// r23 — the week (Joe, October 13): Tonight's "This week" strip shows
    /// tonight's dinner and the plan; a day can take a classic or an open
    /// night; today's chip chooses tonight's dinner.
    func flowWeekPlan(_ capture: RecipeCapture = .standard) {
        launchRecipes([RecipeFixtureText.frozenBerry], capture)
        let today = app.descendants(matching: .any)["week-day-0"].firstMatch
        if !today.waitForExistence(timeout: 10) { attachHierarchy("week-strip-missing-hierarchy") }
        waitForExistence(today, timeout: 1, "This week on Tonight")
        // Below AT THE TABLE and Choose from Recipes (Joe).
        let recipesButton = app.buttons["open-recipes"]
        XCTAssertGreaterThan(today.frame.minY, recipesButton.frame.maxY, "the week sits below Choose from Recipes")
        scrollTo(today)
        XCTAssertTrue(today.label.hasPrefix("Today: Steak night"), "today shows tonight’s dinner: \(today.label)")
        photograph("r23a-week-strip" + capture.suffix)

        func openDay(_ index: Int) {
            let chip = app.descendants(matching: .any)["week-day-\(index)"].firstMatch
            scrollTo(chip)
            waitForStableFrame(chip)
            let done = app.buttons["day-plan-done"]
            let sheet = app.descendants(matching: .any)["day-plan-sheet"].firstMatch
            // Evidence first (runs 38508449584, 38519974627: the sheet never
            // showed): the chip as it is about to be tapped, a second tap at
            // its center, the hierarchy if the sheet is still missing.
            photograph("r23-day-chip-before-tap-\(index)")
            for attempt in 0..<2 where !done.exists && !sheet.exists {
                if attempt == 0 { chip.tap() } else {
                    photograph("r23-day-chip-tap-missed")
                    chip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                }
                _ = sheet.waitForExistence(timeout: 5)
            }
            if !sheet.exists {
                photograph("r23-day-sheet-missing"); attachHierarchy("r23-day-sheet-missing-hierarchy")
                // The failure message itself carries the facts (the run's
                // annotation is readable where its artifacts are not): the
                // chip's frame and hittability, what is presented, and every
                // navigation bar's title — a presented day sheet has one.
                let dayPlan = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'day-plan-'")).count
                let bars = app.navigationBars.allElementsBoundByIndex.map { $0.identifier }
                XCTFail("day sheet missing after tapping week-day-\(index): chip exists=\(chip.exists) hittable=\(chip.exists && chip.isHittable) "
                        + "frame=\(chip.frame) window=\(app.windows.firstMatch.frame) alerts=\(app.alerts.count) popovers=\(app.popovers.count) "
                        + "sheets=\(app.sheets.count) navBars=\(bars) day-plan elements=\(dayPlan) done=\(done.exists) "
                        + "selected='\(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Selected:'")).firstMatch.label)'")
            }
            waitForExistence(sheet, timeout: 1, "the day’s plan sheet")
            waitForExistence(done, timeout: 3, "the day’s plan sheet’s Done")
        }
        // Inside the day sheet: `scrollTo` measures Tonight's pinned bar
        // behind the sheet and kept dragging past the four-minute limit
        // (run 38610973412). Tap what is already tappable; otherwise drag
        // inside the sheet itself.
        func showInSheet(_ option: XCUIElement) {
            let window = app.windows.firstMatch.frame
            for _ in 0..<6 {
                if option.exists && option.isHittable && option.frame.maxY < window.maxY - 30 && option.frame.minY > window.minY + 60 { return }
                let up = !option.exists || option.frame.midY > window.midY
                let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: up ? 0.75 : 0.35))
                let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: up ? 0.4 : 0.7))
                from.press(forDuration: 0.1, thenDragTo: to, withVelocity: .default, thenHoldForDuration: 0.3)
                Thread.sleep(forTimeInterval: 0.4)
            }
        }
        func plan(day index: Int, choose identifier: String) {
            openDay(index)
            let option = app.descendants(matching: .any)[identifier].firstMatch
            if !option.waitForExistence(timeout: 5) { attachHierarchy("r23-day-sheet-hierarchy-\(identifier)") }
            waitForExistence(option, timeout: 1, "the day’s plan sheet offers \(identifier)")
            showInSheet(option)
            tapEvenInPopover(option)
            waitForDisappearance(app.buttons["day-plan-done"], "choosing closes the sheet")
        }
        // Every day starts as the cook's pick (no built-in rotation, Joe,
        // October 14); a day takes one of the cook's recipes or Thanksgiving.
        let day1 = app.descendants(matching: .any)["week-day-1"].firstMatch
        XCTAssertTrue(day1.label.hasSuffix("Your pick"), "an unplanned day is the cook's pick: \(day1.label)")
        plan(day: 1, choose: "day-plan-recipe")
        XCTAssertTrue(day1.label.hasSuffix(RecipeFixtureText.frozenBerryTitle), "the recipe is planned for tomorrow: \(day1.label)")
        openDay(2)
        photograph("r23b-day-plan-sheet" + capture.suffix)
        let holiday = app.descendants(matching: .any)["day-plan-thanksgiving"].firstMatch
        waitForExistence(holiday, timeout: 5, "Thanksgiving in the day sheet")
        showInSheet(holiday)
        tapEvenInPopover(holiday)
        waitForDisappearance(app.buttons["day-plan-done"], "choosing closes the sheet")
        let day2 = app.descendants(matching: .any)["week-day-2"].firstMatch
        XCTAssertTrue(day2.label.hasSuffix("Thanksgiving, together"), "\(day2.label)")
        plan(day: 2, choose: "day-plan-open")
        XCTAssertTrue(day2.label.hasSuffix("Your pick"), "back to the cook's pick: \(day2.label)")

        plan(day: 0, choose: "day-plan-thanksgiving")
        XCTAssertTrue(app.staticTexts["Selected: Thanksgiving, together"].waitForExistence(timeout: 5), "today’s chip chose tonight’s dinner")
        XCTAssertTrue(today.label.hasPrefix("Today: Thanksgiving, together"), today.label)
        photograph("r23c-week-planned" + capture.suffix)
    }

    /// r24 — A2-44 checks 2 and 3 (A1's priority): recipes imported but none
    /// chosen keep the notebook and no dinner; choosing A (with a photo)
    /// shows A's photo, choosing B (without one) shows B's title on the
    /// notebook and nothing of A's, and back to A shows A's photo again.
    /// Then Tonight's first launch in Dark Mode and with solid cards, for
    /// the frosted card's review (A2, PR #14).
    func flowCoverSwitching() {
        launch(seed: UISeed.tonight(now: Date(), menuID: ""), extraLaunchArguments: RecipeCapture.standard.launchArguments,
               openCooking: false, recipes: [RecipeFixtureText.frozenBerry, RecipeFixtureText.missingText], photo: "pastel")
        let cover = app.descendants(matching: .any)["tonight-cover"].firstMatch
        func coverShows(_ expected: String, _ why: String) {
            waitForExistence(cover, timeout: 10, "Tonight's cover")
            scrollToTop(maxDrags: 3)
            let shown = NSPredicate(format: "value == %@", expected)
            if XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: shown, object: cover)], timeout: 5) != .completed {
                attachHierarchy("r24-cover-\(expected)-hierarchy")
                XCTFail("Tonight's cover shows '\(cover.value as? String ?? "nil")', expected '\(expected)': \(why)")
            }
        }
        func cookTonight(_ title: String, reviewed: Bool) {
            openRecipe(title)
            let cook = app.buttons["cook-this-recipe"]
            if !reviewed {
                tapPinned(cook, "Check timing to continue")
                let confirm = app.buttons["timing-looks-right"]
                waitForExistence(confirm, timeout: 5, "the Timing tab")
                tapPinned(confirm, "Timing looks right")
                waitForDisappearance(confirm, "the review is recorded")
            }
            tapPinned(cook, "Cook this for dinner")
            XCTAssertTrue(app.staticTexts["Selected: \(title)"].waitForExistence(timeout: 5), "Tonight with \(title)")
        }

        // Check 2: imported, nothing chosen.
        coverShows("notebook", "recipes in the cookbook are not tonight's dinner until chosen")
        XCTAssertTrue(app.staticTexts["Nothing chosen for tonight yet"].exists, "no dinner is selected by importing")
        XCTAssertFalse(app.buttons["tonight-recipe"].exists, "no recipe is named as tonight's")
        photograph("r24a-imported-not-chosen")

        // Check 3: A with a photo, B without, back to A.
        cookTonight(RecipeFixtureText.frozenBerryTitle, reviewed: false)
        coverShows("cover", "A's photo")
        photograph("r24b-a-with-photo")
        cookTonight(RecipeFixtureText.missingTextTitle, reviewed: false)
        coverShows("notebook", "B has no photo: the notebook, never A's photo")
        let named = app.buttons["tonight-recipe"]
        XCTAssertTrue(named.waitForExistence(timeout: 5) && named.label.hasPrefix(RecipeFixtureText.missingTextTitle),
                      "B's own title under the cover: \(named.label)")
        photograph("r24c-b-without-photo")
        cookTonight(RecipeFixtureText.frozenBerryTitle, reviewed: true)
        coverShows("cover", "back to A: A's photo again")

        // Tonight's frosted card in Dark Mode and as a solid card.
        for capture in [RecipeCapture.darkMode, RecipeCapture.solidCards] {
            launch(seed: UISeed.tonight(now: Date(), menuID: ""), extraLaunchArguments: capture.launchArguments, openCooking: false)
            waitForExistence(app.descendants(matching: .any)["tonight-cover"].firstMatch, timeout: 10, "Tonight")
            photograph("r24d-tonight-first-launch" + capture.suffix)
        }
    }

    /// r25 — Tonight after a pale recipe page in the system's own
    /// appearance, the way Joe reached it on build 18 (Whipped Frozen Apple
    /// Cider: a black clock over the photo): back with "Cook this for
    /// dinner", then back with the Tonight tab while the page stays open.
    /// Then the card's "…" (Joe, build 18: "a little dark … like slider?"):
    /// the glass at both ends and back to standard.
    func flowTonightAfterPalePageAndGlass() {
        launch(seed: UISeed.tonight(now: Date(), menuID: ""), extraLaunchArguments: RecipeCapture.system.launchArguments,
               openCooking: false, recipes: [RecipeFixtureText.frozenBerry], photo: "pastel")
        let title = RecipeFixtureText.frozenBerryTitle
        let cover = app.descendants(matching: .any)["tonight-cover"].firstMatch

        openRecipe(title)
        let cook = app.buttons["cook-this-recipe"]
        tapPinned(cook, "Check timing to continue")
        let confirm = app.buttons["timing-looks-right"]
        waitForExistence(confirm, timeout: 5, "the Timing tab")
        tapPinned(confirm, "Timing looks right")
        waitForDisappearance(confirm, "the review is recorded")
        tapPinned(cook, "Cook this for dinner")
        XCTAssertTrue(app.staticTexts["Selected: \(title)"].waitForExistence(timeout: 5), "Tonight with \(title)")
        waitForExistence(cover, timeout: 10, "Tonight's cover")
        scrollToTop(maxDrags: 3)
        expectLightClock("r25a")
        photograph("r25a-tonight-after-pale-page-system")

        // Tonight's recipe → its page, then the Tonight tab (or sidebar row)
        // with the page still open under Recipes.
        scrollAndTap(app.buttons["tonight-recipe"], "tonight's recipe")
        waitForExistence(app.staticTexts["recipe-title"], timeout: 10, "the recipe page for “\(title)”")
        goToTonight()
        waitForExistence(cover, timeout: 10, "Tonight's cover")
        scrollToTop(maxDrags: 3)
        expectLightClock("r25b")
        photograph("r25b-tonight-via-tab-system")

        // The card's "…": clearer, darker, back to standard.
        scrollAndTap(app.buttons["table-card-more"], "the dinner-time card's …")
        let slider = app.sliders["glass-slider"]
        waitForExistence(slider, timeout: 5, "the card-glass slider")
        let standard = slider.value as? String
        let reset = app.buttons["glass-reset"]
        XCTAssertFalse(reset.isEnabled, "the glass starts standard: nothing to reset")
        slider.adjust(toNormalizedSliderPosition: 0)
        photograph("r25c-card-see-through")
        slider.adjust(toNormalizedSliderPosition: 1)
        photograph("r25d-card-solid")
        XCTAssertNotEqual(slider.value as? String, standard, "the slider moved")
        XCTAssertTrue(reset.isEnabled, "Reset is offered once the glass has changed")
        reset.tap()
        XCTAssertEqual(slider.value as? String, standard, "Reset puts the standard glass back")
        app.buttons["glass-done"].tap()
        waitForDisappearance(slider, "the panel closes with Done")
        XCTAssertTrue(cover.exists, "Tonight is still there")
    }

    /// Back from a recipe page: the bar's back button by its identifier (it
    /// is not always inside a NavigationBar element — the Duo, run
    /// 38733138966), else the first button of a navigation bar, else the
    /// edge swipe.
    private func goBack() {
        let back = app.buttons["BackButton"].firstMatch
        if back.exists { back.tap(); return }
        let barBack = app.navigationBars.buttons.firstMatch
        if barBack.exists { barBack.tap(); return }
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)))
    }

    /// The Tonight tab on iPhone. iPad has no tab bar, and its clock follows
    /// the sidebar, so the page's own Back to Tonight serves (run
    /// 38670042839: a "Tonight" text tapped there did not switch).
    private func goToTonight() {
        let tab = app.tabBars.buttons["Tonight"].firstMatch
        if tab.exists { tab.tap(); return }
        tapPinned(app.buttons["cook-this-recipe"], "Back to Tonight")
    }

    /// On iPhone the photo runs up behind the status bar, so the clock must
    /// be light there. Reads the clock's corner of a real screenshot:
    /// near-white against near-black pixels (the scrim keeps the photo in
    /// the middle tones there). Fails only on a clock that is plainly dark;
    /// a layout where neither shows (another device's status bar) is noted,
    /// with the crop attached either way. iPad: the photo starts below the
    /// clock, which follows the sidebar.
    private func expectLightClock(_ step: String, file: StaticString = #filePath, line: UInt = #line) {
        guard app.frame.width < 700 else { return }
        var light = 0, dark = 0
        for attempt in 0..<4 {
            if attempt > 0 { Thread.sleep(forTimeInterval: 0.5) } // the bar's style animates in
            let image = XCUIScreen.main.screenshot().image
            guard let cg = image.cgImage, image.size.width > 0 else { return XCTFail("\(step): no screenshot pixels", file: file, line: line) }
            let scale = CGFloat(cg.width) / image.size.width
            // The status bar's left ear, where the time is on Face ID iPhones.
            let region = CGRect(x: 12 * scale, y: 6 * scale, width: image.size.width * 0.3 * scale, height: 44 * scale).integral
            guard let crop = cg.cropping(to: region) else { return XCTFail("\(step): could not crop the clock", file: file, line: line) }
            let w = crop.width, h = crop.height
            var pixels = [UInt8](repeating: 0, count: w * h * 4)
            let drawn: Bool = pixels.withUnsafeMutableBytes { buffer in
                guard let ctx = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
                ctx.draw(crop, in: CGRect(x: 0, y: 0, width: w, height: h))
                return true
            }
            guard drawn else { return XCTFail("\(step): could not read the clock's pixels", file: file, line: line) }
            light = 0; dark = 0
            for i in stride(from: 0, to: pixels.count, by: 4) {
                let l = (0.2126 * Double(pixels[i]) + 0.7152 * Double(pixels[i + 1]) + 0.0722 * Double(pixels[i + 2])) / 255
                if l > 0.88 { light += 1 } else if l < 0.12 { dark += 1 }
            }
            if attempt == 3 || (light >= 40 && light > dark * 2) {
                let attachment = XCTAttachment(image: UIImage(cgImage: crop))
                attachment.name = "\(step)-clock-light\(light)-dark\(dark)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
            if light >= 40 && light > dark * 2 { return }
        }
        if dark >= 40 && dark >= light {
            XCTFail("\(step): the clock over Tonight's photo is dark (near-black px \(dark), near-white px \(light))", file: file, line: line)
        } else {
            print("\(step): clock check inconclusive (near-white px \(light), near-black px \(dark)); see the attached crop")
        }
    }

    /// r26 — the cookbook spread (Joe and A2, October 14, for the iPhone
    /// Duo): on a window open like a book the recipe page is two pages —
    /// the cover photo on the left, the main recipe on the right; the cook
    /// can read a second recipe on the left and bring the photo back, and
    /// the right page keeps its tab throughout. On any other window the page
    /// is the single page, unchanged, which this flow records too.
    func flowCookbookSpread(_ capture: RecipeCapture = .standard) {
        launchRecipes([RecipeFixtureText.frozenBerry, RecipeFixtureText.beanSpread], capture, photo: "pastel")
        // The window as this device gives it (the Duo's shape was unknown
        // until its first run: 466 × 678 in run 38723119849).
        photograph("r26-0-first-screen" + capture.suffix)
        attachHierarchy("r26-0-first-screen-hierarchy")
        // A near-square phone screen (the Duo) turns like a book for the spread.
        let first = app.frame
        if UIDevice.current.userInterfaceIdiom == .phone, min(first.width, first.height) / max(first.width, first.height) >= 0.6 {
            XCUIDevice.shared.orientation = .landscapeLeft
            addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
            Thread.sleep(forTimeInterval: 1.5)
            photograph("r26-0-turned" + capture.suffix)
        }
        openRecipe(RecipeFixtureText.frozenBerryTitle)
        photograph("r26-0-recipe-page" + capture.suffix)
        attachHierarchy("r26-0-recipe-page-hierarchy")
        let left = app.descendants(matching: .any)["spread-left"].firstMatch
        let frame = app.frame
        let phone = UIDevice.current.userInterfaceIdiom == .phone
        let openBook = phone && frame.width >= 600 && frame.height >= 450 && capture.typeSize == nil
        guard openBook else {
            XCTAssertFalse(left.exists, "a window that is not open like a book shows the single page (\(frame.size))")
            XCTAssertTrue(app.staticTexts["recipe-title"].exists, "…the recipe page as always")
            photograph("r26a-single-page" + capture.suffix)
            return
        }

        // The spread: photo left, recipe right, each on its own half.
        waitForExistence(left, timeout: 5, "the spread's left page")
        let title = app.staticTexts["recipe-title"]
        XCTAssertTrue(title.exists, "the main recipe is the right page")
        XCTAssertGreaterThan(title.frame.minX, frame.midX - 1, "…on the right half: \(title.frame)")
        let photo = app.descendants(matching: .any)["spread-cover-photo"].firstMatch
        XCTAssertTrue(photo.exists, "the cover photo leads the left page")
        XCTAssertLessThan(photo.frame.maxX, frame.midX + 1, "…on the left half: \(photo.frame)")
        XCTAssertGreaterThan(photo.frame.height, frame.height * 0.8, "…edge to edge: \(photo.frame)")
        photograph("r26b-spread-cover" + capture.suffix)

        // The right page's place: Directions, kept while the left changes.
        app.buttons["recipe-tab-directions"].tap()
        XCTAssertTrue(app.buttons["recipe-tab-directions"].isSelected, "Directions on the right")

        // A second recipe on the left, with its own tabs.
        let more = app.buttons["spread-more"]
        waitForExistence(more, timeout: 5, "the photo page's …")
        more.tap()
        let add = app.buttons["Add a second recipe"]
        waitForExistence(add, timeout: 5, "Add a second recipe")
        add.tap()
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", RecipeFixtureText.beanSpreadTitle)).firstMatch
        waitForExistence(row, timeout: 5, "the second-recipe picker")
        row.tap()
        let secondTitle = app.staticTexts["recipe-title-second"]
        waitForExistence(secondTitle, timeout: 5, "the second recipe on the left page")
        XCTAssertTrue(secondTitle.label.hasPrefix(RecipeFixtureText.beanSpreadTitle), secondTitle.label)
        XCTAssertLessThan(secondTitle.frame.maxX, frame.midX + 1, "…on the left half: \(secondTitle.frame)")
        XCTAssertTrue(app.buttons["cook-both"].exists, "the left page offers Cook both together")
        XCTAssertLessThan(app.buttons["cook-both"].frame.maxX, frame.midX + 1, "…on the left half")
        app.buttons["recipe-tab-directions-second"].tap()
        XCTAssertTrue(app.buttons["recipe-tab-directions-second"].isSelected, "the left page has its own tabs")
        XCTAssertTrue(app.buttons["recipe-tab-directions"].isSelected, "…and the right page kept its place")
        XCTAssertTrue(title.label.hasPrefix(RecipeFixtureText.frozenBerryTitle), "the main recipe stays on the right")
        photograph("r26c-spread-second-recipe" + capture.suffix)

        // Back to the photo, the right page untouched.
        app.buttons["spread-show-cover"].tap()
        waitForExistence(photo, timeout: 5, "the cover photo is back")
        XCTAssertFalse(secondTitle.exists, "the second recipe has left the page")
        XCTAssertTrue(app.buttons["recipe-tab-directions"].isSelected, "the right page still on Directions")
        photograph("r26d-spread-cover-again" + capture.suffix)

        // Cook both together (Joe, October 14: two recipes, on the Duo).
        // The main recipe's timing first, on the right…
        let cook = app.buttons["cook-this-recipe"]
        tapPinned(cook, "Check timing to continue")
        let confirm = app.buttons["timing-looks-right"]
        waitForExistence(confirm, timeout: 5, "the main recipe's Timing tab")
        tapPinned(confirm, "Timing looks right")
        waitForDisappearance(confirm, "the main recipe's review is recorded")
        // …then the side's, on the left, and both together.
        more.tap()
        waitForExistence(add, timeout: 5, "Add a second recipe")
        add.tap()
        waitForExistence(row, timeout: 5, "the second-recipe picker")
        row.tap()
        let both = app.buttons["cook-both"]
        waitForExistence(both, timeout: 5, "Cook both together")
        both.tap() // the side's timing check
        let confirmSide = app.buttons["timing-looks-right-second"]
        waitForExistence(confirmSide, timeout: 5, "the side's Timing tab")
        confirmSide.tap()
        waitForDisappearance(confirmSide, "the side's review is recorded")
        XCTAssertTrue(both.label.hasPrefix("Cook both"), both.label)
        photograph("r26e-spread-cook-both" + capture.suffix)
        both.tap()
        let pairTitle = "\(RecipeFixtureText.frozenBerryTitle) + \(RecipeFixtureText.beanSpreadTitle)"
        XCTAssertTrue(app.staticTexts["Selected: \(pairTitle)"].waitForExistence(timeout: 8), "Tonight: both recipes, one dinner")
        photograph("r26f-tonight-two-recipes" + capture.suffix)
    }

    /// r27 — favorites and the week's Add a new recipe (Joe, build 20): a
    /// recipe starred with a swipe leads Your Recipes and the day sheet,
    /// keeps its star on the page, and a day offers + Add a new recipe.
    func flowFavoritesAndWeekAdd(_ capture: RecipeCapture = .standard) {
        launchRecipes([RecipeFixtureText.frozenBerry, RecipeFixtureText.beanSpread], capture)
        openRecipesLibrary()
        func row(_ title: String) -> XCUIElement {
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ OR label BEGINSWITH %@", title, "Favorite, " + title)).firstMatch
        }
        let bean = row(RecipeFixtureText.beanSpreadTitle)
        scrollTo(bean)
        XCTAssertFalse(app.descendants(matching: .any)["favorites-section"].exists, "no Favorites section before a star")
        // The star beside the row, one tap (Joe, build 20).
        let star = app.buttons["Add \(RecipeFixtureText.beanSpreadTitle) to favorites"]
        waitForExistence(star, timeout: 5, "the row's star")
        star.tap()
        let section = app.descendants(matching: .any)["favorites-section"].firstMatch
        waitForExistence(section, timeout: 5, "the Favorites section")
        XCTAssertTrue(app.buttons["Remove \(RecipeFixtureText.beanSpreadTitle) from favorites"].exists, "the star is now filled")
        let first = row(RecipeFixtureText.beanSpreadTitle) // the row itself, not its star
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        let berry = row(RecipeFixtureText.frozenBerryTitle)
        XCTAssertLessThan(first.frame.minY, berry.frame.minY, "the starred recipe leads Your Recipes")
        XCTAssertLessThan(section.frame.minY, first.frame.minY, "…under Favorites")
        let all = app.descendants(matching: .any)["all-recipes-section"].firstMatch
        XCTAssertTrue(all.exists && all.frame.minY < berry.frame.minY, "the rest under All recipes")
        photograph("r27a-favorite-first" + capture.suffix)

        // The page shows the star, filled.
        scrollAndTap(first, "the starred recipe")
        let pageStar = app.buttons["recipe-favorite"]
        waitForExistence(pageStar, timeout: 5, "the page's star")
        XCTAssertTrue(pageStar.isSelected, "…filled for a favorite")
        goBack()

        // Search by title or ingredient, from a fresh launch: an active search
        // collapses iOS 27's tab bar, which the week part needs (run 38723119849).
        func searchFromFreshLaunch() {
            launchRecipes([RecipeFixtureText.frozenBerry, RecipeFixtureText.beanSpread], capture)
            openRecipesLibrary()
            let bean = row(RecipeFixtureText.beanSpreadTitle), berry = row(RecipeFixtureText.frozenBerryTitle)
            waitForExistence(berry, timeout: 5, "the berry drink in Your Recipes")
            let search = app.searchFields.firstMatch
            guard search.waitForExistence(timeout: 3) else { return XCTFail("Your Recipes offers search") }
            search.tap()
            search.typeText("olive")
            XCTAssertTrue(bean.waitForExistence(timeout: 5), "the bean spread (1 tablespoon olive oil) matches")
            XCTAssertFalse(berry.exists, "the berry drink has no olive oil, and no 'olive' in its title")
            photograph("r27d-search-ingredient" + capture.suffix)
        }

        // A day two days out: favorites first, and + Add a new recipe.
        // (iPhone: the Tonight tab; iPad's sidebar row did not switch from a
        // pushed page in run 38670042839, so iPad stops here for now.)
        guard app.tabBars.buttons["Tonight"].firstMatch.exists else { return searchFromFreshLaunch() }
        goToTonight()
        let chip = app.descendants(matching: .any)["week-day-2"].firstMatch
        scrollTo(chip)
        waitForStableFrame(chip)
        chip.tap()
        let sheet = app.descendants(matching: .any)["day-plan-sheet"].firstMatch
        waitForExistence(sheet, timeout: 5, "the day's sheet")
        let firstRecipe = app.buttons.matching(identifier: "day-plan-recipe").firstMatch
        waitForExistence(firstRecipe, timeout: 5, "the day's recipes")
        XCTAssertTrue(firstRecipe.label.contains(RecipeFixtureText.beanSpreadTitle), "the favorite leads the day's recipes: \(firstRecipe.label)")
        let add = app.buttons["day-plan-add-recipe"]
        waitForExistence(add, timeout: 5, "the day offers + Add a new recipe")
        if !add.isHittable { sheet.swipeUp() }
        photograph("r27b-day-add-recipe" + capture.suffix)
        add.tap()
        waitForExistence(app.buttons["import-recipe"], timeout: 5, "the Add recipe sheet, from the day")
        photograph("r27c-add-from-day" + capture.suffix)
        searchFromFreshLaunch()
    }

    /// r22 — tonight's recipe cover on Tonight and on Cooking's RIGHT NOW
    /// (A2-35): a photo band on Tonight's card, a strip on an ordinary
    /// start, a thumbnail on the timeline. At AX3 the row and plain cards
    /// stay (text first); the actions are where they were either way.
    func flowRecipeCovers(_ capture: RecipeCapture = .standard, photo: String = "pastel") {
        launchRecipes([RecipeFixtureText.frozenBerry], capture, photo: photo)
        openRecipe(RecipeFixtureText.frozenBerryTitle)
        let cook = app.buttons["cook-this-recipe"]
        tapPinned(cook, "Check timing to continue")
        let confirm = app.buttons["timing-looks-right"]
        waitForExistence(confirm, timeout: 5, "the Timing tab")
        tapPinned(confirm, "Timing looks right")
        waitForDisappearance(confirm, "the review is recorded")
        tapPinned(cook, "Cook this for dinner")
        XCTAssertTrue(app.staticTexts["Selected: \(RecipeFixtureText.frozenBerryTitle)"].waitForExistence(timeout: 5), "Tonight")

        let card = app.buttons["tonight-recipe"]
        scrollTo(card, requireHittable: false)  // the label is read, never tapped (A1)
        XCTAssertTrue(card.label.hasPrefix(RecipeFixtureText.frozenBerryTitle), "the card names the recipe first: \(card.label)")
        // The recipe's photo is Tonight's cover (Joe and A2, October 14).
        let cover = app.descendants(matching: .any)["tonight-cover"].firstMatch
        XCTAssertTrue(cover.exists, "the photo cover leads Tonight")
        XCTAssertGreaterThan(cover.frame.height, 300, "the cover is a full cover: \(cover.frame)")
        scrollToTop(maxDrags: 3)
        photograph("r22a-tonight-cover-\(photo)" + capture.suffix)
        // (Build is pinned: no need to scroll back to the recipe's name —
        // at AX3 that second scroll could not settle, run 38610973412.)

        let build = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Build'")).firstMatch
        waitForExistence(build, timeout: 5, "the build action")
        tapPinned(build, "Build the plan")
        waitForExistence(app.staticTexts["serving-time"], timeout: 10, "the Cooking screen")
        // Capture the actual arrival viewport before any helper scrolls it.
        // A future start can show breathing room; this image records that
        // honestly and does not certify a featured or expired-step state.
        photograph("r22b-cooking-initial-\(photo)" + capture.suffix)
        let start = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Start '")).firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 10), "a step-start action is available")
        scrollTo(start)
        XCTAssertTrue(start.isHittable, "the step-start action is reachable after scrolling")
        photograph("r22c-start-action-revealed-\(photo)" + capture.suffix)
    }

    /// r21 — what an import could not establish stays in view on every tab
    /// and after the timing check (A2-30; fixture A1 #20 / A2 PR #16).
    /// Positioning only scrolls; nothing is tapped to make the card appear.
    func flowImportWarningPersists(_ capture: RecipeCapture = .standard) {
        launchRecipes([RecipeFixtureText.missingText], capture, warnings: [[RecipeFixtureText.missingTextWarning]])
        openRecipe(RecipeFixtureText.missingTextTitle)
        let card = app.descendants(matching: .any)["import-content-warning"]
        func cardShowsWarning(_ place: String) {
            waitForExistence(card, timeout: 5, "the import warning card on \(place)")
            let text = app.staticTexts[RecipeFixtureText.missingTextWarning]
            XCTAssertTrue(text.exists, "…with its exact warning, on \(place)")
        }
        cardShowsWarning("Ingredients")
        app.buttons["recipe-tab-directions"].tap()
        cardShowsWarning("Directions")
        app.buttons["recipe-tab-timing"].tap()
        cardShowsWarning("Timing")
        bringIntoView(card)
        photograph("r21a-warning-on-timing" + capture.suffix)
        let confirm = app.buttons["timing-looks-right"]
        waitForExistence(confirm, timeout: 5, "Timing looks right")
        tapPinned(confirm, "Timing looks right")
        waitForDisappearance(confirm, "the timing check is done")
        cardShowsWarning("the page after the timing check")
        bringIntoView(card)
        photograph("r21b-warning-after-check" + capture.suffix)
    }

    /// r20 — Your Recipes: swipe left for Edit and Delete (Joe, build 12).
    /// Edit fixes a title the import got wrong; Delete asks first, Cancel
    /// keeps the recipe, Delete removes it.
    func flowSwipeEditAndDelete(_ capture: RecipeCapture = .standard) {
        launchRecipes([RecipeFixtureText.frozenBerry, RecipeFixtureText.beanSpread], capture)
        openRecipesLibrary()
        func row(_ title: String) -> XCUIElement {
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
        }
        let berry = row(RecipeFixtureText.frozenBerryTitle)
        scrollTo(berry)
        let edit = app.buttons["Edit"].firstMatch
        for _ in 0..<2 where !edit.exists {
            berry.swipeLeft()
            _ = edit.waitForExistence(timeout: 3)
        }
        waitForExistence(edit, timeout: 2, "swipe left shows Edit")
        XCTAssertTrue(app.buttons["Delete"].firstMatch.exists, "…and Delete")
        photograph("r20a-swipe-actions" + capture.suffix)
        edit.tap()

        let field = app.descendants(matching: .any)["recipe-edit-title"]
        waitForExistence(field, timeout: 5, "the Edit recipe sheet")
        let save = app.buttons["recipe-edit-save"]
        XCTAssertFalse(save.isEnabled, "nothing to save before a change")
        // Clear the old title, then type the new one.
        tapPinned(app.buttons["recipe-edit-title-clear"], "the title's clear button")
        XCTAssertTrue(app.staticTexts["A recipe needs a title."].waitForExistence(timeout: 3), "a blank title is refused")
        XCTAssertFalse(save.isEnabled, "…and cannot be saved")
        // The cook's own notes, on the same sheet (A2, build 19), typed
        // before the title while no keyboard covers them — at the standard
        // size (passed in runs 38682393276 and 38686178891). At AX3 the
        // keyboard and the Save bar leave the fields beyond a test's reach
        // (four runs); r20b still records the AX3 sheet, test36 the notes.
        let typesNotes = capture.typeSize == nil
        if typesNotes {
            let notes = app.descendants(matching: .any)["recipe-edit-notes"]
            waitForExistence(notes, timeout: 5, "the Notes field")
            for _ in 0..<4 where !notes.isHittable { app.swipeUp() }
            notes.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
            notes.typeText("Use extra lime. Check five minutes early.")
            scrollTo(field, requireHittable: false)
        }
        field.tap()
        field.typeText("Berry lime slush")
        photograph("r20b-edit-recipe" + capture.suffix)
        tapPinned(save, "Save changes")
        waitForDisappearance(save, "the Edit sheet closed")
        XCTAssertTrue(row("Berry lime slush").waitForExistence(timeout: 5), "the list shows the new title")
        XCTAssertFalse(row(RecipeFixtureText.frozenBerryTitle).exists, "…not the old one")

        // The notes are on the page, under the directions, with a way to edit them.
        if typesNotes {
        scrollAndTap(row("Berry lime slush"), "the renamed recipe's row")
        waitForExistence(app.staticTexts["recipe-title"], timeout: 10, "the recipe page")
        app.buttons["recipe-tab-directions"].tap()
        let shown = app.staticTexts["recipe-notes"]
        scrollTo(shown, requireHittable: false)
        XCTAssertEqual(shown.label, "Use extra lime. Check five minutes early.", "the page shows the cook's notes")
        XCTAssertTrue(app.buttons["edit-notes"].exists, "…with Edit notes beside them")
        photograph("r20b2-recipe-notes" + capture.suffix)
        goBack()
        waitForExistence(app.buttons["add-recipe"], timeout: 5, "back in Your Recipes")
        }

        let bean = row(RecipeFixtureText.beanSpreadTitle)
        scrollTo(bean)
        let delete = app.buttons["Delete"].firstMatch
        func swipeToDelete() {
            for _ in 0..<2 where !delete.exists {
                bean.swipeLeft()
                _ = delete.waitForExistence(timeout: 3)
            }
            waitForExistence(delete, timeout: 2, "swipe left shows Delete")
            delete.tap()
        }
        swipeToDelete()
        let alert = app.alerts["Delete this recipe?"]
        waitForExistence(alert, timeout: 5, "Delete asks first")
        photograph("r20c-delete-alert" + capture.suffix)
        alert.buttons["Cancel"].tap()
        waitForDisappearance(alert, "Cancel closes the question")
        XCTAssertTrue(bean.waitForExistence(timeout: 3), "Cancel keeps the recipe")
        if app.buttons["Delete"].firstMatch.exists { bean.swipeRight() }   // close the open swipe, if it stayed open
        swipeToDelete()
        waitForExistence(alert, timeout: 5, "Delete asks again")
        alert.buttons["Delete recipe"].tap()
        waitForDisappearance(bean, "the recipe is gone from the list")
        XCTAssertTrue(row("Berry lime slush").exists, "the other recipe stays")
        photograph("r20d-after-delete" + capture.suffix)

        // The renamed recipe's page carries the new title.
        scrollAndTap(row("Berry lime slush"), "open the renamed recipe")
        XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout: 10), "the recipe page")
        XCTAssertEqual(app.staticTexts["recipe-title"].label, "Berry lime slush")
    }

    /// The sheet itself renders at the forced type size (A2-17): the helper
    /// text wraps to several large lines at AX3 and two small ones otherwise.
    private func verifySheetTypeSize(_ capture: RecipeCapture, file: StaticString = #filePath, line: UInt = #line) {
        let help = app.staticTexts["page-style-help"]
        guard help.waitForExistence(timeout: 5) else { return XCTFail("the sheet's helper text", file: file, line: line) }
        // Two lines of AX3 subheadline on an iPad-width sheet measured 86 pt;
        // iPhone default two lines 36 pt, iPad default one line 18 pt.
        if capture.typeSize != nil {
            XCTAssertGreaterThan(help.frame.height, 60, "AX3 inside the sheet: helper text height \(help.frame.height)", file: file, line: line)
        } else {
            XCTAssertLessThan(help.frame.height, 50, "default type inside the sheet: helper text height \(help.frame.height)", file: file, line: line)
        }
    }

    /// At AX3 the grid is taller than the half-height sheet; scroll within it.
    private func scrollAndTapSwatch(_ id: String) {
        let target = swatch(id)
        revealSwatch(id)
        // Settled and inside the viewport, the element's own tap lets XCTest
        // resolve the true hit point; the blind center tap missed Classic at
        // the bottom of the iPad AX3 form sheet (A1, issue #18). The
        // coordinate tap stays as the fallback for a popover-hosted sheet.
        Thread.sleep(forTimeInterval: 0.5)
        if target.exists && target.isHittable { target.tap() } else { tapEvenInPopover(target) }
    }

    /// Scrolls the Page color sheet until the swatch is inside the sheet's
    /// own viewport. Never taps.
    private func revealSwatch(_ id: String) {
        let target = swatch(id)
        // The sheet's own scroll viewport: on iPad at AX3 the sheet is a small
        // form sheet, the grid continues below its edge, and XCTest still
        // reports those swatches hittable (run 38388564793 tapped Classic
        // through the sheet's bottom). Scroll until the swatch is inside the
        // viewport, dragging inside the viewport.
        let anchor = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'page-style-'")).firstMatch
        func viewport() -> CGRect {
            guard anchor.exists else { return app.frame }
            let c = CGPoint(x: anchor.frame.midX, y: anchor.frame.midY)
            let hosts = app.scrollViews.allElementsBoundByIndex.filter { $0.frame.contains(c) && $0.frame.height < app.frame.height }
            return hosts.min(by: { $0.frame.height < $1.frame.height })?.frame ?? app.frame
        }
        func inside() -> Bool {
            guard target.exists else { return false }
            let v = viewport().insetBy(dx: 0, dy: 30)
            return v.contains(CGPoint(x: target.frame.midX, y: target.frame.midY))
        }
        for _ in 0..<8 where !inside() {
            let v = viewport()
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let from = origin.withOffset(CGVector(dx: v.midX, dy: v.maxY - 24))
            let to = origin.withOffset(CGVector(dx: v.midX, dy: v.minY + 24))
            from.press(forDuration: 0.1, thenDragTo: to, withVelocity: .default, thenHoldForDuration: 0.3)
            Thread.sleep(forTimeInterval: 0.4)
        }
        XCTAssertTrue(inside(), "the \(id) swatch is inside the sheet's viewport \(viewport()) — frame \(target.frame)")
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
        XCTAssertGreaterThan(start, 0.6, "a typed recipe starts on the cream page\(capture.dark ? ", in Dark Mode too" : ""): \(start)")
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
        // The inserted error can also evict Lagoon from the lazy grid.
        // Reveal without selecting, preserving the rollback assertion.
        revealSwatch("lagoon")
        XCTAssertFalse(swatch("lagoon").isSelected, "the failed choice is not shown as chosen")
        // At AX3 the error pushes Classic, last in the lazy grid, below the
        // sheet's viewport, where it does not exist yet (run 38425982728,
        // A2-33). Scroll it into the viewport — never tap it — then look.
        revealSwatch("classic")
        XCTAssertTrue(swatch("classic").waitForSelection(), "the page’s real color stays selected")
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
