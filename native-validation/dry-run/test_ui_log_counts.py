"""XCTest log diagnostics, including the exact Duo run 38906198562 format."""
import importlib.util
from pathlib import Path
import unittest


SPEC = importlib.util.spec_from_file_location(
    "ui_log_counts", Path(__file__).resolve().parents[1] / "read-ui-log-counts.py")
COUNTS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(COUNTS)


class UILogCountsTests(unittest.TestCase):
    def test_duo_actual_skipped_summary(self):
        self.assertEqual(COUNTS.read_counts(
            "\t Executed 18 tests, with 1 test skipped and 0 failures (0 unexpected) "
            "in 1588.807 (1589.890) seconds\n::error::Native command exceeded no-output deadline"),
            (18, 0, 1))

    def test_ordinary_summary(self):
        self.assertEqual(COUNTS.read_counts(
            "Executed 18 tests, with 0 failures (0 unexpected) in 2.0 seconds"), (18, 0, 0))

    def test_multiple_skips_and_failures(self):
        self.assertEqual(COUNTS.read_counts(
            "Executed 18 tests, with 2 tests skipped and 3 failures (1 unexpected)"), (18, 3, 2))

    def test_singular(self):
        self.assertEqual(COUNTS.read_counts(
            "Executed 1 test, with 1 failure (0 unexpected)"), (1, 1, 0))

    def test_last_suite_wins(self):
        self.assertEqual(COUNTS.read_counts(
            "Executed 2 tests, with 0 failures (0 unexpected)\n"
            "Executed 18 tests, with 1 test skipped and 1 failure (0 unexpected)"), (18, 1, 1))

    def test_missing_summary(self):
        with self.assertRaises(ValueError):
            COUNTS.read_counts("Running tests...\nTest Case 'example' started.")

    def test_zero_executed_is_zero(self):
        self.assertEqual(COUNTS.read_counts(
            "Executed 0 tests, with 0 failures (0 unexpected)"), (0, 0, 0))

    def test_rejects_inconsistent_counts(self):
        with self.assertRaises(ValueError):
            COUNTS.read_counts("Executed 1 test, with 1 test skipped and 1 failure (0 unexpected)")

    def test_malformed_final_summary_does_not_reuse_old_counts(self):
        with self.assertRaises(ValueError):
            COUNTS.read_counts("Executed 18 tests, with 0 failures (0 unexpected)\nExecuted ??? tests")

    def test_unrelated_embedded_text_is_not_summary(self):
        with self.assertRaises(ValueError):
            COUNTS.read_counts("debug: Executed 18 tests, with 0 failures (0 unexpected)")


if __name__ == "__main__":
    unittest.main()
