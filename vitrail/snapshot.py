"""Snapshots before an update, with whatever the machine has.

btrfs first (`btrfs subvolume snapshot -r /`), timeshift second. Both need
root; the commands run with `sudo -n` so a password prompt never hangs an
unattended update — an update without a snapshot warns instead.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
from typing import Callable

Runner = Callable[[list[str]], str | None]
BTRFS_DIR = "/.snapshots"


def log(message: str) -> None:
    print(f"vitrail-snapshot: {message}", file=sys.stderr, flush=True)


def run_text(argv: list[str]) -> str | None:
    try:
        found = subprocess.run(argv, capture_output=True, text=True, check=False)
    except OSError:
        return None
    return found.stdout if found.returncode == 0 else None


def backend(run: Runner = run_text) -> str:
    filesystem = (run(["findmnt", "-no", "FSTYPE", "/"]) or "").strip()
    if filesystem == "btrfs" and shutil.which("btrfs"):
        return "btrfs"
    if shutil.which("timeshift"):
        return "timeshift"
    return ""


def create(label: str, run: Runner = run_text, kind: str | None = None) -> dict:
    kind = kind if kind is not None else backend(run)
    if kind == "btrfs":
        target = f"{BTRFS_DIR}/{label}"
        if run(["sudo", "-n", "mkdir", "-p", target]) is None:
            return {"error": "btrfs needs root without a password (sudo -n)"}
        if run(["sudo", "-n", "btrfs", "subvolume", "snapshot", "-r", "/", target]) is None:
            return {"error": "the btrfs snapshot failed"}
        return {"path": target, "backend": "btrfs"}
    if kind == "timeshift":
        if run(["sudo", "-n", "timeshift", "--create", "--scripted", "--comments", label]) is None:
            return {"error": "the timeshift snapshot failed"}
        return {"path": label, "backend": "timeshift"}
    return {"error": "no snapshot backend (btrfs or timeshift)"}


def listing(run: Runner = run_text) -> list[str]:
    kind = backend(run)
    if kind == "btrfs":
        text = run(["btrfs", "subvolume", "list", "-o", BTRFS_DIR]) or ""
        return sorted(line for line in text.splitlines() if line.strip())
    if kind == "timeshift":
        text = run(["timeshift", "--list"]) or ""
        return [line.rstrip() for line in text.splitlines() if line.strip()]
    return []


def main(argv: list[str] | None = None, run: Runner = run_text) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    if args[:1] == ["list"]:
        for line in listing(run):
            print(line)
        return 0
    if args[:1] == ["create"]:
        import time

        label = args[1] if len(args) > 1 else time.strftime("vitrail-%Y%m%d-%H%M%S")
        result = create(label, run)
        print(result.get("path") or result.get("error", ""))
        return 0 if "path" in result else 1
    print("usage: snapshot create [label] | snapshot list", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
