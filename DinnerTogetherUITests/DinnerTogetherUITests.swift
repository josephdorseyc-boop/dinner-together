import XCTest

/// XCUITest tap-through of Dinner, Together's interactive flows on iPhone.
/// Each test seeds the app via the DEBUG-only DT_SEED_JSON launch
/// environment variable (see LaunchOptions.writeSeedFileIfPresent), drives
/// the real app in the simulator, and attaches keep-always screenshots.
/// Run on the iPhone simulator; the iPad subset lives in
/// DinnerTogetherUITests_iPad.swift.
final class DinnerTogetherUITests: DinnerTogetherUITestCase {

    /// Flow 1 — Review dinner time from a late-prep notice.
    func test01_reviewDinnerTimeLatePrep() {
        flowReviewDinnerTimeLatePrep()
    }

    /// Flow 2 — Review sheet on a lower-bound estimate.
    func test02_reviewSheetLowerBound() {
        flowReviewSheetLowerBound()
    }

    /// Flow 3 — Adjust time from the serving card.
    func test03_adjustTimeOnSchedule() {
        flowAdjustTimeOnSchedule()
    }

    /// Flow 4 — Expired timer completion.
    func test04_expiredTimerCompletion() {
        flowExpiredTimerCompletion()
    }

    /// Flow 5 — Blocked start: Cancel changes nothing, "Start anyway" starts.
    func test05_blockedStartAnyway() {
        flowBlockedStartAnyway()
    }

    /// Flow 6 — Unstarted completion confirmation; start never fabricated.
    func test06_unstartedCompletion() {
        flowUnstartedCompletion()
    }

    /// Flow 7a — Stale plan with progress: "Resume this plan".
    func test07a_stalePlanWithProgress() {
        flowStalePlanWithProgress()
    }

    /// Flow 7b — Stale plan without progress: "Keep menu, fresh time".
    func test07b_stalePlanNoProgress() {
        flowStalePlanNoProgress()
    }

    /// Flow 8 — Flow 1 at accessibility text size.
    func test08_reviewDinnerTimeAXTextSize() {
        flowReviewDinnerTimeAXTextSize()
    }
}
