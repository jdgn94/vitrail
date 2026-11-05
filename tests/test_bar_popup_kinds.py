"""A bar element reports its own popup kind, on hover as on click.

Clicking a bar element opens its popup (`togglePopup`); hovering one while a
popup is open moves that popup to it (`hoverPopup`). Both carry a kind. When
they disagree, the pointer entering the same element again (a layer surface
above the bar makes the compositor repeat the enter event when a popup opens)
moves the popup the click just opened to the other kind: the next click sees a
different kind, reopens instead of closing, and the button never toggles. The
kind must also be a popout `bar/Popout.qml` loads, or the click opens nothing.

The elements live in `bar/shell.qml` as components the bar's layout document
places (bar → Editor).
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHELL = ROOT / "bar" / "shell.qml"
CLICK = re.compile(r'togglePopup\("([^"]+)"')
HOVER = re.compile(r'hoverPopup\("([^"]+)"')
POPOUT = re.compile(r'Popout\s*\{\s*\n\s*name:\s*"([^"]+)"')


def element_block(source: str) -> str:
    """The components that draw the bar's elements (not the IPC handlers,
    which open the same kinds without a button to hover)."""
    start = source.index("// --- the bar's elements")
    end = source.index("// Neighbouring connection buttons")
    return source[start:end]


def kinds(source: str) -> tuple[list[str], list[str]]:
    return CLICK.findall(source), HOVER.findall(source)


def popout_names() -> set[str]:
    return set(POPOUT.findall(SHELL.read_text(encoding="utf-8")))


class BarPopupKindTests(unittest.TestCase):
    def test_each_kind_opens_a_popup(self) -> None:
        # The battery chip shares the power profile popup with the mode chip
        # inside the connection pill, so its kind appears twice.
        clicked, _ = kinds(element_block(SHELL.read_text(encoding="utf-8")))
        self.assertIn("network", clicked)
        self.assertIn("bluetooth", clicked)
        self.assertIn("vpn", clicked)
        self.assertEqual(clicked.count("powerprofile"), 2)
        self.assertIn("power", clicked)
        self.assertIn("keyboard", clicked)

    def test_the_clock_opens_the_dashboard(self) -> None:
        source = SHELL.read_text(encoding="utf-8")
        self.assertIn('togglePopup("dashboard", clockButton', source)
        self.assertIn("dashboard", popout_names())
        self.assertNotIn('name: "clock"', source)

    def test_hover_and_click_report_the_same_kind(self) -> None:
        clicked, hovered = kinds(element_block(SHELL.read_text(encoding="utf-8")))
        self.assertTrue(clicked, "no clickable element found in bar/shell.qml")
        self.assertEqual(set(clicked), set(hovered))

    def test_every_kind_is_a_popout(self) -> None:
        clicked, _ = kinds(element_block(SHELL.read_text(encoding="utf-8")))
        self.assertTrue(popout_names(), "no popout found in shell.qml")
        self.assertEqual([kind for kind in clicked if kind not in popout_names()], [])

    def test_pattern_catches_the_bug(self) -> None:
        source = 'togglePopup("network", network)\nhoverPopup("vpn", vpn)\n'
        clicked, hovered = kinds(source)
        self.assertEqual(clicked, ["network"])
        self.assertNotEqual(clicked, hovered)


if __name__ == "__main__":
    unittest.main()
