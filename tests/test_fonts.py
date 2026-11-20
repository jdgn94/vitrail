"""The Fonts page's data: what the machine actually has installed.

The window cannot run commands, so `vitrail.fonts` reads the families from
fontconfig and the icon/cursor packs from the theme folders, then hands the
lists to the page as JSON. Nothing is curated in the repository: the list is
what the machine has.
"""

from __future__ import annotations

import shutil
import struct
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
            ("ScalableCursor", ["cursors_scalable"]),
            ("Junk", []),
        ):
            (self.root / name).mkdir(parents=True)
            for folder in folders:
                (self.root / name / folder).mkdir()
            if name != "Junk":
                (self.root / name / "index.theme").write_text("[Icon Theme]\n", encoding="utf-8")

    def tearDown(self) -> None:
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_icon_and_cursor_themes_are_found_by_their_shape(self) -> None:
        self.assertEqual(
            fonts.themes([self.root]),
            (["Adwaita", "Papirus"], ["Adwaita", "OnlyCursor", "ScalableCursor"]),
        )

    def test_a_folder_without_index_theme_is_not_a_theme(self) -> None:
        self.assertNotIn("Junk", fonts.themes([self.root])[0])
        self.assertNotIn("Junk", fonts.themes([self.root])[1])

    def test_a_theme_name_with_a_control_character_is_skipped(self) -> None:
        (self.root / "Bad\nName" / "48x48").mkdir(parents=True)
        (self.root / "Bad\nName" / "index.theme").write_text("[Icon Theme]\n", encoding="utf-8")
        icons, cursors = fonts.themes([self.root])
        self.assertNotIn("Bad\nName", icons)
        self.assertNotIn("Bad\nName", cursors)


class StateTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.mkdtemp()
        self.root = Path(self.tmp)

    def tearDown(self) -> None:
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


def xcursor(path: Path, width: int = 24, height: int = 24, argb: int = 0xFF0000FF) -> None:
    """A one-image Xcursor file, as the themes ship them."""
    chunk = struct.pack("<IIIIIIIII", 36, 0xFFFD0002, 24, 1, width, height, 0, 0, 0)
    pixels = b"".join(struct.pack("<I", argb) for _ in range(width * height))
    header = struct.pack("<IIII", 0x72756358, 16, 1, 1)
    toc = struct.pack("<III", 0xFFFD0002, 24, 16 + 12)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(header + toc + chunk + pixels)


class PreviewTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.mkdtemp()
        self.root = Path(self.tmp)
        self.icons = self.root / "icons"
        self.cache = self.root / "cache"
        adwaita = self.icons / "Adwaita"
        (adwaita / "48x48" / "places").mkdir(parents=True)
        (adwaita / "32x32" / "apps").mkdir(parents=True)
        (adwaita / "cursors").mkdir()
        (adwaita / "index.theme").write_text(
            "[Icon Theme]\nDirectories=32x32/apps,48x48/places,scalable/apps\nInherits=hicolor\n"
            "\n[32x32/apps]\nSize=32\n\n[48x48/places]\nSize=48\n"
            "\n[scalable/apps]\nSize=48\nType=Scalable\n",
            encoding="utf-8",
        )
        (adwaita / "48x48" / "places" / "folder.png").write_bytes(b"png")
        (adwaita / "32x32" / "apps" / "web-browser.svg").write_text("<svg/>", encoding="utf-8")
        (adwaita / "scalable" / "apps").mkdir(parents=True)
        (adwaita / "scalable" / "apps" / "image-x-generic.svg").write_text("<svg/>", encoding="utf-8")
        xcursor(adwaita / "cursors" / "default")
        xcursor(adwaita / "cursors" / "hand2")
        hicolor = self.icons / "hicolor"
        (hicolor / "16x16" / "apps").mkdir(parents=True)
        (hicolor / "index.theme").write_text(
            "[Icon Theme]\nDirectories=16x16/apps\n\n[16x16/apps]\nSize=16\n", encoding="utf-8"
        )
        (hicolor / "16x16" / "apps" / "user-trash.svg").write_text("<svg/>", encoding="utf-8")

    def tearDown(self) -> None:
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_icon_previews_resolve_the_names_and_prefer_48_px(self) -> None:
        found = fonts.icon_previews(self.icons / "Adwaita", ["folder", "web-browser"], [self.icons])
        self.assertEqual(found["folder"], str(self.icons / "Adwaita" / "48x48" / "places" / "folder.png"))
        self.assertEqual(found["web-browser"], str(self.icons / "Adwaita" / "32x32" / "apps" / "web-browser.svg"))

    def test_a_vector_icon_is_preferred_over_the_nearest_size(self) -> None:
        found = fonts.icon_previews(self.icons / "Adwaita", ["image-x-generic"], [self.icons])
        self.assertTrue(found["image-x-generic"].endswith("image-x-generic.svg"))

    def test_an_icon_missing_from_the_theme_comes_from_its_parent(self) -> None:
        found = fonts.icon_previews(self.icons / "Adwaita", ["user-trash"], [self.icons])
        self.assertEqual(found["user-trash"], str(self.icons / "hicolor" / "16x16" / "apps" / "user-trash.svg"))

    def test_a_name_with_no_icon_anywhere_is_not_invented(self) -> None:
        found = fonts.icon_previews(self.icons / "Adwaita", ["nope"], [self.icons])
        self.assertEqual(found, {})

    def test_the_cursor_previews_are_a_png_per_shape(self) -> None:
        paths = fonts.cursor_previews(self.icons / "Adwaita", self.cache)
        self.assertEqual(len(paths), 2)
        for path in paths:
            self.assertEqual(Path(path).read_bytes()[:8], b"\x89PNG\r\n\x1a\n")

    def test_the_mosaic_shows_eight_cursor_shapes(self) -> None:
        cursors = self.icons / "Adwaita" / "cursors"
        for name in ("xterm", "sb_h_double_arrow", "sb_v_double_arrow", "fleur", "help", "progress"):
            xcursor(cursors / name)
        self.assertEqual(len(fonts.cursor_previews(self.icons / "Adwaita", self.cache)), 8)

    def test_a_cursor_without_a_readable_file_has_no_preview(self) -> None:
        empty = self.icons / "Bare"
        (empty / "cursors").mkdir(parents=True)
        (empty / "index.theme").write_text("[Icon Theme]\n", encoding="utf-8")
        self.assertEqual(fonts.cursor_previews(empty, self.cache), [])

    def test_the_cursor_previews_are_cached(self) -> None:
        first = fonts.cursor_previews(self.icons / "Adwaita", self.cache)
        stamps = [Path(path).stat().st_mtime_ns for path in first]
        self.assertEqual(fonts.cursor_previews(self.icons / "Adwaita", self.cache), first)
        self.assertEqual([Path(path).stat().st_mtime_ns for path in first], stamps)

    def test_state_offers_a_vitrail_design_for_each_pack(self) -> None:
        state = fonts.state(run=lambda argv: FACES, roots=[self.icons], cache=self.cache)
        self.assertIn("Adwaita", state["cursorDesigns"])
        self.assertIn("Adwaita", state["cursorThemes"])
        self.assertIn("Adwaita", state["iconDesigns"])

    def test_state_carries_the_previews(self) -> None:
        state = fonts.state(run=lambda argv: "Roboto\t80\n", roots=[self.icons], cache=self.cache)
        self.assertTrue(state["iconPreviews"]["Adwaita"][0].endswith("folder.png"))
        self.assertTrue(state["cursorPreviews"]["Adwaita"][0].endswith(".png"))

    def test_state_does_not_prebuild_icon_styles(self) -> None:
        state = fonts.state(
            run=lambda argv: "Roboto\t80\n",
            roots=[self.icons],
            cache=self.cache,
        )
        self.assertNotIn("vitrail-icons-Adwaita@light", state["iconPreviews"])
        self.assertNotIn("vitrail-icons-Adwaita@solid", state["iconPreviews"])


class EntryTests(unittest.TestCase):
    def test_state_prints_the_lists(self) -> None:
        import contextlib
        import io
        import tempfile as temp

        with temp.TemporaryDirectory() as tmp:
            buffer = io.StringIO()
            with contextlib.redirect_stdout(buffer):
                self.assertEqual(fonts.main(["state"], run=lambda argv: FACES, cache=Path(tmp)), 0)
            self.assertIn("Adwaita Sans", buffer.getvalue())


class ApplyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.mkdtemp()
        self.root = Path(self.tmp)
        self.icons = self.root / "icons"
        for name, folders in (
            ("Adwaita", ["cursors", "48x48"]),
            ("Papirus", ["cursors", "48x48"]),
            ("Scalable", ["cursors_scalable"]),
        ):
            (self.icons / name).mkdir(parents=True)
            for folder in folders:
                (self.icons / name / folder).mkdir()
            (self.icons / name / "index.theme").write_text("[Icon Theme]\n", encoding="utf-8")
        xcursor(self.icons / "Adwaita" / "cursors" / "default")
        xcursor(self.icons / "Adwaita" / "cursors" / "hand2")
        xcursor(self.icons / "Papirus" / "cursors" / "default")
        self.config = self.root / "config"
        (self.config / "qt6ct").mkdir(parents=True)
        (self.config / "qt6ct" / "qt6ct.conf").write_text("[Appearance]\n", encoding="utf-8")

    def tearDown(self) -> None:
        shutil.rmtree(self.tmp, ignore_errors=True)

    def recording(self, text: str, calls: list[list[str]] | None = None):
        calls = [] if calls is None else calls

        def run(argv: list[str]) -> str:
            calls.append(argv)
            return text if argv[0] == "fc-list" else ""

        return run

    def apply(self, values: dict, run=None, mode=None) -> int:
        return fonts.apply(
            values,
            self.config,
            run=run or self.recording(FACES),
            roots=[self.icons],
            hyprland=True,
            data_home=self.root / "data",
            cache=self.root / "cache",
            cursor_home=self.root,
            mode=mode,
        )

    def test_the_font_name_keeps_the_size_already_set(self) -> None:
        # gsettings prints the value quoted.
        self.assertEqual(fonts.font_name("'Sans 11'", "Roboto"), "Roboto 11")
        self.assertEqual(fonts.font_name("'Sans 13.5'", "Roboto"), "Roboto 13.5")
        self.assertEqual(fonts.font_name("", "Roboto"), "Roboto 11")

    def test_the_console_family_is_empty_when_it_is_not_installed(self) -> None:
        self.assertEqual(fonts.console_family("No Such Font", run=lambda argv: FACES), "")
        self.assertEqual(fonts.console_family("Roboto", run=lambda argv: FACES), "Roboto")

    def test_the_console_family_is_empty_when_the_list_could_not_be_read(self) -> None:
        self.assertEqual(fonts.console_family("Roboto", run=lambda argv: None), "")

    def test_an_unknown_ui_icon_variant_leaves_the_apply_partial(self) -> None:
        code = self.apply(
            {
                "fontSystem": "Roboto",
                "uiIcons": "bogus",
                "iconTheme": "Adwaita",
                "cursorTheme": "Adwaita",
                "cursorSize": 24,
            }
        )
        self.assertEqual(code, 1)

    def test_an_empty_icon_list_skips_only_the_icons(self) -> None:
        empty = self.root / "no-themes"
        empty.mkdir()
        code = fonts.apply(
            {"fontSystem": "Roboto", "iconTheme": "Adwaita", "cursorTheme": "Adwaita", "cursorSize": 24},
            self.config,
            run=self.recording(FACES),
            roots=[empty],
            hyprland=True,
            cache=self.root / "cache",
        )
        self.assertEqual(code, 0)
        self.assertTrue((self.config / "fontconfig/conf.d/50-vitrail-font.conf").exists())
        self.assertFalse((self.config / "gtk-3.0/settings.ini").exists())
        self.assertFalse((self.config / "environment.d/20-vitrail-cursor.conf").exists())

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
            {
                "fontSystem": "Roboto",
                "iconTheme": "Adwaita",
                "cursorTheme": "Adwaita",
                "cursorAdaptive": "false",
                "cursorSize": 24,
            },
            run=self.recording(FACES, calls),
        )
        self.assertEqual(code, 0)
        self.assertIn(["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", "Adwaita"], calls)
        self.assertIn(["gsettings", "set", "org.gnome.desktop.interface", "cursor-theme", "vitrail-cursor"], calls)
        self.assertIn(["hyprctl", "setcursor", "vitrail-cursor", "24"], calls)
        self.assertIn(
            "XCURSOR_THEME=vitrail-cursor",
            (self.config / "environment.d/20-vitrail-cursor.conf").read_text(encoding="utf-8"),
        )
        self.assertIn("gtk-icon-theme-name=Adwaita", (self.config / "gtk-3.0/settings.ini").read_text(encoding="utf-8"))
        self.assertIn("icon_theme=Adwaita", (self.config / "qt6ct/qt6ct.conf").read_text(encoding="utf-8"))

    def test_an_adaptive_cursor_builds_the_stable_theme(self) -> None:
        self.apply(
            {
                "fontSystem": "Roboto",
                "iconTheme": "Adwaita",
                "cursorTheme": "Adwaita",
                "cursorAdaptive": "true",
                "cursorSize": 24,
            }
        )
        theme = self.root / "data" / "icons" / "vitrail-cursor"
        self.assertTrue((theme / "cursors").is_dir())
        self.assertFalse((theme / "cursors").is_symlink())
        self.assertIn("Inherits=Adwaita", (theme / "index.theme").read_text(encoding="utf-8"))
        env = (self.config / "environment.d" / "20-vitrail-cursor.conf").read_text(encoding="utf-8")
        self.assertIn("XCURSOR_THEME=vitrail-cursor", env)

    def test_an_up_to_date_adaptive_cursor_is_still_the_one_applied(self) -> None:
        values = {
            "fontSystem": "Roboto",
            "iconTheme": "Adwaita",
            "cursorTheme": "Adwaita",
            "cursorAdaptive": "true",
            "cursorSize": 24,
        }
        self.apply(values)
        calls: list[list[str]] = []
        self.apply(values, run=self.recording(FACES, calls))
        self.assertIn(["hyprctl", "setcursor", "vitrail-cursor", "24"], calls)
        self.assertIn(["gsettings", "set", "org.gnome.desktop.interface", "cursor-theme", "vitrail-cursor"], calls)
        env = (self.config / "environment.d" / "20-vitrail-cursor.conf").read_text(encoding="utf-8")
        self.assertIn("XCURSOR_THEME=vitrail-cursor", env)

    def test_a_static_cursor_aliases_the_pack(self) -> None:
        self.apply(
            {
                "fontSystem": "Roboto",
                "iconTheme": "Adwaita",
                "cursorTheme": "Adwaita",
                "cursorAdaptive": "false",
                "cursorSize": 24,
            }
        )
        theme = self.root / "data" / "icons" / "vitrail-cursor"
        self.assertTrue((theme / "cursors").is_symlink())
        self.assertEqual((theme / "cursors").resolve(), (self.icons / "Adwaita" / "cursors").resolve())

    def test_the_stable_theme_is_linked_into_the_cursor_path(self) -> None:
        self.apply(
            {
                "fontSystem": "Roboto",
                "iconTheme": "Adwaita",
                "cursorTheme": "Adwaita",
                "cursorAdaptive": "true",
                "cursorSize": 24,
            }
        )
        link = self.root / ".icons" / "vitrail-cursor"
        self.assertTrue(link.is_symlink())
        self.assertEqual(link.resolve(), (self.root / "data" / "icons" / "vitrail-cursor").resolve())

    def test_the_cursor_writes_the_hyprland_startup_file(self) -> None:
        self.apply(
            {
                "fontSystem": "Roboto",
                "iconTheme": "Adwaita",
                "cursorTheme": "Adwaita",
                "cursorAdaptive": "false",
                "cursorSize": 24,
            }
        )
        text = (self.config / "hypr" / "vitrail-cursor.lua").read_text(encoding="utf-8")
        self.assertIn('VITRAIL_CURSOR_THEME = "vitrail-cursor"', text)
        self.assertIn('VITRAIL_CURSOR_SIZE = "24"', text)
        self.assertIn('hl.env("XCURSOR_THEME", VITRAIL_CURSOR_THEME)', text)

    def test_the_hyprland_config_loads_the_generated_cursor(self) -> None:
        config = Path(__file__).resolve().parents[1] / "dots" / ".config" / "hypr" / "hyprland.lua"
        text = config.read_text(encoding="utf-8")
        self.assertIn("vitrail-cursor.lua", text)
        self.assertIn("hyprctl setcursor", text)
        self.assertIn("vitrail-apply-settings", text)

    def test_old_generated_names_are_mirrored_into_the_cursor_path(self) -> None:
        old = self.root / "data" / "icons" / "vitrail-Bibata"
        (old / "cursors").mkdir(parents=True)
        (old / "index.theme").write_text("[Icon Theme]\n", encoding="utf-8")
        self.apply(
            {
                "fontSystem": "Roboto",
                "iconTheme": "Adwaita",
                "cursorTheme": "Adwaita",
                "cursorAdaptive": "false",
                "cursorSize": 24,
            }
        )
        alias = self.root / ".icons" / "vitrail-Bibata"
        self.assertTrue(alias.is_symlink())
        self.assertEqual(alias.resolve(), (self.root / ".icons" / "vitrail-cursor").resolve())

    def test_a_legacy_vitrail_value_still_adapts(self) -> None:
        self.apply(
            {
                "fontSystem": "Roboto",
                "iconTheme": "Adwaita",
                "cursorTheme": "vitrail-Adwaita",
                "cursorSize": 24,
            }
        )
        theme = self.root / "data" / "icons" / "vitrail-cursor"
        self.assertFalse((theme / "cursors").is_symlink())
        self.assertIn("Inherits=Adwaita", (theme / "index.theme").read_text(encoding="utf-8"))

    def test_a_vitrail_cursor_without_its_pack_falls_back(self) -> None:
        code = self.apply(
            {
                "fontSystem": "Roboto",
                "iconTheme": "Adwaita",
                "cursorTheme": "vitrail-NoSuchPack",
                "cursorSize": 24,
            }
        )
        self.assertEqual(code, 1)
        env = (self.config / "environment.d" / "20-vitrail-cursor.conf").read_text(encoding="utf-8")
        self.assertIn("XCURSOR_THEME=vitrail-cursor", env)

    def test_a_pack_without_cursors_falls_back_to_its_name(self) -> None:
        self.apply(
            {
                "fontSystem": "Roboto",
                "iconTheme": "Adwaita",
                "cursorTheme": "Scalable",
                "cursorAdaptive": "true",
                "cursorSize": 24,
            }
        )
        env = (self.config / "environment.d" / "20-vitrail-cursor.conf").read_text(encoding="utf-8")
        self.assertIn("XCURSOR_THEME=Scalable", env)

    def test_a_cursor_change_reaches_x11_too(self) -> None:
        calls: list[list[str]] = []
        code = fonts.apply(
            {
                "fontSystem": "Roboto",
                "iconTheme": "Adwaita",
                "cursorTheme": "Adwaita",
                "cursorAdaptive": "false",
                "cursorSize": 24,
            },
            self.config,
            run=self.recording(FACES, calls),
            roots=[self.icons],
            hyprland=False,
            x11=True,
            data_home=self.root / "data",
            cache=self.root / "cache",
            cursor_home=self.root,
        )
        self.assertEqual(code, 0)
        resources = self.config / "X11" / "vitrail-cursor.Xresources"
        self.assertIn(["xrdb", "-merge", str(resources)], calls)
        self.assertIn(["pkill", "-HUP", "-x", "xsettingsd"], calls)
        self.assertIn("Xcursor.theme: vitrail-cursor", resources.read_text(encoding="utf-8"))
        self.assertIn("Xcursor.size: 24", resources.read_text(encoding="utf-8"))
        self.assertIn(
            "gtk-cursor-theme-name=vitrail-cursor", (self.config / "gtk-3.0/settings.ini").read_text(encoding="utf-8")
        )
        self.assertIn(
            'Gtk/CursorThemeName "vitrail-cursor"',
            (self.config / "xsettingsd/xsettingsd.conf").read_text(encoding="utf-8"),
        )

    def test_each_mode_aliases_its_own_pack_under_the_stable_name(self) -> None:
        values = {
            "fontSystem": "Roboto",
            "iconTheme": "Adwaita",
            "cursorTheme": "Adwaita",
            "cursorThemeLight": "Papirus",
            "cursorThemeDark": "Adwaita",
            "cursorThemeSplit": "true",
            "cursorAdaptive": "false",
            "cursorSize": 24,
        }
        theme = self.root / "data" / "icons" / "vitrail-cursor"
        self.apply(values, mode="light")
        self.assertEqual((theme / "cursors").resolve(), (self.icons / "Papirus" / "cursors").resolve())
        self.apply(values, mode="dark")
        self.assertEqual((theme / "cursors").resolve(), (self.icons / "Adwaita" / "cursors").resolve())

    def test_without_the_split_the_shared_cursor_wins(self) -> None:
        self.apply(
            {
                "fontSystem": "Roboto",
                "iconTheme": "Adwaita",
                "cursorTheme": "Adwaita",
                "cursorThemeLight": "Papirus",
                "cursorThemeDark": "Papirus",
                "cursorThemeSplit": "false",
                "cursorAdaptive": "false",
                "cursorSize": 24,
            },
            mode="light",
        )
        theme = self.root / "data" / "icons" / "vitrail-cursor"
        self.assertEqual((theme / "cursors").resolve(), (self.icons / "Adwaita" / "cursors").resolve())

    def test_an_empty_theme_falls_back_to_the_shared_cursor(self) -> None:
        values = {
            "fontSystem": "Roboto",
            "iconTheme": "Adwaita",
            "cursorTheme": "Adwaita",
            "cursorThemeLight": "",
            "cursorThemeDark": "",
            "cursorThemeSplit": "true",
            "cursorAdaptive": "false",
            "cursorSize": 24,
        }
        theme = self.root / "data" / "icons" / "vitrail-cursor"
        for mode in ("light", "dark"):
            self.apply(values, mode=mode)
            self.assertEqual((theme / "cursors").resolve(), (self.icons / "Adwaita" / "cursors").resolve())

    def test_an_adaptive_cursor_is_built_for_the_active_theme(self) -> None:
        values = {
            "fontSystem": "Roboto",
            "iconTheme": "Adwaita",
            "cursorTheme": "Adwaita",
            "cursorThemeLight": "Adwaita",
            "cursorThemeDark": "Papirus",
            "cursorThemeSplit": "true",
            "cursorAdaptive": "true",
            "cursorSize": 24,
        }
        theme = self.root / "data" / "icons" / "vitrail-cursor"
        self.apply(values, mode="light")
        self.assertIn("Inherits=Adwaita", (theme / "index.theme").read_text(encoding="utf-8"))
        self.apply(values, mode="dark")
        self.assertIn("Inherits=Papirus", (theme / "index.theme").read_text(encoding="utf-8"))

    def test_monochrome_is_applied_only_with_adaptive(self) -> None:
        self.apply(
            {
                "fontSystem": "Roboto",
                "iconTheme": "Adwaita",
                "cursorTheme": "Adwaita",
                "cursorAdaptive": "false",
                "cursorMonochrome": "true",
                "cursorSize": 24,
            }
        )
        theme = self.root / "data" / "icons" / "vitrail-cursor"
        self.assertTrue((theme / "cursors").is_symlink())

    def test_the_cursor_reaches_hyprland_env_and_the_user_bus(self) -> None:
        calls: list[list[str]] = []
        self.apply(
            {
                "fontSystem": "Roboto",
                "iconTheme": "Adwaita",
                "cursorTheme": "Adwaita",
                "cursorAdaptive": "false",
                "cursorSize": 24,
            },
            run=self.recording(FACES, calls),
        )
        self.assertIn(["hyprctl", "setcursor", "vitrail-cursor", "24"], calls)
        self.assertTrue(
            any(
                argv[:2] == ["hyprctl", "eval"] and 'hl.env("XCURSOR_THEME", "vitrail-cursor")' in argv[2]
                for argv in calls
            )
        )
        self.assertIn(
            ["systemctl", "--user", "set-environment", "XCURSOR_THEME=vitrail-cursor", "XCURSOR_SIZE=24"], calls
        )
        self.assertIn(["dbus-update-activation-environment", "--systemd", "XCURSOR_THEME", "XCURSOR_SIZE"], calls)

    def test_a_changed_cursor_switches_away_before_setting_it(self) -> None:
        values = {
            "fontSystem": "Roboto",
            "iconTheme": "Adwaita",
            "cursorTheme": "Adwaita",
            "cursorAdaptive": "true",
            "cursorSize": 24,
        }
        calls: list[list[str]] = []
        self.apply(values, run=self.recording(FACES, calls))
        # Hyprland caches the theme by name; the rebuild needs the reload.
        self.assertIn(["hyprctl", "setcursor", "Adwaita", "24"], calls)
        self.assertIn(["hyprctl", "setcursor", "vitrail-cursor", "24"], calls)
        # A no-op apply leaves the cursor alone instead of flashing it.
        calls.clear()
        self.apply(values, run=self.recording(FACES, calls))
        self.assertNotIn(["hyprctl", "setcursor", "Adwaita", "24"], calls)
        self.assertIn(["hyprctl", "setcursor", "vitrail-cursor", "24"], calls)

    def test_the_active_cursor_reaches_every_app_channel(self) -> None:
        calls: list[list[str]] = []
        self.apply(
            {
                "fontSystem": "Roboto",
                "iconTheme": "Adwaita",
                "cursorTheme": "Adwaita",
                "cursorThemeLight": "Papirus",
                "cursorThemeSplit": "true",
                "cursorAdaptive": "false",
                "cursorSize": 24,
            },
            run=self.recording(FACES, calls),
            mode="light",
        )
        # Wayland, GTK (dconf) and X11's XSETTINGS.
        self.assertIn(["hyprctl", "setcursor", "vitrail-cursor", "24"], calls)
        self.assertIn(
            ["gsettings", "set", "org.gnome.desktop.interface", "cursor-theme", "vitrail-cursor"],
            calls,
        )
        self.assertIn(
            ["gsettings", "set", "org.gnome.desktop.interface", "cursor-size", "24"],
            calls,
        )
        gtk = (self.config / "gtk-3.0" / "settings.ini").read_text(encoding="utf-8")
        self.assertIn("gtk-cursor-theme-name=vitrail-cursor", gtk)
        self.assertIn("gtk-cursor-theme-size=24", gtk)
        self.assertIn(
            "XCURSOR_THEME=vitrail-cursor",
            (self.config / "environment.d" / "20-vitrail-cursor.conf").read_text(encoding="utf-8"),
        )
        self.assertIn(
            "Xcursor.theme: vitrail-cursor",
            (self.config / "X11" / "vitrail-cursor.Xresources").read_text(encoding="utf-8"),
        )
        self.assertIn(
            'Gtk/CursorThemeName "vitrail-cursor"',
            (self.config / "xsettingsd" / "xsettingsd.conf").read_text(encoding="utf-8"),
        )

    def test_an_adaptive_icon_layer_is_built_before_it_is_set(self) -> None:
        places = self.icons / "Adwaita" / "48x48" / "places"
        places.mkdir(parents=True)
        (places / "folder.svg").write_text('<path style="fill:#5294e2"/>', encoding="utf-8")
        (self.icons / "Adwaita" / "index.theme").write_text(
            "[Icon Theme]\nDirectories=48x48/places\n\n[48x48/places]\nSize=48\n", encoding="utf-8"
        )
        self.apply(
            {
                "fontSystem": "Roboto",
                "iconTheme": "Adwaita",
                "iconAdaptive": "true",
                "iconFill": "pack",
                "cursorTheme": "Adwaita",
                "cursorAdaptive": "false",
                "cursorSize": 24,
            }
        )
        theme = self.root / "data" / "icons" / "vitrail-icons-Adwaita"
        self.assertTrue((theme / "48x48" / "places" / "folder.svg").is_file())
        self.assertIn("Inherits=Adwaita", (theme / "index.theme").read_text(encoding="utf-8"))
        self.assertIn(
            "gtk-icon-theme-name=vitrail-icons-Adwaita",
            (self.config / "gtk-3.0/settings.ini").read_text(encoding="utf-8"),
        )

    def test_the_icon_fill_style_is_applied(self) -> None:
        places = self.icons / "Adwaita" / "48x48" / "places"
        places.mkdir(parents=True)
        (places / "folder.svg").write_text(
            '<svg><path style="fill:#5294e2"/><path style="fill:#2b2b2b"/></svg>', encoding="utf-8"
        )
        (self.icons / "Adwaita" / "index.theme").write_text(
            "[Icon Theme]\nDirectories=48x48/places\n\n[48x48/places]\nSize=48\n", encoding="utf-8"
        )
        self.apply(
            {
                "fontSystem": "Roboto",
                "iconTheme": "Adwaita",
                "iconAdaptive": "true",
                "iconFill": "light",
                "cursorTheme": "Adwaita",
                "cursorAdaptive": "false",
                "cursorSize": 24,
            }
        )
        theme = self.root / "data" / "icons" / "vitrail-icons-Adwaita@light"
        self.assertTrue(theme.is_dir())
        self.assertIn("Name=Vitrail icons · Adwaita (light)", (theme / "index.theme").read_text(encoding="utf-8"))
        self.assertIn(
            "gtk-icon-theme-name=vitrail-icons-Adwaita@light",
            (self.config / "gtk-3.0/settings.ini").read_text(encoding="utf-8"),
        )

    def test_a_plain_icon_pack_is_applied_as_is(self) -> None:
        self.apply(
            {
                "fontSystem": "Roboto",
                "iconTheme": "Adwaita",
                "iconAdaptive": "false",
                "cursorTheme": "Adwaita",
                "cursorAdaptive": "false",
                "cursorSize": 24,
            }
        )
        self.assertIn(
            "gtk-icon-theme-name=Adwaita",
            (self.config / "gtk-3.0/settings.ini").read_text(encoding="utf-8"),
        )
        self.assertFalse((self.root / "data" / "icons" / "vitrail-icons-Adwaita").exists())

    def test_a_legacy_vitrail_icon_value_still_adapts(self) -> None:
        places = self.icons / "Adwaita" / "48x48" / "places"
        places.mkdir(parents=True)
        (places / "folder.svg").write_text('<path style="fill:#5294e2"/>', encoding="utf-8")
        (self.icons / "Adwaita" / "index.theme").write_text(
            "[Icon Theme]\nDirectories=48x48/places\n\n[48x48/places]\nSize=48\n", encoding="utf-8"
        )
        self.apply(
            {
                "fontSystem": "Roboto",
                "iconTheme": "vitrail-icons-Adwaita@light",
                "cursorTheme": "Adwaita",
                "cursorAdaptive": "false",
                "cursorSize": 24,
            }
        )
        self.assertTrue((self.root / "data" / "icons" / "vitrail-icons-Adwaita@light" / "index.theme").is_file())
        self.assertIn(
            "gtk-icon-theme-name=vitrail-icons-Adwaita@light",
            (self.config / "gtk-3.0/settings.ini").read_text(encoding="utf-8"),
        )

    def test_the_own_busy_cursor_is_not_written_from_the_page(self) -> None:
        def render(svg: str) -> bytes:
            return bytes((0, 255, 0, 255)) * (32 * 32)

        base = {
            "fontSystem": "Roboto",
            "iconTheme": "Adwaita",
            "cursorTheme": "Adwaita",
            "cursorAdaptive": "true",
            "cursorSize": 24,
        }
        target = self.root / "data" / "icons" / "vitrail-cursor"
        arguments = dict(
            run=self.recording(FACES),
            roots=[self.icons],
            hyprland=False,
            x11=False,
            data_home=self.root / "data",
            cache=self.root / "cache",
            render=render,
            palette={"on_surface": "#ffffff", "surface": "#000000", "primary": "#ff0000"},
            cursor_home=self.root,
        )
        fonts.apply(dict(base, cursorSpinner="true"), self.config, **arguments)
        self.assertFalse((target / "cursors" / "wait").exists())

    def test_a_theme_that_is_not_installed_falls_back(self) -> None:
        code = self.apply({"fontSystem": "Roboto", "iconTheme": "Adwaita", "cursorTheme": "Nope", "cursorSize": 24})
        self.assertEqual(code, 1)
        text = (self.config / "environment.d/20-vitrail-cursor.conf").read_text(encoding="utf-8")
        self.assertIn("XCURSOR_THEME=vitrail-cursor", text)

    def test_a_cursor_size_out_of_range_falls_back_to_the_default(self) -> None:
        code = self.apply({"fontSystem": "Roboto", "iconTheme": "Adwaita", "cursorTheme": "Adwaita", "cursorSize": 999})
        self.assertEqual(code, 1)
        text = (self.config / "environment.d/20-vitrail-cursor.conf").read_text(encoding="utf-8")
        self.assertIn("XCURSOR_SIZE=24", text)


if __name__ == "__main__":
    unittest.main()
