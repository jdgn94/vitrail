"""`vitrail update`: bring the installed checkout to main, then reinstall.

The installer records where it installed from and the choices it made in
`~/.local/share/vitrail/install.json`. `vitrail update --check` compares the
installed commit with the remote branch; `vitrail update` fetches that branch,
moves the checkout to it (refusing to lose local changes) and re-runs the
installer with the same choices, which is idempotent.

Nothing in `~/.config` is touched: preferences, wallpapers and the palette live
there and survive the update.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import Callable

Runner = Callable[[list[str]], str | None]

STATE = "install.json"
ERR_DIRTY = "the checkout has local changes; commit them or use --force"
ERR_FETCH = "could not fetch the remote branch"
ERR_MOVE = "could not move the checkout"


class UpdateError(RuntimeError):
    pass


def run_text(argv: list[str]) -> str | None:
    import subprocess

    try:
        found = subprocess.run(argv, capture_output=True, text=True, check=False)
    except OSError:
        return None
    return found.stdout if found.returncode == 0 else None


def data_dir() -> Path:
    base = os.environ.get("XDG_DATA_HOME") or str(Path.home() / ".local" / "share")
    return Path(base) / "vitrail"


def state_path(folder: Path | None = None) -> Path:
    return (folder or data_dir()) / STATE


def state(folder: Path | None = None) -> dict:
    """What the installer recorded; {} when Vitrail was not installed here."""
    try:
        document = json.loads(state_path(folder).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    return document if isinstance(document, dict) else {}


def installed_version(root: str | Path) -> str:
    """The version in the checkout's pyproject.toml, or ""."""
    try:
        text = (Path(root) / "pyproject.toml").read_text(encoding="utf-8")
    except OSError:
        return ""
    for line in text.splitlines():
        if line.strip().startswith("version"):
            return line.split("=", 1)[1].strip().strip('"').strip("'")
    return ""


def remote_commit(document: dict, run: Runner = run_text) -> str:
    """The commit the tracked branch points at, or "" when unreachable."""
    root = document.get("root")
    if not root or not Path(root, ".git").exists():
        return ""
    branch = document.get("branch") or "main"
    remote = document.get("remote") or "origin"
    answer = run(["git", "-C", str(root), "ls-remote", remote, f"refs/heads/{branch}"])
    if not answer or not answer.strip():
        return ""
    return answer.split()[0]


def is_dirty(document: dict, run: Runner = run_text) -> bool:
    answer = run(["git", "-C", str(document.get("root", "")), "status", "--porcelain"])
    return bool((answer or "").strip())


def check(document: dict, run: Runner = run_text) -> dict:
    installed = document.get("commit") or ""
    remote = remote_commit(document, run)
    return {
        "installed": installed,
        "remote": remote,
        "behind": bool(remote) and remote != installed,
        "version": installed_version(document.get("root", "")),
    }


def apply(document: dict, run: Runner = run_text, force: bool = False) -> dict:
    """Moves the checkout to the remote branch; {"commit"} or {"error"}."""
    if not document.get("root"):
        return {"error": "no install record: run the installer first"}
    if is_dirty(document, run) and not force:
        return {"error": ERR_DIRTY}
    branch = document.get("branch") or "main"
    remote = document.get("remote") or "origin"
    root = str(document["root"])
    if run(["git", "-C", root, "fetch", "--depth", "1", remote, branch]) is None:
        return {"error": ERR_FETCH}
    if run(["git", "-C", root, "reset", "--hard", "FETCH_HEAD"]) is None:
        return {"error": ERR_MOVE}
    return {"commit": (run(["git", "-C", root, "rev-parse", "HEAD"]) or "").strip()}


def reinstall(document: dict, run: Runner = run_text, dry_run: bool = False) -> bool:
    """Runs the installer again with the recorded choices."""
    root = document.get("root") or ""
    installer = Path(root) / "install.sh"
    if not installer.is_file():
        return False
    command = [str(installer), "--yes"]
    for compositor in (document.get("compositors") or "").split():
        command += ["--compositor", compositor]
    for helper in (document.get("aur") or "").split():
        command += ["--aur", helper]
    if document.get("vpn"):
        command += ["--vpn", document["vpn"]]
    if dry_run:
        command.append("--dry-run")
    return run(command) is not None


def command(args) -> int:
    document = state()
    if not document:
        print("vitrail is not installed from a checkout; nothing to update.")
        return 1
    if args.check:
        result = check(document)
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0
    result = apply(document, force=args.force)
    if "error" in result:
        print(f"update refused: {result['error']}")
        return 1
    print(f"checkout at {result['commit'][:12]}")
    if not reinstall(document, dry_run=args.dry_run):
        print("the checkout moved but the installer did not run; run ./install.sh yourself")
        return 1
    print("updated")
    return 0


def main(argv: list[str] | None = None, run: Runner = run_text) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    options = type("Options", (), {})()
    options.check = "--check" in args
    options.force = "--force" in args
    options.dry_run = "--dry-run" in args
    return command(options)


if __name__ == "__main__":
    raise SystemExit(main())
