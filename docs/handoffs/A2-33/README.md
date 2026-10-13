# A2-33 — build 13 parallel failure investigation
October 13, 2026. Three read-only investigators; root independently checked decisive source, result counts, recording frame/hierarchy, and shell reproductions. No active app, test, or workflow branch was edited; no extra CI run was dispatched.

## Actual verdict, kept separate from latent risks
Run [38425982728](https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38425982728), fa04aa07, is now cancelled. Its completed immutable evidence contains:
- Debug and Release compilation passed.
- XCTest 192/192 on each iPhone and iPad; macOS swift test 192 passed.
- iPhone UI 35/36; test31_pageColorSaveFailureAX3 failed again on retry.
- iPad UI 18/18; 32 static screenshots.
- status.txt: REQUIRED_FAILURES=2, SCREENSHOT_FAILURES=0.
The intermediate green build/test step deliberately allows artifact upload. It is not a final green validation verdict. This run was not shown to have masked its actual failure.

Evidence: ui-review-evidence-38425982728, artifact 11835025797 (~209 MB), uploaded at 17:36:29 UTC. Use this per-run copy, not ci-results: that branch still points to cancelled run 38425822531/abdcaf8 and has only 12 small files.

## S2 — retry classification can hide a failure
Evidence tier: source review + supplemental shell check. Not native simulation.
native-validation/run-native-pass.sh is identical at fa04aa0 and 82047ca:
- 249–250 scrape failing identities from prose without proving coverage of structured failedTests.
- 255–261 discard retry exit status and accept any matching passed line; comparison uses method without exact class identity.
- 267–270 replace the initial failure count with only parsed retry failures.
The attached exact-function reproduction uses fake xcodebuild/xcresult commands. Three cases all incorrectly leave REQUIRED_FAILURES=0: two structured failures but one parsed identity; retry prints passed then exits65; retry prints passed and later failed for the same test. Root re-ran all three. These are modeled control-flow failures, not assertions about current simulator behavior.
A3/A1: permit a flaky pass only after complete initial failure-identity coverage, zero retry process exit, and structured retry results proving all requested full identities executed and passed without unexpected failure/skip. Otherwise preserve the original failure verdict. Keep original logs and flaky annotation. Add these scenarios to the existing fake-toolchain dry run.
Reproduce: bash docs/handoffs/A2-33/retry-gate-repro.sh partial-failure-identities (or retry-process-error / retry-pass-then-fail). Current exit0 demonstrates the defect; it is not an app test pass.

## S3 — AX3 test queries a lazy offscreen choice
Evidence tiers: source review + simulator execution logs + simulator rendering.
test31 fails at UITestSupport.swift:1453, swatch("classic").isSelected. After failed Lagoon save, the 258-point AX error appears above LazyVGrid. Classic is last and below the viewport; the current hierarchy has Cider/Tomato at y571, Olive/Saffron y704.7, Plum/Lagoon y838.3, but no Classic. The recording shows a scrollable sheet, readable error and visible Done. Standard counterpart test26 passes.
This missing-element failure does not establish failed rollback. Latest 82047ca does not fix the immediate query.
A1: reveal Classic using a bounded scroll-only helper, assert it exists inside the sheet viewport, then inspect selection. Do not tap Classic. Retain failed-Lagoon unselected, error wording, and post-dismiss cream-page assertions. Preserve those assertions rather than lowering expectations. Generic automation-type diagnostics do not establish a separate alert API defect.

## S3 — publication delays the final gate; fix already owned by A3
Evidence tiers: executed CI metadata + source review.
After successful artifact uploads at 17:36:26–29 UTC, native run remained in the ci-results publish step. A3 added timeout-minutes:6 in 82047ca at 17:51:34 UTC. Appropriate minimal fix; no duplicate patch needed. The old fa workflow cannot inherit it.
The four-push best-effort retry loop can end with echo/sleep exit0 even if no push succeeds. Optional follow-up: emit an explicit final warning naming the immutable artifact when every push fails; publication status must not imply validation success.
Running job logs returned BlobNotFound404 during investigation, so which command stalled (tar/git add/git push) remains unproven.

## Duo and render limits
Duo run38425944734/fa04aa0 still has both Xcode27.1 matrix legs in Build + XCTest, with no artifact at the latest check. It has no ci-results publish step. No Duo failure has been classified; no compatibility signoff.
A2 inspected r19a iPhone, r19b AX3 and r19c iPad from the native artifact: pale page/body/chrome are visibly readable in those sampled renders. r19b-pale-directions-ax3 contains header/review notice/tabs but no actual STEP text, so it does not prove AX direction reading. A1 should bring STEP1 into view before that capture. This is capture framing, not evidence the directions are absent from the app. Full material/photo/device/VoiceOver signoff is not claimed.
