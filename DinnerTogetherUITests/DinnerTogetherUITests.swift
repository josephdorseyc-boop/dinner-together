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

    /// Flow 9 — Tonight on first launch: nothing chosen, the first recipe,
    /// Cooking empty, Thanksgiving chosen and built.
    func test09_tonightFirstLaunch() {
        flowTonightFirstLaunch()
    }

    /// Recipes — r01: Tonight with an empty library.
    func test10_recipeLibraryEmpty() { flowRecipeLibraryEmpty() }
    /// Recipes — r02, r04, r04b, r05: review gate, duration editor, confirmation.
    func test11_recipeReviewGate() { flowRecipeReviewGate() }
    /// Recipes — r06: an Apple News link explains itself.
    func test12_appleNewsLink() { flowAppleNewsLink() }
    /// Recipes — r07: a failed confirmation stays honest.
    func test13_timingSaveFailure() { flowTimingSaveFailure() }
    /// Recipes — r08: Thanksgiving on Tonight.
    func test14_thanksgivingCard() { flowThanksgivingCard() }
    /// Recipes — r03: the untimed step stays an estimate.
    func test15_recipeEstimate() { flowRecipeEstimate() }
    /// Recipes — r09: a failed delete keeps the recipe.
    func test16_deleteFailure() { flowDeleteFailure() }
    /// Recipes — r10: landscape hero photo, no sideways scroll.
    func test17_heroPhoto() { flowHeroPhoto() }
    /// Recipes at AX3 (verified: tabs stack) — r02, r04, r04b, r05.
    func test18_recipeReviewGateAX3() { flowRecipeReviewGate(.ax3) }
    /// Recipes at AX3 — r03.
    func test19_recipeEstimateAX3() { flowRecipeEstimate(.ax3) }
    /// Recipes at AX3 — r06.
    func test20_appleNewsLinkAX3() { flowAppleNewsLink(.ax3) }
    /// Recipes in Dark Mode (verified: screen luminance) — r02, r03.
    func test21_recipeDark() { flowRecipePageAndEstimate(.darkMode) }
    /// Cover crop (A2-13, A1 PR #8) — r11, r12: stubbed screenshots, real on-device OCR.
    func test22_coverCropHappyPath() { flowCoverCropHappyPath() }
    /// Cover crop — r13: recipe saved, cover failed → retry / continue.
    func test23_coverSaveFailureRetry() { flowCoverSaveFailureRetry() }
    /// Page colors — r14: photo colors, frosted cards, ••• → Page color → Classic cream.
    func test24_photoPageColors() { flowPhotoPageColors() }
    /// Page colors — r15: a typed recipe picks Plum from the page.
    func test25_typedPageColor() { flowTypedPageColor() }
    /// Page colors — r16: a color that can’t be saved.
    func test26_pageColorSaveFailure() { flowPageColorSaveFailure() }
    // A2-17's capture requests: AX3 and Dark Mode of r14/r15, r16 at AX3, a
    // Tomato Directions page, and the solid-card rendering.
    func test27_photoPageColorsAX3() { flowPhotoPageColors(.ax3) }
    func test28_typedPageColorAX3() { flowTypedPageColor(.ax3) }
    func test29_photoPageColorsDark() { flowPhotoPageColors(.darkMode) }
    func test30_typedPageColorDark() { flowTypedPageColor(.darkMode) }
    func test31_pageColorSaveFailureAX3() { flowPageColorSaveFailure(.ax3) }
    func test32_typedTomatoDirections() { flowTypedPageColor(preset: "tomato") }
    /// The rendering Reduce Transparency and Increase Contrast select (-dt-solid-cards).
    func test33_photoPageColorsSolidCards() { flowPhotoPageColors(.solidCards) }
    /// A pastel photo's pale page (Joe, build 11), with the step Remove button.
    func test34_palePhotoPage() { flowPalePhotoPage() }
    func test35_palePhotoPageAX3() { flowPalePhotoPage(.ax3) }
    /// Your Recipes: swipe left for Edit and Delete (Joe, build 12).
    func test36_swipeEditAndDelete() { flowSwipeEditAndDelete() }
    func test37_swipeEditAndDeleteAX3() { flowSwipeEditAndDelete(.ax3) }
    /// Import warnings stay on every tab and after the timing check (A2-30).
    func test38_importWarningPersists() { flowImportWarningPersists() }
    func test39_importWarningPersistsAX3() { flowImportWarningPersists(.ax3) }
    /// Tonight's recipe cover on Tonight and RIGHT NOW (A2-35): pale and deep covers, and AX3.
    func test40_recipeCoversPale() { flowRecipeCovers(photo: "pastel") }
    func test41_recipeCoversDeep() { flowRecipeCovers(photo: "landscape") }
    func test42_recipeCoversAX3() { flowRecipeCovers(.ax3, photo: "landscape") }
    /// The week: This week on Tonight, a day's plan, the classics folder (Joe, Oct 13).
    func test43_weekPlan() { flowWeekPlan() }
    /// r24 — A2-44 checks 2 and 3: imported but not chosen, A with a photo → B without → A.
    func test44_coverSwitching() { flowCoverSwitching() }
    /// r25 — Tonight after a pale recipe page in the system appearance (Joe's
    /// black clock, build 18), and the card-glass slider.
    func test45_tonightAfterPalePageAndGlass() { flowTonightAfterPalePageAndGlass() }
    /// r26 — the cookbook spread on a window open like a book (the Duo); the single page elsewhere.
    func test46_cookbookSpread() { flowCookbookSpread() }
    /// r27 — favorites first, and a day's + Add a new recipe (Joe, build 20).
    func test47_favoritesAndWeekAdd() { flowFavoritesAndWeekAdd() }
    /// r28 — the whole meal (A1's plan on issue #23, build 21).
    func test48_dayPlanMultiCheck() { flowDayPlanMultiCheck() }
    func test49_alsoTonightRemoveAndAdd() { flowAlsoTonight() }
    func test50_addToDinnerFromRecipe() { flowAddToDinnerFromRecipe() }
    func test51_fourDishCap() { flowFourDishCap() }
    /// r29 — This Week on a phone turned sideways (the folded Duo's cover, A2-63/A2-65).
    func test53_weekShowcaseSideways() throws { try flowWeekShowcase() }
    /// r30 — build 22: Timing while cooking (locked started step; rewording).
    func test54_timingWhileCooking() { flowTimingWhileCooking() }
    /// r31 — build 22: manual full-screen timers on every destination.
    func test55_fullScreenTimers() { flowFullScreenTimers() }
    /// r31d — the full-screen timers at night: dark and dim.
    func test56_fullScreenTimersNight() { flowFullScreenTimers(night: true) }
    /// Automatic nightstand entry, landscape fit, dismissal and re-entry.
    /// Required on ordinary iPhone; closed-Duo coverage is reported by CI.
    func test57_automaticNightstandTimers() { flowFullScreenTimers(automatic: true) }
}
