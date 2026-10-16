# A2 support: timeout / watchdog review

Reviewed exact A3 source `2afd76db20504a4a68f035ea5f3c997928cbd746`. No active branch files, remote commits, workflow dispatches/cancellations, or GitHub comments changed.

## Evidence from previous run

`ci-results/RUN.txt` identifies run `38628522264`, source `89db1f7e17243cd51e0092269d49a4c02a72f402`.

- `25-ui-test-ipad.log`: test01 exceeded **3 minutes**, despite the old command showing default150 and maximum240. The maximum is a cap, not the default. Avoid describing this as a proven240-second timeout.
- test01 launch/automation took about46s. It opened the review sheet at111s, captured it116s, moved dinner197s, confirmed the changed serving time204s, and captured `01-after-move`208s.
- Undo existed223s. Geometry helpers repeatedly enumerated about20 buttons and performed scrolls until271s; XCTest then restarted the test runner and ran the other22 tests successfully. No completed Undo assertion is evidenced for test01.
- Structured result: iPad23 executed,22 passed,1 failed. The plain log ends with22 passing tests because it describes the restarted suite; that must not override the structured failure.
- Retry was correctly refused: structured summary named one failure but the current regex found no matching `failed` case line. The timeout line uses `exceeded execution time allowance`, so retry identity was incomplete. Do not relax identity matching or reinterpret that suite as green.

This is evidence of slow automation plus a viewport helper repeatedly seeking the Undo control, not a silent lifecycle stall. It does not establish that Undo is user-reachable or that every failure is solely an infrastructure issue.

## Current budgets

- Latest source sets default240s, maximum360s, per-device wall-clock6600s/110min, no-output600s/10min, retry900s/15min, whole-job210min.
- Default240s still may be too short for test01, which was active beyond271s previously. Maximum360s does not grant360s automatically.
- Two sequential full110min device deadlines exceed the210min job budget before builds, retries, captures, and uploads. This is a worst-case evidence-preservation gap, not a demonstrated cause of the prior failure. Prior job log timestamps20:01:33→22:24:21 measure about143min; the210min job now adds about67min to that observed run. Do not interrupt the active run merely for this worst case.
- Retry900s fits three default240s tests with180s overhead, but not three360s maximum-allowance tests. Leave fail-closed behavior intact; assess actual retries before further expanding budgets.
- Warm-up/build/unit/capture subprocesses are not all independently bounded; whole-job timeout remains final protection. Follow-up should reserve explicit time for evidence publication rather than blindly raise every limit.

## Minimal optional patch

`ipad-move-undo-allowance.patch` sets `executionTimeAllowance = 360` only for iPad test01, using A3's existing cap. It changes no product code, assertions, or global budgets. Adopt only if the pending run again times out this flow or A3 wants the observed slow flow covered explicitly. If the run passes, retain it as a contingency rather than churn a validated commit.

Verified the patch applies to the local checkout (same unchanged method as exact-head GitHub source). Verified latest native script with `bash -n`. Four focused latest-watchdog subprocess checks passed: normal exit0; failed command exit65 preserved; silent timeout exit124; continuously logging wall-clock timeout exit124. Linux checks validate process/gate mechanics only, not XCTest behavior or native compilation.

## What to inspect when the current run finishes

Require complete test01 Move and Undo assertions and named screenshots, not merely207 passing unit tests. Keep command exit, structured result counts, retry identity, and timeout diagnostics consistent. Compare test01 duration with the240s default. If Undo still triggers repeated geometry scans, fix targeted viewport/element handling rather than raise the allowance again.

Sources: https://github.com/josephdorseyc-boop/dinner-together/actions/runs/38628522264 ; exact-head `native-validation/run-native-pass.sh`, `run-with-deadline.py`, `.github/workflows/native-validation.yml`, `DinnerTogetherUITests/DinnerTogetherUITests_iPad.swift`; prior `ci-results/25-ui-test-ipad.log`, `SUMMARY.md`, and `RUN.txt`.
