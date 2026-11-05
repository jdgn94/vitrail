"""The on-screen keyboard is a floating layer window, not a bar popup.

It must not take the keyboard focus: `wtype` has to keep typing into the active
application. That rules out a focusable window and a bar `Popout`.
"""

from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WINDOW = ROOT / "bar" / "keyboard" / "KeyboardWindow.qml"
SHELL = ROOT / "bar" / "shell.qml"
BAR_ITEMS = ROOT / "bar" / "BarItems.qml"


class KeyboardWindowTests(unittest.TestCase):
    def test_it_is_a_floating_layer_window_without_keyboard_focus(self) -> None:
        text = WINDOW.read_text(encoding="utf-8")
        for expected in (
            "PanelWindow {",
            "focusable: false",
            "WlrLayershell.keyboardFocus: WlrKeyboardFocus.None",
            'WlrLayershell.namespace: "vitrail-keyboard"',
            "WlrLayershell.layer: WlrLayer.Overlay",
        ):
            with self.subTest(expected=expected):
                self.assertIn(expected, text)

    def test_it_is_not_a_bar_popup(self) -> None:
        shell = SHELL.read_text(encoding="utf-8")
        self.assertNotIn('name: "keyboardosk"', shell)
        self.assertNotIn('togglePopup("keyboardosk"', shell)
        self.assertIn("KeyboardWindow {", shell)
        self.assertIn("keyboardOskOpen", shell)

    def test_the_abbreviation_is_the_last_element_of_the_end_group(self) -> None:
        text = BAR_ITEMS.read_text(encoding="utf-8")
        self.assertGreater(text.rfind("KeyboardButton {"), text.rfind("PowerButton {"))


if __name__ == "__main__":
    unittest.main()
