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

from vitrail.wallpaper import kind_of

ENGINES = {"image": "awww", "svg": "awww", "video": "mpvpaper"}
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


def write_state(cache: Path, engine: str, path: str, kind: str) -> dict:
    state = {"engine": engine, "path": path, "kind": kind}
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
) -> dict:
    """Displays `path` with the engine its kind needs, and records the state."""
    kind = kind_of(path)
    engine = engine_for(kind or "")
    if engine is None:
        raise ValueError(f"not a wallpaper: {path}")

    stop(cache, run)
    if engine == "awww":
        if not awww_running(run):
            spawn(["awww-daemon"])
            for _ in range(attempts):
                if awww_running(run):
                    break
                sleep(0.05)
        _call(run, ["awww", "img", path, *AWWW_OPTIONS], check=True)
    else:
        _call(run, ["mpvpaper", "-f", "-o", MPV_OPTIONS, OUTPUT, path], check=True)
    return write_state(cache, engine, path, kind)
