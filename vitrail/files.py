"""The file manager the desktop is configured with.

`xdg-mime query default inode/directory` names it (`org.gnome.Nautilus.desktop`);
its .desktop file gives the argv. Nothing is hardcoded: Nautilus is only the
fallback of a system whose `mimeapps.list` says nothing, and `xdg-open` the
last resort. The same program opens a folder and the files inside it, so
"open folder" and "open file" agree with what the desktop shows.
"""

from __future__ import annotations

import os
import re
import shlex
import shutil
import subprocess
from collections.abc import Callable
from pathlib import Path

# The MIME type of a folder, and what a desktop entry may be called.
FOLDER = "inode/directory"
SUFFIX = ".desktop"
FALLBACK = "nautilus"
LAST_RESORT = "xdg-open"
# The `%f`, `%U`… field codes a launcher replaces; Vitrail passes the path.
FIELD = re.compile(r"%[fFuUdiIckmv]")
TIMEOUT = 5


def data_dirs() -> list[Path]:
    """The folders a desktop entry may live in, in the order the spec reads them."""
    home = os.environ.get("XDG_DATA_HOME") or str(Path.home() / ".local" / "share")
    others = os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"
    return [Path(home), *(Path(one) for one in others.split(":") if one)]


def desktop_path(name: str) -> Path | None:
    """The entry `xdg-mime` named; None when it is not an entry or not installed."""
    if not name.endswith(SUFFIX) or "/" in name:
        return None
    for folder in data_dirs():
        path = folder / "applications" / name
        if path.is_file():
            return path
    return None


def exec_argv(text: str) -> list[str]:
    """The argv of an `Exec=` line, field codes dropped (`%%` becomes `%`)."""
    words = shlex.split(text.replace("%%", "\x00"))
    return [word.replace("\x00", "%") for word in words if word and not FIELD.fullmatch(word)]


def exec_of(path: Path) -> list[str]:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return []
    for line in text.splitlines():
        if line.startswith("Exec="):
            return exec_argv(line.removeprefix("Exec="))
    return []


def run_text(argv: list[str]) -> str | None:
    if shutil.which(argv[0]) is None:
        return None
    try:
        done = subprocess.run(argv, capture_output=True, text=True, timeout=TIMEOUT, check=False)
    except (OSError, subprocess.SubprocessError):
        return None
    return done.stdout if done.returncode == 0 else None


Runner = Callable[[list[str]], "str | None"]


def file_manager(run: Runner = run_text) -> list[str]:
    """The configured file manager's argv; Nautilus, then `xdg-open`, when the
    desktop does not name one."""
    answer = (run(["xdg-mime", "query", "default", FOLDER]) or "").strip()
    entry = desktop_path(answer)
    argv = exec_of(entry) if entry else []
    if argv:
        return argv
    if shutil.which(FALLBACK):
        return [FALLBACK]
    return [LAST_RESORT]


def open_path(path: Path, run: Runner = run_text, spawn=subprocess.Popen) -> list[str]:
    """Opens a folder or a file with that manager; returns the argv it ran."""
    argv = [*file_manager(run), str(path)]
    spawn(argv)
    return argv
