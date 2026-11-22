"""Every bar component the shell instantiates is imported by its directory.

QML resolves a type only when the folder that holds it is imported. A merge
that adds an element to `bar/shell.qml` but forgets `import "<folder>"` loads
every test fine and only fails when the shell starts ("NotesPanel is not a
type"), which no test did until this one.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHELL = ROOT / "bar/shell.qml"
BAR = ROOT / "bar"


def components() -> dict[str, str]:
    """Each QML type under bar/, by name, mapped to its folder."""
    found: dict[str, str] = {}
    for path in sorted(BAR.rglob("*.qml")):
        folder = path.parent.relative_to(BAR).as_posix()
        if folder == ".":
            continue
        found.setdefault(path.stem, folder)
    return found


class ShellImportTests(unittest.TestCase):
    def setUp(self) -> None:
        self.shell = SHELL.read_text(encoding="utf-8")

    def test_every_instantiated_bar_component_is_imported(self) -> None:
        missing = []
        for name, folder in components().items():
            if not re.search(rf"(?m)^\s*{re.escape(name)}\s*\{{", self.shell):
                continue
            if f'import "{folder}"' in self.shell:
                continue
            missing.append(f'{name} lives in bar/{folder}, but shell.qml has no import "{folder}"')
        self.assertEqual(missing, [], "the shell cannot resolve:\n" + "\n".join(missing))


if __name__ == "__main__":
    unittest.main()
