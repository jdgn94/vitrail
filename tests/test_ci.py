"""The workflows run the gates and the release actually builds the tarball."""

from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WORKFLOWS = ROOT / ".github" / "workflows"


class WorkflowTests(unittest.TestCase):
    def text(self, name: str) -> str:
        return (WORKFLOWS / name).read_text(encoding="utf-8")

    def test_the_gate_workflow_runs_the_three_suites(self) -> None:
        text = self.text("tests.yml")
        self.assertIn("python -m unittest discover -s tests", text)
        self.assertIn("tests/install_test.sh", text)
        self.assertIn("tests/qml_smoke.sh", text)
        self.assertIn("ruff check", text)

    def test_every_job_has_a_runner_and_a_timeout(self) -> None:
        for name in ("tests.yml", "release.yml"):
            text = self.text(name)
            jobs = re.findall(r"^  (\w+):\n(.*?)(?=^  \w+:|\Z)", text.split("\njobs:\n", 1)[1], re.M | re.S)
            self.assertTrue(jobs, name)
            for job, body in jobs:
                with self.subTest(workflow=name, job=job):
                    self.assertIn("runs-on:", body)
                    self.assertIn("timeout-minutes:", body)

    def test_every_script_the_workflows_call_exists(self) -> None:
        for name in ("tests.yml", "release.yml"):
            for script in re.findall(r"(?:bash |run: )([\w./-]+\.sh)", self.text(name)):
                with self.subTest(workflow=name, script=script):
                    self.assertTrue((ROOT / script).is_file(), script)

    def test_a_tag_publishes_the_tarball(self) -> None:
        text = self.text("release.yml")
        self.assertIn('"v*"', text)
        self.assertIn("scripts/release.sh", text)
        self.assertIn("dist/*.tar.gz", text)
        self.assertIn("pyproject.toml", text)


if __name__ == "__main__":
    unittest.main()
