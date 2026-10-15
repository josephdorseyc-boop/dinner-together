# A2-61: Duo native window investigation and candidate
Baseline: 0c4d696c0441eae53babb3ba3c99b1ac25ff14ba.
Status: independently reviewed candidate; native compile and wide-window validation pending. A3 owns integration. No live CI run dispatched/cancelled.

## Evidence and cause of misleading coverage
Completed run 38738590746 at c163289 accepted Landscape Left at 7.40s; test46 then captured r26a-single-page and passed at 30.22s. It never established a wide app window. Current source already advertises both landscapes and permits near-square-phone rotation; adding those masks again is not justified.
Apple's official Duo guidance says inner-display interface orientation behaves differently and recommends adaptive window geometry/size classes:
https://developer.apple.com/videos/play/tech-talks/111461/
Device orientation command success does not prove UI/window geometry. Neither a forced SwiftUI width nor a mocked screen is native fit evidence.

## Candidate
Apply sibling A2-61-native-duo-window.patch from repository root:
`git apply --check docs/handoffs/A2-61-native-duo-window.patch`
`git apply docs/handoffs/A2-61-native-duo-window.patch`

This changes only DEBUG app instrumentation, project registration and UI tests.
- Opt-in -dt-request-landscape-scene attaches to the actual foreground window scene and submits requestGeometryUpdate. Records request/error, real window/scene bounds, scene ID, safe-area insets, traits and interface orientation in dt-scene-geometry-status. It is an experiment, not guaranteed to resize Duo.
- New explicitly selected DinnerTogetherDuoWindowTests/test01_wideNativeWindowCookbookSpread invokes existing full spread interactions with strict actual native frame >=600 wide, >=450 high, width>height. No narrow fallback can pass. Scene orientation is telemetry only.
- Existing mixed upright/spread test remains available. Main iPhone discovery has 48 methods; iPad has26 at baseline; source discovery remains unchanged. Dedicated class is in the already compiled UITestSupport.swift, outside those ordinary discovery files.
- No engine, SessionStore, timer-deadline or synthetic layout changes; no orientation-mask broadening.

## Native integration and verification
A3 should reconcile this flag/probe with any startup hook already being implemented rather than install duplicates. Rebase/apply-check against current active head first. Build Debug app + UI tests with Xcode27.1 on an isolated Duo simulator. Explicitly select:
`-only-testing:DinnerTogetherUITests/DinnerTogetherDuoWindowTests/test01_wideNativeWindowCookbookSpread`
Use existing build/test destination and normal deadline/evidence wrappers. This class is NOT selected by the ordinary 48-test script list. Require exactly one executed test, passed, zero skips, no accounting/export errors; inspect its screenshots, hierarchy and geometry diagnostic.

If request fails or bounds stay narrow, keep failure/error evidence and use Apple's documented Device Hub open/rotate/fold controls to establish a real wide window. The application request is not guaranteed to control inner-display pose. A native resized-window screenshot verifies layout fit; physical sideways/open-device proof requires pose evidence separately. Do not claim rotation resolved from a successful request or interface-orientation enum.

Then validate upright fallback, wide native recipe interactions, return to original pose without losing tab/reading state, and narrow/AX3 reachability. Recipe-reader candidate is not a timer-preservation test or proof of the newer Cooking compositions.

## Verification performed
All four specialist reviews complete; independent combined review found no blockers. Both patches apply together cleanly to exact baseline; diff whitespace checks and9 geometry scenarios +14 harness source invariants passed. No Swift/Xcode/native simulator exists on this Linux host, so source checks do not establish compile success or runtime rotation.

— A2
