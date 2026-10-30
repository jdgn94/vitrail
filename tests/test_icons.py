"""Every Material Symbol named in the QML renders as one glyph.

Icons are written as ligature names ("wifi"); a typo silently renders the
word itself. Qt measures each name in the icon font: a real icon is about
one em wide, a misspelt one is a whole word.
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
QML_DIRS = ("bar", "kit", "shell", "gallery")
RUNNER = Path("/usr/lib/qt6/bin/qmltestrunner")
# The value of an icon / glyph property, up to the next comma or brace, and
# the ternary branches that continue it on the following lines.
ICON_VALUE = re.compile(r"\b(?:icon|glyph|endIcon|actionIcon)\s*:\s*([^,}]*)")
GLYPH_LIST = re.compile(r"\bglyphs\s*=\s*\[(.*)\]")
CONTINUATION = re.compile(r"^\s*:\s*(.*)")
NAME = re.compile(r'"([a-z][a-z0-9_]*)"')
# Size tables reuse the `icon` key for a text variant.
NOT_ICONS = {"body", "subtitle", "title", "label", "content", "display"}


def icon_names() -> set[str]:
    names: set[str] = set()
    for folder in QML_DIRS:
        for path in (ROOT / folder).rglob("*.qml"):
            if path.is_relative_to(ROOT / "bar" / "kit"):
                continue
            open_value = False
            for line in path.read_text(encoding="utf-8").splitlines():
                match = ICON_VALUE.search(line) or GLYPH_LIST.search(line)
                if match:
                    names |= set(NAME.findall(match.group(1)))
                    open_value = line.rstrip().endswith(("?", ":")) or "?" in match.group(1)
                elif open_value and (match := CONTINUATION.match(line)):
                    names |= set(NAME.findall(match.group(1)))
                else:
                    open_value = False
    return names - NOT_ICONS


class IconTests(unittest.TestCase):
    def test_every_icon_name_is_a_material_symbol(self) -> None:
        if not RUNNER.exists() or not shutil.which("fc-list"):
            self.skipTest("qmltestrunner or fontconfig missing")
        names = sorted(icon_names())
        self.assertTrue(names)
        family = re.search(r'icons:\s*"([^"]+)"', (ROOT / "kit" / "tokens.js").read_text()).group(1)
        test = f"""
import QtQuick
import QtTest
TestCase {{
    name: "Icons"
    TextMetrics {{ id: metrics; font.family: "{family}"; font.pixelSize: 24 }}
    function test_names() {{
        var bad = []
        var names = {names!r}
        for (var i = 0; i < names.length; i++) {{
            metrics.text = names[i]
            if (metrics.advanceWidth > 30)
                bad.push(names[i])
        }}
        compare(bad, [])
    }}
}}
"""
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "tst_icons.qml"
            target.write_text(test, encoding="utf-8")
            result = subprocess.run(
                [str(RUNNER), "-input", str(target)],
                capture_output=True, text=True, timeout=60,
                env={**os.environ, "QT_QPA_PLATFORM": "offscreen"},
            )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
