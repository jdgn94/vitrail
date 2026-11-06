"""Wallpaper folders, selection and rotation."""

from __future__ import annotations

import json
import random
import shutil
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

from test_colors import THEME_JSON
from vitrail import cli, media, prefs, wallpaper


def passthrough(source: Path, kind: str, work: Path, **_kwargs) -> media.Result:
    """An optimizer that keeps every file as it is (no ffmpeg / magick here)."""
    copy = work / source.name
    copy.write_bytes(source.read_bytes())
    return media.Result(copy, media.Report(source.name, kind, 1, 1, "x", "", "original"))


def put(config: Path, text: str) -> None:
    """Stores the key=value lines of `text` the way the app does: by key."""
    for line in text.splitlines():
        if "=" in line:
            key, _, value = line.partition("=")
            prefs.write_pref(config, key, value)


class KindTests(unittest.TestCase):
    def test_kind_follows_the_extension(self) -> None:
        self.assertEqual(wallpaper.kind_of("/w/images/a.JPG"), "image")
        self.assertEqual(wallpaper.kind_of("/w/videos/rain.webm"), "video")
        self.assertEqual(wallpaper.kind_of("/w/incoming/loop.GIF"), "video")
        self.assertIsNone(wallpaper.kind_of("/w/svg/waves.svg"))
        self.assertIsNone(wallpaper.kind_of("/w/notes.txt"))

    def test_requests_drop_their_nonce(self) -> None:
        self.assertEqual(wallpaper.request_paths("1730000000|/a.png|/b c.png"), ["/a.png", "/b c.png"])
        self.assertEqual(wallpaper.request_paths(""), [])

    def test_folders_are_created_per_kind(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            folders = wallpaper.ensure_folders(Path(tmp))
            self.assertEqual(set(folders), {"image", "video"})
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
        self.config = self.root / "config" / "vitrail"
        self.library = self.config / "wallpapers"

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def test_the_library_lives_in_the_config_folder(self) -> None:
        self.assertEqual(wallpaper.library({}, self.config), self.library)
        self.assertEqual(wallpaper.library({"wallpaperDir": "/elsewhere"}, self.config), Path("/elsewhere"))

    def test_imports_are_copied_into_their_kind_folder(self) -> None:
        photo = self.root / "photo.png"
        photo.write_bytes(b"png")
        clip = self.root / "clip.webm"
        clip.write_bytes(b"webm")
        notes = self.root / "notes.txt"
        notes.write_text("no")
        put(self.config, f"[appearance]\nwallpaperImport=17|{photo}|{clip}|{notes}\n")
        wallpaper.sync(self.config, passthrough)
        self.assertEqual((self.library / "images" / "photo.png").read_bytes(), b"png")
        self.assertTrue((self.library / "videos" / "clip.webm").exists())
        self.assertTrue(photo.exists(), "the original stays where it was")
        self.assertEqual(prefs.read_prefs(self.config)["wallpaperImport"], "")

    def test_an_import_never_overwrites(self) -> None:
        (self.library / "images").mkdir(parents=True)
        (self.library / "images" / "photo.png").write_bytes(b"old")
        photo = self.root / "photo.png"
        photo.write_bytes(b"new")
        put(self.config, f"[appearance]\nwallpaperImport=1|{photo}\n")
        wallpaper.sync(self.config, passthrough)
        self.assertEqual((self.library / "images" / "photo.png").read_bytes(), b"old")
        self.assertEqual((self.library / "images" / "photo-2.png").read_bytes(), b"new")

    def test_removal_only_deletes_inside_the_library(self) -> None:
        inside = self.library / "images" / "old.png"
        inside.parent.mkdir(parents=True)
        inside.write_bytes(b"png")
        outside = self.root / "keep.png"
        outside.write_bytes(b"png")
        put(self.config, f"[appearance]\nwallpaperRemove=9|{inside}|{outside}\n")
        wallpaper.sync(self.config)
        self.assertFalse(inside.exists())
        self.assertTrue(outside.exists())
        self.assertEqual(prefs.read_prefs(self.config)["wallpaperRemove"], "")


class SyncPruneTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.config = self.root / "vitrail"
        self.alive = self.root / "alive.png"
        self.alive.write_bytes(b"png")
        self.dead = self.root / "dead.png"
        self.legacy = self.root / "art.svg"
        self.legacy.write_text("<svg/>")

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def prefs(self, selection: list[Path], current: Path | str, extra: str = "") -> dict[str, str]:
        put(
            self.config,
            f"[appearance]\nwallpaperSelection={'|'.join(map(str, selection))}\nwallpaper={current}\n{extra}",
        )
        wallpaper.sync(self.config)
        return prefs.read_prefs(self.config)

    def test_missing_files_leave_the_selection(self) -> None:
        prefs = self.prefs([self.dead, self.alive], self.alive)
        self.assertEqual(prefs["wallpaperSelection"], str(self.alive))
        self.assertEqual(prefs["wallpaper"], str(self.alive))

    def test_a_missing_wallpaper_moves_to_the_first_remaining(self) -> None:
        prefs = self.prefs([self.dead, self.alive], self.dead)
        self.assertEqual(prefs["wallpaper"], str(self.alive))

    def test_nothing_left_clears_the_wallpaper(self) -> None:
        prefs = self.prefs([self.dead], self.dead)
        self.assertEqual(prefs["wallpaperSelection"], "")
        self.assertEqual(prefs["wallpaper"], "")

    def test_a_healthy_selection_is_untouched(self) -> None:
        before = f"[appearance]\nwallpaperSelection={self.alive}\nwallpaper={self.alive}\n"
        put(self.config, before)
        stored = (self.config / "wallpaper.ini").read_text(encoding="utf-8")
        wallpaper.sync(self.config)
        self.assertEqual((self.config / "wallpaper.ini").read_text(encoding="utf-8"), stored)

    def test_an_old_svg_selection_is_pruned(self) -> None:
        prefs = self.prefs([self.legacy, self.alive], self.alive)
        self.assertEqual(prefs["wallpaperSelection"], str(self.alive))
        self.assertEqual(prefs["wallpaper"], str(self.alive))

    def test_an_old_svg_wallpaper_is_cleared(self) -> None:
        prefs = self.prefs([self.legacy], self.legacy, "wallpaperType=svg\n")
        self.assertEqual(prefs["wallpaperSelection"], "")
        self.assertEqual(prefs["wallpaper"], "")
        self.assertEqual(prefs["wallpaperType"], "")


class ImportTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.folders = wallpaper.ensure_folders(self.root / "library")
        self.assets = self.root / "assets"
        self.assets.mkdir()

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def test_files_and_folders_land_in_their_kind_folder(self) -> None:
        (self.assets / "a.png").write_bytes(b"a")
        (self.assets / "b.webm").write_bytes(b"b")
        (self.assets / "notes.txt").write_text("no")
        added = wallpaper.import_paths(self.folders, [self.assets], passthrough)
        self.assertEqual({path.name for path in added}, {"a.png", "b.webm"})
        self.assertTrue((self.folders["image"] / "a.png").exists())
        self.assertTrue((self.folders["video"] / "b.webm").exists())

    def test_importing_twice_adds_nothing(self) -> None:
        (self.assets / "a.png").write_bytes(b"a")
        wallpaper.import_paths(self.folders, [self.assets], passthrough)
        self.assertEqual(wallpaper.import_paths(self.folders, [self.assets], passthrough), [])
        self.assertEqual(len(list(self.folders["image"].iterdir())), 1)

    def test_an_svg_is_not_a_wallpaper_and_copies_nothing(self) -> None:
        (self.assets / "art.svg").write_text('<svg><rect fill="#3366cc"/></svg>')
        self.assertEqual(wallpaper.import_paths(self.folders, [self.assets], passthrough), [])
        self.assertFalse((self.root / "library" / "svg").exists())
        self.assertEqual(list(self.root.rglob("*.svg")), [self.assets / "art.svg"])

    def test_identical_content_under_another_name_is_skipped(self) -> None:
        (self.assets / "a.png").write_bytes(b"same")
        (self.assets / "copy.png").write_bytes(b"same")
        self.assertEqual(len(wallpaper.import_paths(self.folders, [self.assets], passthrough)), 1)

    def test_different_content_with_the_same_name_gets_a_free_name(self) -> None:
        (self.folders["image"] / "a.png").write_bytes(b"old")
        (self.assets / "a.png").write_bytes(b"new")
        wallpaper.import_paths(self.folders, [self.assets], passthrough)
        self.assertEqual((self.folders["image"] / "a-2.png").read_bytes(), b"new")
        self.assertEqual((self.folders["image"] / "a.png").read_bytes(), b"old")

    def test_an_imported_source_is_not_optimized_again(self) -> None:
        (self.assets / "a.png").write_bytes(b"a")
        calls: list[str] = []

        def counting(source, kind, work, **kwargs):
            calls.append(source.name)
            return passthrough(source, kind, work, **kwargs)

        wallpaper.import_paths(self.folders, [self.assets], counting)
        wallpaper.import_paths(self.folders, [self.assets], counting)
        self.assertEqual(calls, ["a.png"])

    def test_the_optimized_file_is_what_lands_in_the_library(self) -> None:
        (self.assets / "a.png").write_bytes(b"big")

        def shrink(source, kind, work, **_kwargs):
            out = work / "out.webp"
            out.write_bytes(b"small")
            return media.Result(out, media.Report(source.name, kind, 3, 5, "webp", "", "webp"))

        said: list[str] = []
        (added,) = wallpaper.import_paths(self.folders, [self.assets], shrink, said.append)
        self.assertEqual((added.name, added.read_bytes()), ("a.webp", b"small"))
        self.assertTrue(any("a.png" in line for line in said))

    def test_a_broken_file_is_never_copied(self) -> None:
        (self.assets / "bad.mp4").write_bytes(b"junk")

        def reject(source, kind, work, **_kwargs):
            return media.Result(
                None, media.Report(source.name, kind, 4, 0, "", "", "rejected", note="the video does not decode")
            )

        said: list[str] = []
        self.assertEqual(wallpaper.import_paths(self.folders, [self.assets], reject, said.append), [])
        self.assertEqual(list(self.folders["video"].iterdir()), [])
        self.assertIn("rejected", said[0])

    def test_a_missing_folder_is_skipped_quietly(self) -> None:
        self.assertEqual(wallpaper.import_paths(self.folders, [self.root / "nope"]), [])


class ForceTests(unittest.TestCase):
    PALETTE = THEME_JSON

    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.config = self.root / "vitrail"
        self.image = self.root / "w.png"
        self.image.write_bytes(b"png")
        put(self.config, f"[appearance]\nwallpaper={self.image}\n")
        self.calls = 0

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def run_matugen(self, *_args, **_kwargs):
        self.calls += 1
        return SimpleNamespace(returncode=0, stdout=json.dumps(self.PALETTE), stderr="")

    def apply(self, **kwargs):
        return wallpaper.apply(self.config, self.root / "cache", self.run_matugen, **kwargs)

    def test_the_stamp_skips_a_repeat(self) -> None:
        self.assertEqual(self.apply(), str(self.image))
        calls = self.calls
        self.assertIsNone(self.apply())
        self.assertEqual(self.calls, calls)

    def test_force_extracts_again(self) -> None:
        self.apply()
        calls = self.calls
        self.assertEqual(self.apply(force=True), str(self.image))
        self.assertGreater(self.calls, calls)

    def test_the_cli_takes_a_force_flag(self) -> None:
        args = cli._parser().parse_args(["wallpaper", "apply", "--force"])
        self.assertTrue(args.force)
        self.assertFalse(cli._parser().parse_args(["wallpaper", "apply"]).force)

    def test_the_cli_takes_paths_to_import(self) -> None:
        args = cli._parser().parse_args(["wallpaper", "import", "a", "b"])
        self.assertEqual(args.paths, ["a", "b"])


class PickTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.config = self.root / "vitrail"
        self.first = self.root / "a.png"
        self.second = self.root / "b.png"
        self.clip = self.root / "c.webm"
        for path in (self.first, self.second):
            path.write_bytes(b"png")
        self.clip.write_bytes(b"webm")
        self.legacy = self.root / "art.svg"
        self.legacy.write_text("<svg/>")
        self.notes = self.root / "notes.txt"
        self.notes.write_text("no")

    def test_picking_shows_it_and_starts_the_selection(self) -> None:
        self.assertEqual(wallpaper.pick(self.config, str(self.first)), str(self.first))
        stored = prefs.read_prefs(self.config)
        self.assertEqual(stored["wallpaper"], str(self.first))
        self.assertEqual(stored["wallpaperSelection"], str(self.first))
        self.assertEqual(stored["wallpaperType"], "image")

    def test_picking_another_of_the_kind_joins_the_selection(self) -> None:
        wallpaper.pick(self.config, str(self.first))
        wallpaper.pick(self.config, str(self.second))
        stored = prefs.read_prefs(self.config)
        self.assertEqual(stored["wallpaper"], str(self.second))
        self.assertEqual(wallpaper.parse_selection(stored["wallpaperSelection"]), [str(self.first), str(self.second)])

    def test_another_kind_starts_over(self) -> None:
        wallpaper.pick(self.config, str(self.first))
        wallpaper.pick(self.config, str(self.clip))
        stored = prefs.read_prefs(self.config)
        self.assertEqual(stored["wallpaperSelection"], str(self.clip))
        self.assertEqual(stored["wallpaperType"], "video")

    def test_something_that_is_not_a_wallpaper_is_refused(self) -> None:
        self.assertIsNone(wallpaper.pick(self.config, str(self.notes)))
        self.assertIsNone(wallpaper.pick(self.config, str(self.root / "gone.png")))
        self.assertIsNone(wallpaper.pick(self.config, str(self.legacy)))
        self.assertEqual(prefs.read_prefs(self.config).get("wallpaper", ""), "")

    def test_the_cli_takes_the_pick_action(self) -> None:
        args = cli._parser().parse_args(["wallpaper", "pick", "a.png"])
        self.assertEqual((args.action, args.paths), ("pick", ["a.png"]))


class SystemColorTests(unittest.TestCase):
    def test_decision_table(self) -> None:
        table = [
            # fixed system colour -> seed (None: extract from the image)
            ("", None),
            ("#ff0000", "#ff0000"),
        ]
        for fixed, expected in table:
            self.assertEqual(wallpaper.palette_seed(fixed), expected, fixed)

    def test_the_old_seed_pref_counts_as_the_system_colour(self) -> None:
        self.assertEqual(wallpaper.system_color({"wallpaperSeed": "#112233"}), "#112233")
        self.assertEqual(wallpaper.system_color({"wallpaperSeed": "#112233", "systemColor": "#445566"}), "#445566")
        self.assertEqual(wallpaper.system_color({}), "")


class SystemColorApplyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.config = self.root / "vitrail"
        self.media = {"image": self.root / "w.png", "video": self.root / "w.webm"}
        for path in self.media.values():
            path.write_bytes(b"x")
        self.commands: list[list[str]] = []

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def run_tools(self, command, **_kwargs):
        self.commands.append(command)
        return SimpleNamespace(returncode=0, stdout=json.dumps(THEME_JSON), stderr="")

    def apply(self, kind: str, extra: str = "") -> str | None:
        shutil.rmtree(self.config, ignore_errors=True)
        put(self.config, f"[appearance]\nwallpaper={self.media[kind]}\n{extra}")
        self.commands.clear()
        return wallpaper.apply(self.config, self.root / "cache", self.run_tools)

    def matugen(self) -> list[str]:
        return next(command for command in self.commands if command[0] == "matugen")

    def test_a_fixed_colour_drives_images_and_videos_too(self) -> None:
        for kind in ("image", "video"):
            self.apply(kind, "systemColor=#ff0000\n")
            self.assertEqual(self.matugen()[1:4], ["color", "hex", "#ff0000"], kind)
        self.assertFalse(any(command[0] == "ffmpeg" for command in self.commands), "no frame is needed")

    def test_automatic_extracts_from_the_image_or_a_video_frame(self) -> None:
        self.apply("image")
        self.assertEqual(self.matugen()[1], "image")
        self.apply("video")
        self.assertEqual(self.commands[0][0], "ffmpeg")
        self.assertEqual(self.matugen()[1], "image")

    def test_the_old_seed_pref_still_works(self) -> None:
        self.apply("image", "wallpaperSeed=#00ff00\n")
        self.assertEqual(self.matugen()[3], "#00ff00")

    def test_changing_the_colour_regenerates_every_kind(self) -> None:
        for kind in ("image", "video"):
            self.assertIsNotNone(self.apply(kind))
            self.assertIsNone(wallpaper.apply(self.config, self.root / "cache", self.run_tools), kind)
            self.assertIsNotNone(self.apply(kind, "systemColor=#ff0000\n"), kind)

    def test_sync_migrates_the_old_pref(self) -> None:
        put(self.config, "[appearance]\nwallpaperSeed=#112233\nradius=14\n")
        wallpaper.sync(self.config)
        text = (self.config / "wallpaper.ini").read_text(encoding="utf-8")
        self.assertNotIn("wallpaperSeed", text)
        self.assertEqual(prefs.read_prefs(self.config)["systemColor"], "#112233")
        self.assertIn("radius=14", (self.config / "appearance.ini").read_text(encoding="utf-8"))

    def test_the_migration_keeps_an_existing_system_colour(self) -> None:
        put(self.config, "[appearance]\nwallpaperSeed=#112233\nsystemColor=#445566\n")
        wallpaper.sync(self.config)
        self.assertEqual(prefs.read_prefs(self.config)["systemColor"], "#445566")
        self.assertNotIn("wallpaperSeed", (self.config / "wallpaper.ini").read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
