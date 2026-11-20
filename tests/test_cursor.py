"""The tinted cursor: Xcursor round-trip and the palette's two inks."""

from __future__ import annotations

import struct
import tempfile
import unittest
from pathlib import Path
from unittest import mock

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

    def test_a_small_body_outweighs_more_transparent_rim_pixels(self) -> None:
        # One opaque white body pixel and two dark anti-aliased rim pixels: the
        # body is the bigger visible area, not the bigger pixel count.
        pixels = struct.pack("<III", 0xFFFFFFFF, 0x0A000000, 0x0A000000)
        out = struct.unpack("<III", cursor.tint(pixels, 3, 1, "#ff0000", "#000000"))
        self.assertEqual(out[0], 0xFFFF0000)

    def test_the_rim_touching_transparency_is_not_the_body(self) -> None:
        # 7x7: a white 3x3 body inside a black rim, transparent outside. The
        # rim has more pixels; the body is what does not touch the background.
        words = []
        for y in range(7):
            for x in range(7):
                if 2 <= x <= 4 and 2 <= y <= 4:
                    words.append(0xFFFFFFFF)
                elif 1 <= x <= 5 and 1 <= y <= 5:
                    words.append(0xFF000000)
                else:
                    words.append(0x00000000)
        out = struct.unpack("<49I", cursor.tint(struct.pack("<49I", *words), 7, 7, "#ff0000", "#0000ff"))
        self.assertEqual(out[3 * 7 + 3], 0xFFFF0000)  # body takes the fill
        self.assertEqual(out[1 * 7 + 1], 0xFF0000FF)  # rim takes the outline


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
        self.target = root / "icons" / cursor.STABLE
        self.cache = root / "cache"

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def build(self, primary: str = "#ff0000", spinner: bool = False, render=None, mono: bool = False) -> bool:
        palette = dict(PALETTE, on_surface=primary)
        return cursor.build(
            self.pack,
            self.target,
            palette,
            self.cache,
            spinner=spinner,
            render=render or (lambda svg: None),
            mono=mono,
        )

    def test_every_shape_takes_the_accent(self) -> None:
        self.assertTrue(self.build())
        arrow = struct.unpack("<II", cursor.read_cursor(self.target / "cursors" / "left_ptr")[0]["pixels"])
        hand = struct.unpack("<I", cursor.read_cursor(self.target / "cursors" / "hand2")[0]["pixels"][:4])[0]
        self.assertEqual(arrow, (0xFF00FF00, 0xFF000000))
        self.assertEqual(hand, 0xFF00FF00)

    def test_the_generated_theme_inherits_the_pack(self) -> None:
        self.build()
        theme = (self.target / "index.theme").read_text(encoding="utf-8")
        self.assertIn("Inherits=Bibata", theme)
        self.assertIn("Name=Vitrail · Cursor", theme)

    def test_the_stable_name_is_not_a_pack(self) -> None:
        self.assertEqual(cursor.STABLE, "vitrail-cursor")
        self.assertEqual(cursor.source_of(cursor.STABLE), "")
        self.assertEqual(cursor.source_of("vitrail-Bibata"), "Bibata")
        self.assertEqual(cursor.source_of("Adwaita"), "")

    def test_monochrome_paints_every_shape_with_the_ink(self) -> None:
        self.assertTrue(self.build(mono=True))
        arrow = struct.unpack("<I", cursor.read_cursor(self.target / "cursors" / "left_ptr")[0]["pixels"][:4])[0]
        hand = struct.unpack("<I", cursor.read_cursor(self.target / "cursors" / "hand2")[0]["pixels"][:4])[0]
        self.assertEqual(arrow, 0xFFFF0000)
        self.assertEqual(hand, 0xFFFF0000)

    def test_a_static_pack_is_aliased_not_copied(self) -> None:
        self.assertTrue(cursor.alias(self.pack, self.target))
        self.assertTrue((self.target / "cursors").is_symlink())
        self.assertTrue((self.target / "cursors" / "left_ptr").is_file())
        self.assertIn("Inherits=Bibata", (self.target / "index.theme").read_text(encoding="utf-8"))

    def test_building_over_an_alias_replaces_the_symlink(self) -> None:
        cursor.alias(self.pack, self.target)
        self.assertTrue(self.build())
        self.assertFalse((self.target / "cursors").is_symlink())
        arrow = cursor.read_cursor(self.target / "cursors" / "left_ptr")[0]["pixels"]
        self.assertEqual(struct.unpack("<I", arrow[:4])[0], 0xFF00FF00)

    def test_an_alias_over_a_generated_theme_removes_it(self) -> None:
        self.build()
        self.assertTrue(cursor.alias(self.pack, self.target))
        self.assertTrue((self.target / "cursors").is_symlink())
        self.assertEqual((self.target / "cursors").resolve(), (self.pack / "cursors").resolve())

    def test_a_stale_pack_does_not_leave_cursors_behind(self) -> None:
        self.build()
        (self.pack / "cursors" / "left_ptr").unlink()
        cursor.write_cursor([image()], self.pack / "cursors" / "new_shape")
        self.assertTrue(self.build(primary="#0000ff"))
        self.assertFalse((self.target / "cursors" / "left_ptr").exists())
        self.assertTrue((self.target / "cursors" / "new_shape").is_file())

    def test_old_generated_themes_become_aliases(self) -> None:
        icons = self.pack.parent
        self.assertTrue(cursor.alias(self.pack, icons / cursor.STABLE))
        old = icons / "vitrail-Bibata"
        cursor.write_cursor([image()], old / "cursors" / "left_ptr")
        (old / "index.theme").write_text("[Icon Theme]\n", encoding="utf-8")
        self.assertEqual(cursor.migrate_aliases(icons), 1)
        self.assertTrue(old.is_symlink())
        self.assertEqual(old.resolve(), (icons / cursor.STABLE).resolve())
        self.assertEqual(cursor.migrate_aliases(icons), 0)

    def test_a_current_theme_is_not_rebuilt(self) -> None:
        self.build()
        stamp = (self.target / "index.theme").stat().st_mtime_ns
        self.assertFalse(self.build())
        self.assertEqual((self.target / "index.theme").stat().st_mtime_ns, stamp)

    def test_a_new_tint_version_forces_a_rebuild(self) -> None:
        self.build()
        with mock.patch.object(cursor, "TINT_VERSION", cursor.TINT_VERSION + 1):
            self.assertTrue(self.build())

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
        self.assertTrue((icons / cursor.STABLE / "index.theme").is_file())

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


class ParallelBuildTests(unittest.TestCase):
    """A real pack carries hundreds of shapes: tinting them one at a time
    leaves the pointer waiting while the settings apply runs. A large pack is
    spread over the machine's cores; a small one stays on the current one."""

    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.pack = root / "icons" / "Big"
        (self.pack / "cursors").mkdir(parents=True)
        for index in range(cursor.PARALLEL_FILES):
            cursor.write_cursor([image()], self.pack / "cursors" / f"shape{index}")
        (self.pack / "index.theme").write_text("[Icon Theme]\n", encoding="utf-8")
        self.target = root / "icons" / cursor.STABLE
        self.cache = root / "cache"

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def test_a_large_pack_is_spread_over_the_cores(self) -> None:
        started: list[int] = []

        class Pool:
            def __init__(self, max_workers: int | None = None, mp_context=None) -> None:
                started.append(max_workers or 0)

            def __enter__(self) -> "Pool":
                return self

            def __exit__(self, *_exc) -> bool:
                return False

            def map(self, function, jobs):
                return [function(job) for job in jobs]

        with mock.patch.object(cursor, "ProcessPoolExecutor", Pool):
            self.assertTrue(cursor.build(self.pack, self.target, PALETTE, self.cache, spinner=False))

        self.assertEqual(len(started), 1)
        self.assertGreater(started[0], 1)
        # Every shape still comes out tinted, whichever core tinted it.
        tinted = cursor.read_cursor(self.target / "cursors" / "shape0")[0]["pixels"]
        self.assertEqual(struct.unpack("<I", tinted[:4])[0], 0xFF00FF00)


class UserRootTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.home = root / "home"
        self.pack = root / "icons" / "Bibata"
        (self.pack / "cursors").mkdir(parents=True)
        cursor.write_cursor([image()], self.pack / "cursors" / "left_ptr")
        (self.pack / "index.theme").write_text("[Icon Theme]\n", encoding="utf-8")
        self.target = root / "data" / "icons" / cursor.STABLE

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def test_the_stable_theme_is_linked_where_cursors_are_read(self) -> None:
        self.assertTrue(cursor.alias(self.pack, self.target))
        self.assertTrue(cursor.link_user(self.target, self.home))
        link = self.home / ".icons" / cursor.STABLE
        self.assertTrue(link.is_symlink())
        self.assertEqual(link.resolve(), self.target.resolve())
        self.assertFalse(cursor.link_user(self.target, self.home))

    def test_old_names_are_mirrored_next_to_the_stable_one(self) -> None:
        self.assertTrue(cursor.alias(self.pack, self.target))
        cursor.link_user(self.target, self.home)
        old = self.target.parent / "vitrail-Bibata"
        (old / "cursors").mkdir(parents=True)
        (old / "index.theme").write_text("[Icon Theme]\n", encoding="utf-8")
        self.assertEqual(cursor.mirror_aliases(self.target.parent, self.home), 1)
        alias = self.home / ".icons" / "vitrail-Bibata"
        self.assertTrue(alias.is_symlink())
        self.assertEqual(alias.resolve(), (self.home / ".icons" / cursor.STABLE).resolve())
        self.assertEqual(cursor.mirror_aliases(self.target.parent, self.home), 0)


if __name__ == "__main__":
    unittest.main()
