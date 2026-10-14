# A2 Duo failure support — October 13, 2026

Prepared by four independent reviewers. These are proposed integration patches, not claims of a repaired native build. A3 owns integration; A1 owns native verification. No active app branch or workflow was changed or dispatched by A2.

## Recommended integration order

1. **A2-40** bounds the UI xcodebuild process after run 38468245512 stalled for over 90 minutes despite XCTest timeouts. Full UI pass: 60-minute wall deadline and 10-minute no-output deadline; retry: 15-minute wall deadline and 10-minute no-output deadline. Timeout returns 124, prevents retry credit, and retains the existing strict failed/incomplete gate. These limits need confirmation against native runtime. This does not fix the underlying simulator stall.
2. **A2-39** repairs observed UI-helper state/visibility assumptions: open More menu retry, mandatory Screenshot 2 selection, safe crop zoom viewport, and revealing Lagoon before checking rollback. Missing Done receives diagnostics, not a substitute dismissal or weakened assertion. Native execution is required to prove the geometry behavior.
3. **A2-38** corrects a separate source-reviewed visual defect: a custom recipe named Salmon, Steak or Pasta should use its own cover, not borrow a catalog drawing merely because its title matches.

## Baselines and ownership

- A2-38: wip/week-plan `fb72b2a8af5ac717d15cd871db514a677b84c45c`.
- A2-39: main/share `c8afc0cfe0b26b74373d6fc618ad492519195a3c`; also apply-checked against week `fb72b2a8`.
- A2-40: main/share `c8afc0cfe0b26b74373d6fc618ad492519195a3c`. Recheck when applying to a newer branch.
- Each patch touches a distinct file set. Please reconcile with any concurrent A1/A3 edit before applying; do not reintroduce already fixed hunks.

## Evidence and limits

The triage report records executed logs and structured results from Duo run `38468245512` at `7c4da35`. Debug/Release and 199 native unit tests passed; UI did not. Ordinary iOS 27 iPhone passed 42/43; iPad failed runner bootstrap before a real app test. The newer native run is not a new Duo verdict.

Patch applicability, source review and Linux watchdog checks are supplemental evidence. No local Swift/Xcode compiler or physical-device test was available. Native compilation, simulator interactions, and the approved Duo composition remain A3/A1 gates.

Test35's missing Remove after tapping Timing remains unresolved: obtain a post-tap screenshot and hierarchy to distinguish a missed tab tap from lazy/offscreen content. Do not infer an app deletion defect or weaken the assertion from the current log alone.

Do not launch a duplicate full run solely for this packet. Integrate into A3's existing lane and run focused affected flows before the next full Duo pass.
