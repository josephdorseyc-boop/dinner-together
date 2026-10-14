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

    /// Flow 9 on iPad — Tonight on first launch, Cooking empty, Thanksgiving.
    func test03_tonightFirstLaunch_iPad() {
        flowTonightFirstLaunch()
    }

    // Recipes on iPad (A2 capture contract): r02–r10 and Dark Mode r02/r03.
    func test04_recipeReviewGate_iPad() { flowRecipeReviewGate() }
    func test05_recipeEstimate_iPad() { flowRecipeEstimate() }
    func test06_appleNewsLink_iPad() { flowAppleNewsLink() }
    func test07_timingSaveFailure_iPad() { flowTimingSaveFailure() }
    func test08_thanksgivingCard_iPad() { flowThanksgivingCard() }
    func test09_deleteFailure_iPad() { flowDeleteFailure() }
    func test10_heroPhoto_iPad() { flowHeroPhoto() }
    func test11_recipeDark_iPad() { flowRecipePageAndEstimate(.darkMode) }
    // Page colors on iPad: r14, r15.
    func test12_photoPageColors_iPad() { flowPhotoPageColors() }
    func test13_typedPageColor_iPad() { flowTypedPageColor() }
    func test14_photoPageColorsAX3_iPad() { flowPhotoPageColors(.ax3) }
    func test15_typedPageColorAX3_iPad() { flowTypedPageColor(.ax3) }
    func test16_photoPageColorsDark_iPad() { flowPhotoPageColors(.darkMode) }
    func test17_typedPageColorDark_iPad() { flowTypedPageColor(.darkMode) }
    func test18_palePhotoPage_iPad() { flowPalePhotoPage() }
    func test19_swipeEditAndDelete_iPad() { flowSwipeEditAndDelete() }
    func test20_importWarningPersists_iPad() { flowImportWarningPersists() }
    func test21_recipeCovers_iPad() { flowRecipeCovers(photo: "pastel") }
    func test22_weekPlan_iPad() { flowWeekPlan() }
    func test23_coverSwitching_iPad() { flowCoverSwitching() }
}
