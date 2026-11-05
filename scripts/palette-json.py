#!/usr/bin/env python3
"""Prints the wallpaper palette as JSON for the QML entry points.

`vitrail colors` writes `generated/palette.json` with the theme files; this
reads it when it is there and falls back to joining the two theme summaries.
With `--write` it also leaves the file for the bar, which then needs no Python
at start-up.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path


def generated_dir() -> Path:
    return Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "vitrail" / "generated"


def palette(base: Path) -> dict[str, dict[str, str]]:
    try:
        stored = json.loads((base / "palette.json").read_text())
    except (OSError, ValueError):
        stored = {}
    if isinstance(stored, dict) and all(isinstance(stored.get(mode), dict) for mode in ("dark", "light")):
        return stored
    out: dict[str, dict[str, str]] = {}
    for mode in ("dark", "light"):
        try:
            colors = json.loads((base / f"theme-{mode}.json").read_text())["colors"]
        except (OSError, ValueError, KeyError):
            continue
        # Every Material role: adaptive SVG previews may name any of them.
        out[mode] = colors
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="also write generated/palette.json")
    args = parser.parse_args()
    base = generated_dir()
    data = palette(base)
    text = json.dumps(data, separators=(",", ":"))
    if args.write and data:
        base.mkdir(parents=True, exist_ok=True)
        (base / "palette.json").write_text(text + "\n", encoding="utf-8")
    print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
