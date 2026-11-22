"""The privacy element's wiring: its preferences, its words, how the shell polls
it and how Cut off reaches the module (the logic itself is tested in
tests/qml/tst_privacy.qml and tests/test_privacy.py)."""

from __future__ import annotations

import json
import re
import unittest
from pathlib import Path

from vitrail import privacy

ROOT = Path(__file__).resolve().parent.parent


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class PrivacyWiringTests(unittest.TestCase):
    def test_the_two_preferences_are_mapped_and_declared(self) -> None:
        for key in ("privacyWatch", "privacyDotColor"):
            with self.subTest(key=key):
                self.assertRegex(read("vitrail/prefs.map"), rf"(?m)^bar {key}$")
                self.assertIn(f"property alias {key}: barFile.{key}", read("shell/Prefs.qml"))

    def test_the_defaults_watch_everything_in_the_error_colour(self) -> None:
        prefs = read("shell/Prefs.qml")
        self.assertIn('property string privacyWatch: "[\\"microphone\\",\\"camera\\",\\"screen\\"]"', prefs)
        self.assertIn('property string privacyDotColor: "error"', prefs)

    def test_the_kinds_match_the_module(self) -> None:
        kinds = re.search(r"var KINDS = \[([^\]]*)\]", read("bar/privacy/privacy.js")).group(1)
        self.assertEqual(tuple(re.findall(r'"(\w+)"', kinds)), privacy.KINDS)

    def test_the_dot_colours_are_palette_roles_never_literals(self) -> None:
        roles = re.search(r"var DOT_COLORS = \[([^\]]*)\]", read("bar/privacy/privacy.js")).group(1)
        palette = read("kit/VitrailPalette.qml")
        for role in re.findall(r'"(\w+)"', roles):
            with self.subTest(role=role):
                self.assertRegex(palette, rf"readonly property color {role}:")
        self.assertNotRegex(read("bar/privacy/PrivacyButton.qml"), r'"#[0-9a-fA-F]{3,8}"')

    def test_it_starts_in_only_while_active_and_hidden(self) -> None:
        self.assertIn('"privacy"', read("bar/elements.js"))
        self.assertIn('\\"privacy\\"', read("shell/Prefs.qml"))
        self.assertRegex(read("bar/layouts.js"), r'DEFAULT_HIDDEN = \{ bar: \[[^\]]*"privacy"')

    def test_the_settings_block_has_every_kind_and_the_colour(self) -> None:
        page = read("shell/pages/BarElementsPage.qml")
        self.assertIn("Privacy.KINDS", page)
        self.assertIn('objectName: "privacyDotColor"', page)
        self.assertIn("Privacy.DOT_COLORS", page)

    def test_every_word_exists_in_every_language_with_the_same_placeholders(self) -> None:
        reference = json.loads(read("kit/i18n/en.json"))
        keys = [key for key in reference if key.startswith("bar.privacy.") or key == "bar.widget.privacy"]
        self.assertGreater(len(keys), 15)
        for path in sorted((ROOT / "kit" / "i18n").glob("*.json")):
            table = json.loads(path.read_text(encoding="utf-8"))
            for key in keys:
                with self.subTest(language=path.stem, key=key):
                    self.assertIn(key, table)
                    self.assertEqual(sorted(re.findall(r"%\d", table[key])), sorted(re.findall(r"%\d", reference[key])))

    def test_every_translation_key_the_files_use_exists(self) -> None:
        table = json.loads(read("kit/i18n/en.json"))
        text = "".join(read(f"bar/privacy/{name}") for name in ("privacy.js", "PrivacyButton.qml", "PrivacyPanel.qml"))
        text += read("shell/pages/BarElementsPage.qml")
        for key in set(re.findall(r"\"(bar\.privacy\.[\w.]*\w)\"", text)):
            with self.subTest(key=key):
                self.assertIn(key, table)
        for kind in privacy.KINDS:
            for suffix in (f"kind.{kind}", f"watch.{kind}", f"watch.{kind}.help"):
                self.assertIn(f"bar.privacy.{suffix}", table)
        for role in ("error", "primary", "info"):
            self.assertIn(f"bar.privacy.dotColor.{role}", table)

    def test_the_snapshot_is_polled_only_while_in_a_bar_and_asks_for_the_watched_kinds(self) -> None:
        shell = read("bar/shell.qml")
        block = re.search(r"BarSnapshot \{\s*id: privacyData(.*?)\n    \}", shell, re.S).group(1)
        self.assertIn('module: "privacy"', block)
        self.assertIn('active: shell.barShows("privacy")', block)
        self.assertIn("Privacy.watchArguments(shell.prefs.privacyWatch)", block)

    def test_cut_off_runs_the_modules_stop_once_and_refreshes(self) -> None:
        shell = read("bar/shell.qml")
        body = re.search(r"function privacyCut\(kind, node\) \{(.*?)\n    \}", shell, re.S).group(1)
        self.assertIn("privacyCutter.running", body)
        self.assertIn('"vitrail.privacy", "stop"', body)
        self.assertIn("onExited: privacyData.refresh()", shell)
        self.assertNotIn("pw-cli", shell, "the module decides what is destroyed")
        self.assertNotIn("Process", read("bar/privacy/PrivacyPanel.qml"))

    def test_the_popup_refreshes_when_it_opens(self) -> None:
        self.assertRegex(read("bar/shell.qml"), r'kind === "privacy"\)\s+privacyData\.refresh\(\)')


if __name__ == "__main__":
    unittest.main()
