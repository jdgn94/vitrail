"""Screenshots and screen recording through grim, slurp and wf-recorder.

Three capture modes (full screen, active window, region) and one recording
session, all without a helper daemon:

    python3 -m vitrail.capture shot full|window|region
    python3 -m vitrail.capture record start|stop|toggle [--region]
    python3 -m vitrail.capture status

The bar's panel calls these; the recording state lives in
`$XDG_RUNTIME_DIR/vitrail/record.json`, which the bar watches to light its
indicator and to offer "stop".
"""

from __future__ import annotations

import json
import os
import shutil
import signal
import subprocess
import sys
import time
from pathlib import Path
from typing import Callable

Runner = Callable[[list[str]], str | None]
Spawner = Callable[[list[str], Path], int]

STAMP = "%Y-%m-%d_%H-%M-%S"


def log(message: str) -> None:
    print(f"vitrail-capture: {message}", file=sys.stderr, flush=True)


def run_text(argv: list[str]) -> str | None:
    try:
        found = subprocess.run(argv, capture_output=True, text=True, check=False)
    except OSError:
        return None
    return found.stdout if found.returncode == 0 else None


def run_bytes(argv: list[str], data: bytes) -> bool:
    try:
        found = subprocess.run(argv, input=data, capture_output=True, check=False)
    except OSError:
        return False
    return found.returncode == 0


def spawn(argv: list[str], log_path: Path) -> int:
    """Starts a detached process and returns its pid."""
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with open(log_path, "ab") as log_file:
        process = subprocess.Popen(
            argv, stdout=log_file, stderr=log_file, stdin=subprocess.DEVNULL, start_new_session=True
        )
    return process.pid


def runtime_dir() -> Path:
    base = os.environ.get("XDG_RUNTIME_DIR") or "/tmp"
    return Path(base) / "vitrail"


def status_file(runtime: Path | None = None) -> Path:
    return (runtime or runtime_dir()) / "record.json"


def pictures() -> str:
    return str(Path.home() / "Pictures" / "Screenshots")


def videos() -> str:
    return str(Path.home() / "Videos" / "Recordings")


# --- screenshots -------------------------------------------------------------


def target(directory: str, now: float | None = None, suffix: str = "png") -> Path:
    folder = Path(directory).expanduser()
    folder.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime(STAMP, time.localtime(now))
    return folder / f"Screenshot_{stamp}.{suffix}"


def geometry(mode: str, run: Runner = run_text) -> str | None:
    """The grim `-g` argument, "" for the whole screen, None when cancelled."""
    if mode == "full":
        return ""
    if mode == "region":
        answer = run(["slurp"])
        return answer.strip() if answer and answer.strip() else None
    answer = run(["hyprctl", "activewindow", "-j"])
    try:
        window = json.loads(answer or "")
        x, y = window["at"]
        width, height = window["size"]
    except (TypeError, ValueError, KeyError):
        return None
    if width <= 0 or height <= 0:
        return None
    return f"{int(width)}x{int(height)}+{int(x)}+{int(y)}"


def shot(
    mode: str,
    directory: str | None = None,
    copy: bool = True,
    annotate: bool = False,
    run: Runner = run_text,
    copy_run=run_bytes,
    annotate_run: Runner = run_text,
    now: float | None = None,
) -> dict:
    """Saves one screenshot; {"path"} or {"error"}."""
    area = geometry(mode, run)
    if area is None:
        return {"error": "cancelled"}
    path = target(directory or pictures(), now)
    command = ["grim"] + (["-g", area] if area else []) + [str(path)]
    if run(command) is None:
        return {"error": "grim failed"}
    if copy:
        try:
            copied = copy_run(["wl-copy"], path.read_bytes())
        except OSError:
            copied = False
        if not copied:
            log("the screenshot was saved but not copied")
    if annotate:
        if shutil.which("swappy"):
            annotate_run(["swappy", "-f", str(path)])
        else:
            log("swappy is not installed; the screenshot is unannotated")
    return {"path": str(path)}


# --- recording ---------------------------------------------------------------


def _alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    return True


def status(runtime: Path | None = None, alive: Callable[[int], bool] = _alive) -> dict:
    path = status_file(runtime)
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    pid = document.get("pid")
    if not isinstance(pid, int) or not alive(pid):
        return {}
    return document


def _write_status(document: dict, runtime: Path | None = None) -> None:
    path = status_file(runtime)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.part")
    temporary.write_text(json.dumps(document, separators=(",", ":")), encoding="utf-8")
    os.replace(temporary, path)


def record(
    action: str,
    directory: str | None = None,
    region: bool = False,
    audio: bool = False,
    runtime: Path | None = None,
    run: Runner = run_text,
    spawner: Spawner = spawn,
    killer: Callable[[int, int], None] = os.kill,
    alive: Callable[[int], bool] = _alive,
    now: float | None = None,
) -> dict:
    """start / stop / toggle; {"path"} or {"recording": bool}."""
    current = status(runtime, alive)
    if action == "toggle":
        action = "stop" if current else "start"
    if action == "stop":
        if not current:
            return {"recording": False}
        try:
            killer(current["pid"], signal.SIGINT)
        except OSError:
            pass
        for _ in range(20):
            if not alive(current["pid"]):
                break
            time.sleep(0.05)
        _write_status({}, runtime)
        return {"recording": False, "path": current.get("path", "")}
    if action != "start":
        return {"error": f"unknown action {action!r}"}
    if current:
        return {"recording": True, "path": current.get("path", "")}

    area = ""
    if region:
        area = geometry("region", run) or ""
        if not area:
            return {"error": "cancelled"}
    folder = Path(directory or videos()).expanduser()
    folder.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime(STAMP, time.localtime(now))
    path = folder / f"Recording_{stamp}.mp4"
    command = ["wf-recorder"] + (["-a"] if audio else []) + (["-g", area] if area else []) + ["-f", str(path)]
    pid = spawner(command, (runtime or runtime_dir()) / "record.log")
    _write_status({"pid": pid, "path": str(path), "started": int(time.time())}, runtime)
    return {"recording": True, "path": str(path)}


# --- entry -------------------------------------------------------------------


def _preferences() -> dict:
    from . import prefs

    try:
        return prefs.read_prefs(prefs.config_dir())
    except OSError:
        return {}


def _flag(value: object, fallback: bool) -> bool:
    if value is None or value == "":
        return fallback
    return str(value).strip().lower() in ("true", "1", "yes", "on")


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    values = _preferences()
    if args[:1] == ["shot"] and len(args) >= 2:
        result = shot(
            args[1], directory=values.get("captureDir") or pictures(), copy=_flag(values.get("captureCopy"), True)
        )
        print(json.dumps(result, separators=(",", ":")))
        return 0 if "path" in result else 1
    if args[:1] == ["record"] and len(args) >= 2:
        result = record(
            args[1],
            directory=values.get("captureRecordDir") or videos(),
            region="--region" in args,
            audio=_flag(values.get("captureRecordAudio"), False),
        )
        print(json.dumps(result, separators=(",", ":")))
        return 0 if "error" not in result else 1
    if args[:1] == ["status"]:
        print(json.dumps(status(), separators=(",", ":")))
        return 0
    print(
        "usage: capture shot <full|window|region> | record <start|stop|toggle> [--region] [--audio] | status",
        file=sys.stderr,
    )
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
