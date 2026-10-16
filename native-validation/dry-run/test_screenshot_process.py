"""Exercise screenshots.sh's real process check, including long simctl output.

No simulator or copied implementation: extract just the shell function so
the script's screenshot side effects do not run. xcrun supplies a recorded
process-list shape. Long lists stress the early-consumer-exit bug under
pipefail; a genuine missing app must still fail.
"""
from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[1] / "screenshots.sh"
FUNCTION = re.search(r"^app_running\(\).*?^}", SOURCE.read_text(), re.M | re.S).group()
APP = "1234 0 UIKitApplication:com.example.dinnertogether[0x1][1234]\n"
OTHER = "999 0 UIKitApplication:other.app[0][9]\n"


class ScreenshotProcessTests(unittest.TestCase):
    def check_process(self, snapshot, expected, repeats=1, spawn_status=0):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "launchctl.txt"
            path.write_text(snapshot)
            script = '''set -uo pipefail
BUNDLE=com.example.dinnertogether
xcrun() { cat "$SNAPSHOT"; return "$SPAWN_STATUS"; }
''' + FUNCTION + '''
bad=0
for ((i=0; i<REPEATS; i++)); do
  app_running fake-simulator
  actual=$?
  if [ "$actual" -ne "$EXPECTED" ]; then bad=$((bad+1)); fi
done
printf '%s\\n' "$bad"
'''
            result = subprocess.run(
                ["bash", "-c", 'SNAPSHOT="$1"; REPEATS="$2"; '
                 'SPAWN_STATUS="$3"; EXPECTED="$4"\n' + script,
                 "process-check", str(path), str(repeats), str(spawn_status), str(expected)],
                capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), "0", result.stderr)
            self.assertEqual(result.stderr, "")

    def test_running_small_list(self):
        self.check_process("PID Status Label\n" + APP + OTHER, 0)

    def test_running_long_list_early_match(self):
        # Real CI intermittently failed the second grep -q when it matched
        # before the producer finished. Repeat to expose that scheduling race.
        self.check_process(APP + "123 0 background.service\n" * 4000, 0, repeats=256)

    def test_running_long_list_late_match(self):
        self.check_process("123 0 background.service\n" * 4000 + APP, 0)

    def test_missing_app_still_fails(self):
        self.check_process("PID Status Label\n" + OTHER, 1)

    def test_missing_app_long_list_still_fails(self):
        self.check_process(OTHER + "123 0 background.service\n" * 4000, 1)

    def test_unknown_format_preserves_existing_policy(self):
        self.check_process("PID Status Label\n123 0 background.service\n", 0)

    def test_spawn_error_preserves_existing_policy(self):
        self.check_process("", 0, spawn_status=1)


if __name__ == "__main__":
    unittest.main()
