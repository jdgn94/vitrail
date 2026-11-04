"""A bar element reports one popup kind, on hover as on click.

Clicking a bar element opens its popup (`togglePopup`); hovering one while a
popup is open moves that popup to it (`hoverPopup`). Both carry a kind. When
they disagree, the pointer entering the same element again (a layer surface
above the bar makes the compositor repeat the enter event when a popup opens)
moves the popup the click just opened to the other kind: the next click sees a
different kind, reopens instead of closing, and the button never toggles.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path

BAR_ITEMS = Path(__file__).resolve().parent.parent / "bar" / "BarItems.qml"
CLICK = re.compile(r'root\.clicked\("([^"]+)"')
HOVER = re.compile(r'root\.hovered\("([^"]+)"')


def kinds(source: str) -> tuple[list[str], list[str]]:
    return CLICK.findall(source), HOVER.findall(source)


class BarPopupKindTests(unittest.TestCase):
    def test_hover_and_click_report_the_same_kind(self) -> None:
        clicked, hovered = kinds(BAR_ITEMS.read_text(encoding="utf-8"))
        self.assertTrue(clicked, "no clickable element found in BarItems.qml")
        self.assertEqual(clicked, hovered)

    def test_pattern_catches_the_bug(self) -> None:
        source = 'onClicked: root.clicked("connection", network)\nroot.hovered("network", network)\n'
        clicked, hovered = kinds(source)
        self.assertEqual(clicked, ["connection"])
        self.assertNotEqual(clicked, hovered)


if __name__ == "__main__":
    unittest.main()
