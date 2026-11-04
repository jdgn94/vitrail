"""The doctor can export a sanitised report."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest import mock

from vitrail import doctor


class ReportTests(unittest.TestCase):
    def test_the_report_replaces_the_home_path(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "report.txt"
            with (
                mock.patch.object(doctor, "collect", return_value={"problems": []}),
                mock.patch.object(doctor, "render", return_value="config in " + str(Path.home()) + "/.config"),
            ):
                code = doctor.main(["--report", str(target)])
            text = target.read_text(encoding="utf-8")
        self.assertEqual(code, 0)
        self.assertIn("~/.config", text)
        self.assertNotIn(str(Path.home()), text)

    def test_a_problem_exits_one(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            with (
                mock.patch.object(doctor, "collect", return_value={"problems": ["x"]}),
                mock.patch.object(doctor, "render", return_value="a problem"),
            ):
                code = doctor.main(["--report", str(Path(tmp) / "r.txt")])
        self.assertEqual(code, 1)


if __name__ == "__main__":
    unittest.main()
