"""Icons are never filled: the active state is the colour, not a FILL axis.

Material Symbols can fill a glyph through the `FILL` variable axis. Vitrail
does not use it: a selected / active icon is drawn in the accent colour, so
the shape never changes with the state (and no Text can get stuck on a
variable-font instance).
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# Every directory that draws a Material Symbol.
SOURCES = ("kit", "shell", "bar", "gallery", "login", "lock")

# The FILL axis: `font.variableAxes` at all, or the axis name.
FILL_AXIS = re.compile(r"\bvariableAxes\b|[\"']FILL[\"']")
# The icon `filled:` property. `field`'s "filled" variant is a table entry
# (`filled: { role: ... }`), not an icon state, so an object value is allowed.
FILLED_PROPERTY = re.compile(r"(?m)^\s*filled\s*:(?![ \t]*\{)")
COMMENT = re.compile(r"//[^\n]*|/\*.*?\*/", re.S)


def ui_sources() -> list[Path]:
    files = []
    for name in SOURCES:
        files.extend(sorted((ROOT / name).rglob("*.qml")))
    return files


def code_of(path: Path) -> str:
    return COMMENT.sub("", path.read_text(encoding="utf-8"))


class IconFillTest(unittest.TestCase):
    def test_no_fill_axis_anywhere(self) -> None:
        for path in ui_sources():
            body = code_of(path)
            self.assertIsNone(
                FILL_AXIS.search(body),
                f"{path.relative_to(ROOT)} sets the FILL axis; the active state is the colour",
            )
            self.assertIsNone(
                FILLED_PROPERTY.search(body),
                f"{path.relative_to(ROOT)} fills an icon; the active state is the colour",
            )

    def test_the_vpn_icon_is_a_coloured_shield_with_a_lock(self) -> None:
        for name in ("bar/network/VpnButton.qml", "bar/network/VpnPanel.qml"):
            body = (ROOT / name).read_text(encoding="utf-8")
            self.assertIn('text: "shield_lock"', body, f"{name} draws shield_lock")
        # The button never swaps the glyph with the state: the colour says it.
        button = (ROOT / "bar/network/VpnButton.qml").read_text(encoding="utf-8")
        self.assertNotIn('activeVpn ? "shield_lock" : "shield"', button)

    def test_the_patterns_catch_the_old_code(self) -> None:
        self.assertTrue(FILL_AXIS.search('font.variableAxes: ({ "FILL": 1 })'))
        self.assertTrue(FILLED_PROPERTY.search("                    filled: true\n"))
        self.assertTrue(FILLED_PROPERTY.search("filled: root.activeVpn !== null\n"))
        # A text field's "filled" variant is a table entry, not an icon state.
        self.assertFalse(FILLED_PROPERTY.search("        filled: { role: 'surfaceHigh' },\n"))
        self.assertFalse(FILLED_PROPERTY.search("        filled: {\n"))


if __name__ == "__main__":
    unittest.main()
