"""The on-screen keyboard is a floating layer window, not a bar popup.

It must not take the keyboard focus: `wtype` has to keep typing into the active
application. That rules out a focusable window and a bar `Popout`.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WINDOW = ROOT / "bar" / "keyboard" / "KeyboardWindow.qml"
SHELL = ROOT / "bar" / "shell.qml"
LAYOUTS = ROOT / "bar" / "layouts.js"


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

    def test_the_card_alone_takes_the_pointer_and_can_be_dragged(self) -> None:
        text = WINDOW.read_text(encoding="utf-8")
        for expected in (
            "mask: Region",
            "drag.target: card",
            "drag.minimumX: 0",
            "drag.maximumY: Math.max(0, root.height - card.height)",
        ):
            with self.subTest(expected=expected):
                self.assertIn(expected, text)

    def test_the_abbreviation_is_the_last_element_of_the_end_group(self) -> None:
        # The layout registry is the default document (bar → Editor): the
        # keyboard sits between the battery and the power button.
        text = LAYOUTS.read_text(encoding="utf-8")
        rows = re.findall(r'\{ id: "(\w+)", surface: "bar", group: "(\w+)"', text)
        end = [name for name, group in rows if group == "end"]
        self.assertEqual(end[-2:], ["keyboard", "power"])


if __name__ == "__main__":
    unittest.main()
