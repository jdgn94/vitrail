"""Wallpaper folders, selection, rotation and adaptive SVGs."""

from __future__ import annotations

import random
import tempfile
import unittest
from pathlib import Path

from vitrail import wallpaper


class KindTests(unittest.TestCase):
    def test_kind_follows_the_extension(self) -> None:
        self.assertEqual(wallpaper.kind_of("/w/images/a.JPG"), "image")
        self.assertEqual(wallpaper.kind_of("/w/svg/waves.svg"), "svg")
        self.assertEqual(wallpaper.kind_of("/w/videos/rain.webm"), "video")
        self.assertIsNone(wallpaper.kind_of("/w/notes.txt"))

    def test_requests_drop_their_nonce(self) -> None:
        self.assertEqual(wallpaper.request_paths("1730000000|/a.png|/b c.png"), ["/a.png", "/b c.png"])
        self.assertEqual(wallpaper.request_paths(""), [])

    def test_folders_are_created_per_kind(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            folders = wallpaper.ensure_folders(Path(tmp))
            self.assertEqual(set(folders), {"image", "svg", "video"})
            for folder in folders.values():
                self.assertTrue(folder.is_dir())
            self.assertEqual(folders["video"].name, "videos")


class SelectionTests(unittest.TestCase):
    def test_selection_round_trips_through_the_ini_value(self) -> None:
        paths = ["/w/images/a.png", "/w/images/b c.png"]
        self.assertEqual(wallpaper.parse_selection(wallpaper.join_selection(paths)), paths)
        self.assertEqual(wallpaper.parse_selection(""), [])

    def test_sequential_rotation_wraps_around(self) -> None:
        chosen = ["a", "b", "c"]
        self.assertEqual(wallpaper.next_wallpaper(chosen, "a", "sequential"), "b")
        self.assertEqual(wallpaper.next_wallpaper(chosen, "c", "sequential"), "a")
        self.assertEqual(wallpaper.next_wallpaper(chosen, "gone", "sequential"), "a")

    def test_random_rotation_never_repeats_the_current_one(self) -> None:
        chosen = ["a", "b", "c"]
        rng = random.Random(4)
        for _ in range(20):
            self.assertNotEqual(wallpaper.next_wallpaper(chosen, "b", "random", rng), "b")

    def test_a_single_wallpaper_stays(self) -> None:
        self.assertEqual(wallpaper.next_wallpaper(["a"], "a", "random"), "a")
        self.assertIsNone(wallpaper.next_wallpaper([], "a", "sequential"))


class LibraryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.settings = self.root / "config" / "vitrail" / "settings.ini"
        self.settings.parent.mkdir(parents=True)
        self.library = self.settings.parent / "wallpapers"

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def test_the_library_lives_in_the_config_folder(self) -> None:
        self.assertEqual(wallpaper.library({}, self.settings), self.library)
        self.assertEqual(wallpaper.library({"wallpaperDir": "/elsewhere"}, self.settings), Path("/elsewhere"))

    def test_imports_are_copied_into_their_kind_folder(self) -> None:
        photo = self.root / "photo.png"
        photo.write_bytes(b"png")
        clip = self.root / "clip.webm"
        clip.write_bytes(b"webm")
        notes = self.root / "notes.txt"
        notes.write_text("no")
        self.settings.write_text(
            f"[appearance]\nwallpaperImport=17|{photo}|{clip}|{notes}\n", encoding="utf-8")
        wallpaper.sync(self.settings)
        self.assertEqual((self.library / "images" / "photo.png").read_bytes(), b"png")
        self.assertTrue((self.library / "videos" / "clip.webm").exists())
        self.assertTrue(photo.exists(), "the original stays where it was")
        self.assertEqual(wallpaper.read_prefs(self.settings)["wallpaperImport"], "")

    def test_an_import_never_overwrites(self) -> None:
        (self.library / "images").mkdir(parents=True)
        (self.library / "images" / "photo.png").write_bytes(b"old")
        photo = self.root / "photo.png"
        photo.write_bytes(b"new")
        self.settings.write_text(f"[appearance]\nwallpaperImport=1|{photo}\n", encoding="utf-8")
        wallpaper.sync(self.settings)
        self.assertEqual((self.library / "images" / "photo.png").read_bytes(), b"old")
        self.assertEqual((self.library / "images" / "photo-2.png").read_bytes(), b"new")

    def test_removal_only_deletes_inside_the_library(self) -> None:
        inside = self.library / "svg" / "waves.svg"
        inside.parent.mkdir(parents=True)
        inside.write_text("<svg/>")
        outside = self.root / "keep.svg"
        outside.write_text("<svg/>")
        self.settings.write_text(
            f"[appearance]\nwallpaperRemove=9|{inside}|{outside}\n", encoding="utf-8")
        wallpaper.sync(self.settings)
        self.assertFalse(inside.exists())
        self.assertTrue(outside.exists())
        self.assertEqual(wallpaper.read_prefs(self.settings)["wallpaperRemove"], "")


class SvgTests(unittest.TestCase):
    SVG = (
        '<svg><rect fill="{{surface}}"/><circle fill="#3366cc"/>'
        '<path stroke="#3366CC"/><path fill="#ffffff"/><path fill="{{primary}}"/></svg>'
    )

    def test_seed_is_the_most_used_coloured_hex(self) -> None:
        self.assertEqual(wallpaper.svg_seed(self.SVG), "#3366cc")

    def test_seed_skips_greys(self) -> None:
        self.assertIsNone(wallpaper.svg_seed('<svg fill="#ffffff" stroke="#202020"/>'))

    def test_placeholders_take_the_palette(self) -> None:
        out = wallpaper.render_svg(self.SVG, {"surface": "#101010", "primary": "#abcdef"})
        self.assertIn('fill="#101010"', out)
        self.assertIn('fill="#abcdef"', out)
        self.assertNotIn("{{", out)

    def test_unknown_placeholder_falls_back_to_on_surface(self) -> None:
        out = wallpaper.render_svg('<svg fill="{{nope}}"/>', {"on_surface": "#eeeeee"})
        self.assertEqual(out, '<svg fill="#eeeeee"/>')


if __name__ == "__main__":
    unittest.main()
