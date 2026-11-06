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

    def test_a_mapped_window_settles_before_the_drop_takes_its_rect(self) -> None:
        shell = SHELL.read_text(encoding="utf-8")
        track = function_body(shell, "trackLaunch")
        self.assertIn("DropletJS.watch(", track)
        self.assertIn("DropletJS.settle(", track)
        self.assertIn("request.final", track)

    def test_a_dock_launch_reserves_its_last_rect_or_the_icon(self) -> None:
        shell = SHELL.read_text(encoding="utf-8")
        begin = function_body(shell, "beginLaunch")
        self.assertIn("DropletJS.lastRect(", begin)
        self.assertIn("DropletJS.local(last", begin)
        self.assertNotIn("DropletJS.fallback(", begin)
        droplet = (ROOT / "bar" / "droplet" / "droplet.js").read_text(encoding="utf-8")
        tokens = (ROOT / "kit" / "tokens.js").read_text(encoding="utf-8")
        self.assertNotIn("function fallback(", droplet)
        self.assertNotIn("fallbackWidth", tokens)

    def test_a_keyboard_launch_reserves_the_window_rect(self) -> None:
        shell = SHELL.read_text(encoding="utf-8")
        keyboard = function_body(shell, "keyboardPointer")
        self.assertIn("DropletJS.local(window.rect, screen)", keyboard)
        self.assertNotIn("DropletJS.fallback(", keyboard)

    def test_the_final_rect_is_held_before_fading(self) -> None:
        shell = SHELL.read_text(encoding="utf-8")
        track = function_body(shell, "trackLaunch")
        self.assertIn("launchHold.restart()", track)
        self.assertIn("launchFade.stop()", track)
        self.assertIn("DropletJS.fade(request, Date.now())", shell)
        self.assertIn('2 * VitrailTokens.duration("slow")', shell)
        self.assertIn("launchHold.stop()", function_body(shell, "endLaunch"))

    def test_a_keyboard_launch_starts_at_the_pointer(self) -> None:
        shell = SHELL.read_text(encoding="utf-8")
        sync = function_body(shell, "syncToplevels")
        keyboard = function_body(shell, "keyboardPointer")
        self.assertIn("hyprctl", sync + keyboard)
        self.assertIn("cursorpos", sync + keyboard)
        self.assertIn("DropletJS.pointerOrigin(", keyboard)
        self.assertIn("DropletJS.screenFor(", keyboard)
        self.assertIn("DropletJS.watch(", keyboard)

    def test_a_closed_window_keeps_its_last_rect_for_the_drop(self) -> None:
        shell = SHELL.read_text(encoding="utf-8")
        sync = function_body(shell, "syncToplevels")
        close = function_body(shell, "beginClose")
        self.assertIn("DropletJS.sync(", sync)
        self.assertIn("beginClose(", sync)
        self.assertIn("DropletJS.closing(", close)
        self.assertIn("DropletJS.own(", close)
        self.assertIn("closeFade.restart()", close)

    def test_the_startup_baseline_ignores_windows_already_open(self) -> None:
        shell = SHELL.read_text(encoding="utf-8")
        sync = function_body(shell, "syncToplevels")
        self.assertIn("!shell.liveWarm", sync)
        self.assertNotIn("liveReady", shell)
        self.assertIn("DropletJS.sync(({}), Hyprland.toplevels.values)", shell)
        self.assertIn("Hyprland.refreshToplevels()", sync)

    def test_the_close_burst_uses_the_burst_tokens(self) -> None:
        shell = SHELL.read_text(encoding="utf-8")
        close = function_body(shell, "beginClose")
        self.assertIn("VitrailTokens.droplet.burst.puff", close)
        self.assertIn("VitrailTokens.droplet.burst.duration", shell)
        tokens = (ROOT / "kit" / "tokens.js").read_text(encoding="utf-8")
        self.assertIn("burst: {", tokens)
        self.assertIn("count: 7", tokens)
        self.assertIn("duration: 250", tokens)
        burst = (ROOT / "bar" / "droplet" / "burst.js").read_text(encoding="utf-8")
        self.assertIn("function particles(", burst)
        self.assertNotIn("import", burst)

    def test_the_gallery_shows_both_droplet_phases(self) -> None:
        gallery = (ROOT / "gallery" / "Main.qml").read_text(encoding="utf-8")
        self.assertIn("Launch droplet", gallery)
        self.assertIn('phase: "open"', gallery)
        self.assertIn('phase: "burst"', gallery)
        self.assertTrue((ROOT / "gallery" / "DropletPreview.qml").exists())

    def test_the_droplet_ignores_edit_mode(self) -> None:
        shell = SHELL.read_text(encoding="utf-8")
        self.assertIn("shell.editMode", function_body(shell, "syncToplevels"))
        self.assertIn("shell.editMode", function_body(shell, "keyboardPointer"))
        self.assertIn("shell.editMode", function_body(shell, "beginLaunch"))


if __name__ == "__main__":
    unittest.main()
