"""Wallpaper supervisor: awww for stills, mpvpaper for video.

The library and the palette live in vitrail/wallpaper.py; this module only puts
the selected file on screen and remembers which engine owns it. awww caches
every frame at output resolution, so animated files always go to mpvpaper,
which streams and decodes on the GPU.
"""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Callable

from vitrail import effects
from vitrail.wallpaper import kind_of, parse_monitors

# `parse_monitors` is re-exported: the per-output document is what this module
# puts on screen.
__all__ = [
    "STILL_KINDS",
    "engine_for",
    "parse_monitors",
    "read_state",
    "show",
    "spawn_detached",
    "state_path",
    "stop",
    "write_state",
]

ENGINES = {"image": "awww", "svg": "awww", "video": "mpvpaper"}
# The kinds awww can put on one output; a video override stays on the global one.
STILL_KINDS = ("image", "svg")
STATE = "wallpaper.state"
AWWW_OPTIONS = ("--transition-type", "center", "--transition-duration", "1")
MPV_OPTIONS = "no-audio loop hwdec=vaapi"
# mpvpaper takes one output or "*" for every connected one.
OUTPUT = "*"


def engine_for(kind: str) -> str | None:
    return ENGINES.get(kind)


def state_path(cache: Path) -> Path:
    return cache / STATE


def read_state(cache: Path) -> dict:
    try:
        return json.loads(state_path(cache).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def write_state(cache: Path, engine: str, path: str, kind: str, outputs: dict[str, str] | None = None) -> dict:
    state = {"engine": engine, "path": path, "kind": kind}
    if outputs:
        state["outputs"] = outputs
    cache.mkdir(parents=True, exist_ok=True)
    state_path(cache).write_text(json.dumps(state) + "\n", encoding="utf-8")
    return state


def spawn_detached(argv: list[str]) -> None:
    """Starts a long running daemon without waiting for it."""
    subprocess.Popen(
        argv,
        start_new_session=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def _call(run: Callable[..., subprocess.CompletedProcess], argv: list[str], **kwargs):
    """Runs a command, tolerating one that is not installed."""
    try:
        return run(argv, **kwargs)
    except FileNotFoundError:
        return None


def awww_running(run: Callable[..., subprocess.CompletedProcess] = subprocess.run) -> bool:
    result = _call(run, ["awww", "query"], capture_output=True, text=True)
    return bool(result is not None and result.returncode == 0)


def stop(cache: Path, run: Callable[..., subprocess.CompletedProcess] = subprocess.run) -> None:
    """Stops both engines; safe to call when nothing is running."""
    _call(run, ["pkill", "-x", "mpvpaper"], check=False)
    if awww_running(run):
        _call(run, ["awww", "kill"], check=False)
    state_path(cache).unlink(missing_ok=True)


def show(
    path: str,
    cache: Path,
    run: Callable[..., subprocess.CompletedProcess] = subprocess.run,
    sleep: Callable[[float], None] = time.sleep,
    spawn: Callable[[list[str]], None] = spawn_detached,
    attempts: int = 20,
    monitors: dict[str, dict[str, str]] | None = None,
    effect: str = "none",
    derive: Callable[..., Path] | None = None,
) -> dict:
    """Displays `path` with the engine its kind needs, and records the state.

    `monitors` holds the per-output overrides: each one, still the global
    picture; the global one covers every output first, so an output without an
    override (or whose picture is gone) keeps it. The effect is baked into the
    derived file before it is shown.
    """
    kind = kind_of(path)
    engine = engine_for(kind or "")
    if engine is None:
        raise ValueError(f"not a wallpaper: {path}")

    derive = derive or effects.derive
    stop(cache, run)
    shown = str(derive(path, effect, cache, run=run))
    if engine == "awww":
        if not awww_running(run):
            spawn(["awww-daemon"])
            for _ in range(attempts):
                if awww_running(run):
                    break
                sleep(0.05)
        _call(run, ["awww", "img", shown, *AWWW_OPTIONS], check=True)
        outputs: dict[str, str] = {}
        for output, entry in sorted((monitors or {}).items()):
            chosen = entry.get("wallpaper") or path
            if kind_of(chosen) not in STILL_KINDS or not Path(chosen).is_file():
                continue
            one = str(derive(chosen, entry.get("effect") or effect, cache, run=run))
            _call(run, ["awww", "img", "-o", output, one, *AWWW_OPTIONS], check=True)
            outputs[output] = one
        return write_state(cache, engine, shown, kind, outputs)
    _call(run, ["mpvpaper", "-f", "-o", MPV_OPTIONS, OUTPUT, shown], check=True)
    return write_state(cache, engine, shown, kind)
