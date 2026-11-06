"""Wallpaper effects: the ImageMagick recipes and their cache."""

from __future__ import annotations

import json
import re
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

from test_colors import THEME_JSON
from vitrail import effects, prefs, wallpaper

ROOT = Path(__file__).resolve().parent.parent
NAMES = [
    "none",
    "b&w",
    "blur",
    "charcoal",
    "edge",
    "emboss",
    "raise",
    "sunken",
    "negate",
    "paint",
    "posterize",
    "polaroid",
    "sepia",
    "solarize",
    "sharpen",
    "vignette",
    "vignette-black",
    "zoomed",
]


def put(config: Path, text: str) -> None:
    for line in text.splitlines():
        if "=" in line:
            key, _, value = line.partition("=")
            prefs.write_pref(config, key, value)


class RecipeTests(unittest.TestCase):
    def test_the_eighteen_recipes_are_all_there(self) -> None:
        self.assertEqual(list(effects.RECIPES), NAMES)

    def test_every_recipe_is_an_argument_list_for_magick(self) -> None:
        for name, recipe in effects.RECIPES.items():
            with self.subTest(effect=name):
                self.assertIsInstance(recipe, list)
                self.assertTrue(all(isinstance(argument, str) for argument in recipe))
        self.assertEqual(effects.RECIPES["none"], [])

    def test_no_recipe_is_a_shell_command(self) -> None:
        for name, recipe in effects.RECIPES.items():
            with self.subTest(effect=name):
                for argument in recipe:
                    for forbidden in (";", "&&", "||", "`", "$(", "|"):
                        self.assertNotIn(forbidden, argument)

    def test_the_qml_list_matches_the_recipes(self) -> None:
        text = (ROOT / "bar" / "effects.js").read_text(encoding="utf-8")
        names = re.findall(r'"([^"]+)"', text.split("NAMES =", 1)[1].split("]", 1)[0])
        self.assertEqual(names, NAMES)

    def test_only_images_take_an_effect(self) -> None:
        for name in ("a.PNG", "a.jpg", "a.jpeg", "a.webp", "a.bmp"):
            self.assertTrue(effects.is_image(name), name)
        for name in ("a.mp4", "a.webm", "notes.txt"):
            self.assertFalse(effects.is_image(name), name)

    def test_the_bar_draws_a_stable_copy_per_screen(self) -> None:
        self.assertEqual(effects.shown(Path("/cache")).name, "wallpaper-effect.png")
        self.assertEqual(effects.shown(Path("/cache"), "DP-1").name, "wallpaper-effect-DP-1.png")
        self.assertEqual(effects.shown(Path("/cache"), "A/B").name, "wallpaper-effect-A_B.png")


class ApplyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.source = self.root / "wall.png"
        self.source.write_bytes(b"pixels")
        self.calls: list[list[str]] = []

    def fake_run(self, argv, **_kwargs):
        self.calls.append(argv)
        if argv[0] == "magick":
            Path(argv[-1]).write_bytes(b"effect")
        return SimpleNamespace(returncode=0)

    def test_an_effect_runs_magick_with_the_source_and_the_target(self) -> None:
        target = self.root / "out.png"
        self.assertEqual(effects.apply(self.source, "blur", target, run=self.fake_run), target)
        self.assertEqual(self.calls, [["magick", str(self.source), *effects.RECIPES["blur"], str(target)]])
        self.assertTrue(target.exists())

    def test_none_and_unknown_effects_show_the_original(self) -> None:
        target = self.root / "out.png"
        for name in ("none", "", "nope"):
            with self.subTest(effect=name):
                self.assertEqual(effects.apply(self.source, name, target, run=self.fake_run), self.source)
        self.assertEqual(self.calls, [])

    def test_nothing_is_ever_evaluated_by_a_shell(self) -> None:
        effects.apply(self.source, "sepia", self.root / "out.png", run=self.fake_run)
        self.assertEqual(self.calls[0][0], "magick")
        self.assertNotIn("sh", self.calls[0])


class DeriveTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.cache = Path(self.tmp.name) / "cache"
        self.source = Path(self.tmp.name) / "wall.png"
        self.source.write_bytes(b"pixels")
        self.calls: list[list[str]] = []

    def fake_run(self, argv, **_kwargs):
        self.calls.append(argv)
        Path(argv[-1]).write_bytes(b"effect")
        return SimpleNamespace(returncode=0)

    def test_the_derived_file_is_cached_under_its_hash_and_effect(self) -> None:
        first = effects.derive(self.source, "blur", self.cache, run=self.fake_run)
        self.assertEqual(first.parent, self.cache / "effects")
        self.assertRegex(first.name, r"^[0-9a-f]+-blur\.png$")
        self.assertTrue(first.exists())
        self.assertEqual(len(self.calls), 1)

    def test_a_second_request_does_not_run_magick_again(self) -> None:
        effects.derive(self.source, "blur", self.cache, run=self.fake_run)
        self.assertEqual(effects.derive(self.source, "blur", self.cache, run=self.fake_run).exists(), True)
        self.assertEqual(len(self.calls), 1)

    def test_each_effect_and_each_picture_gets_its_own_file(self) -> None:
        blur = effects.derive(self.source, "blur", self.cache, run=self.fake_run)
        sepia = effects.derive(self.source, "sepia", self.cache, run=self.fake_run)
        self.assertNotEqual(blur, sepia)
        self.source.write_bytes(b"other pixels")
        self.assertNotEqual(effects.derive(self.source, "blur", self.cache, run=self.fake_run), blur)

    def test_none_and_unknown_effects_keep_the_original(self) -> None:
        for name in ("none", "", "nope"):
            self.assertEqual(effects.derive(self.source, name, self.cache, run=self.fake_run), self.source)
        self.assertEqual(self.calls, [])

    def test_other_kinds_are_left_alone(self) -> None:
        video = self.source.with_suffix(".mp4")
        video.write_bytes(b"loop")
        said: list[str] = []
        self.assertEqual(effects.derive(video, "blur", self.cache, run=self.fake_run, say=said.append), video)
        self.assertEqual(self.calls, [])
        self.assertEqual(len(said), 1)


class WallpaperApplyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.config = self.root / "vitrail"
        self.cache = self.root / "cache"
        self.image = self.root / "w.png"
        self.image.write_bytes(b"pixels")
        self.commands: list[list[str]] = []
        self.said: list[str] = []

    def fake_run(self, command, **_kwargs):
        self.commands.append(command)
        if command[0] == "magick":
            Path(command[-1]).write_bytes(b"effect")
            return SimpleNamespace(returncode=0, stdout="", stderr="")
        return SimpleNamespace(returncode=0, stdout=json.dumps(THEME_JSON), stderr="")

    def apply(self, extra: str = ""):
        put(self.config, f"[wallpaper]\nwallpaper={self.image}\n{extra}")
        self.commands.clear()
        return wallpaper.apply(self.config, self.cache, self.fake_run, say=self.said.append)

    def derived(self) -> Path:
        matugen = next(command for command in self.commands if command[0] == "matugen")
        return Path(matugen[2])

    def test_the_palette_comes_from_the_derived_image(self) -> None:
        self.assertIsNotNone(self.apply("wallpaperEffect=blur\n"))
        self.assertEqual(self.commands[0][0], "magick")
        self.assertEqual(self.derived().parent, self.cache / "effects")
        self.assertTrue((self.cache / "wallpaper-effect.png").exists())

    def test_the_stamp_includes_the_effect(self) -> None:
        self.assertIsNotNone(self.apply("wallpaperEffect=blur\n"))
        self.assertIsNone(wallpaper.apply(self.config, self.cache, self.fake_run))
        self.assertIsNotNone(self.apply("wallpaperEffect=sepia\n"))

    def test_an_effect_on_a_kind_that_cannot_take_it_is_skipped_with_a_notice(self) -> None:
        video = self.root / "w.webm"
        video.write_bytes(b"loop")
        put(self.config, f"[wallpaper]\nwallpaper={video}\nwallpaperEffect=blur\n")
        self.commands.clear()
        self.assertIsNotNone(wallpaper.apply(self.config, self.cache, self.fake_run, say=self.said.append))
        self.assertEqual([command for command in self.commands if command[0] == "magick"], [])
        self.assertEqual(len(self.said), 1)
        self.assertIn("image", self.said[0])

    def test_nothing_is_said_when_no_effect_was_asked_for(self) -> None:
        self.assertIsNotNone(self.apply())
        self.assertEqual(self.said, [])

    def test_a_per_monitor_effect_gets_its_own_shown_copy(self) -> None:
        other = self.root / "other.png"
        other.write_bytes(b"other pixels")
        monitors = json.dumps(
            {
                "DP-1": {"wallpaper": str(other), "effect": "sepia"},
                "HDMI-A-1": {"effect": "negate"},
                "eDP-1": {"wallpaper": str(other)},
            }
        )
        self.apply(f"wallpaperMonitors={monitors}\n")
        self.assertTrue((self.cache / "wallpaper-effect-DP-1.png").exists())
        self.assertTrue((self.cache / "wallpaper-effect-HDMI-A-1.png").exists())
        self.assertFalse((self.cache / "wallpaper-effect-eDP-1.png").exists())


if __name__ == "__main__":
    unittest.main()
