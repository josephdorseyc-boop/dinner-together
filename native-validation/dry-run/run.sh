#!/usr/bin/env bash
# Dry run of the native-validation scripts against a FAKE Xcode/simctl/swift
# toolchain (./faketools). Proves the scripts' own logic — counters, required
# gates, exit codes, status.txt — on any machine, in seconds. It executes no
# Swift and proves nothing about the app; it exists so the harness itself
# can't silently report success when something could not run.
#
#   bash native-validation/dry-run/run.sh          # expect: all 16 scenarios OK
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
run_case all-good               0    0     0    32   13   FAKE_X=1
run_case zero-executed          1    0     2    32   13   FAKE_EXECUTED=0
run_case two-failing-cases      1    0     4    32   13   FAKE_FAIL_CASES=2
run_case no-ipad                1    1     4    16   10    FAKE_NO_IPAD=1
run_case no-debug-flag          1    0     1    32   13   FAKE_NO_DEBUG=1
run_case app-dead-at-capture    0    1     1    0    13   FAKE_APP_DEAD=1
run_case swift-test-short       1    0     1    32   13   FAKE_SWIFT_EXECUTED=12
run_case no-content-size        0    0     0    28   13   FAKE_CONTENT_SIZE_RC=1
run_case screenshot-fails       0    1     1    0    13   FAKE_SHOT_FAIL=1
run_case appearance-fails       0    1     1    4    13   FAKE_APPEARANCE_RC=1   # A2-3: required light/dark not set → fail; 4 bonus shots only
run_case build-fails-partial    1    1     5    0    0    FAKE_BUILD_RC=65       # CI run 3: failed build leaves a partial .app → must not count as present
run_case skipped-test           1    0     2    32   13   FAKE_SKIPPED=1         # A1-4: a skipped test on each device fails the gate
run_case ui-no-executed         1    0     2    32   0    FAKE_UI_EXECUTED=0     # A1-U: no UI tests executed on either device fails the gate
run_case ui-one-failing         1    0     4    32   13   FAKE_UI_FAIL_CASES=1   # A1-U: one failing UI test per device
run_case ui-attachments-missing 1    0     2    32   0    FAKE_UI_ATTACHMENTS_RC=1  # A1-U: export failure → the flows were not photographed
run_case ui-skipped             1    0     2    32   13   FAKE_UI_SKIPPED=1      # A1-U: a skipped UI test on each device fails the gate
rm -rf "$WORK"
if [ "$bad" -eq 0 ]; then echo "PASS: 16 harness dry-run scenarios (fake toolchain; no Swift executed)."; else echo "FAIL: $bad scenario(s)"; exit 1; fi
