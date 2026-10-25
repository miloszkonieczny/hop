#!/usr/bin/env python3
"""Negative/positive test of bounded command execution and cleanup."""
import json
from pathlib import Path
import sys
import tempfile
import unittest
from run_bounded import run_command


class BoundTest(unittest.TestCase):
    def test_success_and_failure_are_distinct(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            good = run_command([sys.executable, "-c", "print('ok')"], d, 2, root/"a.log", root/"a.json")
            bad = run_command([sys.executable, "-c", "raise SystemExit(7)"], d, 2, root/"b.log", root/"b.json")
            self.assertEqual(good, 0)
            self.assertEqual(bad, 1)
            self.assertEqual(json.loads((root/"b.json").read_text())["state"], "COMMAND_FAILED")

    def test_hung_command_is_timed_out(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            rc = run_command([sys.executable, "-c", "import time; time.sleep(20)"],
                             d, 1, root/"log.txt", root/"result.json")
            self.assertEqual(rc, 124)
            self.assertEqual(json.loads((root/"result.json").read_text())["state"], "TIMEOUT")


if __name__ == "__main__":
    unittest.main(verbosity=2)
