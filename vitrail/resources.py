"""What the machine is doing: CPU, memory, temperature, network and disk.

    python3 -m vitrail.resources state
    python3 -m vitrail.resources state --tick [--top]
    python3 -m vitrail.resources kill PID [--force]

Everything comes from the kernel's own files (`/proc/stat`, `/proc/meminfo`,
`/sys/class/thermal/thermal_zone*/temp`, `/proc/net/dev`) and `shutil`, so there
is no dependency and no program to run. CPU is a percentage between two
readings: the first one has no delta (`cpu: null`) and keeps its counters under
`cpuTicks`, which the caller passes back as `previous`. Network counters are
the totals since boot, loopback aside, in bytes.

`state --tick` is the shell's shared sampler: one cheap read per tick, no pause.
What the next tick needs (the CPU ticks, the network counters, each process's
ticks) is kept in a small cache file, so the CPU percentage and the network
rate are real from the second tick on. `--top` adds the busiest processes,
read from `/proc/<pid>/stat` (never `ps`). `kill` sends one signal to one
process, never to pid 1, this program or the shell that started it.

The kernel counts network bytes since boot, not since midnight: the tick also
carries `today`, the bytes received and sent since the day began. Its baseline
(date and the totals at the day's first reading) lives in
`~/.cache/vitrail/netusage.json`, outside the runtime cache, because a day
outlives a reboot.
"""

from __future__ import annotations

import json
import os
import shutil
import signal
import sys
import tempfile
import time
from collections.abc import Callable
from pathlib import Path

PROC = Path("/proc")
THERMAL = Path("/sys/class/thermal")
SAMPLE_SECONDS = 0.2
# Loopback traffic says nothing about the machine's network.
EXCLUDED_INTERFACES = {"lo"}
DiskUsage = Callable[[str], tuple[int, int, int]]
TOP_LIMIT = 5
# A cache older than this says nothing about "now": the rate would be an average
# over a gap, not a speed.
CACHE_MAX_AGE = 60.0
Sender = Callable[[int, int], None]


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
    """Used, total, free and percentage of a filesystem; zeros when it cannot be read."""
    try:
        total, used, free = usage(path)
    except OSError:
        return {"used": 0, "total": 0, "free": 0, "percent": 0.0}
    return {
        "used": used,
        "total": total,
        "free": free,
        "percent": round(100 * used / total, 1) if total else 0.0,
    }


def network_rate(before: dict | None, after: dict | None, seconds: float) -> dict | None:
    """Bytes per second received and sent between two counter readings; None
    without a usable pair (the first tick, a gap, a counter that went back)."""
    if not before or not after or seconds <= 0:
        return None
    rx = after["rx"] - before["rx"]
    tx = after["tx"] - before["tx"]
    if rx < 0 or tx < 0:
        return None
    return {"rx": round(rx / seconds), "tx": round(tx / seconds)}


def _counter(value: object) -> int | None:
    """A byte counter as a non-negative integer; anything else is absent."""
    if isinstance(value, bool) or not isinstance(value, (int, float)) or value < 0:
        return None
    return int(value)


def today(previous: dict | None, current: dict, date: str) -> tuple[dict, dict]:
    """The day's baseline and the bytes used since it began.

    `previous` is the stored baseline (`{"date", "rx", "tx"}`) or None, `current`
    the network counters now and `date` the local day ("YYYY-MM-DD"). The first
    reading of a day, and the first after a missed one, starts the baseline at
    `current` and reads zero. A counter that went back within the day is a
    reboot: that direction restarts at `current` too, so a total is never
    negative. Returns `(baseline, {"rx", "tx"})`, both pure.
    """
    now = {"rx": _counter(current.get("rx")) or 0, "tx": _counter(current.get("tx")) or 0}
    baseline = dict(now)
    used = {"rx": 0, "tx": 0}
    if isinstance(previous, dict) and previous.get("date") == date:
        for key in ("rx", "tx"):
            start = _counter(previous.get(key))
            if start is not None and start <= now[key]:
                baseline[key] = start
                used[key] = now[key] - start
    return {"date": date, **baseline}, used


def cpu_count(text: str) -> int:
    """How many `cpuN` lines /proc/stat has (at least 1)."""
    count = sum(1 for line in text.splitlines() if line.startswith("cpu") and line[3:4].isdigit())
    return max(count, 1)


def parse_process(pid: int, text: str, page_size: int) -> dict | None:
    """One `/proc/<pid>/stat` line: name, busy ticks and resident bytes.

    The name sits in parentheses and may hold spaces and parentheses itself,
    so the fields after it are counted from the last closing one.
    """
    start = text.find("(")
    end = text.rfind(")")
    if start < 0 or end < start:
        return None
    rest = text[end + 1 :].split()
    # rest[0] is the state (field 3); utime and stime are fields 14 and 15, rss 24.
    if len(rest) < 22:
        return None
    try:
        ticks = int(rest[11]) + int(rest[12])
        rss = int(rest[21]) * page_size
    except ValueError:
        return None
    return {"pid": pid, "name": text[start + 1 : end], "ticks": ticks, "rss": max(rss, 0)}


def read_processes(proc: Path = PROC, page_size: int | None = None) -> dict[int, dict]:
    """Every readable process, by pid. One that exits mid-read is skipped."""
    size = page_size or os.sysconf("SC_PAGE_SIZE")
    found: dict[int, dict] = {}
    try:
        entries = list(proc.iterdir())
    except OSError:
        return found
    for entry in entries:
        if not entry.name.isdigit():
            continue
        parsed = parse_process(int(entry.name), _read(entry / "stat"), size)
        if parsed:
            found[parsed["pid"]] = parsed
    return found


def top(
    current: dict[int, dict],
    previous: dict | None,
    elapsed: float,
    cpus: int,
    memory_total: int,
    *,
    limit: int = TOP_LIMIT,
    skip: tuple[int, ...] = (),
) -> list[dict]:
    """The busiest processes. `previous` maps a pid (as text) to its ticks at
    the last tick and `elapsed` is how many ticks all CPUs gained since, so
    `cpu` is a share of one core (it can pass 100) and None without a delta.
    Sorted by CPU, then by memory."""
    rows = []
    per_core = elapsed / cpus if cpus and elapsed > 0 else 0
    for pid, item in current.items():
        if pid in skip:
            continue
        before = previous.get(str(pid)) if isinstance(previous, dict) else None
        cpu = None
        if per_core > 0 and before is not None and item["ticks"] >= before:
            cpu = round(100 * (item["ticks"] - before) / per_core, 1)
        rows.append(
            {
                "pid": pid,
                "name": item["name"],
                "cpu": cpu,
                "memory": item["rss"],
                "percent": round(100 * item["rss"] / memory_total, 1) if memory_total else 0.0,
            }
        )
    rows.sort(key=lambda row: (row["cpu"] or 0, row["memory"]), reverse=True)
    return rows[:limit]


def kill_plan(pid: object, force: bool = False, *, own: tuple[int, ...] | None = None) -> dict:
    """What a click may do to `pid`: `{"signal": n}`, or `{"error": code}`.

    SIGTERM by default; SIGKILL only when `force` is asked for. Pid 1 and
    anything below it, this program and the shell that started it are refused.
    """
    protected = (os.getpid(), os.getppid()) if own is None else own
    if isinstance(pid, bool) or not isinstance(pid, int) or pid <= 1:
        return {"error": "refused"}
    if pid in protected:
        return {"error": "refused"}
    return {"signal": int(signal.SIGKILL if force else signal.SIGTERM)}


def kill(pid: object, force: bool = False, *, sender: Sender = os.kill, own: tuple[int, ...] | None = None) -> dict:
    """Send the signal `kill_plan` allows. `{"ok": true}` or `{"error": code}`
    (`refused`, `gone`, `denied`, `failed`); never raises."""
    plan = kill_plan(pid, force, own=own)
    if "error" in plan:
        return plan
    try:
        sender(pid, plan["signal"])
    except ProcessLookupError:
        return {"error": "gone"}
    except PermissionError:
        return {"error": "denied"}
    except OSError:
        return {"error": "failed"}
    return {"ok": True}


def cache_path() -> Path:
    base = os.environ.get("XDG_RUNTIME_DIR") or tempfile.gettempdir()
    return Path(base) / f"vitrail-resources-{os.getuid()}.json"


def day_path() -> Path:
    """Where today's network baseline lives: outside the runtime folder, since
    a day outlives a reboot."""
    base = os.environ.get("XDG_CACHE_HOME") or (Path.home() / ".cache")
    return Path(base) / "vitrail" / "netusage.json"


def _load_day(path: Path) -> dict | None:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    return data if isinstance(data, dict) else None


def _store_day(path: Path, data: dict) -> None:
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary = path.with_name(path.name + ".tmp")
        temporary.write_text(json.dumps(data, separators=(",", ":")), encoding="utf-8")
        temporary.replace(path)
    except OSError:
        pass


def _load_cache(path: Path, now: float) -> dict | None:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    at = data.get("at") if isinstance(data, dict) else None
    if not isinstance(at, (int, float)) or isinstance(at, bool) or not 0 <= now - at <= CACHE_MAX_AGE:
        return None
    return data


def _store_cache(path: Path, data: dict) -> None:
    try:
        temporary = path.with_name(path.name + ".tmp")
        temporary.write_text(json.dumps(data, separators=(",", ":")), encoding="utf-8")
        temporary.replace(path)
    except OSError:
        pass


def tick(
    with_top: bool = False,
    *,
    cache: Path | None = None,
    day_file: Path | None = None,
    clock: Callable[[], float] = time.time,
    proc: Path = PROC,
    thermal: Path = THERMAL,
    disk: str = "/",
    usage: DiskUsage = shutil.disk_usage,
    page_size: int | None = None,
    skip: tuple[int, ...] | None = None,
) -> dict:
    """One shared-sampler reading against the last one in the cache.

    `network` is the counters, `rate` bytes per second (None on the first
    tick), `today` the bytes since local midnight, `top` the busiest processes
    when asked (cpu None until a tick has seen them twice). Never raises: a
    missing source is None or zeros.
    """
    path = cache or cache_path()
    now = clock()
    previous = _load_cache(path, now)
    seconds = now - previous["at"] if previous else 0.0
    data = state(previous, proc=proc, thermal=thermal, disk=disk, usage=usage)
    ticks = data.pop("cpuTicks")
    data["at"] = round(now, 3)
    data["rate"] = network_rate(previous.get("network") if previous else None, data["network"], seconds)
    baseline_file = day_file or day_path()
    day = time.strftime("%Y-%m-%d", time.localtime(now))
    baseline, data["today"] = today(_load_day(baseline_file), data["network"], day)
    _store_day(baseline_file, baseline)
    saved = {"at": now, "cpuTicks": ticks, "network": data["network"]}
    if with_top:
        current = read_processes(proc, page_size)
        before = previous.get("procs") if previous else None
        elapsed = (
            ticks["total"] - previous["cpuTicks"]["total"] if previous and previous.get("cpuTicks") and ticks else 0
        )
        data["top"] = top(
            current,
            before,
            elapsed,
            cpu_count(_read(proc / "stat")),
            data["memory"]["total"],
            skip=(os.getpid(),) if skip is None else skip,
        )
        saved["procs"] = {str(pid): item["ticks"] for pid, item in current.items()}
    _store_cache(path, saved)
    return data


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
    if args[:2] == ["state", "--tick"] and args[2:] in ([], ["--top"]):
        print(json.dumps(tick(args[2:] == ["--top"]), separators=(",", ":")))
        return 0
    if len(args) in (2, 3) and args[0] == "kill" and args[2:] in ([], ["--force"]) and args[1].isdigit():
        result = kill(int(args[1]), args[2:] == ["--force"])
        print(json.dumps(result, separators=(",", ":")))
        return 0 if result.get("ok") else 1
    print("usage: resources state [--tick [--top]] | resources kill PID [--force]", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
