"""What a session action would interrupt: downloads, package updates, jobs.

Before shutting down, rebooting, suspending, hibernating or logging out,
`running()` says what is still working:

    a download the watcher knows (`vitrail/downloads.py`: a .part/.crdownload…
    modified today in the XDG download folders),
    a package manager (pacman, yay, paru, checkupdates, flatpak…),
    a long job registered by `vitrail/jobs.py`.

    python3 -m vitrail.session check     # {"jobs": [{kind, label}]}
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

from . import downloads, jobs

# The package managers and updaters a session action must not cut.
UPDATERS = {
    "pacman", "pacman-key", "yay", "paru", "pikaur", "trizen", "aurman",
    "checkupdates", "makepkg", "flatpak", "snap", "dnf", "zypper", "apt", "apt-get",
}


def process_commands() -> list[list[str]]:
    """The argv of every visible process, read from /proc."""
    found: list[list[str]] = []
    try:
        entries = list(Path("/proc").iterdir())
    except OSError:
        return found
    for entry in entries:
        if not entry.name.isdigit():
            continue
        try:
            raw = (entry / "cmdline").read_bytes()
        except OSError:
            continue
        argv = [part.decode("utf-8", "replace") for part in raw.split(b"\0") if part]
        if argv:
            found.append(argv)
    return found


def package_updates(commands: list[list[str]] | None = None) -> list[str]:
    """The updaters running now, one name each."""
    commands = process_commands() if commands is None else commands
    found = set()
    for argv in commands:
        name = os.path.basename(argv[0])
        if name in UPDATERS:
            found.add(name)
    return sorted(found)


def active_downloads(dirs: list[Path] | None = None) -> list[Path]:
    """The files a downloader is still writing (the watcher's own rules)."""
    return downloads.Watcher(downloads.download_dirs() if dirs is None else dirs).temp_files()


def running(dirs: list[Path] | None = None, commands: list[list[str]] | None = None,
            folder: Path | None = None) -> list[dict]:
    """[{kind: "download"|"update"|"job", label}] — what an action would cut."""
    found = [{"kind": "download", "label": path.name} for path in active_downloads(dirs)]
    found += [{"kind": "update", "label": name} for name in package_updates(commands)]
    found += [{"kind": "job", "label": job["name"] or job["app"]}
              for job in jobs.jobs_running(folder) if job["name"] or job["app"]]
    return found


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    if args == ["check"]:
        print(json.dumps({"jobs": running()}, ensure_ascii=False, separators=(",", ":")))
        return 0
    print("usage: session check", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
