#!/usr/bin/env bash
# Isolate a toolchain/finalization failure. This never supplies release credit.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
RESULTS="$ROOT/native-validation/probe-results"
mkdir -p "$RESULTS/direct"
printf 'DIAGNOSTIC_ONLY=true\nRELEASE_CREDIT=false\ncollect_test_diagnostics=never\nsource=%s\nxcode=%s\ndiscard_success=%s\n' \
  "$(git rev-parse HEAD)" "$PROBE_XCODE" "$PROBE_DISCARD_SUCCESS" > "$RESULTS/PROVENANCE.txt"
export DEVELOPER_DIR="/Applications/Xcode_${PROBE_XCODE}.app/Contents/Developer"
[ -d "$DEVELOPER_DIR" ] || { echo "::error::Requested Xcode is unavailable: $DEVELOPER_DIR"; exit 1; }
{
  sw_vers
  xcodebuild -version
  xcodebuild -showsdks
  xcrun simctl list runtimes available
  xcrun simctl list devicetypes
} > "$RESULTS/environment.txt" 2>&1
cat "$RESULTS/environment.txt"
# Same ordinary iPhone/runtime for both toolchains. This cannot prove Duo.
xcrun simctl list devices available -j > "$RESULTS/devices.json"
DEVICE=$(python3 - "$RESULTS/devices.json" <<'PY'
import json, sys
devices = json.load(open(sys.argv[1]))['devices']
for runtime, entries in devices.items():
    if not runtime.endswith('iOS-27-0'):
        continue
    for entry in entries:
        if entry.get('isAvailable') and entry['name'] == 'iPhone 17':
            print(entry['udid'])
            sys.exit(0)
sys.exit('The matched iOS 27.0 / iPhone 17 destination is unavailable')
PY
)
COMMON=(-project DinnerTogether.xcodeproj -scheme DinnerTogether -configuration Debug
        -derivedDataPath "$RESULTS/build" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="")
python3 native-validation/run-with-deadline.py --seconds 900 --idle-seconds 300 \
  --diagnostics-dir "$RESULTS/build-timeout" -- \
  xcodebuild build-for-testing "${COMMON[@]}" -destination "id=$DEVICE" > "$RESULTS/build.log" 2>&1 \
  || { tail -50 "$RESULTS/build.log"; exit 1; }
xcrun simctl boot "$DEVICE" > "$RESULTS/warmup.log" 2>&1 || true
python3 native-validation/run-with-deadline.py --seconds 180 --idle-seconds 180 -- \
  xcrun simctl bootstatus "$DEVICE" -b >> "$RESULTS/warmup.log" 2>&1
# The second flow is the actual failing screenshot-import test in the full run.
set +e
TEST_RUNNER_DT_SHOT_DIR="$RESULTS/direct" TEST_RUNNER_DT_SIMULATOR_NAME="iPhone 17" \
TEST_RUNNER_DT_PROBE_DELETE_SUCCESS_ATTACHMENTS="$PROBE_DISCARD_SUCCESS" \
python3 native-validation/run-with-deadline.py --seconds 1200 --idle-seconds 600 \
  --start-pattern "Test Suite '" --start-seconds 300 \
  --done-pattern "Test Suite 'Selected tests' passed" --done-pattern "Test Suite 'Selected tests' failed" \
  --done-idle-seconds 60 --diagnostics-dir "$RESULTS/test-timeout" -- \
  xcodebuild test-without-building "${COMMON[@]}" -destination "id=$DEVICE" \
  -collect-test-diagnostics never \
  -only-testing:DinnerTogetherUITests/DinnerTogetherUITests/test10_recipeLibraryEmpty \
  -only-testing:DinnerTogetherUITests/DinnerTogetherUITests/test22_coverCropHappyPath \
  -resultBundlePath "$RESULTS/probe.xcresult" \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 360 \
  -maximum-test-execution-time-allowance 480 > "$RESULTS/tests.log" 2>&1
test_rc=$?
python3 native-validation/run-with-deadline.py --seconds 60 --idle-seconds 60 -- \
  xcrun xcresulttool get test-results summary --path "$RESULTS/probe.xcresult" \
  > "$RESULTS/summary.json" 2> "$RESULTS/summary-error.log"
summary_rc=$?
python3 native-validation/run-with-deadline.py --seconds 60 --idle-seconds 60 -- \
  xcrun xcresulttool export attachments --path "$RESULTS/probe.xcresult" \
  --output-path "$RESULTS/attachments" > "$RESULTS/attachments.log" 2>&1
attachments_rc=$?
set -e
printf 'test_exit=%s\nsummary_exit=%s\nattachments_exit=%s\n' \
  "$test_rc" "$summary_rc" "$attachments_rc" >> "$RESULTS/PROVENANCE.txt"
tail -30 "$RESULTS/tests.log"
cat "$RESULTS/PROVENANCE.txt"
[ "$test_rc" -eq 0 ] && [ "$summary_rc" -eq 0 ] && [ "$attachments_rc" -eq 0 ] || exit 1
python3 - "$RESULTS" <<'PY'
import json, pathlib, struct, sys
root = pathlib.Path(sys.argv[1])
summary = json.loads((root / 'summary.json').read_text())
assert summary['totalTestCount'] == 2 and summary['passedTests'] == 2, summary
assert summary['failedTests'] == 0 and summary.get('skippedTests', 0) == 0, summary
assert summary.get('expectedFailures', 0) == 0, summary
images = list((root / 'direct').glob('*.png'))
assert images, 'Direct screenshots were not written'
for image in images:
    data = image.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n' and len(data) >= 24, image
    assert all(struct.unpack('>II', data[16:24])), image
print(f'::notice::Diagnostic completed normally: 2/2 passed; result summary and attachment export readable; {len(images)} direct PNGs. No release credit.')
PY
# Keep the small result bundle and logs, not the compiled app / build cache.
rm -rf "$RESULTS/build"
