"""The system health element's wiring: its preferences, its words, how the
shell feeds it the bar's own load failures and how Fix and Logs reach a
terminal (the logic itself is tested in tests/qml/tst_health.qml)."""

from __future__ import annotations

import json
import re
import unittest
from pathlib import Path

from vitrail import health

ROOT = Path(__file__).resolve().parent.parent


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class HealthWiringTests(unittest.TestCase):
    def test_the_two_preferences_are_mapped_and_declared(self) -> None:
        for key in ("healthDiskThreshold", "healthChecks"):
            with self.subTest(key=key):
                self.assertRegex(read("vitrail/prefs.map"), rf"(?m)^bar {key}$")
                self.assertIn(f"property alias {key}: barFile.{key}", read("shell/Prefs.qml"))
                self.assertIn("healthDisk", read("kit/tokens.js"))

    def test_the_threshold_range_matches_the_module(self) -> None:
        tokens = read("kit/tokens.js")
        found = re.search(r"healthDisk: \{ min: (\d+), max: (\d+), step: 1, value: (\d+) \}", tokens)
        self.assertIsNotNone(found)
        low, high, default = (float(number) for number in found.groups())
        self.assertEqual((low, high), health.THRESHOLD_RANGE)
        self.assertEqual(default, health.DISK_THRESHOLD)

    def test_the_settings_block_has_the_threshold_and_every_check(self) -> None:
        page = read("shell/pages/BarElementsPage.qml")
        self.assertIn('objectName: "healthDiskThreshold"', page)
        self.assertIn("Health.CHECKS", page)
        names = re.search(r"var CHECKS = \[([^\]]*)\]", read("bar/health/health.js")).group(1)
        self.assertEqual(sorted(re.findall(r'"(\w+)"', names)), sorted(health.CHECK_GROUPS))

    def test_it_starts_in_only_while_active_and_hidden(self) -> None:
        self.assertIn('"health"', read("bar/elements.js"))
        self.assertIn('\\"health\\"', read("shell/Prefs.qml"))
        self.assertRegex(read("bar/layouts.js"), r'DEFAULT_HIDDEN = \{ bar: \[[^\]]*"health"')

    def test_every_problem_kind_has_a_translated_title(self) -> None:
        kinds = re.search(r"var KINDS = \[([^\]]*)\]", read("bar/health/health.js")).group(1)
        kinds = re.findall(r'"([\w-]+)"', kinds) + ["unknown"]
        self.assertTrue({"service-user", "service-system", "disk", "hyprland", "doctor", health.BAR_ID} <= set(kinds))
        for path in sorted((ROOT / "kit" / "i18n").glob("*.json")):
            table = json.loads(path.read_text(encoding="utf-8"))
            for kind in kinds:
                with self.subTest(language=path.stem, kind=kind):
                    self.assertIn(f"bar.health.title.{kind}", table)

    def test_the_words_agree_on_their_placeholders_in_every_language(self) -> None:
        reference = json.loads(read("kit/i18n/en.json"))
        for path in sorted((ROOT / "kit" / "i18n").glob("*.json")):
            table = json.loads(path.read_text(encoding="utf-8"))
            for key, value in reference.items():
                if key.startswith("bar.health."):
                    with self.subTest(language=path.stem, key=key):
                        self.assertEqual(sorted(re.findall(r"%\d", table[key])), sorted(re.findall(r"%\d", value)))

    def test_the_shell_counts_each_bars_load_failure_and_feeds_the_element(self) -> None:
        shell = read("bar/shell.qml")
        for side in ("start", "center", "end"):
            with self.subTest(side=side):
                self.assertIn(
                    f"onFailedChanged: shell.noteBarFailure({side}Entry.modelData, {side}Entry.failed)", shell
                )
        self.assertIn("failed: shell.barFailedIds", shell)
        self.assertEqual(shell.count("failed: shell.barFailedIds"), 2, "the button and the panel")
        self.assertIn("status === Loader.Error", read("bar/BarEntry.qml"))

    def test_fix_and_logs_open_the_terminal_and_never_run_on_their_own(self) -> None:
        shell = read("bar/shell.qml")
        body = re.search(r"function runHealth\(argv\) \{(.*?)\n    \}", shell, re.S).group(1)
        self.assertIn("Commands.runInTerminal(argv)", body)
        panel = read("bar/health/HealthPanel.qml")
        self.assertEqual(len(re.findall(r"Requested\(Health\.argv\(", panel)), 2)
        self.assertNotIn("Process", panel)

    def test_the_snapshot_is_polled_once_a_minute_only_while_in_a_bar(self) -> None:
        shell = read("bar/shell.qml")
        block = re.search(r"BarSnapshot \{\s*id: healthData(.*?)\n    \}", shell, re.S).group(1)
        self.assertIn('module: "health"', block)
        self.assertIn("interval: 60000", block)
        self.assertIn('active: shell.barShows("health")', block)


if __name__ == "__main__":
    unittest.main()
