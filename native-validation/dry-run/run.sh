#!/usr/bin/env bash
# Dry run of the native-validation scripts against a FAKE Xcode/simctl/swift
# toolchain (./faketools). Proves the scripts' own logic — counters, required
# gates, exit codes, status.txt — on any machine, in seconds. It executes no
# Swift and proves nothing about the app; it exists so the harness itself
# can't silently report success when something could not run.
#
#   bash native-validation/dry-run/run.sh          # expect: all 10 scenarios OK
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
WORK="${TMPDIR:-/tmp}/dinner-dry-run-$$"
mkdir -p "$WORK"
chmod +x "$HERE"/faketools/*
bad=0
run_case() { # name expect_pass_rc expect_shots_rc expect_required_failures expect_pngs env...
  local name="$1" e_pass="$2" e_shots="$3" e_fail="$4" e_png="$5"; shift 5
  local R="$WORK/$name"; rm -rf "$R"; mkdir -p "$R"
  local pass_rc shots_rc
  ( export PATH="$HERE/faketools:$PATH" FAKE_CONTAINER="$R/container" SHOT_SETTLE_SECONDS=0
    env "$@" bash "$ROOT/native-validation/run-native-pass.sh" "$R" >/dev/null 2>&1; echo $? > "$R/pass.rc"
    env "$@" bash "$ROOT/native-validation/screenshots.sh" "$R" >/dev/null 2>&1; echo $? > "$R/shots.rc" )
  pass_rc=$(cat "$R/pass.rc"); shots_rc=$(cat "$R/shots.rc")
  local failures pngs
  failures=$(sed -n 's/^REQUIRED_FAILURES=//p' "$R/status.txt" | head -1)
  pngs=$(find "$R/screenshots" -name '*.png' 2>/dev/null | wc -l | tr -d ' ')
  local got="pass-rc=$pass_rc shots-rc=$shots_rc required-failures=${failures:-?} pngs=$pngs"
  local want="pass-rc=$e_pass shots-rc=$e_shots required-failures=$e_fail pngs=$e_png"
  if [ "$got" = "$want" ]; then printf 'OK   %-18s %s\n' "$name" "$got"; else printf 'FAIL %-18s got: %s\n%-23s want: %s\n' "$name" "$got" "" "$want"; bad=$((bad+1)); fi
}
#        name               pass shots fail pngs  env
run_case all-good            0    0     0    28   FAKE_X=1
run_case zero-executed       1    0     2    28   FAKE_EXECUTED=0
run_case two-failing-cases   1    0     4    28   FAKE_FAIL_CASES=2
run_case no-ipad             1    1     3    14   FAKE_NO_IPAD=1
run_case no-debug-flag       1    0     1    28   FAKE_NO_DEBUG=1
run_case app-dead-at-capture 0    1     1    0    FAKE_APP_DEAD=1
run_case swift-test-short    1    0     1    28   FAKE_SWIFT_EXECUTED=12
run_case no-content-size     0    0     0    24   FAKE_CONTENT_SIZE_RC=1
run_case screenshot-fails    0    1     1    0    FAKE_SHOT_FAIL=1
run_case appearance-fails    0    1     1    4    FAKE_APPEARANCE_RC=1   # A2-3: required light/dark not set → fail; 4 bonus shots only
rm -rf "$WORK"
if [ "$bad" -eq 0 ]; then echo "PASS: 10 harness dry-run scenarios (fake toolchain; no Swift executed)."; else echo "FAIL: $bad scenario(s)"; exit 1; fi
