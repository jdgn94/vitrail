"""Pending package updates: repository, AUR and Flatpak.

Every program is answered by a fake runner, so these tests never run pacman,
an AUR helper or flatpak. The fixtures are recorded output (`checkupdates`,
`paru -Qua`, `yay -Qua` and `flatpak remote-ls --updates`) and the parsers are
pure functions of their text.
"""

from __future__ import annotations

import json
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from unittest import mock

from vitrail import updates

CHECKUPDATES = "linux 6.12.1.arch1-1 -> 6.12.2.arch1-1\nmesa 1:24.2.7-1 -> 1:24.3.1-1\npython 3.12.7-1 -> 3.12.8-1\n"
PARU = "claude-desktop 5.11492.5-1 -> 6.28899.2-1\npython311 3.11.16-1 -> 3.11.18-2\n"
YAY = (
    " -> No AUR package found for openssl-3 (required by: python311)\n"
    "claude-desktop 5.11492.5-1 -> 6.28899.2-1 [19h1m]\n"
    "python311 3.11.16-1 -> 3.11.18-2 [8d7h]\n"
)
FLATPAK = "org.mozilla.firefox\t135.0\ncom.spotify.Client\t\norg.gnome.Platform\t47\n"
ALL = ("checkupdates", "flatpak", "paru", "yay")


class Fake:
    """A runner and a `which` that answer from a table, recording the argv."""

    def __init__(
        self, answers: dict[str, tuple[int, str, str]] | None = None, installed: tuple[str, ...] | set[str] = ALL
    ):
        self.answers = answers or {}
        self.installed = set(installed)
        self.calls: list[list[str]] = []

    def which(self, program: str) -> str | None:
        return f"/usr/bin/{program}" if program in self.installed else None

    def run(self, argv: list[str]) -> tuple[int, str, str]:
        self.calls.append(list(argv))
        return self.answers.get(argv[0], (0, "", ""))


def ready() -> Fake:
    return Fake(
        {
            "checkupdates": (0, CHECKUPDATES, ""),
            "paru": (0, PARU, ""),
            "yay": (0, YAY, ""),
            "flatpak": (0, FLATPAK, ""),
        }
    )


class ParseTests(unittest.TestCase):
    def test_checkupdates_lines_become_name_from_to(self) -> None:
        self.assertEqual(
            updates.parse_versions(CHECKUPDATES),
            [
                {"name": "linux", "from": "6.12.1.arch1-1", "to": "6.12.2.arch1-1"},
                {"name": "mesa", "from": "1:24.2.7-1", "to": "1:24.3.1-1"},
                {"name": "python", "from": "3.12.7-1", "to": "3.12.8-1"},
            ],
        )

    def test_the_aur_helper_age_and_warnings_are_ignored(self) -> None:
        self.assertEqual(
            updates.parse_versions(YAY),
            [
                {"name": "claude-desktop", "from": "5.11492.5-1", "to": "6.28899.2-1"},
                {"name": "python311", "from": "3.11.16-1", "to": "3.11.18-2"},
            ],
        )
        self.assertEqual(updates.parse_versions("not an update\n\nname only\n"), [])

    def test_flatpak_rows_are_tab_separated_and_keep_an_empty_from(self) -> None:
        self.assertEqual(
            updates.parse_flatpak(FLATPAK),
            [
                {"name": "org.mozilla.firefox", "from": "", "to": "135.0"},
                {"name": "com.spotify.Client", "from": "", "to": ""},
                {"name": "org.gnome.Platform", "from": "", "to": "47"},
            ],
        )
        self.assertEqual(updates.parse_flatpak("\n\t\n"), [])


class StateTests(unittest.TestCase):
    def test_the_default_state_has_the_documented_shape(self) -> None:
        fake = ready()
        data = updates.state(run=fake.run, which=fake.which, now=1_000.0)
        self.assertEqual(set(data), {"official", "aur", "flatpak", "errors", "total", "checkedAt", "commands"})
        self.assertEqual(data["total"], 3 + 2 + 3)
        self.assertEqual(data["errors"], {})
        self.assertEqual(data["checkedAt"], 1_000_000)
        json.dumps(data)

    def test_every_source_carries_the_argv_of_its_update(self) -> None:
        fake = ready()
        data = updates.state(run=fake.run, which=fake.which)
        self.assertEqual(
            data["commands"],
            {
                "official": ["sudo", "pacman", "-Syu"],
                "aur": ["paru", "-Sua"],
                "flatpak": ["flatpak", "update", "-y"],
            },
        )

    def test_the_aur_update_uses_the_configured_helper(self) -> None:
        fake = ready()
        data = updates.state(helper="yay", run=fake.run, which=fake.which)
        self.assertEqual(data["commands"]["aur"], ["yay", "-Sua"])

    def test_every_source_runs_its_own_program(self) -> None:
        fake = ready()
        updates.state(run=fake.run, which=fake.which)
        self.assertEqual(
            fake.calls,
            [
                ["checkupdates"],
                ["paru", "-Qua"],
                ["flatpak", "remote-ls", "--updates", "--columns=application,version"],
            ],
        )

    def test_no_updates_is_an_empty_list_not_an_error(self) -> None:
        fake = Fake(
            {
                "checkupdates": (2, "", ""),
                "paru": (0, "", ""),
                "flatpak": (0, "", ""),
            }
        )
        data = updates.state(run=fake.run, which=fake.which)
        self.assertEqual(data["official"], [])
        self.assertEqual(data["aur"], [])
        self.assertEqual(data["flatpak"], [])
        self.assertEqual(data["errors"], {})
        self.assertEqual(data["total"], 0)

    def test_a_missing_program_fails_only_its_source(self) -> None:
        fake = Fake(
            {"checkupdates": (0, CHECKUPDATES, ""), "paru": (0, PARU, "")},
            installed=("checkupdates", "paru"),
        )
        data = updates.state(run=fake.run, which=fake.which)
        self.assertEqual(len(data["official"]), 3)
        self.assertEqual(len(data["aur"]), 2)
        self.assertEqual(data["flatpak"], [])
        self.assertIn("flatpak", data["errors"])
        self.assertEqual(data["total"], 5)

    def test_a_failing_program_names_its_source(self) -> None:
        fake = ready()
        fake.answers["checkupdates"] = (1, "", "failed to synchronize any databases\n")
        data = updates.state(run=fake.run, which=fake.which)
        self.assertEqual(data["official"], [])
        self.assertIn("failed to synchronize", data["errors"]["official"])
        self.assertEqual(len(data["aur"]), 2)
        self.assertEqual(len(data["flatpak"]), 3)

    def test_a_runner_that_raises_still_produces_a_document(self) -> None:
        def boom(argv: list[str]) -> tuple[int, str, str]:
            raise OSError(f"cannot run {argv[0]}")

        data = updates.state(run=boom, which=lambda program: program, now=0)
        self.assertEqual(set(data["errors"]), set(updates.SOURCES))
        self.assertEqual(data["total"], 0)
        json.dumps(data)

    def test_paru_is_preferred_when_both_helpers_exist(self) -> None:
        fake = ready()
        updates.state(run=fake.run, which=fake.which)
        self.assertIn(["paru", "-Qua"], fake.calls)
        self.assertNotIn(["yay", "-Qua"], fake.calls)

    def test_yay_is_used_when_paru_is_missing(self) -> None:
        fake = Fake(
            {"checkupdates": (0, CHECKUPDATES, ""), "yay": (0, YAY, ""), "flatpak": (0, FLATPAK, "")},
            installed=("checkupdates", "yay", "flatpak"),
        )
        data = updates.state(run=fake.run, which=fake.which)
        self.assertIn(["yay", "-Qua"], fake.calls)
        self.assertEqual(len(data["aur"]), 2)

    def test_an_explicit_helper_wins(self) -> None:
        fake = ready()
        updates.state(helper="yay", run=fake.run, which=fake.which)
        self.assertIn(["yay", "-Qua"], fake.calls)
        self.assertNotIn(["paru", "-Qua"], fake.calls)

    def test_no_helper_and_no_paru_or_yay_is_an_aur_error(self) -> None:
        fake = Fake(
            {"checkupdates": (0, CHECKUPDATES, ""), "flatpak": (0, FLATPAK, "")}, installed=("checkupdates", "flatpak")
        )
        data = updates.state(run=fake.run, which=fake.which)
        self.assertIn("no AUR helper", data["errors"]["aur"])
        self.assertEqual(data["total"], 6)

    def test_an_explicit_helper_that_is_missing_is_an_error(self) -> None:
        fake = Fake(
            {"checkupdates": (0, CHECKUPDATES, ""), "paru": (0, PARU, ""), "flatpak": (0, FLATPAK, "")},
            installed=("checkupdates", "paru", "flatpak"),
        )
        data = updates.state(helper="yay", run=fake.run, which=fake.which)
        self.assertIn("yay is not installed", data["errors"]["aur"])
        self.assertNotIn(["paru", "-Qua"], fake.calls)

    def test_only_the_requested_sources_run(self) -> None:
        fake = ready()
        data = updates.state(sources=("official",), run=fake.run, which=fake.which)
        self.assertEqual(fake.calls, [["checkupdates"]])
        self.assertEqual(set(data), {"official", "errors", "total", "checkedAt", "commands"})
        self.assertEqual(data["total"], 3)
        self.assertEqual(data["commands"], {"official": ["sudo", "pacman", "-Syu"]})

    def test_a_string_source_is_one_source(self) -> None:
        fake = ready()
        data = updates.state(sources="aur", run=fake.run, which=fake.which)
        self.assertEqual(fake.calls, [["paru", "-Qua"]])
        self.assertEqual(len(data["aur"]), 2)

    def test_an_empty_source_list_checks_nothing(self) -> None:
        fake = ready()
        data = updates.state(sources=[], run=fake.run, which=fake.which)
        self.assertEqual(fake.calls, [])
        self.assertEqual(set(data), {"errors", "total", "checkedAt", "commands"})
        self.assertEqual(data["total"], 0)
        self.assertEqual(data["commands"], {})


class PreferenceTests(unittest.TestCase):
    def test_an_unset_source_list_checks_all_three(self) -> None:
        self.assertEqual(updates.parse_sources(None), updates.SOURCES)

    def test_the_source_list_keeps_the_known_sources_in_their_order(self) -> None:
        self.assertEqual(updates.parse_sources("flatpak, aur,official"), ("official", "aur", "flatpak"))
        self.assertEqual(updates.parse_sources("snap, official"), ("official",))
        self.assertEqual(updates.parse_sources(""), ())

    def test_auto_and_unknown_helpers_mean_decide_from_what_is_installed(self) -> None:
        self.assertIsNone(updates.parse_helper(None))
        self.assertIsNone(updates.parse_helper("auto"))
        self.assertIsNone(updates.parse_helper("pacman"))
        self.assertEqual(updates.parse_helper("yay"), "yay")
        self.assertEqual(updates.parse_helper(" paru "), "paru")


class CommandTests(unittest.TestCase):
    def test_the_update_argv_per_source(self) -> None:
        self.assertEqual(updates.command("official"), ["sudo", "pacman", "-Syu"])
        self.assertEqual(updates.command("aur", "yay"), ["yay", "-Sua"])
        self.assertEqual(updates.command("flatpak"), ["flatpak", "update", "-y"])

    def test_the_aur_default_is_the_installed_helper(self) -> None:
        self.assertEqual(
            updates.command("aur", which=lambda name: "/usr/bin/yay" if name == "yay" else None), ["yay", "-Sua"]
        )
        self.assertEqual(updates.command("aur", which=lambda name: None), ["paru", "-Sua"])

    def test_an_unknown_source_is_refused(self) -> None:
        with self.assertRaises(ValueError):
            updates.command("snap")


class MainTests(unittest.TestCase):
    def test_state_prints_one_json_document(self) -> None:
        document = {"official": [], "aur": [], "flatpak": [], "errors": {}, "total": 0, "checkedAt": 1}
        with mock.patch.object(updates, "state", return_value=document):
            output = StringIO()
            with redirect_stdout(output):
                self.assertEqual(updates.main(["state"]), 0)
        self.assertEqual(json.loads(output.getvalue()), document)

    def test_state_checks_the_sources_and_helper_the_preferences_name(self) -> None:
        document = {"official": [], "errors": {}, "total": 0, "checkedAt": 1, "commands": {}}
        with (
            mock.patch.object(
                updates.prefs,
                "read_prefs",
                return_value={"updatesSources": "official, flatpak", "updatesAurHelper": "yay"},
            ),
            mock.patch.object(updates, "state", return_value=document) as state,
        ):
            with redirect_stdout(StringIO()):
                self.assertEqual(updates.main(["state"]), 0)
        state.assert_called_once_with(sources=("official", "flatpak"), helper="yay")

    def test_an_unset_preference_checks_every_source_with_auto_helper(self) -> None:
        document = {"official": [], "errors": {}, "total": 0, "checkedAt": 1, "commands": {}}
        with (
            mock.patch.object(updates.prefs, "read_prefs", return_value={}),
            mock.patch.object(updates, "state", return_value=document) as state,
        ):
            with redirect_stdout(StringIO()):
                self.assertEqual(updates.main(["state"]), 0)
        state.assert_called_once_with(sources=updates.SOURCES, helper=None)

    def test_an_unknown_action_prints_the_usage(self) -> None:
        errors = StringIO()
        with redirect_stderr(errors):
            self.assertEqual(updates.main(["now"]), 2)
        self.assertIn("usage: updates state", errors.getvalue())


if __name__ == "__main__":
    unittest.main()
