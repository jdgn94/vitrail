#!/usr/bin/env python3
"""Build `assets/emoji.json` from the Unicode data.

The panel needs three things per emoji: the character, its group (for the
category filter) and words to search for in English and Spanish. Unicode's
`emoji-test.txt` gives the character, the group and the English name; CLDR's
`annotations/*.xml` give the keywords in each language.

Usage:
    scripts/build-emoji.py EMOJI_TEST EN.XML ES.XML > assets/emoji.json

Download the sources with:

    curl -o emoji-test.txt https://unicode.org/Public/emoji/latest/emoji-test.txt
    curl -o en.xml https://raw.githubusercontent.com/unicode-org/cldr/main/common/annotations/en.xml
    curl -o es.xml https://raw.githubusercontent.com/unicode-org/cldr/main/common/annotations/es.xml
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from xml.etree import ElementTree

# "1F600 ; fully-qualified # 😀 E1.0 grinning face"
LINE = re.compile(r"^([0-9A-F ]+)\s*;\s*(fully-qualified|component)\s*#\s*(\S+)\s+E[\d.]+\s+(.+)$")
GROUP = re.compile(r"^#\s*group:\s*(.+)$")


def read_emoji_test(path: Path) -> list[dict[str, str]]:
    """Every fully-qualified emoji with its character, group and English name."""
    entries: list[dict[str, str]] = []
    group = ""
    for line in path.read_text(encoding="utf-8").splitlines():
        found = GROUP.match(line.strip())
        if found:
            group = found.group(1).strip()
            continue
        found = LINE.match(line.strip())
        if not found or found.group(2) != "fully-qualified":
            continue
        entries.append({"e": found.group(3), "n": found.group(4).strip(), "g": group})
    return entries


def read_annotations(path: Path) -> dict[str, str]:
    """character -> keywords, from CLDR's keyword annotation."""
    out: dict[str, str] = {}
    root = ElementTree.parse(path).getroot()
    for annotation in root.iter("annotation"):
        if annotation.get("type") == "tts":
            continue
        text = (annotation.text or "").strip()
        if text:
            out[annotation.get("cp", "")] = text
    return out


def build(entries: list[dict[str, str]], english: dict[str, str], spanish: dict[str, str]) -> list[dict[str, str]]:
    """One row per emoji, with the words a search should match.

    The name and both keyword lists are kept whole (their `|` turned into a
    space), so "grinning face" and "cara sonriente" both match, and so does
    any single word inside them.
    """
    out: list[dict[str, str]] = []
    seen: set[str] = set()
    for entry in entries:
        char = entry["e"]
        if char in seen:
            continue
        seen.add(char)
        words = " ".join([entry["n"], english.get(char, ""), spanish.get(char, "")])
        out.append({
            "e": char,
            "n": entry["n"],
            "g": entry["g"],
            "k": re.sub(r"\s+", " ", words.replace("|", " ")).strip().lower(),
        })
    return out


def main(argv: list[str]) -> int:
    if len(argv) != 4:
        print(__doc__, file=sys.stderr)
        return 2
    entries = read_emoji_test(Path(argv[1]))
    rows = build(entries, read_annotations(Path(argv[2])), read_annotations(Path(argv[3])))
    json.dump(rows, sys.stdout, ensure_ascii=False, separators=(",", ":"))
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
