"""The clipboard store's own settings, and the colour copies it drops.

`cliphist` keeps its limits in a flags file, read on every invocation, so
Vitrail writes the history size there instead of passing it on each call.

A colour is not a copy: the palette and the colour picker put one on the
clipboard, but the history should not fill with the colours the user tried.
`forget_color` waits for the watcher to store the copy, then deletes the
entries whose preview is exactly that colour. Copying a history entry never
comes through here.
"""

from __future__ import annotations

import os
import re
import subprocess
import time
from pathlib import Path
from typing import Callable

# The history size when the preference is missing.
DEFAULT_MAX = 100

# How long the watcher gets to store a colour before it is dropped; a copy is
# visible to `wl-paste --watch` almost at once, but not synchronously.
STORE_WAIT = 0.8

COLOR = re.compile(
    r"^(?:#[0-9a-f]{3}|#[0-9a-f]{6}|#[0-9a-f]{8}|(?:rgb|rgba|hsl|hsla)\([^)]*\))$",
    re.IGNORECASE,
)

Runner = Callable[..., bytes | None]


def config_path() -> Path:
    """Where cliphist reads its flags."""
    home = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    return home / "cliphist" / "config"


def apply(max_items: int) -> Path:
    """Writes the history size where cliphist reads it."""
    path = config_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(f"-max-items {int(max_items)}\n", encoding="utf-8")
    return path


def _run(argv: list[str], data: bytes | None = None) -> bytes | None:
    try:
        found = subprocess.run(argv, input=data, capture_output=True, check=False)
    except OSError:
        return None
    return found.stdout if found.returncode == 0 else None


def forget_color(
    text: str,
    delay: float = STORE_WAIT,
    run: Runner = _run,
    sleep: Callable[[float], None] = time.sleep,
) -> int:
    """Drops a colour copy from the history; returns how many entries went.

    Only the entries whose preview is exactly the colour are removed, so a
    copied sentence that contains it (a CSS rule, a hex in a note) stays.
    """
    value = str(text or "").strip()
    if not COLOR.match(value):
        return 0
    sleep(delay)
    listing = run(["cliphist", "list"]) or b""
    ids = []
    for line in listing.decode("utf-8", errors="replace").splitlines():
        ident, _, preview = line.partition("\t")
        if ident.strip() and preview.strip().lower() == value.lower():
            ids.append(ident.strip())
    if ids:
        run(["cliphist", "delete"], ("\n".join(ids) + "\n").encode("utf-8"))
    return len(ids)
