# A2-40 — bound a hung UI-test process and retain failure evidence

Baseline: `c8afc0cfe0b26b74373d6fc618ad492519195a3c` (main/share-extension as supplied). This is a separate proposed patch; no live app, CI branch, or workflow was modified and no CI was dispatched.

## Confirmed failure

**Source review:** `native-validation/run-native-pass.sh` invokes Xcode directly for both the full UI suite and its limited retry. The XCTest per-test allowance is the only in-process bound. `.github/workflows/duo-validation.yml` supplies a 170-minute job bound, but that cancellation can arrive before the script writes its final status or exports attachments.

**Supplemental check — downloaded CI log:** run `38468245512`, Duo job `115540393492`, source `7c4da35`, exceeded the three-minute allowance in `test15_recipeEstimate`; XCUITest nevertheless continued an Increment event through roughly 206 seconds and then produced a roughly 92-minute silent interval. Later recovery resumed testing, but the job was cancelled before final status and UI summary. This is not a reason to increase the XCTest allowance or weaken its result gate.

## Proposed delta

`A2-40-bound-ui-test-process.patch` adds one Python command wrapper and prefixes the two UI Xcode invocations with it.

- Full UI process: 60-minute wall-clock limit, 10-minute no-output limit.
- Limited retry process: 15-minute wall-clock limit, 10-minute no-output limit.
- Terminate the command's separate process group with TERM, drain output for ten seconds, then KILL the group. This covers a child surviving after the leader exits or retaining an output pipe.
- Keep stdout/stderr in the existing log; return 124 and an explicit annotation on deadline.
- Explicitly disallow retry credit after the original process returned 124. Even a partially readable result bundle cannot turn an interrupted run green.
- Preserve the current strict count, skip, identity and retry-exit checks. Preserve result-bundle export and finalization in the parent shell.

The 60-minute full-suite budget deliberately limits one Xcode invocation. If a healthy full suite approaches that budget, divide its execution into measured batches; do not silently relax the bound. This does not guarantee every job finishes before 170 minutes: platform downloads, builds, result tools and the cumulative two-device budget remain outside this focused fix. It directly catches the observed silent test-runner hang early enough to resume the harness rather than spending 95 minutes in that invocation.

The wrapper terminates descendants in the command's process group, not all global simulator services. It does not promise that a degraded simulator immediately recovers or that an interrupted xcresult is readable. Missing results remain failures.

## Validation

**Supplemental checks — executed on Linux:**

1. Normal command preserves output and exit 0.
2. Failed command preserves exit 7.
3. Silent command returns 124 before a short idle deadline.
4. Continuously emitting command returns 124 at the wall-clock deadline.
5. TERM-resistant child is killed even though the parent exits on TERM; delayed write never happens.
6. Child retaining an inherited output pipe is deadline-bounded after its leader exits.
7. `bash -n` accepts the patched shell script.
8. `git apply --check` succeeds against the exact fetched baseline file; applying reconstructs both proposed files byte-for-byte.

Test driver: `check_watchdog.py` (local supplemental test; not installed into the app's test target).

**Pending:** macOS/Xcode execution. No native, simulator or device result is claimed from these checks.
