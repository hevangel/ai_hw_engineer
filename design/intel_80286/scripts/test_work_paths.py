"""Tests for release evidence-root selection."""

import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from work_paths import WORK_ROOT_ENV, get_work_root


class WorkPathTests(unittest.TestCase):
    def test_defaults_to_design_work_directory(self):
        design = Path("fixture/design")
        with patch.dict(os.environ, {}, clear=True):
            self.assertEqual(get_work_root(design), (design / "work").resolve())

    def test_environment_selects_an_absolute_evidence_root(self):
        with tempfile.TemporaryDirectory() as temp:
            evidence = Path(temp) / "release-001"
            with patch.dict(os.environ, {WORK_ROOT_ENV: str(evidence)}):
                self.assertEqual(get_work_root("ignored/design"), evidence.resolve())

    def test_relative_override_resolves_from_the_calling_directory(self):
        with tempfile.TemporaryDirectory() as temp:
            previous = Path.cwd()
            try:
                os.chdir(temp)
                with patch.dict(os.environ, {WORK_ROOT_ENV: "results/release"}):
                    self.assertEqual(get_work_root("ignored/design"),
                                     (Path(temp) / "results/release").resolve())
            finally:
                os.chdir(previous)


if __name__ == "__main__":
    unittest.main()
