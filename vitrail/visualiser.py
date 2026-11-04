"""The audio visualiser: cava's spectrum, reduced to one small JSON file.

cava is the only program that listens to PipeWire and turns the mix into
levels. It runs in raw ASCII mode (64 bars, 60 frames a second) and this
module samples those frames at most every 50 ms, writing the last one to
``$XDG_RUNTIME_DIR/vitrail/cava.json`` as ``{"values": [...]}``. The bar's
background layer watches that file; no D-Bus or IPC surface is needed.

    python3 -m vitrail.visualiser start    # runs until stopped (the bar's Process)
    python3 -m vitrail.visualiser stop
    python3 -m vitrail.visualiser state

The process is injected into the helpers, so tests never start cava or play
audio.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import signal
import subprocess
import time
from pathlib import Path
from typing import Callable, Iterable

# What the bar and the QML helper expect: cava's 0..100 scale, 64 bars. The
# file is written at most every 50 ms, whatever frame rate cava uses.
BARS = 64
FPS = 60
INTERVAL = 0.05
MAX_RANGE = 100
CONFIG = "cava.conf"
STATE = "cava.json"
PID = "cava.pid"


def runtime_dir() -> Path:
    """Where the bar and this module meet: $XDG_RUNTIME_DIR/vitrail."""
    return Path(os.environ.get("XDG_RUNTIME_DIR") or "/tmp") / "vitrail"


def config_path(runtime: Path) -> Path:
    return runtime / CONFIG


def state_path(runtime: Path) -> Path:
    return runtime / STATE


def pid_path(runtime: Path) -> Path:
    return runtime / PID


# What starts cava: our written configuration, raw frames on stdout.
def command(runtime: Path) -> list[str]:
    return ["cava", "-p", str(config_path(runtime))]


def config_text() -> str:
    """cava's raw stdout configuration: 64 bars at 60 frames a second."""
    return (
        "; Written by vitrail.visualiser; the bar reads the same values.\n"
        "[general]\n"
        f"bars = {BARS}\n"
        f"framerate = {FPS}\n"
        "\n"
        "[output]\n"
        "method = raw\n"
        "raw_target = /dev/stdout\n"
        "data_format = ascii\n"
        f"ascii_max_range = {MAX_RANGE}\n"
        "bar_delimiter = 59\n"
        "frame_delimiter = 10\n"
    )


def _number(value: object) -> int:
    """One cava value: an integer on the 0..100 scale, broken values as zero."""
    try:
        number = float(str(value).strip())
    except (TypeError, ValueError):
        return 0
    if not math.isfinite(number):
        return 0
    return max(0, min(MAX_RANGE, int(number)))


def parse_frame(text: str, bars: int = BARS) -> list[int]:
    """A raw ASCII frame ("12;80;...") as exactly `bars` values."""
    values = [_number(part) for part in str(text).replace("\n", " ").split(";") if part.strip() != ""]
    values = values[:bars]
    return values + [0] * (bars - len(values))


def read_state(runtime: Path) -> dict:
    try:
        document = json.loads(state_path(runtime).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    return document if isinstance(document, dict) else {}


def write_state(runtime: Path, values: Iterable[object]) -> dict:
    """Writes the last frame; replaced in one step so the bar never sees half a file."""
    state = {"values": [_number(value) for value in values]}
    runtime.mkdir(parents=True, exist_ok=True)
    target = state_path(runtime)
    temporary = target.with_name(target.name + ".part")
    temporary.write_text(json.dumps(state) + "\n", encoding="utf-8")
    temporary.replace(target)
    return state


def consume(
    lines: Iterable[str],
    runtime: Path,
    clock: Callable[[], float] = time.monotonic,
    bars: int = BARS,
) -> tuple[int, list[int]]:
    """Writes a frame every INTERVAL seconds; returns (writes, last values)."""
    writes = 0
    last: float | None = None
    values = [0] * bars
    for line in lines:
        values = parse_frame(line, bars)
        now = clock()
        if last is None or now - last >= INTERVAL:
            write_state(runtime, values)
            writes += 1
            last = now
    return writes, values


def pid_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def _pid(runtime: Path) -> int | None:
    try:
        return int(pid_path(runtime).read_text(encoding="utf-8").strip())
    except (OSError, ValueError):
        return None


def running(runtime: Path, alive: Callable[[int], bool] = pid_alive) -> bool:
    pid = _pid(runtime)
    return bool(pid and alive(pid))


def start(
    runtime: Path,
    popen: Callable[..., subprocess.Popen] = subprocess.Popen,
    clock: Callable[[], float] = time.monotonic,
    alive: Callable[[int], bool] = pid_alive,
    timeout: float = 2.0,
) -> dict:
    """Runs cava in the foreground, writing its last frame for the bar."""
    if running(runtime, alive):
        return read_state(runtime)

    runtime.mkdir(parents=True, exist_ok=True)
    config = config_path(runtime)
    config.write_text(config_text(), encoding="utf-8")
    process = popen(
        command(runtime),
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        bufsize=1,
    )
    pid_path(runtime).write_text(f"{process.pid}\n", encoding="utf-8")
    try:
        consume(process.stdout or [], runtime, clock=clock)
    finally:
        try:
            process.terminate()
            process.wait(timeout=timeout)
        except (OSError, subprocess.TimeoutExpired):
            pass
        pid_path(runtime).unlink(missing_ok=True)
    return read_state(runtime)


def stop(
    runtime: Path,
    kill: Callable[[int, int], None] = os.kill,
    alive: Callable[[int], bool] = pid_alive,
    sleep: Callable[[float], None] = time.sleep,
) -> None:
    """Stops our cava (safe to call when nothing runs) and forgets the frame."""
    pid = _pid(runtime)
    if pid and alive(pid):
        try:
            kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        for _ in range(10):
            if not alive(pid):
                break
            sleep(0.02)
    pid_path(runtime).unlink(missing_ok=True)
    state_path(runtime).unlink(missing_ok=True)


def state(runtime: Path, alive: Callable[[int], bool] = pid_alive) -> dict:
    return {"running": running(runtime, alive), "values": read_state(runtime).get("values", [])}


def main(
    argv: list[str] | None = None,
    print_: Callable[[str], None] = print,
    popen: Callable[..., subprocess.Popen] = subprocess.Popen,
    kill: Callable[[int, int], None] = os.kill,
    alive: Callable[[int], bool] = pid_alive,
) -> int:
    parser = argparse.ArgumentParser(prog="vitrail-visualiser", description="cava levels for the bar")
    parser.add_argument("action", choices=("start", "stop", "state"))
    parser.add_argument("--runtime", default=None, help="runtime directory (default: $XDG_RUNTIME_DIR/vitrail)")
    args = parser.parse_args(argv)
    runtime = Path(args.runtime) if args.runtime else runtime_dir()

    if args.action == "start":

        def terminate(_signum: int, _frame: object) -> None:
            raise KeyboardInterrupt

        previous = signal.signal(signal.SIGTERM, terminate)
        try:
            start(runtime, popen=popen, alive=alive)
        except KeyboardInterrupt:
            stop(runtime, kill=kill, alive=alive)
        except OSError as error:
            print_(f"vitrail-visualiser: {error}")
            return 1
        finally:
            signal.signal(signal.SIGTERM, previous)
    elif args.action == "stop":
        stop(runtime, kill=kill, alive=alive)
    else:
        print_(json.dumps(state(runtime, alive)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
