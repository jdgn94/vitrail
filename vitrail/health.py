"""System health: what is wrong with the machine, as data for the bar.

    python3 -m vitrail.health state

`state()` returns one JSON object:

    {
      "problems": [
        {"id": "service-user:vitrail-settings.service",
         "severity": "warning",
         "title": "vitrail-settings.service",
         "detail": "user service failed: Vitrail settings",
         "fix": ["systemctl", "--user", "restart", "vitrail-settings.service"],
         "logs": ["journalctl", "--user", "-u", "vitrail-settings.service", "-n", "200"]}
      ],
      "count": 1,
      "checkedAt": "2026-11-21T10:00:00Z",
      "error": null
    }

Every check can be switched off by name (`checks`); all are on when it is None,
and `CHECKS` lists the names. The checks are failed user services, failed system
services, local filesystems below a free-space threshold (5 % by default), the
errors `hyprctl configerrors` reports while Hyprland runs, and `vitrail doctor`'s
own non-zero result. `error` is set only when the snapshot itself could not run
(an unknown check); a missing program is not an error and contributes nothing.

The id is `<check>:<subject>`, so the part before the first colon is stable and
the UI maps it to an icon: `service-user`, `service-system`, `disk`, `hyprland`
and `doctor`. The shell's own load failure uses the documented `bar` id
(`BAR_ID`) and feeds that problem to itself:

    {"id": "bar", "severity": "error", "title": "Vitrail bar",
     "detail": "the health element could not load", "fix": null, "logs": null}

`fix` and `logs` are argv for a terminal or a preview; this module never runs
them. A missing program contributes nothing (a machine without systemd or
Hyprland is not broken), and nothing here writes or needs root.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
import time
from collections.abc import Callable, Sequence
from pathlib import Path

from . import doctor
from .downloads import human_size

CHECKS = ("user_services", "system_services", "disk", "hyprland", "doctor")
# The shell appends its own problem under this id when its health read failed.
BAR_ID = "bar"
DISK_THRESHOLD = 5.0
READ_TIMEOUT = 10
MOUNTS = Path("/proc/mounts")
# Local filesystems only: a network or FUSE mount can block a snapshot.
LOCAL_FILESYSTEMS = {
    "bcachefs",
    "btrfs",
    "exfat",
    "ext2",
    "ext3",
    "ext4",
    "f2fs",
    "jfs",
    "ntfs",
    "ntfs3",
    "overlay",
    "reiserfs",
    "vfat",
    "xfs",
    "zfs",
}
# /proc/mounts escapes spaces and tabs in a mount point in octal.
OCTAL = re.compile(r"\\([0-7]{3})")

DiskUsage = Callable[[str], tuple[int, int, int]]
Runner = Callable[[list[str]], subprocess.CompletedProcess | None]


def run_completed(argv: list[str]) -> subprocess.CompletedProcess | None:
    """A captured command, or None when it is missing or hangs."""
    try:
        return subprocess.run(argv, capture_output=True, text=True, timeout=READ_TIMEOUT, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return None


def _read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def _problem(
    identifier: str, severity: str, title: str, detail: str, fix: list[str] | None = None, logs: list[str] | None = None
) -> dict:
    return {"id": identifier, "severity": severity, "title": title, "detail": detail, "fix": fix, "logs": logs}


def parse_failed(text: str) -> list[tuple[str, str]]:
    """(unit, description) for each line of `systemctl --failed --plain --no-legend`."""
    units: list[tuple[str, str]] = []
    for line in text.splitlines():
        fields = line.replace("●", " ").split()
        # The unit keeps the first column, the description the fifth onwards.
        if len(fields) < 3 or fields[0] == "UNIT" or "." not in fields[0]:
            continue
        units.append((fields[0], " ".join(fields[4:])))
    return units


def parse_mounts(text: str) -> list[str]:
    """Mount points of local filesystems in /proc/mounts, one per source."""
    points: list[str] = []
    seen: set[str] = set()
    for line in text.splitlines():
        fields = line.split()
        if len(fields) < 3:
            continue
        source, target, kind = fields[:3]
        if kind not in LOCAL_FILESYSTEMS or source in seen:
            continue
        seen.add(source)
        points.append(OCTAL.sub(lambda match: chr(int(match.group(1), 8)), target))
    return points


def config_errors(text: str) -> str:
    """What hyprctl reports, or "" when the config has no errors."""
    errors = text.strip()
    return "" if errors.lower().rstrip(".") == "no errors" else errors


def service_problems(scope: str, run: Runner) -> list[dict]:
    """One problem per failed unit; the scope is `user` or `system`."""
    result = run(["systemctl", "--failed", f"--{scope}", "--plain", "--no-legend"])
    if result is None:
        return []
    found: list[dict] = []
    severity = "warning" if scope == "user" else "error"
    for unit, description in parse_failed(result.stdout or ""):
        detail = f"{scope} service failed" + (f": {description}" if description else "")
        if scope == "user":
            fix = ["systemctl", "--user", "restart", unit]
            logs = ["journalctl", "--user", "-u", unit, "-n", "200"]
        else:
            fix = ["systemctl", "restart", unit]
            logs = ["journalctl", "-u", unit, "-n", "200"]
        found.append(_problem(f"service-{scope}:{unit}", severity, unit, detail, fix, logs))
    return found


def disk_problems(usage: DiskUsage, mounts: Sequence[str], threshold: float) -> list[dict]:
    """One problem per local filesystem with less than `threshold` % free."""
    found: list[dict] = []
    for mount in mounts:
        try:
            total, _used, free = usage(mount)
        except OSError:
            continue
        if total <= 0:
            continue
        percent = 100 * free / total
        if percent >= threshold:
            continue
        detail = f"{percent:.1f}% free ({human_size(free)} of {human_size(total)})"
        found.append(_problem(f"disk:{mount}", "warning", f"Low disk space on {mount}", detail))
    return found


def hyprland_problems(run: Runner) -> list[dict]:
    """The Hyprland config errors, only while the compositor answers."""
    version = run(["hyprctl", "version"])
    if version is None or version.returncode != 0:
        return []
    result = run(["hyprctl", "configerrors"])
    errors = config_errors(result.stdout or "") if result is not None else ""
    if not errors:
        return []
    fix = ["hyprctl", "reload"]
    logs = ["hyprctl", "configerrors"]
    return [_problem("hyprland:config", "warning", "Hyprland config errors", errors, fix, logs)]


def _doctor_runner(run: Runner) -> Callable[..., subprocess.CompletedProcess]:
    """doctor.collect's runner: missing programs stay harmless (exit 127)."""

    def call(argv: list[str], **_options: object) -> subprocess.CompletedProcess:
        found = run(argv)
        return found if found is not None else subprocess.CompletedProcess(argv, 127)

    return call


def doctor_problems(run: Runner) -> list[dict]:
    """doctor's problems, summarised into one entry with its report as detail."""
    report = doctor.collect(run=_doctor_runner(run))
    if not report.get("problems"):
        return []
    logs = ["vitrail", "doctor"]
    return [_problem("doctor", "warning", "vitrail doctor found problems", doctor.render(report).strip(), None, logs)]


def state(
    run: Runner = run_completed,
    *,
    checks: Sequence[str] | None = None,
    threshold: float = DISK_THRESHOLD,
    usage: DiskUsage = shutil.disk_usage,
    mounts: Sequence[str] | None = None,
) -> dict:
    """The machine's problems; `checks` picks the checks (None: all of them)."""
    checked_at = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    enabled = set(CHECKS if checks is None else checks)
    unknown = enabled.difference(CHECKS)
    if unknown:
        return {
            "problems": [],
            "count": 0,
            "checkedAt": checked_at,
            "error": f"unknown check: {', '.join(sorted(unknown))}",
        }

    problems: list[dict] = []
    if "user_services" in enabled:
        problems += service_problems("user", run)
    if "system_services" in enabled:
        problems += service_problems("system", run)
    if "disk" in enabled:
        points = mounts if mounts is not None else parse_mounts(_read(MOUNTS))
        problems += disk_problems(usage, points, threshold)
    if "hyprland" in enabled:
        problems += hyprland_problems(run)
    if "doctor" in enabled:
        problems += doctor_problems(run)
    return {"problems": problems, "count": len(problems), "checkedAt": checked_at, "error": None}


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    if args == ["state"]:
        print(json.dumps(state(), separators=(",", ":")))
        return 0
    print("usage: health state", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
