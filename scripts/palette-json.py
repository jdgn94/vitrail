#!/usr/bin/env python3
"""Prints the wallpaper palette as JSON for the QML entry points."""

from __future__ import annotations

import json
import os
from pathlib import Path



def main() -> int:
    base = (
        Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache")))
        / "vitrail"
        / "generated"
    )
    out: dict[str, dict[str, str]] = {}
    for mode in ("dark", "light"):
        try:
            colors = json.loads((base / f"theme-{mode}.json").read_text())["colors"]
        except (OSError, ValueError, KeyError):
            continue
        # Every Material role: adaptive SVG previews may name any of them.
        out[mode] = colors
    print(json.dumps(out, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
