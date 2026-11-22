"""Every QML document in the tree parses as a balanced one.

A merge can glue two blocks together and drop a closer. Nothing loaded
`bar/shell.qml`, so the whole bar stayed unparsable while every test passed.
This reads the files instead of trusting that some test happens to import them:
comments and string literals are stripped (a brace inside a label is not
structure), then the brackets are matched and a merge marker is a failure.
"""

from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DIRECTORIES = ("bar", "kit", "shell", "gallery", "lock", "login")
OPENING = {"(": ")", "[": "]", "{": "}"}
CLOSING = {value: key for key, value in OPENING.items()}
MARKER = "<<<<<<<"
REGEX_AFTER = set("([{=,:;!&|?+-*%~^<>")
REGEX_WORDS = {"return", "typeof", "case", "in", "of", "void", "new", "delete"}


def strip_noise(text: str) -> list[tuple[str, int]]:
    """The characters that are structure, each with its line number.

    Line comments, block comments, the three kinds of string literal and
    regular expression literals are skipped; an unterminated one runs to the
    end, which the caller reports as a different failure. Whether a `/` opens a
    regex is the usual heuristic: after an operator, an opening bracket or one
    of the keywords that expect an expression.
    """
    kept: list[tuple[str, int]] = []
    index, line, length = 0, 1, len(text)
    previous = ""
    word = ""
    while index < length:
        char = text[index]
        if char == "/" and index + 1 < length and text[index + 1] == "/":
            end = text.find("\n", index)
            index = length if end < 0 else end
        elif char == "/" and index + 1 < length and text[index + 1] == "*":
            end = text.find("*/", index + 2)
            index = length if end < 0 else end + 2
        elif char in "\"'`":
            quote = char
            index += 1
            while index < length:
                if text[index] == "\\":
                    index += 2
                    continue
                if text[index] == quote:
                    index += 1
                    break
                if text[index] == "\n":
                    line += 1
                index += 1
            previous, word = quote, ""
        elif char == "/" and (previous in REGEX_AFTER or word in REGEX_WORDS):
            index += 1
            in_class = False
            while index < length:
                if text[index] == "\\":
                    index += 2
                    continue
                if text[index] == "[":
                    in_class = True
                elif text[index] == "]":
                    in_class = False
                elif text[index] == "/" and not in_class:
                    index += 1
                    break
                index += 1
            previous, word = "/", ""
        else:
            if char.isspace():
                if char == "\n":
                    line += 1
                index += 1
                continue
            kept.append((char, line))
            if char.isalnum() or char in "_$":
                word += char
                previous = char
            else:
                word = ""
                previous = char
            index += 1
    return kept


def imbalance(path: Path) -> str | None:
    """A description of the first structural problem, or None."""
    text = path.read_text(encoding="utf-8")
    if MARKER in text:
        line = text[: text.index(MARKER)].count("\n") + 1
        return f"{path.relative_to(ROOT)}:{line}: merge marker left in the file"
    stack: list[tuple[str, int]] = []
    for char, line in strip_noise(text):
        if char in OPENING:
            stack.append((char, line))
        elif char in CLOSING:
            if not stack:
                return f"{path.relative_to(ROOT)}:{line}: '{char}' closes nothing"
            opener, opened = stack.pop()
            if opener != CLOSING[char]:
                return f"{path.relative_to(ROOT)}:{line}: '{opener}' from line {opened} closed by '{char}'"
    if stack:
        opener, opened = stack[-1]
        return f"{path.relative_to(ROOT)}:{opened}: '{opener}' is never closed"
    return None


def qml_files() -> list[Path]:
    files: list[Path] = []
    for name in DIRECTORIES:
        folder = ROOT / name
        if folder.is_dir():
            files.extend(sorted(folder.rglob("*.qml")))
    return files


class QmlBalanceTests(unittest.TestCase):
    def test_every_qml_file_is_balanced(self) -> None:
        files = qml_files()
        self.assertGreater(len(files), 50, "the QML scan found almost nothing")
        problems = [problem for problem in (imbalance(path) for path in files) if problem]
        self.assertEqual(problems, [], "unbalanced QML:\n" + "\n".join(problems))

    def test_the_bar_shell_is_in_the_scan(self) -> None:
        # The file that broke was not loaded by any other test; keep it here.
        self.assertIn(ROOT / "bar" / "shell.qml", set(qml_files()))


if __name__ == "__main__":
    unittest.main()
