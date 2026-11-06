"""The launch droplet's wiring: the launcher resets, launching drops, focusing not."""

from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LAUNCHER = ROOT / "bar" / "launcher" / "Launcher.qml"
SCREEN = ROOT / "bar" / "launcher" / "LauncherScreen.qml"
SHELL = ROOT / "bar" / "shell.qml"
LAYER = ROOT / "bar" / "droplet" / "LaunchDropletLayer.qml"


def function_body(text: str, name: str) -> str:
    match = re.search(rf"function {name}\([^)]*\)\s*\{{(.*?)\n    \}}", text, re.S)
    return match.group(1) if match else ""


class LauncherResetTests(unittest.TestCase):
    def test_the_launcher_has_one_reset_that_clears_the_previous_opening(self) -> None:
        text = LAUNCHER.read_text(encoding="utf-8")
        body = function_body(text, "reset")
        self.assertTrue(body, "Launcher.reset() is missing")
        for field in (
            "field.text",
            "root.current",
            "root.tab",
            "root.expanded",
            "root.menu",
            "root.menuCurrent",
            "root.fileQuery",
            "root.fileItems",
            "root.wallpaperFiles",
            "root.wallpaperLoaded",
            "root.modeBefore",
        ):
            with self.subTest(field=field):
                self.assertIn(field, body)

    def test_a_fresh_launcher_and_every_reopening_call_reset(self) -> None:
        launcher = LAUNCHER.read_text(encoding="utf-8")
        self.assertIn("root.reset()", launcher)
        screen = SCREEN.read_text(encoding="utf-8")
        self.assertIn("onOpenChanged", screen)
        self.assertIn("resetContent()", screen)
        self.assertIn("item.reset()", screen)


class DropletWiringTests(unittest.TestCase):
    def test_launching_starts_the_drop_and_focusing_does_not(self) -> None:
        shell = SHELL.read_text(encoding="utf-8")
        launch = function_body(shell, "launchDockApp")
        self.assertIn("beginLaunch", launch)
        self.assertIn("entries[i].execute()", launch)
        focus = function_body(shell, "focusDockApp")
        self.assertNotIn("beginLaunch", focus)
        self.assertIn("focuswindow", focus)

    def test_the_layer_takes_no_input_and_tracks_a_window(self) -> None:
        text = LAYER.read_text(encoding="utf-8")
        self.assertIn("WlrLayer.Overlay", text)
        self.assertIn("WlrKeyboardFocus.None", text)
        self.assertIn("mask: Region {}", text)
        self.assertIn("ExclusionMode.Ignore", text)
        shell = SHELL.read_text(encoding="utf-8")
        self.assertIn("DropletJS.arrival(", shell)
        self.assertIn("DropletJS.timeout(", shell)


if __name__ == "__main__":
    unittest.main()
