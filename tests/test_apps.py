"""Flatpak and Firefox follow the palette without manual steps."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from vitrail import apps

PALETTE = {
    "surface": "#101418",
    "surface_container_high": "#20262e",
    "on_surface": "#e2e2e9",
    "primary": "#a8c7fa",
    "outline": "#8f9099",
}

PROFILES = """[Install4F96D1932A9F858E]
Default=abc.default-release
Locked=1

[Profile1]
Name=default
IsRelative=1
Path=abc.default

[Profile0]
Name=default-release
IsRelative=1
Path=abc.default-release
Default=1

[General]
StartWithLastProfile=1
"""


class ProfileTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.mozilla = Path(self.tmp.name) / "firefox"
        self.mozilla.mkdir()

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def test_the_default_profile_wins(self) -> None:
        (self.mozilla / "profiles.ini").write_text(PROFILES, encoding="utf-8")
        self.assertEqual(apps.default_profile(self.mozilla), self.mozilla / "abc.default-release")

    def test_without_a_default_the_install_points_at_it(self) -> None:
        text = PROFILES.replace("Default=1\n", "")
        (self.mozilla / "profiles.ini").write_text(text, encoding="utf-8")
        self.assertEqual(apps.default_profile(self.mozilla), self.mozilla / "abc.default-release")

    def test_a_missing_profiles_file_means_firefox_never_ran(self) -> None:
        self.assertIsNone(apps.default_profile(self.mozilla))


class FirefoxTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.profile = Path(self.tmp.name) / "profile"
        self.profile.mkdir()

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def test_the_pref_is_written_once(self) -> None:
        self.assertTrue(apps.write_firefox(self.profile, PALETTE))
        self.assertTrue(apps.write_firefox(self.profile, PALETTE))
        text = (self.profile / "user.js").read_text(encoding="utf-8")
        self.assertEqual(text.count(apps.FIREFOX_PREF), 1)

    def test_existing_user_js_lines_are_kept_and_backed_up(self) -> None:
        (self.profile / "user.js").write_text('user_pref("x", 1);\n', encoding="utf-8")
        apps.write_firefox(self.profile, PALETTE)
        text = (self.profile / "user.js").read_text(encoding="utf-8")
        self.assertIn('user_pref("x", 1);', text)
        self.assertTrue((self.profile / "user.js.before-vitrail").exists())

    def test_the_chrome_stylesheet_uses_the_palette(self) -> None:
        apps.write_firefox(self.profile, PALETTE)
        css = (self.profile / "chrome" / "userChrome.css").read_text(encoding="utf-8")
        self.assertIn(apps.MARKER, css)
        self.assertIn("--vitrail-surface: #101418", css)
        self.assertIn("--vitrail-primary: #a8c7fa", css)

    def test_a_missing_profile_is_not_created(self) -> None:
        self.assertFalse(apps.write_firefox(self.profile / "nope", PALETTE))


class FlatpakTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.cache = Path(self.tmp.name)

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def test_every_theme_folder_is_granted_read_only(self) -> None:
        command = apps.override_command()
        self.assertEqual(command[:3], ["flatpak", "override", "--user"])
        for path in ("xdg-config/gtk-3.0", "xdg-config/gtk-4.0", "xdg-data/icons"):
            self.assertIn(f"--filesystem={path}:ro", command)

    def test_the_overrides_run_once(self) -> None:
        calls: list[list[str]] = []

        def run(command: list[str]) -> str:
            calls.append(command)
            return ""

        with mock.patch.object(apps.shutil, "which", return_value="/usr/bin/flatpak"):
            self.assertTrue(apps.sync_flatpak(run=run, cache=self.cache))
            self.assertFalse(apps.sync_flatpak(run=run, cache=self.cache))
        self.assertEqual(len(calls), 1)

    def test_a_failing_flatpak_is_reported(self) -> None:
        with mock.patch.object(apps.shutil, "which", return_value="/usr/bin/flatpak"):
            self.assertFalse(apps.sync_flatpak(run=lambda command: None, cache=self.cache))

    def test_without_flatpak_nothing_runs(self) -> None:
        with mock.patch.object(apps.shutil, "which", return_value=None):
            self.assertFalse(apps.sync_flatpak(run=lambda command: "", cache=self.cache))


class ApplyTests(unittest.TestCase):
    def test_both_clients_are_synced(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            generated = root / "generated"
            generated.mkdir()
            (generated / "theme-dark.json").write_text(json.dumps({"colors": PALETTE}), encoding="utf-8")
            mozilla = root / "firefox"
            profile = mozilla / "abc.default-release"
            profile.mkdir(parents=True)
            (mozilla / "profiles.ini").write_text(PROFILES, encoding="utf-8")
            with mock.patch.object(apps.shutil, "which", return_value="/usr/bin/flatpak"):
                result = apps.apply("dark", generated, cache=root / "cache", run=lambda command: "", mozilla=mozilla)
            self.assertTrue(result["flatpak"])
            self.assertEqual(result["firefox"], str(profile))
            self.assertTrue((profile / "chrome" / "userChrome.css").is_file())

    def test_without_a_palette_nothing_is_written(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = apps.apply("dark", Path(tmp) / "generated", cache=Path(tmp) / "cache", run=lambda command: "")
            self.assertEqual(result, {"flatpak": False, "firefox": ""})


if __name__ == "__main__":
    unittest.main()
