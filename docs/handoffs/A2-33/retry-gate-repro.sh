#!/usr/bin/env bash
set -uo pipefail
scenario="$1"
RESULTS="$(mktemp -d)"
trap 'rm -rf "$RESULTS"' EXIT
SUMMARY="$RESULTS/SUMMARY.md"; : > "$SUMMARY"
COMMON=()
REQUIRED_FAILURES=0
note() { printf '%s\n' "$*" | tee -a "$SUMMARY"; }
pass() { note "- PASS $1"; }
fail() { note "- FAIL $1"; REQUIRED_FAILURES=$((REQUIRED_FAILURES + 1)); }
step_result() { if [ "$2" -eq 0 ]; then pass "$1"; else fail "$1"; fi; }
xcodebuild() {
  local bundle="" prev="" arg
  for arg in "$@"; do
    if [ "$prev" = "-resultBundlePath" ]; then bundle="$arg"; fi
    prev="$arg"
  done
  mkdir -p "$bundle"
  if [[ "$bundle" = *retry* ]]; then
    printf "Test Case '-[DinnerTogetherUITests.DinnerTogetherUITests testAlpha]' passed\n"
    if [ "$scenario" = "retry-process-error" ]; then printf "Result writing error after test passed\n"; return 65; fi
    if [ "$scenario" = "retry-pass-then-fail" ]; then printf "Test Case '-[DinnerTogetherUITests.DinnerTogetherUITests testAlpha]' failed\n"; return 65; fi
    return 0
  fi
  printf "Test Case '-[DinnerTogetherUITests.DinnerTogetherUITests testAlpha]' failed\n"
  printf "error: -[DinnerTogetherUITests.DinnerTogetherUITests testBeta] - second failure\n"
  return 65
}
xcrun() {
  if [ "$1" = "xcresulttool" ] && [ "$2" = "get" ]; then
    if [ "$scenario" = "partial-failure-identities" ]; then
      printf '{"totalTestCount":10,"passedTests":8,"failedTests":2,"skippedTests":0}\n'
    else
      printf '{"totalTestCount":10,"passedTests":9,"failedTests":1,"skippedTests":0}\n'
    fi
    return 0
  fi
  local out="" prev="" arg
  for arg in "$@"; do if [ "$prev" = "--output-path" ]; then out="$arg"; fi; prev="$arg"; done
  mkdir -p "$out"
  printf 'fake png only for script control-flow reproduction' > "$out/screen.png"
}
run_ui_tests() { # label udid only_testing expected
  local label="$1" udid="$2" only_testing="$3" expected="$4"
  local bundle="$RESULTS/$label-ui.xcresult"
  local log="$RESULTS/25-ui-test-$label.log"
  rm -rf "$bundle"
  # Per-test time allowance: a flow stuck on a missing element fails in
  # minutes instead of running the job into its timeout (run 12: 45 min).
  xcodebuild test-without-building "${COMMON[@]}" -destination "id=$udid" \
    -only-testing:"$only_testing" -resultBundlePath "$bundle" \
    -test-timeouts-enabled YES -default-test-execution-time-allowance 150 -maximum-test-execution-time-allowance 240 \
    > "$log" 2>&1; rc=$?
  local passed failed executed skipped source counts
  local summary="$RESULTS/25-ui-test-$label-summary.json"
  if [ -d "$bundle" ]; then
    xcrun xcresulttool get test-results summary --path "$bundle" > "$summary" 2>/dev/null || rm -f "$summary"
  fi
  local expectedfail=0
  if [ -s "$summary" ] && counts=$(python3 -c 'import json,sys; j=json.load(open(sys.argv[1])); print(j["totalTestCount"], j["passedTests"], j["failedTests"], j.get("skippedTests", 0), j.get("expectedFailures", 0))' "$summary" 2>/dev/null); then
    set -- $counts; executed=$1; passed=$2; failed=$3; skipped=$4; expectedfail=$5; source="xcresult"
  else
    executed=0; passed=0; failed=0; skipped=0; source="unavailable"
  fi
  # Up to three failing flows are run once more, alone (A1, issue #18: four
  # consecutive runs each failed on a different flow; a 90-minute cycle per
  # flake). A flow that passes alone is reported as flaky — in the summary,
  # as an annotation and in FLAKY.txt — never hidden; one that fails again
  # fails the gate as before. The first run's xcodebuild exit is judged
  # after the retry, so a retried pass is a pass.
  local retried="" flaky="" stillfailing="" retrylog="$RESULTS/25-ui-test-$label-retry.log" retrybundle="$RESULTS/$label-ui-retry.xcresult"
  if [ "$failed" -gt 0 ] && [ "$failed" -le 3 ]; then
    local names
    names=$(grep -oE "Test Case '-\[DinnerTogetherUITests\.[A-Za-z_]+ [A-Za-z0-9_]+\]' failed" "$log" \
      | sed -E "s/.*\.([A-Za-z_]+) ([A-Za-z0-9_]+)\]' failed/\1\/\2/" | sort -u)
    if [ -n "$names" ]; then
      local onlyargs=()
      for t in $names; do onlyargs+=("-only-testing:DinnerTogetherUITests/$t"); done
      rm -rf "$retrybundle"
      xcodebuild test-without-building "${COMMON[@]}" -destination "id=$udid" \
        "${onlyargs[@]}" -resultBundlePath "$retrybundle" \
        -test-timeouts-enabled YES -default-test-execution-time-allowance 150 -maximum-test-execution-time-allowance 240 \
        > "$retrylog" 2>&1 || true
      for t in $names; do
        local m="${t##*/}"
        if grep -qE "Test Case '-\[DinnerTogetherUITests\.[A-Za-z_]+ $m\]' passed" "$retrylog"; then flaky="$flaky $t"; else stillfailing="$stillfailing $t"; fi
      done
      retried="$names"
      [ -n "$flaky" ] && printf '%s %s:%s\n' "$(date -u +%FT%TZ)" "$label" "$flaky" >> "$RESULTS/FLAKY.txt"
    fi
  fi
  local finalfailed=$failed
  if [ -n "$retried" ]; then finalfailed=$(printf '%s' "$stillfailing" | wc -w | tr -d ' '); fi
  if [ "$rc" -ne 0 ] && [ -n "$retried" ] && [ "$finalfailed" -eq 0 ]; then
    pass "xcodebuild UI tests on $label ($only_testing) (exit $rc on the first run; every failing flow passed alone on retry) — \`$(basename "$log")\`, \`$(basename "$retrylog")\`"
  else
    step_result "xcodebuild UI tests on $label ($only_testing)" $rc "$log"
  fi
  # The first failure, verbatim, so the summary says what broke without the log.
  grep -m1 -E 'error: -\[|XCTAssert|failed - ' "$log" | cut -c1-300 | sed 's/^/  - first failure: /' | tee -a "$SUMMARY" || true
  # Expected failures (XCTExpectFailure) are documented known issues; they are
  # reported here every run so they can never be forgotten, and never count as passes.
  note "  - UI cases on $label ($source): executed $executed (expected $expected), passed $passed, failed $failed, skipped $skipped, expected-failures $expectedfail — \`$(basename "$log")\`"
  if [ -n "$retried" ]; then
    note "  - retried alone on $label:$(printf ' %s' $retried) — passed on retry (flaky):${flaky:- none}; failed again:${stillfailing:- none} — \`$(basename "$retrylog")\`"
    for t in $flaky; do echo "::warning title=flaky-ui-$label::$t failed in the full run and passed alone on retry (see FLAKY.txt; A1 lane)"; done
  fi
  if [ "$expectedfail" -gt 0 ]; then note "    - ⚠️ $expectedfail expected failure(s) on $label — known issue(s) documented in UITESTS.md; see the test's XCTExpectFailure message in \`$(basename "$log")\`"; fi
  if [ "$executed" -lt "$expected" ]; then fail "$label UI: executed $executed of $expected expected UI tests"; fi
  if [ "$finalfailed" -gt 0 ]; then fail "$label UI: $finalfailed failing UI test(s)$([ -n "$retried" ] && echo " after retry:$stillfailing")"; fi
  # A skipped test is a test that did not run; it cannot count toward "passed" (Agent 1, A1-4).
  if [ "$skipped" -gt 0 ]; then fail "$label UI: $skipped skipped UI test(s) — every test must execute"; fi
  local shots="$RESULTS/ui-screenshots/$label"
  rm -rf "$shots"; mkdir -p "$shots"
  local arc=0 pngs=0
  if [ -d "$bundle" ]; then
    xcrun xcresulttool export attachments --path "$bundle" --output-path "$shots" \
      > "$RESULTS/25-ui-test-$label-attachments.log" 2>&1; arc=$?
    # The retry's own renders, kept apart: the full run's failure state and
    # the retry's pass are both evidence.
    if [ -d "$retrybundle" ]; then
      mkdir -p "$shots/retry"
      xcrun xcresulttool export attachments --path "$retrybundle" --output-path "$shots/retry" \
        >> "$RESULTS/25-ui-test-$label-attachments.log" 2>&1 || true
    fi
  else
    arc=1
  fi
  if [ "$arc" -ne 0 ]; then
    fail "$label UI: attachment export failed (exit $arc) — the flows were not photographed"
  else
    # Best effort, never a gate: give the exported files their attachment
    # names (xcresulttool names them by UUID and describes them in
    # manifest.json), so Agent 2 can read "01-review-sheet.png" instead of a
    # hash. Unknown manifest shape → files keep their exported names. (A3-U-F7)
    for shotdir in "$shots" "$shots/retry"; do [ -d "$shotdir" ] || continue
    python3 - "$shotdir" >> "$RESULTS/25-ui-test-$label-attachments.log" 2>&1 <<'PY' || true
import json, os, sys
d = sys.argv[1]; m = os.path.join(d, "manifest.json")
try:
    entries = json.load(open(m))
except Exception as e:
    print("rename: no usable manifest.json (%s); exported names kept" % e); sys.exit(0)
seen = {}
for entry in (entries if isinstance(entries, list) else []):
    for att in entry.get("attachments", []) if isinstance(entry, dict) else []:
        src = att.get("exportedFileName"); want = att.get("suggestedHumanReadableName") or att.get("name")
        if not src or not want or not os.path.isfile(os.path.join(d, src)): continue
        ext = os.path.splitext(src)[1] or ".plist"   # extension-less exports are XCTest's own binary-plist attachments ("UI Snapshot", "Synthesized Event"); screenshots always arrive with .png
        import re
        want = re.sub(r"_\d+_[0-9A-Fa-f-]{36}(\.\w+)?$", "", want)   # "01-review-sheet_0_<UUID>.png" -> "01-review-sheet"
        want = re.sub(r"\.(png|txt|mp4|jpeg|jpg)$", "", want)
        base = "".join(c if c.isalnum() or c in "-_" else "-" for c in want)
        n = seen.get(base, 0) + 1; seen[base] = n
        dst = base + ("" if n == 1 else "-%d" % n) + ext
        os.rename(os.path.join(d, src), os.path.join(d, dst)); print("rename: %s -> %s" % (src, dst))
PY
    done
    # Count what was exported, whatever the extension: the attachments are
    # all screenshots, and a wrong guess about naming must not fail a run
    # whose flows were photographed. Zero files with tests executed still fails.
    pngs=$(find "$shots" -type f ! -name 'manifest.json' -size +0 2>/dev/null | wc -l | tr -d ' ')
    note "  - UI screenshots on $label: ${pngs:-0} file(s) under \`ui-screenshots/$label/\`"
    if [ "$executed" -gt 0 ] && [ "${pngs:-0}" -eq 0 ]; then
      fail "$label UI: $executed UI test(s) ran but no screenshots were exported"
    fi
  fi
  if [ -d "$bundle" ]; then
    (cd "$RESULTS" && zip -q -r "$label-ui.xcresult.zip" "$(basename "$bundle")" && rm -rf "$bundle") || true
  fi
  if [ -d "$retrybundle" ]; then
    (cd "$RESULTS" && zip -q -r "$label-ui-retry.xcresult.zip" "$(basename "$retrybundle")" && rm -rf "$retrybundle") || true
  fi
}
run_ui_tests iphone fake-udid DinnerTogetherUITests/DinnerTogetherUITests 10
printf '\nSCENARIO=%s REQUIRED_FAILURES=%s\n' "$scenario" "$REQUIRED_FAILURES"
[ "$REQUIRED_FAILURES" -eq 0 ]

