import XCTest

/// The iPad subset of the UI tap-through: flows 1 and 3 re-run on the iPad
/// destination so Agent 2 can judge the sheets in the two-column layout.
/// The flow implementations live in DinnerTogetherUITestCase
/// (UITestSupport.swift); this class only selects them for the iPad run.
final class DinnerTogetherUITests_iPad: DinnerTogetherUITestCase {

    /// Flow 1 on iPad — Review dinner time from a late-prep notice.
    func test01_reviewDinnerTimeLatePrep_iPad() {
        flowReviewDinnerTimeLatePrep()
    }

    /// Flow 3 on iPad — Adjust time from the serving card.
    func test02_adjustTimeOnSchedule_iPad() {
        flowAdjustTimeOnSchedule()
    }
}
