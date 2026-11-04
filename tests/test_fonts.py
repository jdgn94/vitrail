"""The Fonts page's data: what the machine actually has installed.

The window cannot run commands, so `vitrail.fonts` reads the families from
fontconfig and the icon/cursor packs from the theme folders, then hands the
lists to the page as JSON. Nothing is curated in the repository: the list is
what the machine has.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from vitrail import fonts

FACES = "Roboto,Roboto Thin\t80\nJetBrainsMono Nerd Font\t100\nNoto Sans\t80\nAdwaita Sans\t110\n"


class FaceTests(unittest.TestCase):
    def test_families_are_split_deduped_and_sorted(self) -> None:
        self.assertEqual(
            fonts.families(FACES),
            ["Adwaita Sans", "JetBrainsMono Nerd Font", "Noto Sans", "Roboto", "Roboto Thin"],
        )

    def test_monospace_families_come_from_spacing_100_and_110(self) -> None:
        self.assertEqual(
            fonts.monospace(FACES),
            ["Adwaita Sans", "JetBrainsMono Nerd Font"],
        )

    def test_an_empty_answer_is_an_empty_list(self) -> None:
        self.assertEqual(fonts.families(""), [])
        self.assertEqual(fonts.monospace(""), [])


class ThemeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.mkdtemp()
        self.root = Path(self.tmp)
        for name, folders in (
            ("Adwaita", ["cursors", "48x48"]),
            ("Papirus", ["48x48"]),
            ("OnlyCursor", ["cursors"]),
            ("Junk", []),
        ):
            (self.root / name).mkdir(parents=True)
            for folder in folders:
                (self.root / name / folder).mkdir()
            if name != "Junk":
                (self.root / name / "index.theme").write_text("[Icon Theme]\n", encoding="utf-8")

    def tearDown(self) -> None:
        import shutil

        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_icon_and_cursor_themes_are_found_by_their_shape(self) -> None:
        self.assertEqual(
            fonts.themes([self.root]),
            (["Adwaita", "Papirus"], ["Adwaita", "OnlyCursor"]),
        )

    def test_a_folder_without_index_theme_is_not_a_theme(self) -> None:
        self.assertNotIn("Junk", fonts.themes([self.root])[0])
        self.assertNotIn("Junk", fonts.themes([self.root])[1])


class StateTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.mkdtemp()
        self.root = Path(self.tmp)

    def tearDown(self) -> None:
        import shutil

        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_state_lists_what_is_installed(self) -> None:
        calls: list[list[str]] = []

        def run(argv: list[str]) -> str:
            calls.append(argv)
            return FACES

        state = fonts.state(run=run, roots=[self.root])
        self.assertEqual(state["fonts"][0], "Adwaita Sans")
        self.assertIn("JetBrainsMono Nerd Font", state["monospace"])
        self.assertEqual(calls, [fonts.font_query()])

    def test_a_failing_fc_list_gives_empty_lists(self) -> None:
        state = fonts.state(run=lambda argv: None, roots=[self.root])
        self.assertEqual(state["fonts"], [])
        self.assertEqual(state["monospace"], [])


if __name__ == "__main__":
    unittest.main()
