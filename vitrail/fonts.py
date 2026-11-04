"""Fonts, icon packs and cursor: what the machine has and how to apply a choice.

The settings window cannot run commands, so this module does both halves:

    python3 -m vitrail.fonts state            the installed lists, as JSON
    python3 -m vitrail.fonts apply            applies `fonts.ini`
    python3 -m vitrail.fonts console-family   the validated kitty family

`bin/vitrail-settings` injects `state` at launch; `scripts/apply-settings.sh`
runs `apply` when a preference changes. Nothing is curated here: the page
offers what fontconfig and the theme folders report.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path
from typing import Callable

MONO_SPACING = {100, 110}
# A hung fontconfig must not hang the settings watcher.
READ_TIMEOUT = 5

DEFAULT_ROOTS = [
    Path("/usr/share/icons"),
    Path.home() / ".icons",
    Path.home() / ".local/share/icons",
]

Runner = Callable[[list[str]], str | None]


def log(message: str) -> None:
    print(f"vitrail-fonts: {message}", file=sys.stderr, flush=True)


def font_query() -> list[str]:
    """The one call: every family alias and its spacing class (100 mono)."""
    return ["fc-list", "--format", "%{family}\t%{spacing}\n"]


def run_text(argv: list[str], timeout: int = READ_TIMEOUT) -> str | None:
    """A command's stdout, or None when it is missing, failed or timed out."""
    try:
        found = subprocess.run(argv, capture_output=True, text=True, timeout=timeout, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return found.stdout if found.returncode == 0 else None


def _faces(text: str) -> list[tuple[str, int]]:
    """(family, spacing) for every line of an `fc-list --format` answer."""
    faces: list[tuple[str, int]] = []
    for line in text.splitlines():
        aliases, _tab, spacing = line.partition("\t")
        try:
            number = int(spacing.strip())
        except ValueError:
            number = 0
        for name in aliases.split(","):
            name = name.strip()
            if name:
                faces.append((name, number))
    return faces


def _names(text: str, mono: bool | None = None) -> list[str]:
    """The distinct families, deduped case-insensitively and sorted."""
    seen: dict[str, str] = {}
    for name, spacing in _faces(text):
        if mono is not None and (spacing in MONO_SPACING) is not mono:
            continue
        seen.setdefault(name.casefold(), name)
    return sorted(seen.values(), key=str.casefold)


def families(text: str) -> list[str]:
    """Every installed family."""
    return _names(text)


def monospace(text: str) -> list[str]:
    """The families fontconfig calls monospace."""
    return _names(text, mono=True)


def themes(roots: list[Path]) -> tuple[list[str], list[str]]:
    """(icon themes, cursor themes) found one level under `roots`."""
    icons: dict[str, str] = {}
    cursors: dict[str, str] = {}
    for root in roots:
        try:
            entries = sorted(root.iterdir())
        except OSError:
            continue
        for path in entries:
            if not path.is_dir() or not (path / "index.theme").is_file():
                continue
            try:
                folders = [child.name for child in path.iterdir() if child.is_dir()]
            except OSError:
                continue
            if "cursors" in folders:
                cursors.setdefault(path.name.casefold(), path.name)
            if any(name != "cursors" for name in folders):
                icons.setdefault(path.name.casefold(), path.name)
    return (sorted(icons.values(), key=str.casefold), sorted(cursors.values(), key=str.casefold))


def state(run: Runner = run_text, roots: list[Path] | None = None) -> dict:
    """The lists the settings window offers: fonts, packs and cursors."""
    text = run(font_query()) or ""
    icons, cursors = themes(list(roots) if roots is not None else DEFAULT_ROOTS)
    return {
        "fonts": families(text),
        "monospace": monospace(text),
        "iconThemes": icons,
        "cursorThemes": cursors,
    }
