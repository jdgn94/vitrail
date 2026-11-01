"""Safe mode: the marker, the config errors and the fallback session."""

from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

from vitrail import cli, prefs, safe_mode


class MarkerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.config = Path(self.tmp.name) / "vitrail"

    def test_enter_and_exit_round_trip(self) -> None:
        self.assertFalse(safe_mode.is_active(self.config))
        safe_mode.enter(self.config)
        self.assertTrue(safe_mode.is_active(self.config))
        self.assertTrue(safe_mode.exit(self.config))
        self.assertFalse(safe_mode.is_active(self.config))

    def test_exit_without_a_marker_reports_nothing_removed(self) -> None:
        self.assertFalse(safe_mode.exit(self.config))


class ConfigErrorTests(unittest.TestCase):
    def test_no_errors_reads_as_empty(self) -> None:
        run = lambda *_a, **_k: SimpleNamespace(returncode=0, stdout="  \n", stderr="")
        self.assertEqual(safe_mode.config_errors(run=run), [])

    def test_errors_are_split_into_lines(self) -> None:
        run = lambda *_a, **_k: SimpleNamespace(
            returncode=0, stdout="unknown option: foo\nbad bind\n", stderr=""
        )
        self.assertEqual(
            safe_mode.config_errors(run=run), ["unknown option: foo", "bad bind"]
        )

    def test_a_missing_hyprctl_is_not_an_error_list(self) -> None:
        def run(*_args, **_kwargs):
            raise FileNotFoundError("hyprctl")

        self.assertEqual(safe_mode.config_errors(run=run), [])


class SessionTests(unittest.TestCase):
    def test_the_safe_config_ships_with_the_repo(self) -> None:
        self.assertTrue(safe_mode.SAFE_CONFIG.is_file())
        self.assertIn("safe.lua", str(safe_mode.SAFE_CONFIG))

    def test_the_command_points_at_it(self) -> None:
        command = safe_mode.session_command()
        self.assertEqual(command[0], "Hyprland")
        self.assertEqual(command[1], "-c")
        self.assertEqual(command[2], str(safe_mode.SAFE_CONFIG))


class CliTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.env = mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": self.tmp.name})
        self.env.start()
        self.addCleanup(self.env.stop)
        self.config = prefs.config_dir()

    def test_status_is_clean_when_the_config_loads(self) -> None:
        with mock.patch.object(safe_mode, "config_errors", return_value=[]):
            self.assertEqual(cli.main(["safe-mode", "status"]), 0)

    def test_status_fails_and_points_at_safe_mode(self) -> None:
        with mock.patch.object(safe_mode, "config_errors", return_value=["bad bind"]):
            self.assertEqual(cli.main(["safe-mode", "status"]), 1)

    def test_enter_then_exit_through_the_cli(self) -> None:
        self.assertEqual(cli.main(["safe-mode", "enter"]), 0)
        self.assertTrue(safe_mode.is_active(self.config))
        self.assertEqual(cli.main(["safe-mode", "exit"]), 0)
        self.assertFalse(safe_mode.is_active(self.config))


if __name__ == "__main__":
    unittest.main()
