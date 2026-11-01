"""Preferences: one file per area, found by key through vitrail/prefs.map."""

from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from vitrail import cli, prefs

FIXTURE = Path(__file__).parent / "fixtures" / "settings.ini"


class Base(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.config = Path(self.tmp.name) / "vitrail"

    def read(self, name: str) -> str:
        return (self.config / f"{name}.ini").read_text(encoding="utf-8")


class MapTests(unittest.TestCase):
    def test_a_key_is_found_in_its_area_file(self) -> None:
        self.assertEqual(prefs.file_of("radius"), "appearance")
        self.assertEqual(prefs.file_of("wallpaperSelection"), "wallpaper")
        self.assertEqual(prefs.file_of("keyboardLayouts"), "input")

    def test_unknown_keys_go_to_misc(self) -> None:
        self.assertEqual(prefs.file_of("somethingNew"), "misc")

    def test_a_duplicated_key_is_rejected(self) -> None:
        with self.assertRaises(ValueError):
            prefs.parse_map("bar radius\nappearance radius\n")

    def test_comments_and_blank_lines_are_ignored(self) -> None:
        self.assertEqual(prefs.parse_map("# note\n\nbar barSize\n"), [("bar", "barSize")])


class ReadWriteTests(Base):
    def test_a_write_lands_in_the_file_of_its_area(self) -> None:
        prefs.write_pref(self.config, "radius", "9")
        prefs.write_pref(self.config, "barSize", "40")
        self.assertIn("[appearance]", self.read("appearance"))
        self.assertIn("radius=9", self.read("appearance"))
        self.assertIn("barSize=40", self.read("bar"))
        self.assertNotIn("barSize", self.read("appearance"))

    def test_reading_merges_every_file(self) -> None:
        prefs.write_pref(self.config, "radius", "9")
        prefs.write_pref(self.config, "barSize", "40")
        prefs.write_pref(self.config, "unmapped", "x")
        self.assertEqual(
            prefs.read_prefs(self.config), {"radius": "9", "barSize": "40", "unmapped": "x"})

    def test_missing_files_read_as_empty(self) -> None:
        self.assertEqual(prefs.read_prefs(self.config), {})

    def test_a_json_value_round_trips_on_one_line(self) -> None:
        prefs.write_pref(self.config, "quickNotes", '["uno","dos"]')
        self.assertEqual(prefs.read_prefs(self.config)["quickNotes"], '["uno","dos"]')

    def test_a_write_replaces_in_place_and_keeps_the_rest(self) -> None:
        self.config.mkdir(parents=True)
        (self.config / "appearance.ini").write_text(
            "[appearance]\nradius=14\nspacing=12\n", encoding="utf-8")
        prefs.write_pref(self.config, "radius", "9")
        self.assertEqual(self.read("appearance"), "[appearance]\nradius=9\nspacing=12\n")

    def test_values_keep_their_equals_signs_and_case(self) -> None:
        prefs.write_pref(self.config, "launcherBangs", "g*Google*https://x/?q=%s")
        self.assertEqual(
            prefs.read_prefs(self.config)["launcherBangs"], "g*Google*https://x/?q=%s")

    def test_remove_drops_only_that_key(self) -> None:
        prefs.write_pref(self.config, "wallpaperSeed", "#112233")
        prefs.write_pref(self.config, "wallpaper", "/a.png")
        prefs.remove_pref(self.config, "wallpaperSeed")
        self.assertEqual(prefs.read_prefs(self.config), {"wallpaper": "/a.png"})

    def test_the_write_is_atomic(self) -> None:
        prefs.write_pref(self.config, "radius", "9")
        self.assertEqual([p.name for p in self.config.iterdir()], ["appearance.ini"])


class RangeTests(Base):
    def test_the_clipboard_maximum_accepts_its_range(self) -> None:
        prefs.write_pref(self.config, "clipboardMax", "50")
        prefs.write_pref(self.config, "clipboardMax", "1000")
        self.assertEqual(prefs.read_prefs(self.config)["clipboardMax"], "1000")

    def test_the_clipboard_maximum_rejects_out_of_range(self) -> None:
        for value in ("49", "1001", "0", "-5"):
            with self.assertRaises(ValueError):
                prefs.write_pref(self.config, "clipboardMax", value)

    def test_the_clipboard_maximum_rejects_a_non_number(self) -> None:
        with self.assertRaises(ValueError):
            prefs.write_pref(self.config, "clipboardMax", "many")


class SetPrefTests(Base):
    def test_sets_a_choice_in_its_file(self) -> None:
        prefs.set_pref("appearance", "dark", self.config)
        self.assertIn("appearance=dark", self.read("appearance"))

    def test_replaces_an_existing_value(self) -> None:
        prefs.set_pref("surfaceStyle", "glass", self.config)
        prefs.set_pref("surfaceStyle", "solid", self.config)
        self.assertEqual(self.read("appearance").count("surfaceStyle"), 1)
        self.assertIn("surfaceStyle=solid", self.read("appearance"))

    def test_rejects_unknown_keys_and_values(self) -> None:
        with self.assertRaises(ValueError):
            prefs.set_pref("language", "xx", self.config)
        with self.assertRaises(ValueError):
            prefs.set_pref("appearance", "purple", self.config)
        self.assertFalse(self.config.exists())

    def test_cli_sets_and_reports_errors(self) -> None:
        with mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": self.tmp.name}):
            self.assertEqual(cli.main(["set", "appearance", "dark"]), 0)
            self.assertIn("appearance=dark", self.read("appearance"))
            self.assertEqual(cli.main(["set", "appearance", "purple"]), 1)


class MigrationTests(Base):
    def legacy(self, text: str) -> Path:
        self.config.mkdir(parents=True)
        path = self.config / "settings.ini"
        path.write_text(text, encoding="utf-8")
        return path

    def legacy_again(self, text: str) -> None:
        (self.config / "settings.ini").write_text(text, encoding="utf-8")

    def test_nothing_to_do_without_a_legacy_file(self) -> None:
        self.config.mkdir(parents=True)
        self.assertFalse(prefs.migrate(self.config))
        self.assertEqual(list(self.config.iterdir()), [])

    def test_keys_move_to_their_files_and_the_original_is_backed_up(self) -> None:
        original = "[appearance]\nradius=14\nbarSize=36\nfuture=1\nlanguage=es\n"
        self.legacy(original)
        self.assertTrue(prefs.migrate(self.config))
        self.assertIn("radius=14", self.read("appearance"))
        self.assertIn("barSize=36", self.read("bar"))
        self.assertIn("language=es", self.read("language"))
        self.assertIn("future=1", self.read("misc"))
        self.assertFalse((self.config / "settings.ini").exists())
        self.assertEqual(
            (self.config / "settings.ini.before-split").read_text(encoding="utf-8"), original)

    def test_it_is_idempotent(self) -> None:
        self.legacy("[appearance]\nradius=14\n")
        prefs.migrate(self.config)
        before = {p.name: p.read_text(encoding="utf-8") for p in self.config.iterdir()}
        self.assertFalse(prefs.migrate(self.config))
        after = {p.name: p.read_text(encoding="utf-8") for p in self.config.iterdir()}
        self.assertEqual(before, after)

    def test_files_already_split_win_over_the_legacy_file(self) -> None:
        self.legacy("[appearance]\nradius=14\nspacing=12\n")
        (self.config / "appearance.ini").write_text("[appearance]\nradius=3\n", encoding="utf-8")
        prefs.migrate(self.config)
        self.assertEqual(
            prefs.read_prefs(self.config), {"radius": "3", "spacing": "12"})

    def test_an_older_backup_is_never_overwritten(self) -> None:
        self.legacy("[appearance]\nradius=1\n").rename(self.config / "settings.ini.before-split")
        self.legacy_again("[appearance]\nradius=2\n")
        prefs.migrate(self.config)
        self.assertIn("radius=1", (self.config / "settings.ini.before-split").read_text())
        self.assertIn("radius=2", (self.config / "settings.ini.before-split.1").read_text())

    def test_keys_in_other_sections_and_empty_values_survive(self) -> None:
        self.legacy("[General]\nlanguage=de\n[appearance]\nlauncherBangs=\n")
        prefs.migrate(self.config)
        self.assertEqual(prefs.read_prefs(self.config), {"language": "de", "launcherBangs": ""})

    def test_each_file_is_written_once(self) -> None:
        # The path unit rate-limits: a burst of writes would trip it.
        self.legacy(FIXTURE.read_text(encoding="utf-8"))
        with mock.patch("os.replace", wraps=os.replace) as replace:
            prefs.migrate(self.config)
        targets = [call.args[1].name for call in replace.call_args_list]
        self.assertEqual(len(targets), len(set(targets)))

    def test_the_real_key_set_is_preserved_exactly(self) -> None:
        text = FIXTURE.read_text(encoding="utf-8")
        expected = dict(
            line.split("=", 1) for line in text.splitlines() if "=" in line)
        self.legacy(text)
        prefs.migrate(self.config)
        self.assertEqual(prefs.read_prefs(self.config), expected)
        self.assertEqual(len(expected), 56)
        for key in expected:
            self.assertIn(f"{key}=", self.read(prefs.file_of(key)))
        self.assertNotIn("selftest", self.read("appearance"))
        self.assertEqual(prefs.file_of("selftest"), "misc")

    def test_the_cli_runs_it(self) -> None:
        self.legacy("[appearance]\nradius=14\n")
        with mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": self.tmp.name}):
            self.assertEqual(cli.main(["migrate"]), 0)
        self.assertIn("radius=14", self.read("appearance"))


if __name__ == "__main__":
    unittest.main()


class ValidateTests(Base):
    def setUp(self) -> None:
        super().setUp()
        self.config.mkdir(parents=True)

    def write(self, name: str, text: str) -> None:
        (self.config / f"{name}.ini").write_text(text, encoding="utf-8")

    def test_a_clean_folder_has_no_problems(self) -> None:
        self.write("appearance", "[appearance]\nappearance=dark\nradius=14\n")
        self.assertEqual(prefs.validate(self.config), [])

    def test_an_unknown_key_is_reported_but_kept(self) -> None:
        self.write("appearance", "[appearance]\nnotAKey=1\n")
        issues = prefs.validate(self.config)
        self.assertEqual(len(issues), 1)
        self.assertIn("notAKey", issues[0])
        self.assertIn("appearance.ini", issues[0])
        self.assertEqual(self.read("appearance"), "[appearance]\nnotAKey=1\n")

    def test_a_key_in_the_wrong_file_is_reported(self) -> None:
        self.write("bar", "[bar]\nradius=14\n")
        issues = prefs.validate(self.config)
        self.assertEqual(len(issues), 1)
        self.assertIn("radius", issues[0])
        self.assertIn("appearance.ini", issues[0])

    def test_a_known_key_in_misc_is_a_misplacement(self) -> None:
        self.write("misc", "[misc]\nradius=14\n")
        issues = prefs.validate(self.config)
        self.assertEqual(len(issues), 1)
        self.assertIn("radius", issues[0])

    def test_an_unknown_key_in_misc_is_allowed(self) -> None:
        self.write("misc", "[misc]\npluginThing=1\n")
        self.assertEqual(prefs.validate(self.config), [])

    def test_a_newer_schema_is_reported(self) -> None:
        prefs.write_schema(self.config, prefs.SCHEMA + 1)
        issues = prefs.validate(self.config)
        self.assertEqual(len(issues), 1)
        self.assertIn("newer", issues[0])

    def test_the_schema_is_stamped_by_migration(self) -> None:
        (self.config / "settings.ini").write_text(
            "[appearance]\nappearance=dark\n", encoding="utf-8"
        )
        prefs.migrate(self.config)
        self.assertEqual(prefs.schema_version(self.config), prefs.SCHEMA)

    def test_cli_reports_problems_and_exits_one(self) -> None:
        self.write("appearance", "[appearance]\nnotAKey=1\n")
        with mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": self.tmp.name}):
            self.assertEqual(cli.main(["config", "validate"]), 1)
            (self.config / "appearance.ini").write_text(
                "[appearance]\nappearance=dark\n", encoding="utf-8"
            )
            self.assertEqual(cli.main(["config", "validate"]), 0)
