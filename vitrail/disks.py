"""The removable drives, for the bar's Disks popup.

    python3 -m vitrail.disks state
    python3 -m vitrail.disks mount /dev/sdb1
    python3 -m vitrail.disks unmount /dev/sdb1
    python3 -m vitrail.disks eject /dev/sdb1
    python3 -m vitrail.disks open /run/media/juan/KINGSTON

`lsblk --json --bytes` names the devices; this keeps the ones that are
removable or hotplug (loop and zram aside), folds each partition into the
parent disk's transport and model, and adds the used/free space of the mounted
ones. `udisksctl` mounts, unmounts and powers them off as the user, so no root
or password is involved; its error text comes back unchanged, as JSON, instead
of an exception. Opening a mounted drive uses the desktop's own file manager
(`vitrail/files.py`), the one "open folder" already calls.

The popup sees a stick arrive when its `name` appears in `devices` (and leaves
when it disappears); `mounted`, `mountpoint`, `used` and `free` change when it
is mounted or unmounted, and `total` is the number of entries.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
from collections.abc import Callable

from . import files

DiskUsage = Callable[[str], tuple[int, int, int]]
Runner = Callable[[list[str]], tuple[int, str, str]]
Spawn = Callable[[list[str]], object]

# `--bytes` keeps SIZE an integer, and the explicit columns are the ones the
# popup reads: MOUNTPOINTS and HOTPLUG are absent from lsblk's default output.
LSBLK = [
    "lsblk",
    "--json",
    "--bytes",
    "--output",
    "NAME,RM,HOTPLUG,TRAN,MOUNTPOINTS,FSTYPE,LABEL,UUID,SIZE,MODEL,TYPE",
]
# Kernel pseudo-devices that are never a drive the user plugged in.
IGNORED_TYPES = {"loop", "zram"}
# udisksctl can wait for a slow USB bridge; lsblk answers at once.
TIMEOUT = 30


def run_text(argv: list[str]) -> tuple[int, str, str]:
    """(status, stdout, stderr) of one command; a missing or hung one never
    raises out of here."""
    try:
        done = subprocess.run(argv, capture_output=True, text=True, check=False, timeout=TIMEOUT)
    except (OSError, subprocess.SubprocessError) as error:
        return 127, "", str(error)
    return done.returncode, done.stdout, done.stderr


def _text(value: object) -> str:
    return "" if value is None else str(value).strip()


def _size(value: object) -> int:
    try:
        return int(value)  # type: ignore[arg-type]
    except (TypeError, ValueError):
        return 0


def _mountpoints(entry: dict) -> list[str]:
    """The real mount points of one lsblk node; `[SWAP]` and null are not paths."""
    raw = entry.get("mountpoints")
    if raw is None:
        raw = [entry.get("mountpoint")]
    if not isinstance(raw, list):
        raw = [raw]
    return [str(one) for one in raw if one and str(one).startswith("/")]


def _device(entry: dict, parent: dict) -> dict:
    """One partition (or a whole unpartitioned disk) in the popup's shape.

    TRAN and MODEL usually sit on the disk, not on its partitions, so an empty
    child field takes the parent's.
    """
    name = _text(entry.get("name"))
    points = _mountpoints(entry)
    return {
        "name": name if name.startswith("/dev/") else f"/dev/{name}",
        "label": _text(entry.get("label")),
        "uuid": _text(entry.get("uuid")),
        "fstype": _text(entry.get("fstype")),
        "size": _size(entry.get("size")),
        "model": _text(entry.get("model")) or _text(parent.get("model")),
        "transport": _text(entry.get("tran")) or _text(parent.get("tran")),
        "mounted": bool(points),
        "mountpoint": points[0] if points else "",
        "used": None,
        "free": None,
    }


def _removable(entry: dict) -> bool:
    """A drive the user can unplug: removable, hotplug, or on USB (some USB
    bridges report a fixed disk). Fixed NVMe/SATA disks are never here."""
    name = _text(entry.get("name")).lower()
    if _text(entry.get("type")) in IGNORED_TYPES or name.startswith(("loop", "zram")):
        return False
    return bool(entry.get("rm")) or bool(entry.get("hotplug")) or _text(entry.get("tran")) == "usb"


def parse(text: str) -> list[dict]:
    """The removable devices of one `lsblk --json` document, in lsblk's order.

    A disk with partitions contributes its partitions, each carrying the disk's
    transport and model; a disk without partitions (an unpartitioned stick, or
    one just powered off) contributes itself. An unreadable document is no
    devices, never an exception.
    """
    try:
        document = json.loads(text)
    except (TypeError, ValueError):
        return []
    if not isinstance(document, dict):
        return []
    found: list[dict] = []
    for disk in document.get("blockdevices") or []:
        if not isinstance(disk, dict) or not _removable(disk):
            continue
        children = [child for child in disk.get("children") or [] if isinstance(child, dict)]
        if not children:
            found.append(_device(disk, disk))
            continue
        for child in children:
            if _text(child.get("type")) in IGNORED_TYPES or _text(child.get("name")).startswith(("loop", "zram")):
                continue
            found.append(_device(child, disk))
    return found


def state(run: Runner = run_text, usage: DiskUsage = shutil.disk_usage) -> dict:
    """Every removable device, the used and free bytes of the mounted ones, and
    how many there are. A missing or failing lsblk is an empty document."""
    status, out, _err = run(LSBLK)
    devices = parse(out) if status == 0 else []
    for one in devices:
        if not one["mounted"]:
            continue
        try:
            _total, used, free = usage(one["mountpoint"])
        except OSError:
            continue
        one["used"], one["free"] = used, free
    return {"devices": devices, "total": len(devices)}


def mount(device: str) -> list[str]:
    return ["udisksctl", "mount", "-b", device]


def unmount(device: str) -> list[str]:
    return ["udisksctl", "unmount", "-b", device]


def eject(device: str) -> list[str]:
    """Power the drive off, so the user can unplug it safely."""
    return ["udisksctl", "power-off", "-b", device]


def open_command(mountpoint: str, manager: Callable[[], list[str]] = files.file_manager) -> list[str]:
    """The argv that opens a mount point in the desktop's file manager."""
    return [*manager(), str(mountpoint)]


def invoke(argv: list[str], run: Runner = run_text) -> dict:
    """Run one action; `ok`, its output and udisksctl's error text, never a raise."""
    status, out, err = run(argv)
    if status == 0:
        return {"ok": True, "output": out.strip(), "error": None}
    return {
        "ok": False,
        "output": out.strip(),
        "error": err.strip() or out.strip() or f"{argv[0]} exited with status {status}",
    }


def main(
    argv: list[str] | None = None,
    run: Runner = run_text,
    usage: DiskUsage = shutil.disk_usage,
    spawn: Spawn = subprocess.Popen,
) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    if args == ["state"]:
        if shutil.which("lsblk") is None:
            print("disks: lsblk is not installed (util-linux)", file=sys.stderr)
            return 1
        print(json.dumps(state(run, usage), separators=(",", ":")))
        return 0
    if len(args) == 2 and args[0] in ("mount", "unmount", "eject"):
        if shutil.which("udisksctl") is None:
            print("disks: udisksctl is not installed (udisks2)", file=sys.stderr)
            return 1
        action = {"mount": mount, "unmount": unmount, "eject": eject}[args[0]]
        result = invoke(action(args[1]), run)
        print(json.dumps(result, separators=(",", ":")))
        return 0 if result["ok"] else 1
    if len(args) == 2 and args[0] == "open":
        try:
            spawn(open_command(args[1]))
        except OSError as error:
            print(f"disks: {error}", file=sys.stderr)
            return 1
        return 0
    print(
        "usage: disks state | mount <device> | unmount <device> | eject <device> | open <mountpoint>",
        file=sys.stderr,
    )
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
