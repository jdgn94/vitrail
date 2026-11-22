"""Night light: the schedule maths, the actions and the state snapshot."""

from __future__ import annotations

import contextlib
import io
import json
import unittest
from datetime import time
from types import SimpleNamespace
from unittest import mock

from vitrail import nightlight

FIXED = {"mode": "fixed", "start": "20:00", "end": "07:00", "temperature": 4000}
DAY = {"mode": "fixed", "start": "08:00", "end": "17:00", "temperature": 3000}
SUN = {"mode": "sun", "start": "20:00", "end": "07:00", "temperature": 3500}


def done(stdout: str = "", code: int = 0):
    return SimpleNamespace(returncode=code, stdout=stdout, stderr="")


def at(hour: int, minute: int = 0) -> time:
    return time(hour, minute)


class Runner:
    """A fake runner that answers per query and records the argv."""

    def __init__(
        self,
        temperature: str = "4000\n",
        code: int = 0,
        identity: str = "false\n",
        identity_code: int = 0,
    ) -> None:
        self.temperature = temperature
        self.code = code
        self.identity = identity
        self.identity_code = identity_code
        self.calls: list[list[str]] = []

    def __call__(self, cmd: list[str]):
        self.calls.append(cmd)
        if cmd[:3] == ["hyprctl", "hyprsunset", "identity"]:
            return done(self.identity, self.identity_code)
        return done(self.temperature, self.code)


class PlanTests(unittest.TestCase):
    def test_a_fixed_window_crossing_midnight(self) -> None:
        self.assertEqual(nightlight.plan(at(19, 59), FIXED), nightlight.IDENTITY_TEMPERATURE)
        self.assertEqual(nightlight.plan(at(20, 0), FIXED), 4000)
        self.assertEqual(nightlight.plan(at(23, 59), FIXED), 4000)
        self.assertEqual(nightlight.plan(at(0, 0), FIXED), 4000)
        self.assertEqual(nightlight.plan(at(6, 59), FIXED), 4000)
        self.assertEqual(nightlight.plan(at(7, 0), FIXED), nightlight.IDENTITY_TEMPERATURE)
        self.assertEqual(nightlight.plan(at(12, 0), FIXED), nightlight.IDENTITY_TEMPERATURE)

    def test_a_window_within_the_day(self) -> None:
        self.assertEqual(nightlight.plan(at(7, 59), DAY), nightlight.IDENTITY_TEMPERATURE)
        self.assertEqual(nightlight.plan(at(8, 0), DAY), 3000)
        self.assertEqual(nightlight.plan(at(16, 59), DAY), 3000)
        self.assertEqual(nightlight.plan(at(17, 0), DAY), nightlight.IDENTITY_TEMPERATURE)
        self.assertEqual(nightlight.plan(at(23, 0), DAY), nightlight.IDENTITY_TEMPERATURE)

    def test_off_is_identity_all_day(self) -> None:
        schedule = {"mode": "off", "start": "20:00", "end": "07:00", "temperature": 4000}
        for hour in (0, 6, 12, 20, 23):
            with self.subTest(hour=hour):
                self.assertEqual(nightlight.plan(at(hour), schedule), nightlight.IDENTITY_TEMPERATURE)

    def test_sun_mode_runs_from_sunset_to_sunrise(self) -> None:
        self.assertEqual(nightlight.plan(at(12, 0), SUN, "06:30", "19:45"), nightlight.IDENTITY_TEMPERATURE)
        self.assertEqual(nightlight.plan(at(19, 44), SUN, "06:30", "19:45"), nightlight.IDENTITY_TEMPERATURE)
        self.assertEqual(nightlight.plan(at(19, 45), SUN, "06:30", "19:45"), 3500)
        self.assertEqual(nightlight.plan(at(23, 0), SUN, "06:30", "19:45"), 3500)
        self.assertEqual(nightlight.plan(at(3, 0), SUN, "06:30", "19:45"), 3500)
        self.assertEqual(nightlight.plan(at(6, 29), SUN, "06:30", "19:45"), 3500)
        self.assertEqual(nightlight.plan(at(6, 30), SUN, "06:30", "19:45"), nightlight.IDENTITY_TEMPERATURE)

    def test_sun_mode_without_sun_times_falls_back_to_fixed_hours(self) -> None:
        self.assertEqual(nightlight.plan(at(19, 0), SUN), nightlight.IDENTITY_TEMPERATURE)
        self.assertEqual(nightlight.plan(at(21, 0), SUN), 3500)
        self.assertEqual(nightlight.plan(at(3, 0), SUN), 3500)
        self.assertEqual(nightlight.plan(at(8, 0), SUN), nightlight.IDENTITY_TEMPERATURE)

    def test_sun_mode_with_only_one_time_falls_back_to_fixed_hours(self) -> None:
        self.assertEqual(nightlight.plan(at(21, 0), SUN, "06:30", None), 3500)
        self.assertEqual(nightlight.plan(at(21, 0), SUN, None, "19:45"), 3500)
        self.assertEqual(nightlight.plan(at(12, 0), SUN, "06:30", None), nightlight.IDENTITY_TEMPERATURE)

    def test_sun_times_in_the_schedule_are_used_too(self) -> None:
        schedule = dict(SUN, sunrise="06:30", sunset="19:45")
        self.assertEqual(nightlight.plan(at(21, 0), schedule), 3500)
        self.assertEqual(nightlight.plan(at(12, 0), schedule), nightlight.IDENTITY_TEMPERATURE)

    def test_a_malformed_or_empty_window_is_identity(self) -> None:
        self.assertEqual(
            nightlight.plan(at(21, 0), {"mode": "fixed", "start": "nope", "end": "07:00"}),
            nightlight.IDENTITY_TEMPERATURE,
        )
        self.assertEqual(
            nightlight.plan(at(21, 0), {"mode": "fixed", "start": "20:00", "end": "20:00"}),
            nightlight.IDENTITY_TEMPERATURE,
        )
        self.assertEqual(nightlight.plan(at(21, 0), {}), nightlight.IDENTITY_TEMPERATURE)

    def test_the_configured_temperature_is_clamped(self) -> None:
        cold = dict(FIXED, temperature=500)
        hot = dict(FIXED, temperature=20000)
        self.assertEqual(nightlight.plan(at(21, 0), cold), nightlight.MIN_TEMPERATURE)
        self.assertEqual(nightlight.plan(at(21, 0), hot), nightlight.MAX_TEMPERATURE)

    def test_the_window_accepts_a_clock_string_for_now(self) -> None:
        self.assertEqual(nightlight.plan("21:00", FIXED), 4000)


class NextChangeTests(unittest.TestCase):
    def test_the_next_change_is_the_next_boundary(self) -> None:
        self.assertEqual(
            nightlight.next_change(at(12, 0), FIXED),
            {"at": "20:00", "temperature": 4000, "active": True},
        )
        self.assertEqual(
            nightlight.next_change(at(19, 59), FIXED),
            {"at": "20:00", "temperature": 4000, "active": True},
        )
        self.assertEqual(
            nightlight.next_change(at(21, 0), FIXED),
            {"at": "07:00", "temperature": nightlight.IDENTITY_TEMPERATURE, "active": False},
        )
        self.assertEqual(
            nightlight.next_change(at(7, 0), FIXED),
            {"at": "20:00", "temperature": 4000, "active": True},
        )

    def test_a_day_window_crosses_to_the_next_day(self) -> None:
        self.assertEqual(
            nightlight.next_change(at(12, 0), DAY),
            {"at": "17:00", "temperature": nightlight.IDENTITY_TEMPERATURE, "active": False},
        )
        self.assertEqual(
            nightlight.next_change(at(18, 0), DAY),
            {"at": "08:00", "temperature": 3000, "active": True},
        )

    def test_sun_mode_uses_sunset_and_sunrise(self) -> None:
        self.assertEqual(
            nightlight.next_change(at(12, 0), SUN, "06:30", "19:45"),
            {"at": "19:45", "temperature": 3500, "active": True},
        )
        self.assertEqual(
            nightlight.next_change(at(21, 0), SUN, "06:30", "19:45"),
            {"at": "06:30", "temperature": nightlight.IDENTITY_TEMPERATURE, "active": False},
        )

    def test_no_next_change_for_off_or_a_broken_window(self) -> None:
        self.assertIsNone(nightlight.next_change(at(12, 0), {"mode": "off"}))
        self.assertIsNone(nightlight.next_change(at(12, 0), {"mode": "fixed", "start": "nope", "end": "07:00"}))
        self.assertIsNone(nightlight.next_change(at(12, 0), {"mode": "fixed", "start": "20:00", "end": "20:00"}))


class ClampTests(unittest.TestCase):
    def test_the_range_is_kept(self) -> None:
        self.assertEqual(nightlight.clamp_temperature(500), nightlight.MIN_TEMPERATURE)
        self.assertEqual(nightlight.clamp_temperature(1000), 1000)
        self.assertEqual(nightlight.clamp_temperature(4000), 4000)
        self.assertEqual(nightlight.clamp_temperature(10000), 10000)
        self.assertEqual(nightlight.clamp_temperature(20000), nightlight.MAX_TEMPERATURE)

    def test_strings_and_nothing_are_understood(self) -> None:
        self.assertEqual(nightlight.clamp_temperature("3500"), 3500)
        self.assertEqual(nightlight.clamp_temperature(None), nightlight.DEFAULT_TEMPERATURE)


class ArgvTests(unittest.TestCase):
    def test_enable_turns_the_filter_on_at_a_clamped_temperature(self) -> None:
        self.assertEqual(nightlight.enable_argv(4000), ["hyprsunset", "-t", "4000"])
        self.assertEqual(nightlight.enable_argv(100), ["hyprsunset", "-t", "1000"])
        self.assertEqual(nightlight.enable_argv(50000), ["hyprsunset", "-t", "10000"])

    def test_set_temperature_is_the_same_command(self) -> None:
        self.assertEqual(nightlight.set_temperature_argv(3500), ["hyprsunset", "-t", "3500"])

    def test_disable_is_the_identity(self) -> None:
        self.assertEqual(nightlight.disable_argv(), ["hyprsunset", "-i"])


class ActionTests(unittest.TestCase):
    def test_enable_reports_success(self) -> None:
        runner = Runner()
        self.assertTrue(nightlight.enable(4000, run=runner))
        self.assertEqual(runner.calls, [["hyprsunset", "-t", "4000"]])

    def test_a_failed_command_is_false(self) -> None:
        self.assertFalse(nightlight.enable(4000, run=Runner(code=1)))
        self.assertFalse(nightlight.disable(run=Runner(code=1)))
        self.assertFalse(nightlight.set_temperature(4000, run=Runner(code=1)))

    def test_disable_and_set_temperature_use_their_commands(self) -> None:
        disable_runner = Runner()
        set_runner = Runner()
        self.assertTrue(nightlight.disable(run=disable_runner))
        self.assertTrue(nightlight.set_temperature(3500, run=set_runner))
        self.assertEqual(disable_runner.calls, [["hyprsunset", "-i"]])
        self.assertEqual(set_runner.calls, [["hyprsunset", "-t", "3500"]])


class ParseTests(unittest.TestCase):
    def test_the_temperature_is_the_first_number(self) -> None:
        self.assertEqual(nightlight.parse_temperature("4000\n"), 4000)
        self.assertEqual(nightlight.parse_temperature("Temperature: 3500\n"), 3500)

    def test_a_non_answer_is_none(self) -> None:
        self.assertIsNone(nightlight.parse_temperature(""))
        self.assertIsNone(nightlight.parse_temperature("ok\n"))
        self.assertIsNone(nightlight.parse_temperature("unknown request\n"))

    def test_the_identity_flag_is_read_when_it_is_there(self) -> None:
        self.assertIs(nightlight.parse_identity("true\n"), True)
        self.assertIs(nightlight.parse_identity("false\n"), False)
        self.assertIsNone(nightlight.parse_identity(""))
        self.assertIsNone(nightlight.parse_identity("unknown request\n"))


class StateTests(unittest.TestCase):
    def state(self, runner: Runner | None = None, installed: bool = True, **kwargs) -> dict:
        return nightlight.state(
            run=runner or Runner(),
            installed=lambda: installed,
            now=at(21, 0),
            **kwargs,
        )

    def test_the_state_has_the_shape_the_popup_reads(self) -> None:
        data = self.state(schedule=FIXED)
        self.assertEqual(sorted(data), ["effective", "enabled", "error", "next", "schedule", "temperature"])
        self.assertEqual(sorted(data["schedule"]), ["end", "mode", "start", "sunrise", "sunset"])
        self.assertEqual(sorted(data["effective"]), ["active", "temperature"])
        self.assertEqual(
            data["schedule"], {"mode": "fixed", "start": "20:00", "end": "07:00", "sunrise": None, "sunset": None}
        )
        self.assertTrue(data["enabled"])
        self.assertEqual(data["temperature"], 4000)
        self.assertEqual(data["effective"], {"temperature": 4000, "active": True})
        self.assertEqual(data["next"], {"at": "07:00", "temperature": 6500, "active": False})
        self.assertIsNone(data["error"])
        json.dumps(data)

    def test_the_schedule_decides_the_effective_temperature_and_the_daemon_the_switch(self) -> None:
        data = self.state(schedule=FIXED)  # 21:00 is inside the window; the daemon says 4000.
        self.assertTrue(data["enabled"])
        self.assertTrue(data["effective"]["active"])

        runner = Runner("6500\n")  # The daemon is at identity even though the schedule is active.
        data = self.state(runner, schedule=FIXED)
        self.assertFalse(data["enabled"])
        self.assertEqual(data["effective"]["temperature"], 4000)
        self.assertTrue(data["effective"]["active"])

    def test_outside_the_window_the_schedule_asks_for_identity(self) -> None:
        data = nightlight.state(run=Runner(), installed=lambda: True, now=at(12, 0), schedule=FIXED)
        self.assertTrue(data["enabled"])  # The daemon still applies the old filter.
        self.assertEqual(data["effective"], {"temperature": nightlight.IDENTITY_TEMPERATURE, "active": False})

    def test_sun_mode_reports_the_planned_temperature(self) -> None:
        data = self.state(schedule=SUN, sunrise="06:30", sunset="19:45")
        self.assertEqual(data["schedule"]["sunrise"], "06:30")
        self.assertEqual(data["schedule"]["sunset"], "19:45")
        self.assertEqual(data["effective"], {"temperature": 3500, "active": True})

    def test_the_configured_temperature_is_clamped(self) -> None:
        data = self.state(schedule=FIXED, temperature=100)
        self.assertEqual(data["temperature"], nightlight.MIN_TEMPERATURE)
        self.assertEqual(data["effective"]["temperature"], nightlight.MIN_TEMPERATURE)

    def test_the_default_schedule_is_off(self) -> None:
        data = self.state()
        self.assertEqual(data["schedule"]["mode"], "off")
        self.assertEqual(data["effective"]["active"], False)

    def test_a_daemon_that_does_not_answer_is_not_an_error_in_the_command(self) -> None:
        data = self.state(Runner(code=1), schedule=FIXED)
        self.assertFalse(data["enabled"])
        self.assertIn("hyprsunset", data["error"])
        self.assertEqual(data["effective"], {"temperature": 4000, "active": True})

    def test_a_missing_program_is_a_normal_state(self) -> None:
        runner = Runner()
        data = self.state(runner, installed=False, schedule=FIXED)
        self.assertFalse(data["enabled"])
        self.assertEqual(data["temperature"], 4000)
        self.assertIn("hyprsunset", data["error"])
        self.assertEqual(runner.calls, [])
        self.assertEqual(data["effective"], {"temperature": 4000, "active": True})

    def test_the_daemon_read_uses_hyprctl(self) -> None:
        runner = Runner()
        self.state(runner, schedule=FIXED)
        self.assertEqual(
            runner.calls,
            [["hyprctl", "hyprsunset", "temperature"], ["hyprctl", "hyprsunset", "identity", "get"]],
        )

    def test_the_identity_flag_wins_over_a_warm_temperature(self) -> None:
        data = self.state(Runner(identity="true\n"), schedule=FIXED)
        self.assertFalse(data["enabled"])
        self.assertTrue(data["effective"]["active"])
        self.assertIsNone(data["error"])

    def test_an_unsupported_identity_query_falls_back_to_the_temperature(self) -> None:
        data = self.state(Runner(identity="unknown request\n", identity_code=1), schedule=FIXED)
        self.assertTrue(data["enabled"])


class ApplyTests(unittest.TestCase):
    def test_inside_the_window_the_filter_is_enabled(self) -> None:
        runner = Runner(temperature="6500\n", identity="true\n")
        result = nightlight.apply(now=at(21, 0), schedule=FIXED, run=runner)
        self.assertTrue(result["ok"])
        self.assertTrue(result["active"])
        self.assertTrue(result["changed"])
        self.assertEqual(result["temperature"], 4000)
        self.assertIn(["hyprsunset", "-t", "4000"], runner.calls)

    def test_outside_the_window_the_filter_is_reset(self) -> None:
        runner = Runner(temperature="4000\n", identity="false\n")
        result = nightlight.apply(now=at(12, 0), schedule=FIXED, run=runner)
        self.assertFalse(result["active"])
        self.assertTrue(result["changed"])
        self.assertIn(["hyprsunset", "-i"], runner.calls)

    def test_a_daemon_already_at_the_right_temperature_is_left_alone(self) -> None:
        runner = Runner(temperature="4000\n", identity="false\n")
        result = nightlight.apply(now=at(21, 0), schedule=FIXED, run=runner)
        self.assertTrue(result["ok"])
        self.assertFalse(result["changed"])
        self.assertNotIn(["hyprsunset", "-t", "4000"], runner.calls)
        self.assertNotIn(["hyprsunset", "-i"], runner.calls)

    def test_schedule_off_means_on_at_the_configured_temperature(self) -> None:
        runner = Runner(temperature="6500\n", identity="true\n")
        schedule = {"mode": "off", "start": "20:00", "end": "07:00"}
        result = nightlight.apply(now=at(12, 0), schedule=schedule, temperature=3500, run=runner)
        self.assertTrue(result["active"])
        self.assertEqual(result["temperature"], 3500)
        self.assertIn(["hyprsunset", "-t", "3500"], runner.calls)

    def test_a_failed_command_is_not_ok(self) -> None:
        runner = Runner(temperature="", code=1)
        result = nightlight.apply(now=at(21, 0), schedule=FIXED, run=runner)
        self.assertFalse(result["ok"])


class CommandTests(unittest.TestCase):
    def test_state_prints_compact_json(self) -> None:
        answer = {"enabled": False, "temperature": 4000, "schedule": {}, "effective": {}, "error": "missing"}
        out = io.StringIO()
        with mock.patch.object(nightlight, "state", return_value=answer), contextlib.redirect_stdout(out):
            self.assertEqual(nightlight.main(["state"]), 0)
        self.assertEqual(json.loads(out.getvalue()), answer)
        self.assertNotIn(" ", out.getvalue())

    def test_state_passes_the_options_through(self) -> None:
        answer = {"enabled": False, "temperature": 4000, "schedule": {}, "effective": {}, "error": None}
        with (
            mock.patch.object(nightlight, "state", return_value=answer) as state,
            contextlib.redirect_stdout(io.StringIO()),
        ):
            nightlight.main(
                [
                    "state",
                    "--mode",
                    "sun",
                    "--start",
                    "20:00",
                    "--end",
                    "07:00",
                    "--temperature",
                    "3500",
                    "--sunrise",
                    "06:30",
                    "--sunset",
                    "19:45",
                ]
            )
        state.assert_called_once_with(
            schedule={"mode": "sun", "start": "20:00", "end": "07:00"},
            temperature=3500,
            sunrise="06:30",
            sunset="19:45",
        )

    def test_actions_return_the_command_result(self) -> None:
        with mock.patch.object(nightlight, "enable", return_value=True) as enable:
            self.assertEqual(nightlight.main(["enable", "4000"]), 0)
        enable.assert_called_once_with(4000)

        with mock.patch.object(nightlight, "disable", return_value=True) as disable:
            self.assertEqual(nightlight.main(["disable"]), 0)
        disable.assert_called_once_with()

        with (
            mock.patch.object(nightlight, "set_temperature", return_value=False),
            contextlib.redirect_stderr(io.StringIO()),
        ):
            self.assertEqual(nightlight.main(["set-temperature", "3500"]), 1)

    def test_apply_runs_the_schedule_and_prints_its_answer(self) -> None:
        answer = {"ok": True, "active": True, "temperature": 4000, "changed": True}
        out = io.StringIO()
        with mock.patch.object(nightlight, "apply", return_value=answer) as apply, contextlib.redirect_stdout(out):
            self.assertEqual(
                nightlight.main(
                    [
                        "apply",
                        "--mode",
                        "sun",
                        "--start",
                        "20:00",
                        "--end",
                        "07:00",
                        "--temperature",
                        "3500",
                        "--sunrise",
                        "06:30",
                        "--sunset",
                        "19:45",
                    ]
                ),
                0,
            )
        apply.assert_called_once_with(
            schedule={"mode": "sun", "start": "20:00", "end": "07:00"},
            temperature=3500,
            sunrise="06:30",
            sunset="19:45",
        )
        self.assertEqual(json.loads(out.getvalue()), answer)

    def test_usage_is_an_error(self) -> None:
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as raised:
            nightlight.main([])
        self.assertEqual(raised.exception.code, 2)


if __name__ == "__main__":
    unittest.main()
