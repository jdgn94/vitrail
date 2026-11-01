"""The clipboard store's own settings.

`cliphist` keeps its limits in a flags file, read on every invocation, so
Vitrail writes the history size there instead of passing it on each call.
"""

from __future__ import annotations

import os
from pathlib import Path

# The history size when the preference is missing.
DEFAULT_MAX = 100


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
