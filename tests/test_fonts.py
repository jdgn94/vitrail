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


class ApplyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.mkdtemp()
        self.root = Path(self.tmp)
        self.icons = self.root / "icons"
        for name, folders in (("Adwaita", ["cursors", "48x48"]), ("Papirus", ["48x48"])):
            (self.icons / name).mkdir(parents=True)
            for folder in folders:
                (self.icons / name / folder).mkdir()
            (self.icons / name / "index.theme").write_text("[Icon Theme]\n", encoding="utf-8")
        self.config = self.root / "config"
        (self.config / "qt6ct").mkdir(parents=True)
        (self.config / "qt6ct" / "qt6ct.conf").write_text("[Appearance]\n", encoding="utf-8")

    def tearDown(self) -> None:
        import shutil

        shutil.rmtree(self.tmp, ignore_errors=True)

    def recording(self, text: str, calls: list[list[str]] | None = None):
        calls = [] if calls is None else calls

        def run(argv: list[str]) -> str:
            calls.append(argv)
            return text if argv[0] == "fc-list" else ""

        return run

    def apply(self, values: dict, run=None) -> int:
        return fonts.apply(values, self.config, run=run or self.recording(FACES), roots=[self.icons], hyprland=True)

    def test_the_font_name_keeps_the_size_already_set(self) -> None:
        self.assertEqual(fonts.font_name("Sans 11", "Roboto"), "Roboto 11")
        self.assertEqual(fonts.font_name("", "Roboto"), "Roboto 11")

    def test_the_console_family_is_empty_when_it_is_not_installed(self) -> None:
        self.assertEqual(fonts.console_family("No Such Font", run=lambda argv: FACES), "")
        self.assertEqual(fonts.console_family("Roboto", run=lambda argv: FACES), "Roboto")

    def test_an_unknown_font_falls_back_to_the_default_and_is_not_written(self) -> None:
        code = self.apply({"fontSystem": "No Such Font"})
        self.assertEqual(code, 1)
        text = (self.config / "fontconfig/conf.d/50-vitrail-font.conf").read_text(encoding="utf-8")
        self.assertIn("<family>Roboto</family>", text)
        self.assertNotIn("No Such Font", text)

    def test_without_a_font_list_nothing_is_written(self) -> None:
        code = self.apply({"fontSystem": "Roboto"}, run=lambda argv: None)
        self.assertEqual(code, 2)
        self.assertFalse(self.config.joinpath("fontconfig").exists())

    def test_apply_writes_the_alias_with_the_family_escaped(self) -> None:
        code = self.apply(
            {"fontSystem": "A & B", "iconTheme": "Adwaita", "cursorTheme": "Adwaita", "cursorSize": 24},
            run=self.recording("A & B\t80\n"),
        )
        self.assertEqual(code, 0)
        text = (self.config / "fontconfig/conf.d/50-vitrail-font.conf").read_text(encoding="utf-8")
        self.assertIn("<family>A &amp; B</family>", text)
        self.assertNotIn("<family>A & B</family>", text)

    def test_apply_sets_the_whole_system(self) -> None:
        calls: list[list[str]] = []
        code = self.apply(
            {"fontSystem": "Roboto", "iconTheme": "Adwaita", "cursorTheme": "Adwaita", "cursorSize": 24},
            run=self.recording(FACES, calls),
        )
        self.assertEqual(code, 0)
        self.assertIn(["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", "Adwaita"], calls)
        self.assertIn(["gsettings", "set", "org.gnome.desktop.interface", "cursor-theme", "Adwaita"], calls)
        self.assertIn(["hyprctl", "setcursor", "Adwaita", "24"], calls)
        self.assertIn(
            "XCURSOR_THEME=Adwaita", (self.config / "environment.d/20-vitrail-cursor.conf").read_text(encoding="utf-8")
        )
        self.assertIn("gtk-icon-theme-name=Adwaita", (self.config / "gtk-3.0/settings.ini").read_text(encoding="utf-8"))
        self.assertIn("icon_theme=Adwaita", (self.config / "qt6ct/qt6ct.conf").read_text(encoding="utf-8"))

    def test_a_theme_that_is_not_installed_falls_back(self) -> None:
        code = self.apply({"fontSystem": "Roboto", "iconTheme": "Adwaita", "cursorTheme": "Nope", "cursorSize": 24})
        self.assertEqual(code, 1)
        text = (self.config / "environment.d/20-vitrail-cursor.conf").read_text(encoding="utf-8")
        self.assertIn("XCURSOR_THEME=Adwaita", text)

    def test_a_cursor_size_out_of_range_falls_back_to_the_default(self) -> None:
        code = self.apply({"fontSystem": "Roboto", "iconTheme": "Adwaita", "cursorTheme": "Adwaita", "cursorSize": 999})
        self.assertEqual(code, 1)
        text = (self.config / "environment.d/20-vitrail-cursor.conf").read_text(encoding="utf-8")
        self.assertIn("XCURSOR_SIZE=24", text)


if __name__ == "__main__":
    unittest.main()
