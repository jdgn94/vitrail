"""A settings page must not bind a property to an id of the same name.

Inside a page, `prefs: prefs` reads the page's own `prefs` (undefined), not the
`id: prefs` in main.qml, so the page renders unset. Pages bind through `app.`.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path

MAIN = Path(__file__).resolve().parent.parent / "shell" / "main.qml"
SELF_BINDING = re.compile(r"(?m)^\s*(\w+):\s*\1\s*$")


class SettingsBindingsTest(unittest.TestCase):
    def test_no_page_binding_names_itself(self) -> None:
        source = MAIN.read_text(encoding="utf-8")
        start = source.index("LazyPage {")
        self.assertEqual(SELF_BINDING.findall(source[start:]), [])

    def test_pattern_catches_the_bug(self) -> None:
        self.assertTrue(SELF_BINDING.search("    prefs: prefs\n"))
        self.assertFalse(SELF_BINDING.search("    prefs: app.store\n"))


if __name__ == "__main__":
    unittest.main()
