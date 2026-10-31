"""Shareable style files.

A style is a small JSON document with the design tokens a user tuned. It can be
exported, edited and imported on another machine, which is how styles are
shared without shipping a whole dotfiles repository.
"""

from __future__ import annotations

import json
from pathlib import Path

from vitrail import prefs

VERSION = 1

# Defaults mirror kit/tokens.js. Keep both in sync: tests compare them.
DEFAULTS = {
    "spacing": 12,
    "radius": 14,
    "blur": 6,
    "opacity": 0.9,
    "fontBase": 13,
}

# Preference key for each token (the panel already stores some of these).
INI_KEYS = {
    "spacing": "spacing",
    "radius": "radius",
    "blur": "blurStrength",
    "opacity": "surfaceOpacity",
    "fontBase": "fontBase",
}


def read_style(config: Path | None = None) -> dict:
    stored = prefs.read_prefs(config or prefs.config_dir())

    tokens = {}
    for name, default in DEFAULTS.items():
        raw = stored.get(INI_KEYS[name], "")
        try:
            tokens[name] = float(raw) if "." in raw else int(raw)
        except (TypeError, ValueError):
            tokens[name] = default
    tokens["fontBase"] = int(tokens["fontBase"])

    return {
        "version": VERSION,
        "surface": stored.get("surfaceStyle", "glass"),
        "tokens": tokens,
    }


def write_style(style: dict, config: Path | None = None) -> list[str]:
    """Writes the tokens into the preference files, leaving every other key alone."""
    target = config or prefs.config_dir()

    changed: list[str] = []
    tokens = style.get("tokens", {})
    for name, default in DEFAULTS.items():
        value = tokens.get(name, default)
        prefs.write_pref(target, INI_KEYS[name], str(value))
        changed.append(f"{INI_KEYS[name]}={value}")

    surface = style.get("surface")
    if surface in ("solid", "glass"):
        prefs.write_pref(target, "surfaceStyle", surface)
        changed.append(f"surfaceStyle={surface}")
    return changed


def load(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict) or "tokens" not in data:
        raise ValueError("not a Vitrail style file")
    return data


def dump(style: dict, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(style, indent=2) + "\n", encoding="utf-8")
