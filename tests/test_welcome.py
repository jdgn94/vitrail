"""The first run picks a wallpaper without overwriting a choice."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest import mock

from vitrail import welcome


class WelcomeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.assets = self.root / "wallpapers"
        self.assets.mkdir()
        (self.assets / "one.png").write_bytes(b"png")
        (self.assets / "two.jpg").write_bytes(b"jpg")
        self.config = self.root / "config"
        self.config.mkdir()
        self.spawned: list[list[str]] = []

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def run_welcome(self, open_window: bool = False) -> dict:
        with mock.patch.object(welcome, "_apply") as applied:
            result = welcome.run(
                assets=self.assets,
                config=self.config,
                open_window=open_window,
                spawn=lambda argv: self.spawned.append(argv),
            )
        self.applied = applied
        return result

    def test_the_first_wallpaper_is_chosen(self) -> None:
        result = self.run_welcome()
        self.assertTrue(result["applied"])
        self.assertEqual(Path(result["wallpaper"]).name, "one.png")
        self.applied.assert_called_once()

    def test_an_existing_wallpaper_is_not_replaced(self) -> None:
        (self.config / "wallpaper.ini").write_text("[wallpaper]\nwallpaper=/keep.png\n", encoding="utf-8")
        result = self.run_welcome()
        self.assertFalse(result["applied"])
        self.assertEqual(result["wallpaper"], "/keep.png")

    def test_the_window_opens_unless_asked_not_to(self) -> None:
        self.run_welcome(open_window=True)
        self.assertEqual(self.spawned, [["vitrail-settings", "--category", "appearance"]])


if __name__ == "__main__":
    unittest.main()
