"""Safe mode: a minimal session for when the normal Hyprland config breaks.

A broken config can leave the session without a bar and without a way to open
the settings window. Safe mode starts Hyprland with the shipped fallback
config (dots/.config/hypr/safe.lua), which only knows: close window, terminal,
settings and exit. The marker file records that the user chose it, so the
settings window and `vitrail doctor` can say so.
"""

from __future__ import annotations

import os
import subprocess
from pathlib import Path
from typing import Callable

MARKER = "safe-mode"
SAFE_CONFIG = Path(__file__).resolve().parent.parent / "dots" / ".config" / "hypr" / "safe.lua"


def marker_path(config: Path) -> Path:
    return config / MARKER


def is_active(config: Path) -> bool:
    return marker_path(config).exists()


def enter(config: Path) -> Path:
    config.mkdir(parents=True, exist_ok=True)
    path = marker_path(config)
    path.write_text("safe mode\n", encoding="utf-8")
    return path


def exit(config: Path) -> bool:
    """Leaves safe mode. Returns whether there was a marker to remove."""
    path = marker_path(config)
    if not path.exists():
        return False
    path.unlink()
    return True


def config_errors(
    run: Callable[..., subprocess.CompletedProcess] = subprocess.run,
) -> list[str]:
    """Hyprland's config errors, empty when the config loaded."""
    try:
        result = run(["hyprctl", "configerrors"], capture_output=True, text=True)
    except OSError:
        return []
    text = (result.stdout or "").strip()
    return [line.strip() for line in text.splitlines() if line.strip()]


def session_command(hyprland: str = "Hyprland") -> list[str]:
    return [hyprland, "-c", str(SAFE_CONFIG)]


def run_session(hyprland: str = "Hyprland") -> None:
    """Replaces this process with a safe Hyprland session."""
    command = session_command(hyprland)
    os.execvp(command[0], command)
