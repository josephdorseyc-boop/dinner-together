"""Real-process checks that timeout evidence never changes the verdict."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

WRAPPER = Path(__file__).resolve().parents[1] / 'run-with-deadline.py'


class TimeoutDiagnosticsTests(unittest.TestCase):
    def run_probe(self, code, *extra):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / 'diagnostics'
            result = subprocess.run(
                [sys.executable, str(WRAPPER), '--seconds', '1',
                 '--idle-seconds', '0.3', '--grace-seconds', '0.02',
                 '--diagnostics-dir', str(output), *extra,
                 '--', sys.executable, '-c', code],
                text=True, capture_output=True, timeout=10)
            metadata = output / 'deadline.json'
            return result, json.loads(metadata.read_text()) if metadata.exists() else None

    def test_completed_process_gets_no_timeout_diagnostics(self):
        result, metadata = self.run_probe("print('finished')")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIsNone(metadata)

    def test_nonzero_process_is_not_reclassified(self):
        result, metadata = self.run_probe('import sys; sys.exit(65)')
        self.assertEqual(result.returncode, 65, result.stderr)
        self.assertIsNone(metadata)

    def test_post_suite_timeout_stays_a_failure_with_evidence(self):
        result, metadata = self.run_probe(
            "import time; print('SUITE DONE', flush=True); time.sleep(20)",
            '--done-pattern', 'SUITE DONE', '--done-idle-seconds', '0.1')
        self.assertEqual(result.returncode, 124, result.stderr)
        self.assertTrue(metadata['suite_marker_seen'])
        self.assertIn('after the tests finished', metadata['reason'])
        self.assertFalse(metadata['release_credit'])
        self.assertIsNone(metadata['process_returncode_before_signals'])

    def test_not_started_keeps_separate_exit(self):
        result, metadata = self.run_probe(
            'import time; time.sleep(20)', '--start-pattern', 'SUITE START',
            '--start-seconds', '0.1')
        self.assertEqual(result.returncode, 125, result.stderr)
        self.assertFalse(metadata['start_marker_seen'])
        self.assertFalse(metadata['release_credit'])


if __name__ == '__main__':
    unittest.main()
