import XCTest
@testable import DinnerTogether

// The week's dinners (Joe, October 13/14): open days, Thanksgiving on its
// day, and the cook's own choices for any day. These pin the defaults, the
// plan's precedence, and when a planned day takes over tonight's dinner.

final class WeekPlanTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Denver")!
        return c
    }()

    private func day(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    private func id(_ dinner: PlannedDinner) -> String? {
        if case .menu(let id) = dinner { return id }
        return nil
    }

    func testDaysAreOpenExceptThanksgiving() {
        XCTAssertEqual(WeekRotation.suggestion(for: day(2026, 10, 12), calendar: cal), .open, "a Monday is the cook's pick")
        XCTAssertEqual(WeekRotation.suggestion(for: day(2026, 10, 17), calendar: cal), .open, "so is a Saturday")
        XCTAssertEqual(WeekRotation.suggestion(for: day(2026, 11, 26), calendar: cal), .menu("thanksgiving"), "Thanksgiving 2026 is Nov 26")
        XCTAssertTrue(WeekRotation.isThanksgiving(day(2027, 11, 25), calendar: cal))
        XCTAssertFalse(WeekRotation.isThanksgiving(day(2026, 11, 19), calendar: cal), "the third Thursday is not")
        XCTAssertEqual(WeekRotation.suggestion(for: day(2026, 11, 19), calendar: cal), .open)
        XCTAssertEqual(WeekRotation.days(from: day(2026, 10, 14, hour: 20), calendar: cal).count, 7)
    }

    func testTheCooksChoiceWinsAndFallsBackWhenItsRecipeIsGone() {
        var plan = WeekPlan()
        let thursday = day(2026, 10, 15)
        let rotation = WeekRotation.suggestion(for: thursday, calendar: cal)
        XCTAssertEqual(plan.dinner(on: thursday, calendar: cal), rotation)
        plan.set(.menu("recipe:ABC"), on: thursday, calendar: cal)
        XCTAssertEqual(plan.dinner(on: thursday, calendar: cal), .menu("recipe:ABC"))
        XCTAssertTrue(plan.isChosen(thursday, calendar: cal))
        XCTAssertEqual(plan.dinner(on: thursday, calendar: cal, exists: { $0 != "recipe:ABC" }), rotation, "a deleted recipe leaves the day open")
        plan.set(.open, on: thursday, calendar: cal)
        XCTAssertEqual(plan.dinner(on: thursday, calendar: cal), .open, "an open night the cook chose")
        plan.clear(thursday, calendar: cal)
        XCTAssertEqual(plan.dinner(on: thursday, calendar: cal), rotation, "back to the default")
        XCTAssertFalse(plan.isChosen(thursday, calendar: cal))
    }

    func testPruneForgetsOldDays() {
        var plan = WeekPlan()
        plan.set(.menu("pasta"), on: day(2026, 9, 1), calendar: cal)
        plan.set(.menu("salmon"), on: day(2026, 10, 10), calendar: cal)
        plan.prune(before: day(2026, 10, 13), calendar: cal)
        XCTAssertEqual(Array(plan.assignments.keys), ["2026-10-10"])
    }

    func testAPlannedDayBecomesTonightOnlyWhenNothingElseSaysSo() {
        let now = day(2026, 10, 15, hour: 16)
        var plan = WeekPlan()
        plan.set(.menu("salmon"), on: now, calendar: cal)
        var yesterdays = DinnerSession()
        yesterdays.menuID = "steak"
        yesterdays.createdAt = day(2026, 10, 14, hour: 18)
        let all: (String) -> Bool = { _ in true }

        XCTAssertEqual(WeekPlan.menuToAdopt(session: yesterdays, hasProgress: false, plan: plan, now: now, calendar: cal, cookable: all), "salmon",
                       "yesterday's untouched choice gives way to today's plan")
        XCTAssertNil(WeekPlan.menuToAdopt(session: yesterdays, hasProgress: true, plan: plan, now: now, calendar: cal, cookable: all),
                     "never while cooking")
        var todays = yesterdays
        todays.createdAt = day(2026, 10, 15, hour: 9)
        XCTAssertNil(WeekPlan.menuToAdopt(session: todays, hasProgress: false, plan: plan, now: now, calendar: cal, cookable: all),
                     "the cook already chose today")
        XCTAssertNil(WeekPlan.menuToAdopt(session: yesterdays, hasProgress: false, plan: plan, now: now, calendar: cal, cookable: { $0 != "salmon" }),
                     "a planned dinner that can't be cooked yet (a recipe that still needs its timing check) holds the day — no silent substitute")
        XCTAssertNil(WeekPlan.menuToAdopt(session: yesterdays, hasProgress: false, plan: plan, now: now, calendar: cal,
                                          exists: { $0 != "salmon" }, cookable: all),
                     "a deleted recipe leaves the day open, and tonight as it is")
        plan.set(.open, on: now, calendar: cal)
        XCTAssertNil(WeekPlan.menuToAdopt(session: yesterdays, hasProgress: false, plan: plan, now: now, calendar: cal, cookable: all),
                     "an open night leaves tonight as it is")
        plan.set(.menu("steak"), on: now, calendar: cal)
        XCTAssertNil(WeekPlan.menuToAdopt(session: yesterdays, hasProgress: false, plan: plan, now: now, calendar: cal, cookable: all),
                     "already tonight's dinner")
    }

    @MainActor
    func testStorePersistsAndRollsBack() async throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("dt-week-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = WeekPlanStore(directory: dir)
        let friday = Date().addingTimeInterval(2 * 86_400)
        XCTAssertTrue(store.set(.menu("pasta"), on: friday))
        XCTAssertEqual(WeekPlanStore(directory: dir).dinner(on: friday), .menu("pasta"), "persists after relaunch")
        store.simulateSaveFailure = true
        XCTAssertFalse(store.set(.open, on: friday))
        XCTAssertEqual(store.dinner(on: friday), .menu("pasta"), "a failed save changes nothing")
        XCTAssertNotNil(store.saveError)
        store.simulateSaveFailure = false
        XCTAssertTrue(store.clear(friday))
        XCTAssertNil(store.saveError)
        XCTAssertEqual(WeekPlanStore(directory: dir).plan.assignments, [:])
    }
}
