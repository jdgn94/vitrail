"""Shareable style files.

A style is a small JSON document with the design tokens a user tuned. It can be
exported, edited and imported on another machine, which is how styles are
shared without shipping a whole dotfiles repository.
"""

from __future__ import annotations

import configparser
import json
import os
from pathlib import Path

VERSION = 1

# Defaults mirror kit/tokens.js. Keep both in sync: tests compare them.
DEFAULTS = {
    "spacing": 12,
    "radius": 14,
    "blur": 6,
    "opacity": 0.9,
    "fontBase": 13,
}

# settings.ini key for each token (the panel already stores some of these).
INI_KEYS = {
    "spacing": "spacing",
    "radius": "radius",
    "blur": "blurStrength",
    "opacity": "surfaceOpacity",
    "fontBase": "fontBase",
}


def settings_path() -> Path:
    base = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    return base / "vitrail" / "settings.ini"


def read_style(path: Path | None = None) -> dict:
    parser = configparser.ConfigParser(interpolation=None)
    parser.optionxform = str
    parser.read(path or settings_path(), encoding="utf-8")
    section = parser["appearance"] if parser.has_section("appearance") else {}

    tokens = {}
    for name, default in DEFAULTS.items():
        raw = section.get(INI_KEYS[name], "")
        try:
            tokens[name] = float(raw) if "." in raw else int(raw)
        except (TypeError, ValueError):
            tokens[name] = default
    tokens["fontBase"] = int(tokens["fontBase"])

    return {
        "version": VERSION,
        "surface": section.get("surfaceStyle", "glass"),
        "tokens": tokens,
    }


def write_style(style: dict, path: Path | None = None) -> list[str]:
    """Writes the tokens into settings.ini, leaving every other key alone."""
    target = path or settings_path()
    target.parent.mkdir(parents=True, exist_ok=True)

    parser = configparser.ConfigParser(interpolation=None)
    parser.optionxform = str
    parser.read(target, encoding="utf-8")
    if not parser.has_section("appearance"):
        parser.add_section("appearance")

    changed: list[str] = []
    tokens = style.get("tokens", {})
    for name, default in DEFAULTS.items():
        value = tokens.get(name, default)
        parser.set("appearance", INI_KEYS[name], str(value))
        changed.append(f"{INI_KEYS[name]}={value}")

    surface = style.get("surface")
    if surface in ("solid", "glass"):
        parser.set("appearance", "surfaceStyle", surface)
        changed.append(f"surfaceStyle={surface}")

    with target.open("w", encoding="utf-8") as handle:
        parser.write(handle)
    return changed


def load(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict) or "tokens" not in data:
        raise ValueError("not a Vitrail style file")
    return data


def dump(style: dict, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(style, indent=2) + "\n", encoding="utf-8")
