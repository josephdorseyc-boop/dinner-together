# Latest Duo execution triage — 2026-10-14 UTC

Evidence: executed GitHub job logs and raw XCUITest logs/structured summaries, not device testing. No app, test, or workflow files edited.

## Current run
Duo validation 38468245512, SHA 7c4da3595b4d988ca5046aa25b2ab3766585823e, branch wip/share-extension. Overall failure. Duo job115540393492 cancelled at23:59:24UTC; ordinary iOS27 job115540393799 failed normally. Debug and Release build passed and native199/199 tests passed on BOTH legs.

The newer native-validation38484344610 atfb72b2a8af5ac717d15cd871db514a677b84c45c remains in progress at latest check; Linux and JS legs passed, native Build+XCTest phase active. It does not constitute a new Duo verdict.

## Priority1 — wall-clock hang (verification infrastructure)
Duo test15_recipeEstimate started21:36:22UTC. XCTest emitted its3min allowance warning but events continued to Increment synthesis att206.22s (~21:39:48). Next xcodebuild diagnostic is23:11:46, runner restarts23:12:31. This is >90min silence inside xcodebuild despite enabled test timeout. Test16 then timed out during launch and needed another runner restart23:19:59. Test18 also timed out. Final test42passed23:58:19; outerjob cancelled23:59:24 before xcodebuild exit/result conversion, leaving no status.txt/finalsummary/screenshots. The gate correctly failed unknown status.

Next fix: externally bound subprocess walltime, terminate its process group, preserve logs and attempt bounded result export. Keep timeout as failed/incomplete; never mark missing summary success. Root delegated a distinct timeout patch owner; A3/A1 retain integration/native proof.

## Priority2 — current named Duo assertions
Raw artifact11860124401 (1,977,258 bytes) has8files, no screenshots/resultsummary. These are log findings, not fresh visual proof:
- test22_coverCropHappyPath and test23_coverSaveFailureRetry: UITestSupport1234 Use this crop missing. Same signature as prior run; previous rendering showed crop editor closed after slider gesture. Coordinate with existing A1 crop patch rather than duplicate.
- test27_photoPageColorsAX3: UITestSupport1296 recipe-more missing during retry. Prior evidence showed menu already open; A1 state-aware menu helper lane.
- test31_pageColorSaveFailureAX3: UITestSupport1630 page-style-lagoon no snapshot. Existing reveal-before-unselected-assert lane.
- test35_palePhotoPageAX3: UITestSupport1377 each step offers Remove. At62.70s r19b Directions shot, then timing tab tap; immediately5sec existence wait, no scroll/reveal. No fresh screenshot/hierarchy to prove whether tab tap failed versus lazy/offscreenRemove. A1 should assert Timing selection, reveal Remove, retain Remove assertion. Do not label this confirmed app data-loss bug.

## Ordinary iOS27 leg
Artifact11856582391 (147,592,477bytes) structured summary:
- iPhone17:43executed42passed1failed. test03_adjustTimeOnSchedule exceeded3minutes. Rawtail shows repeated Undo: Added10min to dinner search + whole-appbuttonenumeration/scroll. Harness performance/geometry remains unverified; not evidence undo state failed.
- iPad: reported1failure is Runner(96399) bootstrapABRT, no actual testcase, no screenshots, expected21unexecuted. Infrastructure classification. Do not call it a failed undo flow.

## Local evidence
job-115540393492.log, job-115540393799.log
11860124401/25-ui-test-iphone.log (Duo; lines3867–4140hang,6222/6444crop,8167More,10185Lagoon,11926Remove)
11856582391/25-ui-test-iphone-summary.json and ipad-summary.json
11856582391/25-ui-test-iphone.log (ordinaryiPhone;1062timeout, repeatedUndoobservations)

No private user screenshots republished. No workflow dispatched or run retried.
