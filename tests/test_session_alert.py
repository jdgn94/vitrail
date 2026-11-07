"""The session alert is a layer of its own, not part of the menu window."""

from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHELL = ROOT / "bar" / "shell.qml"
SESSION = ROOT / "bar" / "session"


class AlertLayerTests(unittest.TestCase):
    def test_the_menu_window_no_longer_carries_the_confirm(self) -> None:
        shell = SHELL.read_text(encoding="utf-8")
        self.assertNotIn("SessionConfirm", shell)
        self.assertIn("AlertLayer {", shell)
        self.assertIn("shell.sessionAlertShown", shell)

    def test_the_alert_is_a_full_screen_overlay_of_its_own(self) -> None:
        text = (SESSION / "AlertLayer.qml").read_text(encoding="utf-8")
        self.assertIn("PanelWindow {", text)
        self.assertIn("WlrLayershell.layer: WlrLayer.Overlay", text)
        self.assertIn("WlrLayershell.keyboardFocus:", text)
        self.assertIn("exclusionMode: ExclusionMode.Ignore", text)
        self.assertIn("mask: Region {", text)
        for edge in ("top", "bottom", "left", "right"):
            with self.subTest(edge=edge):
                self.assertIn(f"{edge}: true", text)

    def test_the_alert_surface_holds_exactly_one_confirm(self) -> None:
        surface = (SESSION / "SessionAlert.qml").read_text(encoding="utf-8")
        self.assertEqual(surface.count("SessionConfirm {"), 1)
        self.assertIn('objectName: "sessionConfirm"', (SESSION / "SessionConfirm.qml").read_text(encoding="utf-8"))

    def test_the_lock_screen_limit_is_documented(self) -> None:
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        section = readme.split("## Login and lock", 1)[1].split("\n## ", 1)[0]
        self.assertIn("hyprlock", section)
        self.assertIn("alert", section.lower())


if __name__ == "__main__":
    unittest.main()
