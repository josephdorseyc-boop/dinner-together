# CI failure triage for A3 and A1

Reviewed completed native-validation run **38399682685**, branch `wip/build12`, SHA `c83788c9c1491c19742880541b86fea11db5a97f`. Evidence artifact: `ui-review-evidence-38399682685` (id **11822431146**), downloaded unchanged and checked by the reviewers. Replacement run **38412070798**, SHA `32f8fa068475dfdf42ace582c452cd4e4e6d8693`, was still running at inspection.

This report concerns CI/harness only; screenshot-import correctness and app-navigation work are separate owners. No source was edited, no workflow dispatched, and no GitHub message posted by this reviewer.

## Executed result (supplemental check: retrieved CI logs)

- Engine XCTest: **161/161 iPhone and 161/161 iPad**.
- UI: **32/34 iPhone**, **17/17 iPad**.
- Two iPhone failures, both recorded:
  1. `test01_reviewDinnerTimeLatePrep` at `DinnerTogetherUITests/UITestSupport.swift:459`: seeded dinner `1:25 PM` did not return after the tap labelled Undo; readout remained `1:33 PM`.
  2. `test20_appleNewsLinkAX3` at `UITestSupport.swift:1015`: `import-error` not comfortably on-screen after 12 scrolls.

## 1 — The Undo-labelled event actually lands on Completed (simulator rendering + recorded synthesized event)

The full recording is `evidence/ui-screenshots/iphone/Screen-Recording-2026-10-13-at-01-02-35-PM.mp4`. Test start in UI log is `13:02:34.826`; the recording begins approximately the next second. The log records `Tap "Undo: Moved dinner to 1:33 PM" Button` at elapsed **61.40s**.

`Synthesized-Event-2026-10-13-at-01-03-37-PM.plist` records the actual tap as **(201, 679)** on a **402 x 874** screen. The video demonstrates the scroll view still changing position: around 59s, Undo is near y679; around 60s, Undo is near y726 and the **Completed (2)** disclosure row occupies roughly y637–693. After the tap, the Completed disclosure expands, and the dinner readout later stays at 1:33 PM. A2 inspected extracted frames at 59–62 seconds; reproduce from the original recording. Original attachment `01-after-undo.png` only shows the top of the page, so that screenshot alone cannot establish the cause.

**Source review:** `CookingView.swift:344–359` is a `DisclosureGroup(isExpanded: $showCompleted)`. Undo is a distinct button at `:362`, calling `store.undoLast()`. `SessionStore.swift:117–123` restores `frame.session` before notification resync/save. We did not execute `undoLast()` ourselves or prove a state-store defect absent execution telemetry.

**Conclusion:** this run provides strong direct evidence of a wrong-control tap during unstable/stale scroll geometry, rather than evidence that the Undo handler ran and failed. Do not weaken the expected seeded time.

**Smallest A1/A3 next step:** target only this UI flow, stop the scroll overshoot and wait for the Undo target frame to remain stable before tapping. Capture the target frame and a pre-tap screenshot, then check the undo transaction/readout immediately before scrolling away. Preserve post-undo time assertion. If a correctly placed/stable tap still fails, add DEBUG action/undo-stack telemetry before any app fix. Do not assume button visibility diagnoses the handler.

## 2 — The explanation-positioning drags open the system Photos picker (simulator rendering + recorded synthesized events)

Original recording: `Screen-Recording-2026-10-13-at-01-16-56-PM.mp4`. The Apple News explanation and selected Screenshots mode were initially present, as asserted by the test. The log then invokes `scrollTo(error)` only to position a photograph.

After the first drag, the visible **Choose screenshots** button moves to y430–540. At elapsed **52.35s**, the next drag begins at normalized (0.5,0.55), namely **(201,480.7)** — inside that button. `Synthesized-Event-2026-10-13-at-01-17-51-PM.plist` confirms these coordinates. The video around 55s shows the system Photos picker loading; around 135s it shows the Photos grid while the test keeps attempting to position the underlying import error. A2 inspected extracted frames at 51, 52, 55 and 135 seconds; reproduce from the original recording.

**Conclusion:** the recorded failure is not explained solely by a tall paragraph or bounce. A drag activates the photo-selection control, obscuring the required explanation. The initial assertions happen before this side effect.

**Source review of replacement `32f8fa06`:** its only change adds `bringIntoView` (`UITestSupport.swift:369–389`) and replaces `scrollTo(error)` with `bringIntoView(error)` in this flow (`:1033`). It retains the same center-column 0.55/0.30 drag starts, and removes the final visibility assertion. That removes this exact assertion failure but does **not** establish the correct screen is photographed. It may again open Photos and report green unless post-reposition state is checked.

**Smallest A1/A3 next step:** choose scroll-start coordinates over noninteractive content, avoiding `choose-screenshots`, and reassert the explanation/selected Screenshots state is genuinely visible/hittable **after** positioning and before photograph. If the paragraph requires two AX3 views, capture the readable top and continuation rather than asserting full-paragraph fit. Do not count an unintended system Photos picker capture as the requested Apple News explanation.

## Replacement scope / evidence gap

- `32f8fa06` is harness-only and **does not alter test01**.
- This reviewer read the source and examined original simulator recordings/events, not a physical device.
- New-run outcome is pending; successful compilation or removal of test20's assertion cannot alone close these two causal observations.
