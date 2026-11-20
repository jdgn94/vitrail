"""Wallpaper effects: the ImageMagick recipes and their cache."""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

from test_colors import THEME_JSON
from vitrail import effects, prefs, wallpaper

ROOT = Path(__file__).resolve().parent.parent
NAMES = [
    "none",
    "ascii",
    "b&w",
    "blur",
    "charcoal",
    "dots",
    "edge",
    "emboss",
    "raise",
    "sunken",
    "negate",
    "paint",
    "pointillism",
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
    def test_the_twenty_effects_are_all_there_in_order(self) -> None:
        self.assertEqual(list(effects.NAMES), NAMES)

    def test_every_effect_is_either_a_recipe_or_a_renderer(self) -> None:
        self.assertEqual(set(effects.RECIPES) | set(effects.STYLED), set(NAMES))
        self.assertEqual(set(effects.RECIPES) & set(effects.STYLED), set())

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

    def test_the_qml_detail_lists_match_the_python_ones(self) -> None:
        text = (ROOT / "bar" / "effects.js").read_text(encoding="utf-8")
        detailed = re.findall(r'"([^"]+)"', text.split("DETAILED =", 1)[1].split("]", 1)[0])
        self.assertEqual(detailed, list(effects.DETAILED))
        details = re.findall(r'"([^"]+)"', text.split("DETAILS =", 1)[1].split("]", 1)[0])
        self.assertEqual(details, list(effects.DETAILS))

    def test_only_images_take_an_effect(self) -> None:
        for name in ("a.PNG", "a.jpg", "a.jpeg", "a.webp", "a.bmp"):
            self.assertTrue(effects.is_image(name), name)
        for name in ("a.mp4", "a.webm", "notes.txt"):
            self.assertFalse(effects.is_image(name), name)

    def test_the_bar_draws_a_stable_copy_per_screen(self) -> None:
        self.assertEqual(effects.shown(Path("/cache")).name, "wallpaper-effect.png")
        self.assertEqual(effects.shown(Path("/cache"), "DP-1").name, "wallpaper-effect-DP-1.png")
        self.assertEqual(effects.shown(Path("/cache"), "A/B").name, "wallpaper-effect-A_B.png")


class StyleTests(unittest.TestCase):
    """The styles that are drawn rather than handed to magick as a recipe, and
    the ones whose picture depends on the light/dark mode or the detail."""

    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.cache = self.root / "cache"
        self.source = self.root / "wall.png"
        self.source.write_bytes(b"pixels")
        self.calls: list[list[str]] = []

    def fake_run(self, argv, **_kwargs):
        self.calls.append(argv)
        if argv[0] == "fc-match":
            return SimpleNamespace(returncode=0, stdout="Mono" if "%{family}" in argv else "/fonts/mono.ttf", stderr="")
        if argv[0] == "magick":
            if "identify" in argv:
                return SimpleNamespace(returncode=0, stdout="96 64", stderr="")
            if argv[-1] in ("txt:-", "info:"):
                return SimpleNamespace(returncode=0, stdout="", stderr="")
        Path(argv[-1]).write_bytes(b"effect")
        return SimpleNamespace(returncode=0, stdout="", stderr="")

    def test_charcoal_turns_white_on_black_in_dark_mode(self) -> None:
        target = self.root / "out.png"
        effects.apply(self.source, "charcoal", target, run=self.fake_run, mode="dark")
        self.assertIn("-negate", self.calls[0])
        effects.apply(self.source, "charcoal", target, run=self.fake_run, mode="light")
        self.assertNotIn("-negate", self.calls[-1])

    def test_only_the_styles_that_depend_on_the_mode_change_with_it(self) -> None:
        self.assertIn("charcoal", effects.MODED)
        for name in effects.NAMES:
            if name == "none":
                continue
            with self.subTest(effect=name):
                dark = effects.cached(self.source, name, self.cache, mode="dark")
                light = effects.cached(self.source, name, self.cache, mode="light")
                self.assertEqual(name in effects.MODED, dark != light)

    def test_the_cache_names_the_mode_and_the_detail(self) -> None:
        dots = effects.cached(self.source, "dots", self.cache, mode="dark", detail="bold")
        self.assertRegex(dots.name, r"^[0-9a-f]+-dots-bold-dark-v\d+\.png$")
        charcoal = effects.cached(self.source, "charcoal", self.cache, mode="dark")
        self.assertRegex(charcoal.name, r"^[0-9a-f]+-charcoal-dark\.png$")
        blur = effects.cached(self.source, "blur", self.cache, mode="dark", detail="bold")
        self.assertRegex(blur.name, r"^[0-9a-f]+-blur\.png$")

    def test_an_unknown_detail_reads_as_normal(self) -> None:
        self.assertEqual(
            effects.cached(self.source, "ascii", self.cache, detail="nope"),
            effects.cached(self.source, "ascii", self.cache),
        )

    def test_a_preview_of_a_style_is_cached_per_mode_and_detail(self) -> None:
        first = effects.preview(self.source, "dots", self.cache, run=self.fake_run, mode="dark", detail="bold")
        self.assertRegex(first.name, r"^[0-9a-f]+-dots-bold-dark-v\d+\.png$")
        self.assertTrue(first.exists())
        calls = len(self.calls)
        effects.preview(self.source, "dots", self.cache, run=self.fake_run, mode="dark", detail="bold")
        self.assertEqual(len(self.calls), calls)
        self.assertNotEqual(
            effects.preview(self.source, "dots", self.cache, run=self.fake_run, mode="light", detail="bold"),
            first,
        )


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


class PreviewTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.cache = Path(self.tmp.name) / "cache"
        self.source = Path(self.tmp.name) / "wall.png"
        self.source.write_bytes(b"pixels")
        self.calls: list[list[str]] = []

    def fake_run(self, argv, **_kwargs):
        self.calls.append(argv)
        if argv[0] == "fc-match":
            return SimpleNamespace(returncode=0, stdout="Mono" if "%{family}" in argv else "/fonts/mono.ttf")
        if argv[0] == "magick":
            if "identify" in argv:
                return SimpleNamespace(returncode=0, stdout="96 64")
            if argv[-1] in ("txt:-", "info:"):
                return SimpleNamespace(returncode=0, stdout="")
        Path(argv[-1]).write_bytes(b"preview")
        return SimpleNamespace(returncode=0)

    def test_a_preview_is_a_small_copy_cached_by_picture_and_effect(self) -> None:
        first = effects.preview(self.source, "blur", self.cache, run=self.fake_run)
        self.assertEqual(first.parent, self.cache / "previews" / "derived")
        self.assertRegex(first.name, r"^[0-9a-f]+-blur\.png$")
        self.assertIn("-resize", self.calls[0])
        effects.preview(self.source, "blur", self.cache, run=self.fake_run)
        self.assertEqual(len(self.calls), 1)

    def test_the_original_also_gets_a_preview(self) -> None:
        target = effects.preview(self.source, "none", self.cache, run=self.fake_run)
        self.assertEqual(self.calls[0], ["magick", str(self.source), "-resize", "320x", str(target)])

    def test_a_preview_only_exists_for_a_picture(self) -> None:
        video = self.source.with_suffix(".mp4")
        video.write_bytes(b"loop")
        self.assertIsNone(effects.preview(video, "blur", self.cache, run=self.fake_run))
        self.assertIsNone(effects.preview(self.cache / "gone.png", "blur", self.cache, run=self.fake_run))
        self.assertEqual(self.calls, [])

    def test_publishing_fills_one_plain_name_per_effect(self) -> None:
        self.assertTrue(effects.publish(self.source, self.cache, run=self.fake_run))
        folder = self.cache / "previews" / "global"
        for name in effects.NAMES:
            self.assertTrue((folder / f"{name}.png").is_file(), name)

    def test_publishing_nothing_for_a_file_that_is_not_a_picture(self) -> None:
        video = self.source.with_suffix(".mp4")
        video.write_bytes(b"loop")
        self.assertFalse(effects.publish(video, self.cache, run=self.fake_run))
        self.assertFalse((self.cache / "previews" / "global").exists())


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
        if command[0] == "fc-match":
            return SimpleNamespace(
                returncode=0, stdout="Mono" if "%{family}" in command else "/fonts/mono.ttf", stderr=""
            )
        if command[0] == "magick":
            if "identify" in command:
                return SimpleNamespace(returncode=0, stdout="96 64", stderr="")
            if command[-1] in ("txt:-", "info:"):
                return SimpleNamespace(returncode=0, stdout="", stderr="")
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

    def test_the_stamp_includes_the_mode(self) -> None:
        self.assertIsNotNone(self.apply("wallpaperEffect=charcoal\nappearance=dark\n"))
        self.assertIsNone(wallpaper.apply(self.config, self.cache, self.fake_run))
        self.assertIsNotNone(self.apply("wallpaperEffect=charcoal\nappearance=light\n"))

    def test_the_stamp_includes_the_detail(self) -> None:
        self.assertIsNotNone(self.apply("wallpaperEffect=dots\n"))
        self.assertIsNone(wallpaper.apply(self.config, self.cache, self.fake_run))
        self.assertIsNotNone(self.apply("wallpaperEffect=dots\nwallpaperEffectDetail=bold\n"))

    def test_a_drawn_style_leaves_the_palette_to_the_original_picture(self) -> None:
        self.assertIsNotNone(self.apply("wallpaperEffect=dots\n"))
        self.assertEqual(self.derived(), self.image)
        self.assertTrue((self.cache / "wallpaper-effect.png").exists())

    def test_a_recipe_still_leaves_the_palette_to_the_derived_file(self) -> None:
        self.assertIsNotNone(self.apply("wallpaperEffect=blur\n"))
        self.assertEqual(self.derived().parent, self.cache / "effects")

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

    def test_each_output_with_its_own_picture_gets_the_global_effect(self) -> None:
        other = self.root / "other.png"
        other.write_bytes(b"other pixels")
        monitors = json.dumps(
            {
                "DP-1": {"wallpaper": str(other)},
                "eDP-1": {},
            }
        )
        self.apply(f"wallpaperEffect=sepia\nwallpaperMonitors={monitors}\n")
        self.assertTrue((self.cache / "wallpaper-effect.png").exists())
        self.assertTrue((self.cache / "wallpaper-effect-DP-1.png").exists())
        self.assertFalse((self.cache / "wallpaper-effect-eDP-1.png").exists())

    def test_an_output_picture_is_themed_even_without_a_global_change(self) -> None:
        self.assertIsNotNone(self.apply("wallpaperEffect=blur\n"))
        self.assertIsNone(wallpaper.apply(self.config, self.cache, self.fake_run))
        other = self.root / "other.png"
        other.write_bytes(b"other pixels")
        monitors = json.dumps({"DP-1": {"wallpaper": str(other)}})
        self.assertIsNotNone(self.apply(f"wallpaperEffect=blur\nwallpaperMonitors={monitors}\n"))
        self.assertTrue((self.cache / "wallpaper-effect-DP-1.png").exists())

    def test_a_missing_shown_copy_is_written_again(self) -> None:
        self.assertIsNotNone(self.apply("wallpaperEffect=blur\n"))
        (self.cache / "wallpaper-effect.png").unlink()
        self.assertIsNotNone(self.apply("wallpaperEffect=blur\n"))
        self.assertTrue((self.cache / "wallpaper-effect.png").exists())

    def test_every_effect_has_a_preview_of_the_picture(self) -> None:
        self.apply()
        folder = self.cache / "previews" / "global"
        for name in effects.NAMES:
            self.assertTrue((folder / f"{name}.png").is_file(), name)

    def test_the_previews_show_the_global_picture(self) -> None:
        other = self.root / "other.png"
        other.write_bytes(b"other pixels")
        monitors = json.dumps({"DP-1": {"wallpaper": str(other)}})
        self.apply(f"wallpaperEffect=sepia\nwallpaperMonitors={monitors}\n")
        folder = self.cache / "previews" / "global"
        self.assertTrue((folder / "sepia.png").is_file())
        self.assertFalse((self.cache / "previews" / "DP-1").exists())

    def test_a_refused_recipe_still_writes_the_shown_copy(self) -> None:
        def picky(command, **_kwargs):
            if command[0] == "magick" and "identify" in command:
                return SimpleNamespace(returncode=0, stdout="96 64", stderr="")
            if command[0] == "magick" and "-charcoal" in command:
                return SimpleNamespace(returncode=1, stdout="", stderr="")
            if command[0] == "magick":
                if command[-1] in ("txt:-", "info:"):
                    return SimpleNamespace(returncode=0, stdout="", stderr="")
                Path(command[-1]).write_bytes(b"effect")
            if command[0] == "fc-match":
                return SimpleNamespace(returncode=0, stdout="Mono" if "%{family}" in command else "/fonts/mono.ttf")
            return SimpleNamespace(returncode=0, stdout=json.dumps(THEME_JSON), stderr="")

        put(self.config, f"[wallpaper]\nwallpaper={self.image}\nwallpaperEffect=charcoal\n")
        self.assertIsNotNone(wallpaper.apply(self.config, self.cache, picky, say=self.said.append))
        # The screen keeps the picture instead of pointing at a file magick
        # never wrote.
        self.assertEqual((self.cache / "wallpaper-effect.png").read_bytes(), self.image.read_bytes())
        self.assertTrue(any("charcoal" in line for line in self.said))


@unittest.skipUnless(shutil.which("magick"), "ImageMagick is not installed")
class RecipeRunsTests(unittest.TestCase):
    """Every recipe must really produce a file: one magick refusal left a
    monitor blank (the bar points at the copy the recipe should have written)."""

    def test_every_effect_runs(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "picture.png"
            subprocess.run(["magick", "-size", "96x64", "gradient:", str(source)], check=True)
            for name in effects.NAMES:
                if name == "none":
                    continue
                with self.subTest(effect=name):
                    target = root / f"{name}.png"
                    effects.apply(source, name, target)
                    self.assertTrue(target.exists(), name)


if __name__ == "__main__":
    unittest.main()
