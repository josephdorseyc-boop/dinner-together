"""Run the real harness selection blocks without Xcode or a simulator."""
from pathlib import Path
import json
import os
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / "native-validation/run-native-pass.sh").read_text()
SHARDS = 'PART="${DT_PART:-all}"' + SOURCE.split('PART="${DT_PART:-all}"', 1)[1].split('\nnote "# Native validation', 1)[0]
FILTER = SOURCE.split("# A1's review:", 1)[1].split("# Quoted:", 1)[0]
FILTER = FILTER[FILTER.index('\nif [ "$IPHONE_NAME"'):]
GUARD = SOURCE.split('run_ui_tests() {', 1)[1].split('  local log=', 1)[0]


class SelectionTests(unittest.TestCase):
    def select(self, part="all", device="iPhone 16", hinge=""):
        script = '''set -uo pipefail
note() { :; }
fail() { echo "$*" >&2; }
finish() { :; }
count_matches() { grep -c -- "$2" "$1"; }
ROOT="$1"; IPHONE_NAME="$2"
EXPECTED_UI_IPHONE=$(count_matches "$ROOT/DinnerTogetherUITests/DinnerTogetherUITests.swift" 'func test')
''' + SHARDS + FILTER + '''
python3 -c 'import json,sys; print(json.dumps([sys.argv[1], int(sys.argv[2])]))' "$IPHONE_ONLY" "$EXPECTED_UI_IPHONE"
'''
        env = dict(os.environ, DT_PART=part, DT_DUO_HINGE=hinge)
        return subprocess.run(["bash", "-c", script, "selection", str(ROOT), device],
                              env=env, capture_output=True, text=True, timeout=10)

    def selected(self, **kwargs):
        result = self.select(**kwargs)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def test_ordinary_iphone_keeps_full_class(self):
        tests, count = self.selected()
        self.assertEqual(tests, "DinnerTogetherUITests/DinnerTogetherUITests")
        self.assertEqual(count, 56)

    def test_closed_duo_all_excludes_only_rotation_showcase(self):
        tests, count = self.selected(device="iPhone Duo")
        self.assertEqual(count, 55)
        self.assertNotIn("test53_weekShowcaseSideways", tests)
        self.assertIn("test55_fullScreenTimers", tests)

    def test_duo_shards_preserve_other_assignments(self):
        combined = []
        for part in range(1, 4):
            args = dict(part=f"ui-iphone-{part}-of-3")
            normal, _ = self.selected(**args)
            duo, count = self.selected(device="iPhone Duo", **args)
            expected = [line for line in normal.splitlines() if not line.endswith('/test53_weekShowcaseSideways')]
            self.assertEqual(duo.splitlines(), expected)
            self.assertEqual(count, len(expected))
            combined.extend(expected)
        self.assertEqual(len(combined), 55)
        self.assertEqual(len(set(combined)), 55)

    def test_open_duo_keeps_rotation_test(self):
        tests, count = self.selected(part="ui-iphone-2-of-3", device="iPhone Duo", hinge="flat")
        self.assertIn("test53_weekShowcaseSideways", tests)
        self.assertEqual(count, 19)

    def test_window_probe_unchanged(self):
        tests, count = self.selected(part="ui-duo-window", device="iPhone Duo")
        self.assertIn("DinnerTogetherDuoWindowTests", tests)
        self.assertEqual(count, 2)

    def test_similar_device_name_does_not_exclude(self):
        tests, count = self.selected(part="ui-iphone-2-of-3", device="iPhone Duo Test")
        self.assertIn("test53_weekShowcaseSideways", tests)
        self.assertEqual(count, 19)

    def test_invalid_shares_stop_before_xcode(self):
        for part in ("ui-iphone-4-of-3", "ui-iphone-0-of-3", "ui-iphone-1-of-0", "ui-iphone-x-of-3"):
            result = self.select(part=part)
            self.assertEqual(result.returncode, 2, result.stderr)
            self.assertIn("invalid UI share", result.stderr)

    def test_empty_filter_refuses_unfiltered_execution(self):
        script = '''set -uo pipefail
RESULTS=/unused; PART=all
fail() { echo "$*"; }
run_ui_tests() {''' + GUARD + '''
echo SHOULD_NOT_REACH_XCODE
}
run_ui_tests iphone fake-device "   " 0
'''
        result = subprocess.run(["bash", "-c", script], capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("refusing an unfiltered test run", result.stdout)
        self.assertNotIn("SHOULD_NOT_REACH_XCODE", result.stdout)
        self.assertNotIn("unbound variable", result.stderr)


if __name__ == "__main__":
    unittest.main()
