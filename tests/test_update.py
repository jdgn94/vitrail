"""`vitrail update`: compare the installed checkout with its branch and move it."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from vitrail import update

STATE = {
    "root": "/home/someone/.local/share/vitrail",
    "commit": "a" * 40,
    "branch": "master",
    "remote": "origin",
    "compositors": "hyprland",
    "aur": "yay",
    "vpn": "split",
}


class StateTests(unittest.TestCase):
    def test_a_missing_record_means_not_installed(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(update.state(Path(tmp)), {})

    def test_the_record_is_read_back(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "install.json").write_text(json.dumps(STATE), encoding="utf-8")
            self.assertEqual(update.state(Path(tmp)), STATE)

    def test_the_version_comes_from_pyproject(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "pyproject.toml").write_text('[project]\nversion = "1.2.3"\n', encoding="utf-8")
            self.assertEqual(update.installed_version(tmp), "1.2.3")


class RemoteTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        (self.root / ".git").mkdir()
        self.state = dict(STATE, root=str(self.root))

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def test_the_remote_commit_is_the_tracked_branch(self) -> None:
        calls: list[list[str]] = []

        def run(argv: list[str]) -> str:
            calls.append(argv)
            return "b" * 40 + "\trefs/heads/master\n"

        self.assertEqual(update.remote_commit(self.state, run), "b" * 40)
        self.assertEqual(calls[0][:3], ["git", "-C", str(self.root)])

    def test_an_unreachable_remote_is_not_a_change(self) -> None:
        result = update.check(self.state, run=lambda argv: None)
        self.assertFalse(result["behind"])

    def test_a_different_commit_is_behind(self) -> None:
        result = update.check(self.state, run=lambda argv: "b" * 40 + "\trefs/heads/master")
        self.assertTrue(result["behind"])

    def test_the_same_commit_is_up_to_date(self) -> None:
        result = update.check(self.state, run=lambda argv: "a" * 40 + "\trefs/heads/master")
        self.assertFalse(result["behind"])


class ApplyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        (self.root / ".git").mkdir()
        self.state = dict(STATE, root=str(self.root))

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def test_local_changes_are_refused_without_force(self) -> None:
        def run(argv: list[str]) -> str:
            if "status" in argv:
                return " M shell/main.qml\n"
            return ""

        self.assertEqual(update.apply(self.state, run), {"error": update.ERR_DIRTY})

    def test_force_moves_the_checkout(self) -> None:
        calls: list[list[str]] = []

        def run(argv: list[str]) -> str:
            calls.append(argv)
            if "status" in argv:
                return " M file\n"
            if "rev-parse" in argv:
                return "c" * 40 + "\n"
            return ""

        self.assertEqual(update.apply(self.state, run, force=True), {"commit": "c" * 40})
        self.assertIn(["git", "-C", str(self.root), "fetch", "--depth", "1", "origin", "master"], calls)

    def test_a_failed_fetch_is_reported(self) -> None:
        def run(argv: list[str]) -> str | None:
            if "status" in argv:
                return ""
            return None

        self.assertEqual(update.apply(self.state, run), {"error": update.ERR_FETCH})

    def test_reinstall_replays_the_recorded_choices(self) -> None:
        (self.root / "install.sh").write_text("#!/bin/sh\n", encoding="utf-8")
        calls: list[list[str]] = []

        def run(argv: list[str]) -> str:
            calls.append(argv)
            return ""

        self.assertTrue(update.reinstall(self.state, run))
        command = calls[0]
        self.assertIn("--compositor", command)
        self.assertIn("hyprland", command)
        self.assertIn("--aur", command)
        self.assertIn("yay", command)
        self.assertIn("--vpn", command)
        self.assertIn("split", command)
        self.assertIn("--yes", command)

    def test_without_an_installer_nothing_runs(self) -> None:
        self.assertFalse(update.reinstall(self.state, lambda argv: ""))


if __name__ == "__main__":
    unittest.main()
