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
