"""Display brightness for the bar's OSD.

External monitors are read and written over DDC/CI with `ddcutil` (VCP 0x10),
laptop panels through `brightnessctl`. `ddcutil detect` takes seconds, so the
displays it finds are cached against the monitors Hyprland reports and detected
again only when those change. Everything that parses or decides is a pure
function; `collect` takes an injectable `run`, like `colors.generate`.

    python3 -m vitrail.cli brightness list     # JSON the OSD reads
"""

from __future__ import annotations

import glob
import json
import os
import re
import shutil
import subprocess
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Callable

TIMEOUT = 20
INTERNAL = ("eDP", "LVDS", "DSI")

Run = Callable[[list[str]], subprocess.CompletedProcess]


@dataclass(frozen=True)
class Display:
    bus: int
    connector: str
    make: str
    model: str
    serial: str


@dataclass(frozen=True)
class Backlight:
    device: str
    value: int
    maximum: int


def connector(drm: str) -> str:
    """`card1-DP-1` (the kernel's name) -> `DP-1` (Hyprland's)."""
    return re.sub(r"^card\d+-", "", drm.strip())


def parse_detect(text: str) -> list[Display]:
    """The displays of `ddcutil detect --brief`; invalid ones are skipped."""
    displays: list[Display] = []
    for block in re.split(r"\n\s*\n", text):
        lines = [line.strip() for line in block.strip().splitlines()]
        if not lines or not lines[0].startswith("Display "):
            continue
        fields = {key.strip().lower(): value.strip()
                  for key, _, value in (line.partition(":") for line in lines[1:]) if value}
        bus = re.search(r"i2c-(\d+)", fields.get("i2c bus", ""))
        if not bus:
            continue
        make, model, serial = "", "", ""
        parts = fields.get("monitor", "").split(":")
        if len(parts) >= 3:
            make, model, serial = parts[0], ":".join(parts[1:-1]), parts[-1]
        displays.append(Display(int(bus.group(1)), connector(fields.get("drm connector", "")), make, model, serial))
    return displays


def parse_getvcp(text: str) -> tuple[int, int] | None:
    """(current, maximum) of `ddcutil getvcp 10 --brief`."""
    found = re.search(r"VCP\s+10\s+C\s+(\d+)\s+(\d+)", text)
    return (int(found.group(1)), int(found.group(2))) if found else None


def parse_backlights(text: str) -> list[Backlight]:
    """The backlights of `brightnessctl -m -c backlight`: name,class,value,%,max."""
    lights: list[Backlight] = []
    for line in text.splitlines():
        parts = line.split(",")
        if len(parts) >= 5 and parts[1] == "backlight" and parts[2].isdigit() and parts[4].isdigit():
            lights.append(Backlight(parts[0], int(parts[2]), int(parts[4])))
    return lights


def percent(value: int, maximum: int) -> int:
    if maximum <= 0:
        return 0
    return max(0, min(100, round(value * 100 / maximum)))


def is_internal(name: str) -> bool:
    return name.startswith(INTERNAL)


def match_displays(displays: list[Display], monitors: list[dict]) -> dict[str, Display]:
    """Hyprland monitor name -> its display: by connector, then by serial."""
    mapped: dict[str, Display] = {}
    free = list(displays)
    for monitor in monitors:
        found = next((d for d in free if d.connector == monitor["name"]), None)
        if found:
            mapped[monitor["name"]] = found
            free.remove(found)
    for monitor in monitors:
        if monitor["name"] in mapped or not monitor.get("serial"):
            continue
        found = next((d for d in free if d.serial == monitor["serial"]), None)
        if found:
            mapped[monitor["name"]] = found
            free.remove(found)
    return mapped


def i2c_access(paths: list[str], usable: Callable[[str], bool]) -> str:
    """`ok` when some i2c bus can be read and written, else `access`."""
    return "ok" if any(usable(path) for path in paths) else "access"


def _system_access() -> str:
    return i2c_access(sorted(glob.glob("/dev/i2c-*")), lambda path: os.access(path, os.R_OK | os.W_OK))


def _run(cmd: list[str]) -> subprocess.CompletedProcess:
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=TIMEOUT)
    except (OSError, subprocess.TimeoutExpired):
        return subprocess.CompletedProcess(cmd, 1, "", "")


def cache_file() -> Path:
    base = os.environ.get("XDG_CACHE_HOME") or str(Path.home() / ".cache")
    return Path(base) / "vitrail" / "ddc.json"


def _monitors(run: Run) -> list[dict]:
    try:
        return json.loads(run(["hyprctl", "monitors", "-j"]).stdout or "[]")
    except json.JSONDecodeError:
        return []


def _cached(path: Path, key: list[str]) -> list[Display] | None:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        if data["key"] == key:
            return [Display(**item) for item in data["displays"]]
    except (OSError, ValueError, KeyError, TypeError):
        pass
    return None


def _store(path: Path, key: list[str], displays: list[Display]) -> None:
    if not displays:
        return
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps({"key": key, "displays": [asdict(d) for d in displays]}), encoding="utf-8")
    except OSError:
        pass


def _read(run: Run, mapped: dict[str, Display]) -> dict[str, tuple[int, int] | None]:
    def one(item: tuple[str, Display]) -> tuple[str, tuple[int, int] | None]:
        name, display = item
        result = run(["ddcutil", "getvcp", "10", "--brief", "--bus", str(display.bus)])
        return name, parse_getvcp(result.stdout) if result.returncode == 0 else None

    with ThreadPoolExecutor(max_workers=max(1, len(mapped))) as pool:
        return dict(pool.map(one, mapped.items()))


def _external(run: Run, path: Path, monitors: list[dict]) -> list[dict]:
    key = sorted(f"{m['name']}|{m.get('serial', '')}" for m in monitors)
    displays = _cached(path, key)
    for fresh in (displays is None, True):
        if fresh:
            displays = parse_detect(run(["ddcutil", "detect", "--brief"]).stdout)
            _store(path, key, displays)
        mapped = match_displays(displays, monitors)
        values = _read(run, mapped)
        if fresh or all(values.values()):
            break
    return [{"name": monitor["name"], "kind": "ddc", "bus": mapped[monitor["name"]].bus,
             "percent": percent(*values[monitor["name"]]), "max": values[monitor["name"]][1]}
            for monitor in monitors if values.get(monitor["name"])]


def collect(run: Run = _run, cache: Path | None = None, access: Callable[[], str] = _system_access,
            installed: Callable[[], bool] = lambda: shutil.which("ddcutil") is not None) -> dict:
    """{ status, devices }: every monitor Vitrail can dim, in Hyprland's order.

    status: `ok` (some device), else why not: `access` (no i2c permission),
    `missing` (no ddcutil), `none` (nothing adjustable)."""
    monitors = _monitors(run)
    lights = parse_backlights(run(["brightnessctl", "-m", "-c", "backlight"]).stdout)
    internal = [m for m in monitors if is_internal(m["name"])]
    external = [m for m in monitors if not is_internal(m["name"])]
    status = access() if external else "ok"

    by_name: dict[str, dict] = {}
    for monitor, light in zip(internal, lights):
        by_name[monitor["name"]] = {"name": monitor["name"], "kind": "backlight", "device": light.device,
                                    "percent": percent(light.value, light.maximum), "max": light.maximum}
    if external and status == "ok" and installed():
        for device in _external(run, cache or cache_file(), external):
            by_name[device["name"]] = device

    devices = [by_name[m["name"]] for m in monitors if m["name"] in by_name]
    if devices:
        return {"status": "ok", "devices": devices}
    if external and not installed():
        return {"status": "missing", "devices": []}
    if external and status == "access":
        return {"status": "access", "devices": []}
    return {"status": "none", "devices": []}
