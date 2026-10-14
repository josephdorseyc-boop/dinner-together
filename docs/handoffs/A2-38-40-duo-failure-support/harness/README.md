# A2-39 — Duo interaction-state harness delta

Baseline: main / wip/share-extension `c8afc0cfe0b26b74373d6fc618ad492519195a3c`.
Also applies cleanly to wip/week-plan `fb72b2a8af5ac717d15cd871db514a677b84c45c`.
One proposed file: `DinnerTogetherUITests/UITestSupport.swift`. No app, workflow, project, test-list or assertion weakening changes. Integration remains A3/A1. Apply the separate patch, not this source-review folder wholesale.

## Confirmed source gaps and proposed changes

- S3 verification: Page color retries reopen More even when its menu is already open. The former failure renders show the open menu and absent trigger; current source retains that loop. Retry now observes sheet -> menu item -> closed menu, tapping More only when no item/sheet is present. Failed transitions capture screenshots and hierarchy.
- S3 verification: cover crop still makes Screenshot 2 optional and adjusts an off-viewport Zoom slider. Prior execution/render evidence showed crop editor dismissed during the adjustment; the gesture hitting pinned Use is a supported inference, not definitively proven. Require Screenshot 2 choice and observe the selected picker value; identify crop scroll by its Zoom descendant; reveal and settle the full slider within current window/scroll intersection, excluding pinned Use. Capture before adjustment; require changed zoom value and still-present editor afterwards. Preserve explicit Use and saved-cover assertions.
- S3 verification: failed-save test reads Lagoon before revealing it after an error moves the lazy grid. Reveal Lagoon without tapping before the existing unselected assertion, then reveal Classic as before. This does not assert an app rollback defect.
- Done disappearance remains unresolved: added pre-close screenshot/hierarchy only when Done is absent. Keep required Done action; do not replace with swipe-dismiss or count dismissal as success.

No pending A1 PR for these deltas was found in the open-PR list, current branch list, issues 15/18/20, or recent PR14 messages inspected Oct13 evening. Recheck ownership immediately before integration if A1 starts the same work.

## Validation

Supplemental checks performed: `git apply --check` plus actual isolated application passed on both exact SHAs; main applied bytes match generated proposal; existing flow method count retained (28 main,29 week); explicit Use and Lagoon rollback assertions retained. Patch SHA256: `183e84678a73acb8cb9e1dd056384023901a75126a563ba63ec6e073fc66b58d`.

Swift/Xcode/XCUITest execution is NOT available locally. This is a source-reviewed proposed harness correction, not proof native flows pass. A1/A3 compile and run existing test22/23 crop, photo color Dark/AX3, and test31 failed save in the next owned native lane. Confirm that SwiftUI picker exposes selected Screenshot 2 in label/value; if not, instrument a selected-value accessibility contract instead of removing this postcondition. Review r11a before-zoom and r11 after-zoom captures. Any Done failure now retains a fresh frame and hierarchy for app/AX/toolchain discrimination.
