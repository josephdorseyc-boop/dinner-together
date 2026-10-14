# A2-43 — Page color retry candidate

Baseline: wip/week-plan abf2f0b9c54ae97144a3fc51a9ed98f4f382b988.

## Confirmed evidence
Simulator rendering: run 38497304286, iPad test12, both page-color-after-menu-tap-0 and -1 show the More menu still open with Page color visible. Neither shows a picker. Hierarchies contain the Page color button at {{588,40},{224,38}} and no page-style-done. XCTest logs record two element-relative coordinate taps followed by failed Done waits. This is not evidence of a sheet with a missing Done button. It does not establish why activation failed.

## Proposed bounded experiment
Only openPageColorFromMenu changes: first tap unchanged; its existing second attempt uses a freshly read, finite, on-screen item center relative to the app origin. Attach the frames. Preserve both screenshot/hierarchy captures and the final sheet assertion. No More toggle under an open menu, device-name branch, test exclusion, app code or week-flow changes.

This is a candidate harness correction, NOT a proven root-cause fix. Application-coordinate resolution differs from resolving the menu item's coordinate again, but native execution must determine whether that distinction matters. If it fails, retain the evidence and investigate menu presentation/action handling; do not add unlimited retries.

## Validation
Supplemental check: git apply --check against exact baseline and byte-for-byte patched-output verification pass. No Swift compiler or simulator execution by A2. A3 owns whether to include this in a next validation run; do not dispatch a duplicate run while 38508449584 is active.

Acceptance: iPad test12 must open the actual picker, select colors and close it with existing assertions unchanged. Also retain a Duo menu flow to ensure no regression to tapping an absent More trigger. A2-42 remains a separate capture-only patch.
