"""Exercise post-suite grace with real child processes, using scaled budgets."""
from pathlib import Path
import subprocess
import sys
import unittest

WRAPPER = Path(__file__).resolve().parents[1] / "run-with-deadline.py"
DONE = "Test Suite 'Selected tests' passed"


class FinalizationDeadlineTests(unittest.TestCase):
    def run_command(self, code, finalization=1):
        return subprocess.run(
            [sys.executable, str(WRAPPER), "--seconds", "3",
             "--idle-seconds", "2", "--grace-seconds", "0.05",
             "--done-pattern", DONE, "--done-idle-seconds", str(finalization),
             "--", sys.executable, "-c", code],
            capture_output=True, text=True, timeout=5)

    def test_result_writer_finishes_with_extended_window(self):
        result = self.run_command(f"import time; print({DONE!r}, flush=True); time.sleep(0.4); print('result finalized')")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("result finalized", result.stdout)

    def test_short_window_still_interrupts_slow_result_writer(self):
        result = self.run_command(f"import time; print({DONE!r}, flush=True); time.sleep(0.4)", finalization=0.1)
        self.assertEqual(result.returncode, 124, result.stdout + result.stderr)
        self.assertIn("after the tests finished", result.stdout)

    def test_post_suite_nonzero_exit_is_preserved(self):
        result = self.run_command(f"import sys; print({DONE!r}, flush=True); sys.exit(65)")
        self.assertEqual(result.returncode, 65, result.stdout + result.stderr)

    def test_extended_window_still_bounds_a_hang(self):
        result = self.run_command(f"import time; print({DONE!r}, flush=True); time.sleep(20)", finalization=0.2)
        self.assertEqual(result.returncode, 124, result.stdout + result.stderr)
        self.assertIn("Partial results remain failures", result.stdout)


if __name__ == "__main__":
    unittest.main()
