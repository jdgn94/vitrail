"""What the machine is doing: CPU, memory, temperature, network and disk.

    python3 -m vitrail.resources state

Everything comes from the kernel's own files (`/proc/stat`, `/proc/meminfo`,
`/sys/class/thermal/thermal_zone*/temp`, `/proc/net/dev`) and `shutil`, so there
is no dependency and no program to run. CPU is a percentage between two
readings: the first one has no delta (`cpu: null`) and keeps its counters under
`cpuTicks`, which the caller passes back as `previous`. Network counters are
the totals since boot, loopback aside, in bytes.
"""

from __future__ import annotations

import json
import shutil
import sys
import time
from collections.abc import Callable
from pathlib import Path

PROC = Path("/proc")
THERMAL = Path("/sys/class/thermal")
SAMPLE_SECONDS = 0.2
# Loopback traffic says nothing about the machine's network.
EXCLUDED_INTERFACES = {"lo"}
DiskUsage = Callable[[str], tuple[int, int, int]]


def _read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def cpu_times(text: str) -> dict | None:
    """The total and idle ticks of the `cpu` line, or None when it is missing.

    The guest fields are already counted in user and nice, so they stay out.
    """
    for line in text.splitlines():
        if not line.startswith("cpu "):
            continue
        try:
            fields = [int(field) for field in line.split()[1:9]]
        except ValueError:
            return None
        if len(fields) < 5:
            return None
        return {"total": sum(fields), "idle": fields[3] + fields[4]}
    return None


def cpu_percent(before: dict | None, after: dict | None) -> float | None:
    """Busy time between two readings, 0-100; None without a usable delta."""
    if not before or not after:
        return None
    total = after["total"] - before["total"]
    idle = after["idle"] - before["idle"]
    if total <= 0 or idle < 0:
        return None
    return round(100 * (total - idle) / total, 1)


def parse_meminfo(text: str) -> dict:
    """Used, total and percentage of RAM, in bytes (the kernel counts kB)."""
    values: dict[str, int] = {}
    for line in text.splitlines():
        key, _, rest = line.partition(":")
        fields = rest.split()
        if fields and fields[0].isdigit():
            values[key] = int(fields[0]) * 1024
    total = values.get("MemTotal", 0)
    available = values.get("MemAvailable")
    if available is None:
        available = values.get("MemFree", 0) + values.get("Buffers", 0) + values.get("Cached", 0)
    used = max(total - available, 0) if total else 0
    return {"used": used, "total": total, "percent": round(100 * used / total, 1) if total else 0.0}


def parse_network(text: str) -> dict:
    """Bytes received and sent over every interface but loopback."""
    rx = tx = 0
    for line in text.splitlines():
        name, separator, rest = line.partition(":")
        name = name.strip()
        if not separator or not name or name in EXCLUDED_INTERFACES:
            continue
        fields = rest.split()
        if len(fields) < 9:
            continue
        try:
            rx += int(fields[0])
            tx += int(fields[8])
        except ValueError:
            continue
    return {"rx": rx, "tx": tx}


def temperature(folder: Path = THERMAL) -> float | None:
    """The hottest thermal zone in °C; None without a sensor that answers."""
    hottest = None
    try:
        zones = sorted(folder.glob("thermal_zone*/temp"))
    except OSError:
        return None
    for path in zones:
        try:
            celsius = int(path.read_text(encoding="utf-8").strip()) / 1000
        except (OSError, ValueError):
            continue
        if celsius <= 0:
            continue
        if hottest is None or celsius > hottest:
            hottest = celsius
    return round(hottest, 1) if hottest is not None else None


def parse_disk(usage: DiskUsage = shutil.disk_usage, path: str = "/") -> dict:
    """Used, total and percentage of a filesystem; zeros when it cannot be read."""
    try:
        total, used, _free = usage(path)
    except OSError:
        return {"used": 0, "total": 0, "percent": 0.0}
    return {"used": used, "total": total, "percent": round(100 * used / total, 1) if total else 0.0}


def state(
    previous: dict | None = None,
    *,
    proc: Path = PROC,
    thermal: Path = THERMAL,
    disk: str = "/",
    usage: DiskUsage = shutil.disk_usage,
) -> dict:
    """The machine's state. `previous` is the last state (or its `cpuTicks`),
    so the CPU can be a percentage; without it the first reading has none."""
    ticks = cpu_times(_read(proc / "stat"))
    before = previous.get("cpuTicks") if isinstance(previous, dict) else previous
    return {
        "cpu": cpu_percent(before, ticks),
        "cpuTicks": ticks,
        "memory": parse_meminfo(_read(proc / "meminfo")),
        "temperature": temperature(thermal),
        "network": parse_network(_read(proc / "net" / "dev")),
        "disk": parse_disk(usage, disk),
    }


def sample(seconds: float = SAMPLE_SECONDS, **kwargs) -> dict:
    """Two readings with a pause between: a one-shot command still gives a CPU
    percentage instead of the first reading's None."""
    first = state(**kwargs)
    time.sleep(seconds)
    return state(first, **kwargs)


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    if args == ["state"]:
        print(json.dumps(sample(), separators=(",", ":")))
        return 0
    print("usage: resources state", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
