"""Every open/save dialog is the FileChooser portal's GTK 4 chooser.

The settings window reaches the portal on its own (`QT_QPA_PLATFORMTHEME`); a
GTK 3 app only when `GTK_USE_PORTAL` is set, and the portal only picks the
chooser the config names. The backend itself has to come from the installer's
manifest (AGENTS.md, "Dependencies").
"""

from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HYPRLAND = ROOT / "dots" / ".config" / "hypr" / "hyprland.lua"
PORTALS = ROOT / "dots" / ".config" / "xdg-desktop-portal" / "hyprland-portals.conf"
BASE = ROOT / "packages" / "base.txt"


class PortalTests(unittest.TestCase):
    def test_gtk3_apps_are_told_to_use_the_portal(self) -> None:
        self.assertIn('hl.env("GTK_USE_PORTAL", "1")', HYPRLAND.read_text(encoding="utf-8"))

    def test_the_file_chooser_is_the_gtk4_chooser(self) -> None:
        text = PORTALS.read_text(encoding="utf-8")
        self.assertIn("org.freedesktop.impl.portal.FileChooser=phrosh;gtk", text)
        # This file overrides the one xdg-desktop-portal-hyprland ships, so it
        # has to keep the compositor's own portal as the fallback choice.
        self.assertIn("default=hyprland", text.split("[preferred]", 1)[1])

    def test_the_backend_comes_from_the_installer(self) -> None:
        self.assertIn("xdg-desktop-portal-phosh", BASE.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
