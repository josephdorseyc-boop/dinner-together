#!/usr/bin/env bash
# Dry run of the native-validation scripts against a FAKE Xcode/simctl/swift
# toolchain (./faketools). Proves the scripts' own logic — counters, required
# gates, exit codes, status.txt — on any machine, in seconds. It executes no
# Swift and proves nothing about the app; it exists so the harness itself
# can't silently report success when something could not run.
#
#   bash native-validation/dry-run/run.sh          # expect: all 17 scenarios OK
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
WORK="${TMPDIR:-/tmp}/dinner-dry-run-$$"
mkdir -p "$WORK"
chmod +x "$HERE"/faketools/*
bad=0
run_case() { # name expect_pass_rc expect_shots_rc expect_required_failures expect_pngs expect_upngs env...
  local name="$1" e_pass="$2" e_shots="$3" e_fail="$4" e_png="$5" e_upng="$6"; shift 6
  local R="$WORK/$name"; rm -rf "$R"; mkdir -p "$R"
  local pass_rc shots_rc
  ( export PATH="$HERE/faketools:$PATH" FAKE_CONTAINER="$R/container" SHOT_SETTLE_SECONDS=0
    env "$@" bash "$ROOT/native-validation/run-native-pass.sh" "$R" >/dev/null 2>&1; echo $? > "$R/pass.rc"
    env "$@" bash "$ROOT/native-validation/screenshots.sh" "$R" >/dev/null 2>&1; echo $? > "$R/shots.rc" )
  pass_rc=$(cat "$R/pass.rc"); shots_rc=$(cat "$R/shots.rc")
  local failures pngs upngs
  failures=$(sed -n 's/^REQUIRED_FAILURES=//p' "$R/status.txt" | head -1)
  pngs=$(find "$R/screenshots" -name '*.png' 2>/dev/null | wc -l | tr -d ' ')
  upngs=$(find "$R/ui-screenshots" -name '*.png' 2>/dev/null | wc -l | tr -d ' ')
  local got="pass-rc=$pass_rc shots-rc=$shots_rc required-failures=${failures:-?} pngs=$pngs upngs=$upngs"
  local want="pass-rc=$e_pass shots-rc=$e_shots required-failures=$e_fail pngs=$e_png upngs=$e_upng"
  if [ "$got" = "$want" ]; then printf 'OK   %-22s %s\n' "$name" "$got"; else printf 'FAIL %-22s got: %s\n%-27s want: %s\n' "$name" "$got" "" "$want"; bad=$((bad+1)); fi
}
#        name                  pass shots fail pngs upng env
# UI attachments: the fake tool exports one per UI test method, so the
# expectation follows the UI test sources (13 before the recipe flows).
UPNG_IPHONE=$(grep -c "func test" "$ROOT/DinnerTogetherUITests/DinnerTogetherUITests.swift")
UPNG=$(( $(grep -c "func test" "$ROOT/DinnerTogetherUITests/DinnerTogetherUITests.swift") + $(grep -c "func test" "$ROOT/DinnerTogetherUITests/DinnerTogetherUITests_iPad.swift") ))
run_case all-good               0    0     0    32   $UPNG   FAKE_X=1
run_case zero-executed          1    0     1    32   $UPNG   FAKE_EXECUTED=0        # unit tests run on the iPhone simulator only (A1 #19)
run_case two-failing-cases      1    0     2    32   $UPNG   FAKE_FAIL_CASES=2
run_case no-ipad                1    1     3    16   $UPNG_IPHONE    FAKE_NO_IPAD=1   # iPhone attachments only; no iPad unit run to miss
run_case no-debug-flag          1    0     1    32   $UPNG   FAKE_NO_DEBUG=1
run_case app-dead-at-capture    0    1     1    0    $UPNG   FAKE_APP_DEAD=1
run_case swift-test-short       1    0     1    32   $UPNG   FAKE_SWIFT_EXECUTED=12
run_case no-content-size        0    0     0    28   $UPNG   FAKE_CONTENT_SIZE_RC=1
run_case screenshot-fails       0    1     1    0    $UPNG   FAKE_SHOT_FAIL=1
run_case appearance-fails       0    1     1    4    $UPNG   FAKE_APPEARANCE_RC=1   # A2-3: required light/dark not set → fail; 4 bonus shots only
run_case build-fails-partial    1    1     5    0    0    FAKE_BUILD_RC=65       # CI run 3: failed build leaves a partial .app → must not count as present
run_case skipped-test           1    0     1    32   $UPNG   FAKE_SKIPPED=1         # A1-4: a skipped unit test fails the gate (iPhone run)
run_case ui-no-executed         1    0     2    32   0    FAKE_UI_EXECUTED=0     # A1-U: no UI tests executed on either device fails the gate
run_case ui-one-failing         1    0     4    32   $((UPNG+2))   FAKE_UI_FAIL_CASES=1   # A1-U: one failing UI test per device; it is retried alone (one retry render per device) and fails again
run_case ui-flaky-passes-retry  0    0     0    32   $((UPNG+2))   FAKE_UI_FAIL_CASES=1 FAKE_UI_RETRY_PASS=1   # A1 #18: a flow that fails in the full run and passes alone is a flaky pass, reported, never a gate failure
run_case ui-many-failing        1    0     4    32   $UPNG   FAKE_UI_FAIL_CASES=4 FAKE_UI_RETRY_PASS=1   # four failures are not retried: that is a broken build, not a flake
# A2-33's three ways the first retry gate went green with a real failure: each must keep the failure verdict.
run_case ui-retry-partial-ids   1    0     4    32   $UPNG   FAKE_UI_FAIL_CASES=2 FAKE_UI_LOG_HIDE=1 FAKE_UI_RETRY_PASS=1   # xcresult counts 2 failures, the log names 1: nothing is retried, no credit
run_case ui-retry-process-error 1    0     4    32   $((UPNG+2))   FAKE_UI_FAIL_CASES=1 FAKE_UI_RETRY_PASS=1 FAKE_UI_RETRY_RC=65   # the retry prints a pass and exits 65: no credit
run_case ui-retry-pass-then-fail 1   0     4    32   $((UPNG+2))   FAKE_UI_FAIL_CASES=1 FAKE_UI_RETRY_PASS_THEN_FAIL=1   # the retry prints a pass and then a failure for the same test: no credit
run_case ui-attachments-missing 1    0     2    32   0    FAKE_UI_ATTACHMENTS_RC=1  # A1-U: export failure → the flows were not photographed
run_case ui-skipped             1    0     2    32   $UPNG   FAKE_UI_SKIPPED=1      # A1-U: a skipped UI test on each device fails the gate
run_case release-build-fails    1    0     1    32   $UPNG   FAKE_RELEASE_BUILD_RC=65  # build 9, release run 9: a DEBUG-only symbol must fail validation, not the archive
rm -rf "$WORK"
if [ "$bad" -eq 0 ]; then echo "PASS: 22 harness dry-run scenarios (fake toolchain; no Swift executed)."; else echo "FAIL: $bad scenario(s)"; exit 1; fi
