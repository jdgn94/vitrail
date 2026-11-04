#!/usr/bin/env python3
"""Prints every translation as one JSON bundle.

The QML runtime cannot read the JSON files itself, so the launchers pass this
bundle as an argument (the same way the palette and the plugin index travel).
Adding a language means dropping a JSON file in kit/i18n/.
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE_DIR = ROOT / "kit" / "i18n"
REFERENCE = "en"


def load() -> dict[str, dict]:
    languages: dict[str, dict] = {}
    for path in sorted(SOURCE_DIR.glob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except ValueError as error:
            raise SystemExit(f"{path.name}: invalid JSON ({error})")
        if "_label" not in data:
            raise SystemExit(f"{path.name}: missing _label")
        languages[path.stem] = data
    if REFERENCE not in languages:
        raise SystemExit(f"{REFERENCE}.json is required")
    reference = set(languages[REFERENCE])
    for code, table in languages.items():
        if set(table) != reference:
            raise SystemExit(f"{code}.json: keys differ from {REFERENCE}.json")
    return languages


def bundle() -> dict:
    languages = load()
    return {
        "languages": [{"key": code, "label": languages[code]["_label"]} for code in sorted(languages)],
        "strings": languages,
    }


def main() -> int:
    print(json.dumps(bundle(), ensure_ascii=False, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
