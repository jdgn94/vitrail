"""Light / dark and the wallpaper palette reach GTK, Qt and Hyprland."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from vitrail import system_theme

COLORS = {
    "primary": "#a8c7fa", "on_primary": "#002f65", "secondary": "#bec6dc",
    "surface": "#111318", "surface_container": "#1d2024", "surface_container_high": "#282a2f",
    "surface_container_low": "#191c20", "surface_container_highest": "#33353a",
    "on_surface": "#e2e2e9", "on_surface_variant": "#c4c6d0", "outline": "#8e9099",
    "outline_variant": "#44474e", "error": "#ffb4ab", "on_error": "#690005",
    "tertiary": "#dbbce1", "shadow": "#000000", "inverse_surface": "#e2e2e9",
    "inverse_on_surface": "#2e3036", "primary_container": "#284777",
    "on_primary_container": "#d6e3ff",
}


def generated(tmp: Path) -> Path:
    out = tmp / "generated"
    out.mkdir()
    for mode in ("dark", "light"):
        (out / f"theme-{mode}.json").write_text(
            json.dumps({"colors": COLORS, "is_dark": mode == "dark"}), encoding="utf-8"
        )
    return out


class QtSchemeTests(unittest.TestCase):
    def test_each_group_lists_every_palette_role(self) -> None:
        scheme = system_theme.qt_scheme(COLORS)
        self.assertTrue(scheme.startswith("[ColorScheme]\n"))
        for group in ("active_colors", "disabled_colors", "inactive_colors"):
            line = next(l for l in scheme.splitlines() if l.startswith(group + "="))
            values = line.split("=", 1)[1].split(", ")
            self.assertEqual(len(values), len(system_theme.QT_ROLES))
            self.assertTrue(all(v.startswith("#") and len(v) == 9 for v in values))

    def test_highlight_is_the_primary(self) -> None:
        line = system_theme.qt_scheme(COLORS).splitlines()[1]
        values = line.split("=", 1)[1].split(", ")
        self.assertEqual(values[system_theme.QT_ROLES.index("Highlight")], "#ffa8c7fa")


class ApplyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.config = self.root / "config"
        self.calls: list[list[str]] = []

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def run_apply(self, mode: str) -> None:
        system_theme.apply(mode, generated(self.root) if not (self.root / "generated").exists()
                           else self.root / "generated", self.config,
                           run=lambda command, **_: self.calls.append(command), hyprland=False)

    def test_gtk_css_imports_the_mode(self) -> None:
        self.run_apply("dark")
        css = (self.config / "gtk-4.0" / "gtk.css").read_text()
        self.assertIn(system_theme.MARKER, css)
        self.assertIn("@define-color accent_bg_color #a8c7fa", css)

    def test_a_foreign_gtk_css_is_backed_up_once(self) -> None:
        target = self.config / "gtk-3.0" / "gtk.css"
        target.parent.mkdir(parents=True)
        target.write_text("/* someone else's */\n")
        self.run_apply("dark")
        self.run_apply("light")
        backup = target.with_name("gtk.css.before-vitrail")
        self.assertEqual(backup.read_text(), "/* someone else's */\n")
        self.assertIn(system_theme.MARKER, target.read_text())

    def test_gsettings_follow_the_mode(self) -> None:
        self.run_apply("light")
        self.assertIn(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", "prefer-light"],
                      self.calls)

    def test_gtk3_prefers_dark_only_in_dark_mode(self) -> None:
        settings = self.config / "gtk-3.0" / "settings.ini"
        settings.parent.mkdir(parents=True)
        settings.write_text("[Settings]\ngtk-theme-name=Breeze\ngtk-application-prefer-dark-theme=true\n")
        self.run_apply("light")
        text = settings.read_text()
        self.assertIn("gtk-application-prefer-dark-theme=false", text)
        self.assertIn("gtk-theme-name=Breeze", text)

    def test_qt6ct_points_at_the_vitrail_scheme(self) -> None:
        conf = self.config / "qt6ct" / "qt6ct.conf"
        conf.parent.mkdir(parents=True)
        conf.write_text("[Appearance]\nicon_theme=Papirus\ncolor_scheme_path=/old.conf\ncustom_palette=false\n")
        self.run_apply("dark")
        text = conf.read_text()
        scheme = self.config / "qt6ct" / "colors" / "vitrail.conf"
        self.assertIn(f"color_scheme_path={scheme}", text)
        self.assertIn("custom_palette=true", text)
        self.assertIn("icon_theme=Papirus", text)
        self.assertTrue(scheme.read_text().startswith("[ColorScheme]"))


if __name__ == "__main__":
    unittest.main()
