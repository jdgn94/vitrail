"""Every icon the QML draws has an entry in the resolver's table.

`kit/icons.js` is the allow-list `VitrailIcons.resolve` checks. A name that is
not in it draws a question mark, which is the right fallback at runtime but a
silent failure in development: a typo would look deliberate. This test makes
the typo fail the suite instead, by comparing the table with the names the QML
actually uses (collected exactly as `tests/test_icons.py` does).

A second rule keeps the resolver on the only path an icon may take: an icon
primitive (`VitrailIcon`, or a `VitrailText` with the icon variant) sets
`icon`, never `text`, so the string can not skip `resolve`.
"""

from __future__ import annotations

import re
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ICONS_JS = ROOT / "kit" / "icons.js"
QML_DIRS = ("bar", "kit", "shell", "gallery", "login", "lock")
NAMES_BLOCK = re.compile(r"var names\s*=\s*\{(.*?)\n\}", re.S)
ALIASES_BLOCK = re.compile(r"var aliases\s*=\s*\{(.*?)\n\}", re.S)
ENTRY = re.compile(r'^\s*"?(\w+)"?\s*:\s*"([^"]+)"', re.M)


def resolver_names() -> dict[str, str]:
    """The `names` table: name -> the glyph the font draws for it."""
    match = NAMES_BLOCK.search(ICONS_JS.read_text(encoding="utf-8"))
    assert match is not None, "kit/icons.js has no `names` table"
    return dict(ENTRY.findall(match.group(1)))


def resolver_aliases() -> dict[str, str]:
    match = ALIASES_BLOCK.search(ICONS_JS.read_text(encoding="utf-8"))
    return dict(ENTRY.findall(match.group(1))) if match else {}


def qml_icon_names() -> set[str]:
    """The names the QML draws, with the extraction `tests/test_icons.py` uses."""
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    try:
        from test_icons import icon_names
    finally:
        sys.path.pop(0)
    return icon_names()


def icon_blocks() -> list[tuple[Path, int, str, list[str]]]:
    """Every `VitrailIcon` / `VitrailText` block, as (file, line, kind, lines)."""
    blocks = []
    for folder in QML_DIRS:
        for path in sorted((ROOT / folder).rglob("*.qml")):
            if path.is_relative_to(ROOT / "bar" / "kit"):
                continue
            lines = path.read_text(encoding="utf-8").splitlines()
            for index, line in enumerate(lines):
                match = re.match(r"^(\s*)(VitrailIcon|VitrailText)\s*\{\s*$", line)
                if match is None:
                    continue
                indent = len(match.group(1))
                kind = match.group(2)
                end = next(
                    (
                        other
                        for other in range(index + 1, len(lines))
                        if lines[other].strip() == "}" and len(lines[other]) - len(lines[other].lstrip()) <= indent
                    ),
                    None,
                )
                if end is not None:
                    blocks.append((path, index + 1, kind, lines[index + 1 : end]))
    return blocks


class ResolverTableTests(unittest.TestCase):
    def test_every_icon_the_qml_draws_is_in_the_table(self) -> None:
        table = resolver_names() | resolver_aliases()
        missing = sorted(qml_icon_names() - set(table))
        self.assertEqual(missing, [], f"kit/icons.js is missing: {', '.join(missing)}")

    def test_the_table_maps_each_name_to_its_own_ligature(self) -> None:
        for name, glyph in resolver_names().items():
            with self.subTest(name=name):
                self.assertEqual(glyph, name)

    def test_an_alias_points_at_a_name_in_the_table(self) -> None:
        table = resolver_names()
        for alias, target in resolver_aliases().items():
            with self.subTest(alias=alias):
                self.assertIn(target, table)

    def test_the_question_mark_is_itself_an_icon(self) -> None:
        self.assertEqual(resolver_names().get("question_mark"), "question_mark")

    def test_icon_blocks_set_icon_not_text(self) -> None:
        for path, line, kind, body in icon_blocks():
            if kind == "VitrailText" and not any(re.match(r'^\s*variant:\s*"icon"\s*$', row) for row in body):
                continue
            with self.subTest(file=str(path.relative_to(ROOT)), line=line):
                self.assertTrue(
                    any(re.match(r"^\s*icon:", row) for row in body),
                    f"{path.relative_to(ROOT)}:{line} draws an icon through `text`",
                )
                self.assertFalse(
                    any(re.match(r"^\s*text:", row) for row in body),
                    f"{path.relative_to(ROOT)}:{line} draws an icon through `text`",
                )


class ResolverWiringTests(unittest.TestCase):
    def test_icon_text_resolves_before_drawing(self) -> None:
        text = (ROOT / "kit" / "base" / "VitrailText.qml").read_text(encoding="utf-8")
        self.assertIn("VitrailIcons.resolve(root.icon)", text)

    def test_the_icon_primitive_feeds_the_resolver(self) -> None:
        text = (ROOT / "kit" / "base" / "VitrailIcon.qml").read_text(encoding="utf-8")
        self.assertIn("VitrailIcons.resolve(root.icon)", text)
        self.assertIn("icon: root.glyph", text)

    def test_the_resolver_is_a_registered_singleton(self) -> None:
        qmldir = (ROOT / "kit" / "qmldir").read_text(encoding="utf-8")
        self.assertIn("singleton VitrailIcons 1.0 VitrailIcons.qml", qmldir)


if __name__ == "__main__":
    unittest.main()
