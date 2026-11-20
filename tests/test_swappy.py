"""The annotator (swappy) shows its panel and wears the palette, for itself only."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from vitrail import swappy

PALETTE = {
    "primary": "#a8c7fa",
    "on_primary": "#002f65",
    "surface": "#111318",
    "surface_container": "#1d2024",
    "surface_container_high": "#282a2f",
    "surface_container_highest": "#33353a",
    "on_surface": "#e2e2e9",
    "on_surface_variant": "#c4c6d0",
    "outline_variant": "#44474e",
    "error": "#ffb4ab",
}


class PanelTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.config = Path(self.tmp.name)
        self.file = self.config / "swappy" / "config"

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def test_a_missing_file_gets_the_panel_on(self) -> None:
        swappy.set_panel(True, self.config)
        self.assertEqual(self.file.read_text(), "[Default]\nshow_panel=true\n")

    def test_the_users_other_keys_survive(self) -> None:
        self.file.parent.mkdir(parents=True)
        self.file.write_text("[Default]\nsave_dir=/x\nshow_panel=false\nline_size=7\n")
        swappy.set_panel(True, self.config)
        self.assertEqual(self.file.read_text(), "[Default]\nsave_dir=/x\nshow_panel=true\nline_size=7\n")

    def test_off_writes_false(self) -> None:
        swappy.set_panel(False, self.config)
        self.assertIn("show_panel=false", self.file.read_text())


class CssTests(unittest.TestCase):
    def css(self, dark: bool = True, **options) -> str:
        return swappy.render_css(PALETTE, dark, **options)

    def test_it_builds_on_the_matching_adwaita_sheet(self) -> None:
        self.assertIn("gtk-contained-dark.css", self.css(dark=True).splitlines()[1])
        self.assertIn("gtk-contained.css", self.css(dark=False).splitlines()[1])

    def test_the_checked_tool_is_filled_with_the_accent(self) -> None:
        css = self.css()
        self.assertRegex(css, r":checked[^{]*\{[^}]*background-color: #a8c7fa")
        self.assertIn("color: #002f65", css)

    def test_the_radius_and_the_font_come_from_the_preferences(self) -> None:
        css = self.css(radius=20, font="Inter", size=15)
        self.assertIn("border-radius: 20px", css)
        self.assertIn('font-family: "Inter"', css)
        self.assertIn("font-size: 15px", css)

    def test_glass_is_translucent_and_solid_is_not(self) -> None:
        self.assertIn("rgba(17, 19, 24, 0.58)", self.css(glass=True))
        solid = self.css(glass=False)
        self.assertNotIn("rgba(17, 19, 24", solid)
        self.assertIn("#111318", solid)


class InstallTests(unittest.TestCase):
    def test_the_theme_lands_where_gtk_looks_for_a_named_theme(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = swappy.install_theme("body {}", Path(tmp))
            self.assertEqual(path, Path(tmp) / "themes" / "Vitrail-Swappy" / "gtk-3.0" / "gtk.css")
            self.assertEqual(path.read_text(), "body {}")


class EnvironmentTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def run_env(self, values: dict, palette: dict | None = PALETTE) -> dict:
        return swappy.environment(
            values,
            config_home=self.root / "config",
            data_home=self.root / "data",
            palette=palette,
            mode="dark",
            environ={"HOME": "/h"},
        )

    def test_swappy_gets_the_theme_and_keeps_the_rest_of_the_environment(self) -> None:
        env = self.run_env({})
        self.assertEqual(env["GTK_THEME"], "Vitrail-Swappy")
        self.assertEqual(env["HOME"], "/h")
        self.assertTrue((self.root / "data" / "themes" / "Vitrail-Swappy" / "gtk-3.0" / "gtk.css").exists())

    def test_the_panel_is_on_unless_the_preference_is_off(self) -> None:
        self.run_env({})
        shown = (self.root / "config" / "swappy" / "config").read_text()
        self.assertIn("show_panel=true", shown)
        self.run_env({"annotatePanel": "false"})
        self.assertIn("show_panel=false", (self.root / "config" / "swappy" / "config").read_text())

    def test_without_a_palette_the_window_keeps_its_own_look(self) -> None:
        env = self.run_env({}, palette={})
        self.assertNotIn("GTK_THEME", env)
        self.assertFalse((self.root / "data").exists())

    def test_the_surface_style_and_tokens_are_read(self) -> None:
        self.run_env({"surfaceStyle": "solid", "radius": "9", "fontSystem": "Inter", "fontBase": "15"})
        css = (self.root / "data" / "themes" / "Vitrail-Swappy" / "gtk-3.0" / "gtk.css").read_text()
        self.assertNotIn("rgba(17, 19, 24", css)
        self.assertIn("border-radius: 9px", css)
        self.assertIn('"Inter"', css)
        self.assertIn("font-size: 15px", css)


if __name__ == "__main__":
    unittest.main()
