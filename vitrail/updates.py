"""Pending package updates: repository, AUR and Flatpak.

    python3 -m vitrail.updates state

One JSON document, the snapshot the bar and its popup read:

    {
      "official": [{"name": "linux", "from": "6.12.1-1", "to": "6.12.2-1"}],
      "aur": [{"name": "claude-desktop", "from": "5.1-1", "to": "6.2-1"}],
      "flatpak": [{"name": "org.mozilla.firefox", "from": "", "to": "135.0"}],
      "errors": {"flatpak": "flatpak is not installed"},
      "total": 3,
      "checkedAt": 1763730000000
    }

`official` is `checkupdates` (pacman-contrib, a temporary database and no
root), `aur` is the installed helper's `-Qua` (paru before yay) and `flatpak`
is `remote-ls --updates`: it does not publish the installed version, so
`from`/`to` stay empty when the remote has none. `total` counts the entries,
`checkedAt` is epoch milliseconds (like the other snapshots) and `errors` names
only the sources that failed; the rest of the document is still filled.

The parsers are pure functions of their text and every program goes through one
injected runner, so the tests never touch pacman, an AUR helper or flatpak.
`command()` returns the argv of an "Update" action without running it: the
caller hands it to a terminal, and nothing here needs root.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
import time
from collections.abc import Callable, Iterable

Runner = Callable[[list[str]], tuple[int, str, str]]
Which = Callable[[str], str | None]

OFFICIAL = "official"
AUR = "aur"
FLATPAK = "flatpak"
SOURCES = (OFFICIAL, AUR, FLATPAK)
DEFAULT_SOURCES = SOURCES
CHECKUPDATES = "checkupdates"
FLATPAK_COLUMNS = "application,version"
AUR_HELPERS = ("paru", "yay")
DEFAULT_AUR_HELPER = AUR_HELPERS[0]
UPDATE_COMMANDS = {
    OFFICIAL: ("sudo", "pacman", "-Syu"),
    FLATPAK: ("flatpak", "update", "-y"),
}

VERSION_LINE = re.compile(r"^(\S+)\s+(\S+)\s+->\s+(\S+)")


class SourceError(RuntimeError):
    """One source could not answer; the rest of the snapshot still can."""


def run_text(argv: list[str]) -> tuple[int, str, str]:
    """Run one program as (exit code, stdout, stderr); a missing one is code 127."""
    try:
        found = subprocess.run(argv, capture_output=True, text=True, check=False)
    except OSError as error:
        return 127, "", str(error)
    return found.returncode, found.stdout or "", found.stderr or ""


def parse_versions(text: str) -> list[dict[str, str]]:
    """`name old -> new` lines: `checkupdates` and an AUR helper's `-Qua`.

    A helper may append its age (`[19h1m]`) or print a warning; only a line
    with a name and both versions is an update.
    """
    found: list[dict[str, str]] = []
    for line in text.splitlines():
        match = VERSION_LINE.match(line.strip())
        if match is None:
            continue
        name, since, now = match.groups()
        found.append({"name": name, "from": since, "to": now})
    return found


def parse_flatpak(text: str) -> list[dict[str, str]]:
    """Tab-separated `application,version` rows from `remote-ls --updates`.

    The remote does not publish the installed version, so `from` is empty; `to`
    is empty too when the remote has no version either.
    """
    found: list[dict[str, str]] = []
    for line in text.splitlines():
        fields = line.split("\t")
        name = fields[0].strip()
        if not name:
            continue
        version = fields[1].strip() if len(fields) > 1 else ""
        found.append({"name": name, "from": "", "to": version})
    return found


def aur_helper(helper: str | None = None, which: Which = shutil.which) -> str:
    """The installed helper: the configured one, else paru, else yay, else ""."""
    if helper:
        return helper if which(helper) else ""
    for name in AUR_HELPERS:
        if which(name):
            return name
    return ""


def _call(run: Runner, argv: list[str]) -> tuple[int, str, str]:
    try:
        return run(argv)
    except OSError as error:
        raise SourceError(str(error)) from error


def _failure(program: str, code: int, text: str) -> str:
    lines = text.strip().splitlines()
    return lines[0] if lines else f"{program} exited with status {code}"


def check_official(run: Runner, which: Which) -> list[dict[str, str]]:
    if which(CHECKUPDATES) is None:
        raise SourceError(f"{CHECKUPDATES} is not installed (pacman-contrib)")
    code, out, err = _call(run, ["checkupdates"])
    # checkupdates exits 2, with nothing printed, when there is nothing to do.
    if code == 2 and not out.strip():
        return []
    if code != 0:
        raise SourceError(_failure(CHECKUPDATES, code, err or out))
    return parse_versions(out)


def check_aur(run: Runner, which: Which, helper: str | None) -> list[dict[str, str]]:
    name = aur_helper(helper, which)
    if not name:
        if helper:
            raise SourceError(f"{helper} is not installed")
        raise SourceError("no AUR helper (paru or yay) is installed")
    code, out, err = _call(run, [name, "-Qua"])
    if code != 0:
        raise SourceError(_failure(name, code, err or out))
    return parse_versions(out)


def check_flatpak(run: Runner, which: Which) -> list[dict[str, str]]:
    if which("flatpak") is None:
        raise SourceError("flatpak is not installed")
    argv = ["flatpak", "remote-ls", "--updates", f"--columns={FLATPAK_COLUMNS}"]
    code, out, err = _call(run, argv)
    if code != 0:
        raise SourceError(_failure("flatpak", code, err or out))
    return parse_flatpak(out)


def state(
    sources: Iterable[str] | None = None,
    helper: str | None = None,
    *,
    run: Runner = run_text,
    which: Which = shutil.which,
    now: float | None = None,
) -> dict:
    """One snapshot of the pending updates of the requested sources.

    A source that cannot answer leaves its list empty and explains itself under
    `errors`; the other sources are still read. `now` (epoch seconds) is only
    for the tests, which pin `checkedAt`.
    """
    if sources is None:
        wanted = SOURCES
    elif isinstance(sources, str):
        wanted = (sources,)
    else:
        wanted = tuple(sources)
    enabled = tuple(source for source in SOURCES if source in wanted)
    document: dict = {source: [] for source in enabled}
    errors: dict[str, str] = {}
    for source in enabled:
        try:
            if source == OFFICIAL:
                document[source] = check_official(run, which)
            elif source == AUR:
                document[source] = check_aur(run, which, helper)
            else:
                document[source] = check_flatpak(run, which)
        except SourceError as error:
            errors[source] = str(error)
    document["errors"] = errors
    document["total"] = sum(len(document[source]) for source in enabled)
    document["checkedAt"] = int((time.time() if now is None else now) * 1000)
    return document


def command(source: str, helper: str | None = None, *, which: Which = shutil.which) -> list[str]:
    """The argv for an "Update" action; nothing is run here.

    `helper` names the AUR helper (`-Sua`); without one, the installed paru or
    yay is used and `DEFAULT_AUR_HELPER` is the last fallback.
    """
    if source == OFFICIAL:
        return list(UPDATE_COMMANDS[OFFICIAL])
    if source == FLATPAK:
        return list(UPDATE_COMMANDS[FLATPAK])
    if source == AUR:
        name = helper or aur_helper(None, which) or DEFAULT_AUR_HELPER
        return [name, "-Sua"]
    raise ValueError(f"unknown update source: {source}")


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    if args == ["state"]:
        print(json.dumps(state(), separators=(",", ":")))
        return 0
    print("usage: updates state", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
