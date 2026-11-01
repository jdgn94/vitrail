"""vitrail doctor: the report it builds, and the exit code it returns."""

from __future__ import annotations

import contextlib
import io
import json
import os
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

from vitrail import doctor


class Fake:
    """Answers the four commands collect() runs, without touching the machine."""

    def __init__(self, hyprctl: int = 0, path: str = "active", gpu: str = "amd") -> None:
        self.hyprctl = hyprctl
        self.path = path
        self.gpu = gpu
        self.calls: list[list[str]] = []

    def __call__(self, argv, **_kwargs):
        self.calls.append(list(argv))
        if argv[:2] == ["systemctl", "--user"]:
            state = self.path if argv[-1].endswith(".path") else "inactive"
            return SimpleNamespace(returncode=0, stdout=state, stderr="")
        if argv[:1] == ["hyprctl"]:
            return SimpleNamespace(returncode=self.hyprctl, stdout="", stderr="")
        if argv[:1] == ["lspci"]:
            line = {
                "amd": "03:00.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI]",
                "nvidia": "01:00.0 VGA compatible controller: NVIDIA Corporation",
                "intel": "00:02.0 VGA compatible controller: Intel Corporation",
            }[self.gpu]
            return SimpleNamespace(returncode=0, stdout=line, stderr="")
        return SimpleNamespace(returncode=0, stdout="", stderr="")


class ReportTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.config = root / "config" / "vitrail"
        self.config.mkdir(parents=True)
        self.theme = root / "cache" / "vitrail" / "generated" / "theme.json"
        self.theme.parent.mkdir(parents=True)
        self.theme.write_text(json.dumps({"colors": {}}), encoding="utf-8")
        self.env = mock.patch.dict(
            os.environ,
            {
                "XDG_CONFIG_HOME": str(root / "config"),
                "XDG_CACHE_HOME": str(root / "cache"),
                "HYPRLAND_INSTANCE_SIGNATURE": "sig",
            },
        )
        self.env.start()
        self.addCleanup(self.env.stop)

    def test_a_healthy_machine_has_no_problems(self) -> None:
        report = doctor.collect(self.config, run=Fake())
        self.assertEqual(report["problems"], [])
        self.assertEqual(report["system"]["gpu"], "amd")
        self.assertEqual(report["display"]["hyprctl_exit"], 0)
        self.assertEqual(report["services"]["vitrail-settings.path"], "active")

    def test_the_gpu_vendor_is_recognised(self) -> None:
        for vendor in ("amd", "nvidia", "intel"):
            with self.subTest(vendor=vendor):
                report = doctor.collect(self.config, run=Fake(gpu=vendor))
                self.assertEqual(report["system"]["gpu"], vendor)

    def test_a_missing_theme_is_a_problem(self) -> None:
        self.theme.unlink()
        report = doctor.collect(self.config, run=Fake())
        self.assertTrue(any("theme" in problem for problem in report["problems"]))

    def test_an_invalid_theme_is_a_problem(self) -> None:
        self.theme.write_text("{not json", encoding="utf-8")
        report = doctor.collect(self.config, run=Fake())
        self.assertTrue(any("invalid" in problem for problem in report["problems"]))

    def test_a_key_outside_the_map_is_a_problem(self) -> None:
        (self.config / "appearance.ini").write_text(
            "[appearance]\nnotAKey=1\n", encoding="utf-8"
        )
        report = doctor.collect(self.config, run=Fake())
        self.assertTrue(any("notAKey" in problem for problem in report["problems"]))

    def test_an_inactive_path_unit_is_a_problem(self) -> None:
        report = doctor.collect(self.config, run=Fake(path="inactive"))
        self.assertTrue(any("vitrail-settings.path" in problem for problem in report["problems"]))

    def test_a_failing_hyprctl_is_a_problem(self) -> None:
        report = doctor.collect(self.config, run=Fake(hyprctl=1))
        self.assertTrue(any("hyprctl" in problem for problem in report["problems"]))

    def test_render_lists_every_section(self) -> None:
        text = doctor.render(doctor.collect(self.config, run=Fake()))
        for section in ("[system]", "[config]", "[services]", "[display]", "[color]", "[problems]"):
            self.assertIn(section, text)
        self.assertIn("All checks passed", text)

    def test_render_counts_the_problems(self) -> None:
        self.theme.unlink()
        text = doctor.render(doctor.collect(self.config, run=Fake()))
        self.assertIn("problem(s) detected", text)


class ExitCodeTests(unittest.TestCase):
    def report(self, problems: list[str]) -> dict:
        return {
            "system": {},
            "config": {},
            "services": {},
            "display": {},
            "color": {},
            "problems": problems,
        }

    def test_main_returns_one_with_problems(self) -> None:
        with mock.patch.object(doctor, "collect", return_value=self.report(["x"])):
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(doctor.main([]), 1)

    def test_main_returns_zero_when_healthy(self) -> None:
        with mock.patch.object(doctor, "collect", return_value=self.report([])):
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(doctor.main([]), 0)


if __name__ == "__main__":
    unittest.main()
