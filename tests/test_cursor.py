"""The tinted cursor: Xcursor round-trip and the palette's two inks."""

from __future__ import annotations

import struct
import tempfile
import unittest
from pathlib import Path

from vitrail import cursor

PALETTE = {"on_surface": "#ff0000", "surface": "#000000", "primary": "#00ff00"}


def image(
    width: int = 2,
    height: int = 1,
    pixels: tuple[int, ...] = (0xFF000000, 0xFFFFFFFF),
    subtype: int = 24,
    delay: int = 0,
    xhot: int = 0,
    yhot: int = 0,
) -> dict:
    return {
        "subtype": subtype,
        "width": width,
        "height": height,
        "xhot": xhot,
        "yhot": yhot,
        "delay": delay,
        "pixels": b"".join(struct.pack("<I", word) for word in pixels),
    }


class XcursorTests(unittest.TestCase):
    def test_a_written_cursor_reads_back_the_same_images(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "left_ptr"
            images = [
                image(subtype=24),
                image(subtype=32, width=3, height=1, pixels=(0, 0, 0), xhot=2, yhot=1, delay=40),
            ]
            cursor.write_cursor(images, path)
            back = cursor.read_cursor(path)
            self.assertEqual([one["subtype"] for one in back], [24, 32])
            self.assertEqual(back[0]["pixels"], images[0]["pixels"])
            self.assertEqual((back[1]["width"], back[1]["xhot"], back[1]["delay"]), (3, 2, 40))

    def test_a_foreign_file_is_not_an_xcursor(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "x"
            path.write_bytes(b"not a cursor")
            self.assertEqual(cursor.read_cursor(path), [])


class TintTests(unittest.TestCase):
    def test_the_bigger_cluster_is_the_body_and_the_other_the_rim(self) -> None:
        pixels = struct.pack("<III", 0xFF000000, 0xFF000000, 0xFFFFFFFF)
        out = struct.unpack("<III", cursor.tint(pixels, 3, 1, "#ff0000", "#000000"))
        self.assertEqual(out, (0xFFFF0000, 0xFFFF0000, 0xFF000000))

    def test_a_flat_image_takes_the_fill_so_it_never_vanishes(self) -> None:
        pixels = struct.pack("<II", 0xFF000000, 0xFF000000)
        out = struct.unpack("<II", cursor.tint(pixels, 2, 1, "#ff0000", "#000000"))
        self.assertEqual(out, (0xFFFF0000, 0xFFFF0000))

    def test_transparency_is_kept(self) -> None:
        pixels = struct.pack("<I", 0x00000000)
        self.assertEqual(cursor.tint(pixels, 1, 1, "#ff0000", "#000000"), pixels)


class XsettingsTests(unittest.TestCase):
    def test_the_two_keys_are_updated_and_the_rest_kept(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "xsettingsd.conf"
            path.write_text('Xft/DPI 96\nGtk/CursorThemeName "Old"\n', encoding="utf-8")
            cursor.update_xsettings(path, "Vitrail · Bibata", 32)
            text = path.read_text(encoding="utf-8")
            self.assertIn("Xft/DPI 96", text)
            self.assertIn('Gtk/CursorThemeName "Vitrail · Bibata"', text)
            self.assertIn("Gtk/CursorThemeSize 32", text)
            self.assertNotIn('"Old"', text)
            self.assertTrue(path.with_name("xsettingsd.conf.before-vitrail").exists())


class BuildTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.pack = root / "icons" / "Bibata"
        (self.pack / "cursors").mkdir(parents=True)
        cursor.write_cursor([image()], self.pack / "cursors" / "left_ptr")
        cursor.write_cursor([image(pixels=(0xFF000000, 0xFF000000))], self.pack / "cursors" / "hand2")
        (self.pack / "index.theme").write_text("[Icon Theme]\n", encoding="utf-8")
        self.target = root / "icons" / "vitrail-Bibata"
        self.cache = root / "cache"

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def build(self, primary: str = "#ff0000", spinner: bool = False, render=None) -> bool:
        palette = dict(PALETTE, on_surface=primary)
        return cursor.build(
            self.pack, self.target, palette, self.cache, spinner=spinner, render=render or (lambda svg: None)
        )

    def test_the_arrow_takes_the_ink_and_an_active_shape_the_accent(self) -> None:
        self.assertTrue(self.build())
        arrow = struct.unpack("<II", cursor.read_cursor(self.target / "cursors" / "left_ptr")[0]["pixels"])
        hand = struct.unpack("<I", cursor.read_cursor(self.target / "cursors" / "hand2")[0]["pixels"][:4])[0]
        self.assertEqual(arrow, (0xFFFF0000, 0xFF000000))
        self.assertEqual(hand, 0xFF00FF00)

    def test_the_generated_theme_inherits_the_pack(self) -> None:
        self.build()
        theme = (self.target / "index.theme").read_text(encoding="utf-8")
        self.assertIn("Inherits=Bibata", theme)
        self.assertIn("Name=Vitrail · Bibata", theme)

    def test_a_current_theme_is_not_rebuilt(self) -> None:
        self.build()
        stamp = (self.target / "index.theme").stat().st_mtime_ns
        self.assertFalse(self.build())
        self.assertEqual((self.target / "index.theme").stat().st_mtime_ns, stamp)

    def test_a_new_palette_rebuilds_it(self) -> None:
        self.build()
        self.assertTrue(self.build(primary="#0000ff"))

    def test_the_busy_cursor_is_ours(self) -> None:
        def render(svg: str) -> bytes:
            return bytes((0, 255, 0, 255)) * (32 * 32)

        self.assertTrue(self.build(spinner=True, render=render))
        for name in ("wait", "progress", "left_ptr_watch"):
            images = cursor.read_cursor(self.target / "cursors" / name)
            self.assertEqual(len(images), 12)
            self.assertEqual(images[0]["delay"], 120)

    def test_a_folder_without_cursors_is_nothing(self) -> None:
        bare = Path(self.tmp.name) / "icons" / "Bare"
        bare.mkdir(parents=True)
        (bare / "index.theme").write_text("[Icon Theme]\n", encoding="utf-8")
        self.assertFalse(cursor.build(bare, bare.with_name("vitrail-Bare"), PALETTE, self.cache))

    def test_the_cli_builds_an_installed_pack(self) -> None:
        icons = self.pack.parent
        self.assertEqual(
            cursor.main(["build", "Bibata"], roots=[icons], palette=PALETTE, output=icons, cache=self.cache), 0
        )
        self.assertTrue((icons / "vitrail-Bibata" / "index.theme").is_file())

    def test_the_cli_refuses_a_missing_pack(self) -> None:
        self.assertEqual(
            cursor.main(
                ["build", "Nope"],
                roots=[self.pack.parent],
                palette=PALETTE,
                output=self.target.parent,
                cache=self.cache,
            ),
            2,
        )

    def test_the_design_name_round_trips(self) -> None:
        self.assertEqual(cursor.design_name("Bibata"), "vitrail-Bibata")
        self.assertEqual(cursor.source_of("vitrail-Bibata"), "Bibata")
        self.assertEqual(cursor.source_of("Adwaita"), "")


if __name__ == "__main__":
    unittest.main()
