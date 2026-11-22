"""The popups that offer settings carry the gear, in the one place (AGENTS.md,
references/popups.md): the last item of their first row, top-right, and the
shell answers with the page and tab that own them."""

from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GEAR = ROOT / "kit" / "VitrailPopupGear.qml"
SHELL = ROOT / "bar" / "shell.qml"
# The panel, and the settings page and tab its gear opens.
POPUPS = {
    "bar/network/NetworkPanel.qml": None,  # internet and bluetooth: wired per tab
    "bar/network/VpnPanel.qml": ("connection", "vpn"),
    "bar/network/PowerProfilePanel.qml": ("connection", "power"),
    "bar/keyboard/KeyboardPanel.qml": ("input", "keyboard"),
    "bar/sample/SamplePanel.qml": ("bar-elements", "sample"),
    "bar/volume/VolumePanel.qml": ("bar-elements", "volume"),
    "bar/updates/UpdatesPanel.qml": ("bar-elements", "updates"),
    "bar/disks/DisksPanel.qml": ("bar-elements", "disks"),
    "bar/containers/ContainersPanel.qml": ("bar-elements", "containers"),
    "bar/battery/PeripheralsPanel.qml": ("bar-elements", "peripherals"),
    "bar/brightness/BrightnessPanel.qml": ("bar-elements", "brightness"),
    "bar/health/HealthPanel.qml": ("bar-elements", "health"),
}


class PopupGearTests(unittest.TestCase):
    def test_the_gear_is_one_definition_in_the_kit(self) -> None:
        text = GEAR.read_text(encoding="utf-8")
        for marker in ('objectName: "popupSettings"', 'icon: "settings"', 'variant: "plain"', 'size: "sm"'):
            with self.subTest(marker=marker):
                self.assertIn(marker, text)

    def test_every_popup_with_settings_draws_it_at_the_top_right(self) -> None:
        for name in POPUPS:
            with self.subTest(popup=name):
                text = (ROOT / name).read_text(encoding="utf-8")
                self.assertIn("signal settingsRequested()", text)
                gear = re.search(r"VitrailPopupGear\s*\{([^}]*)\}", text)
                self.assertIsNotNone(gear, "draw the shared gear")
                self.assertIn("Qt.AlignTop", gear.group(1))
                self.assertIn("root.settingsRequested()", gear.group(1))
                # It is the last child: nothing may follow it in the row.
                after = text[gear.end() :].lstrip()
                self.assertTrue(after.startswith("}"), "the gear closes its row")

    def test_the_shell_defines_what_the_gears_call(self) -> None:
        shell = SHELL.read_text(encoding="utf-8")
        self.assertIn("function openSettingsAt(", shell)
        self.assertIn("Quickshell.execDetached(", shell)

    def test_the_shell_opens_the_page_and_tab_of_each_gear(self) -> None:
        shell = SHELL.read_text(encoding="utf-8")
        for popup, target in POPUPS.items():
            if target is None:
                continue
            with self.subTest(popup=popup):
                self.assertIn(f'onSettingsRequested: shell.openSettingsAt("{target[0]}", "{target[1]}")', shell)
        # The connection popup carries two tabs, each with its own page.
        self.assertIn('onSettingsRequested: shell.openSettingsAt("connection", "internet")', shell)
        self.assertIn('onSettingsRequested: shell.openSettingsAt("connection", "bluetooth")', shell)


if __name__ == "__main__":
    unittest.main()
