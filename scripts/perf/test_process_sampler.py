#!/usr/bin/env python3
import os
from pathlib import Path
import subprocess
import sys
import unittest
from process_sampler import parse_cpu_time, percentile, get_process, run


class SamplerTests(unittest.TestCase):
    def test_parse_standard_times(self):
        self.assertEqual(parse_cpu_time("00:01"), 1)
        self.assertEqual(parse_cpu_time("02:03.50"), 123.5)
        self.assertEqual(parse_cpu_time("01:02:03"), 3723)
        self.assertEqual(parse_cpu_time("2-01:02:03.25"), 2 * 86400 + 3723.25)

    def test_invalid_times_fail(self):
        for value in ("", "hello", "00:90", "1-xx:02", "01", "10:-1"):
            with self.subTest(value=value):
                with self.assertRaises(ValueError):
                    parse_cpu_time(value)

    def test_percentiles_and_empty(self):
        self.assertIsNone(percentile([], 95))
        self.assertEqual(percentile([1], 95), 1)
        self.assertEqual(percentile([1, 2, 3, 4, 5], 95), 4.8)

    def test_wrong_identity_fails_closed(self):
        outcome = run(os.getpid(), 5, 1, "THIS_SHOULD_NEVER_BE_IN_PS_ARGS")
        self.assertEqual(outcome["status"], "FAIL_IDENTITY_MISMATCH")

    def test_short_lived_process_marked_inconclusive(self):
        child = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(0.8)", "PERF_SHORT_LIVED"])
        try:
            outcome = run(child.pid, 5, .3, "PERF_SHORT_LIVED")
            self.assertEqual(outcome["status"], "INCONCLUSIVE_EARLY_EXIT")
        finally:
            child.wait(timeout=5)

    def test_running_process_cpu_record(self):
        child = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(6.5)", "PERF_CONTROL"])
        try:
            outcome = run(child.pid, 5, 1, "PERF_CONTROL")
            self.assertEqual(outcome["status"], "MEASURED_PROCESS_ONLY")
            self.assertGreaterEqual(outcome["cpu_time_delta_seconds"], 0)
            self.assertGreaterEqual(outcome["rss_kib_max"], 0)
            self.assertGreaterEqual(len(outcome["samples"]), 3)
        finally:
            child.terminate()
            child.wait(timeout=5)


if __name__ == "__main__":
    unittest.main(verbosity=2)
