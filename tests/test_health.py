"""System health: the problems the bar reports, as data."""

from __future__ import annotations

import io
import json
import subprocess
import unittest
from unittest import mock

from vitrail import health

USER_FAILED = ("systemctl", "--failed", "--user", "--plain", "--no-legend")
SYSTEM_FAILED = ("systemctl", "--failed", "--system", "--plain", "--no-legend")
VERSION = ("hyprctl", "version")
CONFIG_ERRORS = ("hyprctl", "configerrors")


def answer(code: int = 0, out: str = "", err: str = "") -> subprocess.CompletedProcess:
    return subprocess.CompletedProcess(["x"], code, out, err)


def one_unit(unit: str, description: str) -> str:
    return f"{unit} loaded failed failed {description}\n"


def fixed_usage(total: int, free: int):
    def usage(_mount: str) -> tuple[int, int, int]:
        return (total, total - free, free)

    return usage


class FakeRunner:
    """argv -> the answer the test gives; anything else exits 0 with no output."""

    def __init__(self, answers: dict[tuple[str, ...], subprocess.CompletedProcess] | None = None):
        self.answers = answers or {}
        self.calls: list[tuple[str, ...]] = []

    def __call__(self, argv: list[str]) -> subprocess.CompletedProcess:
        self.calls.append(tuple(argv))
        return self.answers.get(tuple(argv), answer())


class ServiceTests(unittest.TestCase):
    def test_a_failed_user_unit_is_one_problem_with_its_commands(self) -> None:
        runner = FakeRunner({USER_FAILED: answer(0, one_unit("vitrail-settings.service", "Vitrail settings"))})
        report = health.state(runner, checks={"user_services"})
        self.assertEqual(len(report["problems"]), 1)
        problem = report["problems"][0]
        self.assertEqual(problem["id"], "service-user:vitrail-settings.service")
        self.assertEqual(problem["severity"], "warning")
        self.assertEqual(problem["title"], "vitrail-settings.service")
        self.assertEqual(problem["detail"], "user service failed: Vitrail settings")
        self.assertEqual(problem["fix"], ["systemctl", "--user", "restart", "vitrail-settings.service"])
        self.assertEqual(problem["logs"], ["journalctl", "--user", "-u", "vitrail-settings.service", "-n", "200"])
        self.assertEqual(report["count"], 1)
        self.assertIsNone(report["error"])

    def test_a_failed_system_unit_is_an_error_without_the_user_flag(self) -> None:
        runner = FakeRunner({SYSTEM_FAILED: answer(0, one_unit("NetworkManager.service", "Network Manager"))})
        problem = health.state(runner, checks={"system_services"})["problems"][0]
        self.assertEqual(problem["id"], "service-system:NetworkManager.service")
        self.assertEqual(problem["severity"], "error")
        self.assertEqual(problem["fix"], ["systemctl", "restart", "NetworkManager.service"])
        self.assertEqual(problem["logs"], ["journalctl", "-u", "NetworkManager.service", "-n", "200"])

    def test_no_failed_units_is_no_problem(self) -> None:
        runner = FakeRunner({USER_FAILED: answer(), SYSTEM_FAILED: answer()})
        report = health.state(runner, checks={"user_services", "system_services"})
        self.assertEqual(report["problems"], [])
        self.assertIsNone(report["error"])

    def test_a_missing_systemctl_is_not_a_problem(self) -> None:
        report = health.state(lambda argv: None, checks={"user_services", "system_services"})
        self.assertEqual(report["problems"], [])
        self.assertIsNone(report["error"])

    def test_the_failed_list_is_parsed_column_by_column(self) -> None:
        text = "a.service loaded failed failed First unit\nb.timer loaded failed failed\n"
        self.assertEqual(health.parse_failed(text), [("a.service", "First unit"), ("b.timer", "")])
        self.assertEqual(health.parse_failed(""), [])


class DiskTests(unittest.TestCase):
    def test_a_mount_exactly_at_the_threshold_is_fine(self) -> None:
        report = health.state(lambda argv: None, checks={"disk"}, mounts=["/"], usage=fixed_usage(1000, 50))
        self.assertEqual(report["problems"], [])

    def test_below_the_threshold_reports_the_percentage(self) -> None:
        report = health.state(lambda argv: None, checks={"disk"}, mounts=["/"], usage=fixed_usage(1000, 49))
        problem = report["problems"][0]
        self.assertEqual(problem["id"], "disk:/")
        self.assertEqual(problem["severity"], "warning")
        self.assertIn("4.9%", problem["detail"])
        self.assertIsNone(problem["fix"])
        self.assertIsNone(problem["logs"])

    def test_every_low_mount_is_its_own_problem(self) -> None:
        usage = lambda mount: (1000, 980, 10 if mount == "/home" else 20)  # noqa: E731
        report = health.state(lambda argv: None, checks={"disk"}, mounts=["/", "/home"], usage=usage)
        self.assertEqual([p["id"] for p in report["problems"]], ["disk:/", "disk:/home"])

    def test_the_threshold_is_configurable(self) -> None:
        def report(threshold: int) -> dict:
            return health.state(
                lambda argv: None, checks={"disk"}, mounts=["/"], usage=fixed_usage(1000, 100), threshold=threshold
            )

        self.assertEqual(report(5)["problems"], [])
        self.assertEqual(len(report(15)["problems"]), 1)

    def test_a_mount_that_cannot_be_read_is_skipped(self) -> None:
        def usage(_mount: str) -> tuple[int, int, int]:
            raise OSError("gone")

        report = health.state(lambda argv: None, checks={"disk"}, mounts=["/gone"], usage=usage)
        self.assertEqual(report["problems"], [])

    def test_mounts_are_the_local_filesystems_one_per_source(self) -> None:
        text = "\n".join(
            [
                "/dev/sda1 / ext4 rw,relatime 0 0",
                "proc /proc proc rw 0 0",
                "tmpfs /run tmpfs rw 0 0",
                "/dev/sda2 /home btrfs rw,subvol=/home 0 0",
                "/dev/sda2 /srv btrfs rw,subvol=/srv 0 0",
                "/dev/sdb1 /mnt/My\\040Disk exfat rw 0 0",
                "",
            ]
        )
        self.assertEqual(health.parse_mounts(text), ["/", "/home", "/mnt/My Disk"])


class HyprlandTests(unittest.TestCase):
    def report(
        self,
        configerrors: subprocess.CompletedProcess | None = None,
        version: subprocess.CompletedProcess | None = None,
    ) -> tuple[dict, FakeRunner]:
        answers = {VERSION: version if version is not None else answer()}
        if configerrors is not None:
            answers[CONFIG_ERRORS] = configerrors
        runner = FakeRunner(answers)
        return health.state(runner, checks={"hyprland"}), runner

    def test_a_clean_config_is_no_problem(self) -> None:
        report, runner = self.report(configerrors=answer(0, "no errors\n"))
        self.assertEqual(report["problems"], [])
        self.assertIn(CONFIG_ERRORS, runner.calls)

    def test_an_empty_answer_is_a_clean_config(self) -> None:
        report, _runner = self.report(configerrors=answer())
        self.assertEqual(report["problems"], [])

    def test_config_errors_are_one_problem_with_reload_and_its_logs(self) -> None:
        report, _runner = self.report(configerrors=answer(0, "line 3: unknown keyword\nline 7: bad bind\n"))
        problem = report["problems"][0]
        self.assertEqual(problem["id"], "hyprland:config")
        self.assertEqual(problem["severity"], "warning")
        self.assertIn("line 3: unknown keyword", problem["detail"])
        self.assertEqual(problem["fix"], ["hyprctl", "reload"])
        self.assertEqual(problem["logs"], ["hyprctl", "configerrors"])

    def test_without_hyprland_running_config_errors_are_not_asked_for(self) -> None:
        report, runner = self.report(version=answer(1, "", "not running"))
        self.assertEqual(report["problems"], [])
        self.assertNotIn(CONFIG_ERRORS, runner.calls)

    def test_a_missing_hyprctl_is_not_a_problem(self) -> None:
        report = health.state(lambda argv: None, checks={"hyprland"})
        self.assertEqual(report["problems"], [])
        self.assertIsNone(report["error"])


class DoctorTests(unittest.TestCase):
    def test_a_failed_doctor_is_one_problem_with_its_report(self) -> None:
        with (
            mock.patch.object(health.doctor, "collect", return_value={"problems": ["service: x"]}) as collect,
            mock.patch.object(health.doctor, "render", return_value="[problems]\n  - service: x"),
        ):
            report = health.state(lambda argv: None, checks={"doctor"})
        self.assertEqual(len(report["problems"]), 1)
        problem = report["problems"][0]
        self.assertEqual(problem["id"], "doctor")
        self.assertEqual(problem["severity"], "warning")
        self.assertIn("service: x", problem["detail"])
        self.assertEqual(problem["logs"], ["vitrail", "doctor"])
        self.assertIsNone(problem["fix"])
        self.assertTrue(callable(collect.call_args.kwargs["run"]))

    def test_a_clean_doctor_is_no_problem(self) -> None:
        with mock.patch.object(health.doctor, "collect", return_value={"problems": []}):
            report = health.state(lambda argv: None, checks={"doctor"})
        self.assertEqual(report["problems"], [])


class StateTests(unittest.TestCase):
    def clean(self) -> FakeRunner:
        return FakeRunner(
            {
                USER_FAILED: answer(),
                SYSTEM_FAILED: answer(),
                VERSION: answer(0, "Hyprland 0.45\n"),
                CONFIG_ERRORS: answer(0, "no errors\n"),
            }
        )

    def test_everything_fine_is_an_empty_list_not_an_error(self) -> None:
        with mock.patch.object(health.doctor, "collect", return_value={"problems": []}):
            report = health.state(
                self.clean(),
                checks={"user_services", "system_services", "hyprland", "doctor"},
                mounts=[],
                usage=fixed_usage(1000, 900),
            )
        self.assertEqual(report["problems"], [])
        self.assertEqual(report["count"], 0)
        self.assertIsNone(report["error"])

    def test_each_check_can_be_switched_off(self) -> None:
        runner = FakeRunner({USER_FAILED: answer(0, one_unit("a.service", "A"))})
        report = health.state(runner, checks={"system_services"})
        self.assertEqual(report["problems"], [])
        self.assertNotIn(USER_FAILED, runner.calls)

    def test_no_checks_means_no_problems_and_no_commands(self) -> None:
        runner = FakeRunner()
        report = health.state(runner, checks=set())
        self.assertEqual(report["problems"], [])
        self.assertEqual(runner.calls, [])

    def test_all_checks_are_on_by_default(self) -> None:
        runner = self.clean()
        with mock.patch.object(health.doctor, "collect", return_value={"problems": []}):
            health.state(runner, mounts=[], usage=fixed_usage(1000, 900))
        for argv in (USER_FAILED, SYSTEM_FAILED, VERSION, CONFIG_ERRORS):
            with self.subTest(argv=argv):
                self.assertIn(argv, runner.calls)

    def test_an_unknown_check_is_the_only_error(self) -> None:
        report = health.state(FakeRunner(), checks={"diskz"})
        self.assertEqual(report["problems"], [])
        self.assertIn("diskz", report["error"])

    def test_the_json_shape_is_stable(self) -> None:
        report = health.state(FakeRunner(), checks=set())
        self.assertEqual(set(report), {"problems", "count", "checkedAt", "error"})
        self.assertRegex(report["checkedAt"], r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")
        json.dumps(report)

    def test_a_problem_has_exactly_the_six_documented_keys(self) -> None:
        runner = FakeRunner({USER_FAILED: answer(0, one_unit("a.service", "A"))})
        problem = health.state(runner, checks={"user_services"})["problems"][0]
        self.assertEqual(set(problem), {"id", "severity", "title", "detail", "fix", "logs"})
        self.assertIn(problem["severity"], {"error", "warning"})

    def test_the_bar_id_is_documented_and_never_emitted(self) -> None:
        self.assertEqual(health.BAR_ID, "bar")
        report = health.state(FakeRunner(), checks=set())
        self.assertNotIn(health.BAR_ID, [p["id"] for p in report["problems"]])

    def test_the_check_names_are_the_documented_ones(self) -> None:
        self.assertEqual(set(health.CHECKS), {"user_services", "system_services", "disk", "hyprland", "doctor"})


class CommandTests(unittest.TestCase):
    def test_state_prints_one_json_object(self) -> None:
        with mock.patch.object(
            health, "state", return_value={"problems": [], "count": 0, "checkedAt": "now", "error": None}
        ):
            with mock.patch("sys.stdout", new_callable=io.StringIO) as out:
                code = health.main(["state"])
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(out.getvalue()), {"problems": [], "count": 0, "checkedAt": "now", "error": None})

    def test_anything_else_is_a_usage_error(self) -> None:
        with mock.patch("sys.stderr", new_callable=io.StringIO):
            self.assertEqual(health.main([]), 2)


if __name__ == "__main__":
    unittest.main()
