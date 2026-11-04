"""The documentation points at files and commands that exist."""

from __future__ import annotations

import contextlib
import io
import re
import unittest
from pathlib import Path

from vitrail import cli

ROOT = Path(__file__).resolve().parent.parent
LINK = re.compile(r"\]\(([^)\s]+)")
COMMAND = re.compile(r"`?vitrail (?!-)([a-z-]+)")
# Every documented command must exist; this list stays empty.
PLANNED: set[str] = set()


def cli_commands() -> set[str]:
    buffer = io.StringIO()
    with contextlib.redirect_stdout(buffer), contextlib.redirect_stderr(buffer):
        try:
            cli.main(["--help"])
        except SystemExit:
            pass
    match = re.search(r"\{([a-z,-]+)\}", buffer.getvalue())
    return set(match.group(1).split(",")) if match else set()


class LinkTests(unittest.TestCase):
    def documents(self) -> list[Path]:
        return [*sorted((ROOT / "docs").glob("*.md")), ROOT / "README.md"]

    def test_every_relative_link_resolves(self) -> None:
        for document in self.documents():
            text = document.read_text(encoding="utf-8")
            for target in LINK.findall(text):
                if target.startswith(("http://", "https://", "mailto:", "#")):
                    continue
                path = (document.parent / target.split("#", 1)[0]).resolve()
                with self.subTest(document=document.name, target=target):
                    self.assertTrue(path.exists(), f"{document.name}: {target}")

    def test_the_index_links_every_document(self) -> None:
        index = (ROOT / "docs" / "index.md").read_text(encoding="utf-8")
        for document in sorted((ROOT / "docs").glob("*.md")):
            if document.name == "index.md":
                continue
            with self.subTest(document=document.name):
                self.assertIn(f"({document.name})", index)


class CommandTests(unittest.TestCase):
    def test_documented_commands_exist(self) -> None:
        known = cli_commands()
        self.assertIn("update", known)
        for document in [*sorted((ROOT / "docs").glob("*.md")), ROOT / "README.md"]:
            for command in COMMAND.findall(document.read_text(encoding="utf-8")):
                if command in PLANNED:
                    continue
                with self.subTest(document=document.name, command=command):
                    self.assertIn(command, known)


if __name__ == "__main__":
    unittest.main()
