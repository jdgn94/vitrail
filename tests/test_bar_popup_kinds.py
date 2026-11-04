"""A bar element reports its own popup kind, on hover as on click.

Clicking a bar element opens its popup (`togglePopup`); hovering one while a
popup is open moves that popup to it (`hoverPopup`). Both carry a kind. When
they disagree, the pointer entering the same element again (a layer surface
above the bar makes the compositor repeat the enter event when a popup opens)
moves the popup the click just opened to the other kind: the next click sees a
different kind, reopens instead of closing, and the button never toggles. The
kind must also be a popout `bar/Popout.qml` loads, or the click opens nothing.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BAR_ITEMS = ROOT / "bar" / "BarItems.qml"
SHELL = ROOT / "bar" / "shell.qml"
CLICK = re.compile(r'root\.clicked\("([^"]+)"')
HOVER = re.compile(r'root\.hovered\("([^"]+)"')
POPOUT = re.compile(r'Popout\s*\{\s*\n\s*name:\s*"([^"]+)"')


def kinds(source: str) -> tuple[list[str], list[str]]:
    return CLICK.findall(source), HOVER.findall(source)


def popout_names() -> set[str]:
    return set(POPOUT.findall(SHELL.read_text(encoding="utf-8")))


class BarPopupKindTests(unittest.TestCase):
    def test_each_button_opens_its_own_popup(self) -> None:
        clicked, _ = kinds(BAR_ITEMS.read_text(encoding="utf-8"))
        self.assertEqual(clicked, ["network", "vpn", "powerprofile", "power"])

    def test_hover_and_click_report_the_same_kind(self) -> None:
        clicked, hovered = kinds(BAR_ITEMS.read_text(encoding="utf-8"))
        self.assertTrue(clicked, "no clickable element found in BarItems.qml")
        self.assertEqual(clicked, hovered)

    def test_every_kind_is_a_popout(self) -> None:
        clicked, _ = kinds(BAR_ITEMS.read_text(encoding="utf-8"))
        self.assertTrue(popout_names(), "no popout found in shell.qml")
        self.assertEqual([kind for kind in clicked if kind not in popout_names()], [])

    def test_pattern_catches_the_bug(self) -> None:
        source = 'onClicked: root.clicked("network", network)\nroot.hovered("vpn", vpn)\n'
        clicked, hovered = kinds(source)
        self.assertEqual(clicked, ["network"])
        self.assertNotEqual(clicked, hovered)


if __name__ == "__main__":
    unittest.main()
