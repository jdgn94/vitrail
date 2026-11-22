"""Containers: what docker or podman is running, and how to act on it.

    python3 -m vitrail.containers state

Neither engine is a dependency: `ps -a --format json` (both print one JSON
object per line; an older engine may print one array) is read through an
injected runner, so the module works on a machine with neither installed.
Then the state says `engine: null` and the bar hides the element; that is
normal, not an error. `start`, `stop` and `logs` are only argv builders: the
UI runs them through its own process, this module executes nothing but the
listing of `state()`.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
from collections.abc import Callable

# Docker first: a machine with both usually means docker is the one in use.
ENGINES = ("docker", "podman")
READ_TIMEOUT = 5
# Docker writes "Up 2 hours (healthy)", podman "healthy" in its own field.
HEALTH = re.compile(r"\((healthy|unhealthy|health: starting)\)")
Runner = Callable[[list[str]], str | None]


def run_text(argv: list[str]) -> str | None:
    """Standard output of a command; None when it is missing, fails or hangs."""
    if shutil.which(argv[0]) is None:
        return None
    try:
        done = subprocess.run(argv, capture_output=True, text=True, check=False, timeout=READ_TIMEOUT)
    except (OSError, subprocess.SubprocessError):
        return None
    return done.stdout if done.returncode == 0 else None


def engine(run: Runner = run_text, option: str | None = None) -> str | None:
    """The engine to use: the one `option` names, else docker, else podman.

    An engine is there only when its `--version` answers."""
    candidates = (option,) if option in ENGINES else ENGINES
    return next((name for name in candidates if run([name, "--version"]) is not None), None)


def available(run: Runner = run_text, option: str | None = None) -> bool:
    """Whether there is an engine at all: the UI hides the element without one."""
    return engine(run, option) is not None


def ports_of(value: object) -> str:
    """A readable port list: docker prints a string, podman a list of mappings."""
    if isinstance(value, str):
        return value
    if not isinstance(value, list):
        return ""
    mappings = []
    for port in value:
        if not isinstance(port, dict) or port.get("container_port") is None:
            continue
        target, protocol = port["container_port"], port.get("protocol") or "tcp"
        published = port.get("host_port")
        hosted = f"{port.get('host_ip') or '0.0.0.0'}:{published}->" if published else ""
        mappings.append(f"{hosted}{target}/{protocol}")
    return ", ".join(mappings)


def health_of(status: str) -> str | None:
    """The health a docker status carries; None for a container without one."""
    found = HEALTH.search(status)
    return found.group(1).removeprefix("health: ") if found else None


def container(one: dict) -> dict | None:
    """One container of a `ps --format json` entry, whatever name its engine uses."""
    ident = one.get("ID") or one.get("Id")
    if not isinstance(ident, str) or not ident:
        return None
    name = one.get("Names") or one.get("Name") or ""
    name = name[0] if isinstance(name, list) and name else name
    status = str(one.get("Status") or "")
    health = one.get("Health")
    return {
        "id": ident,
        "name": str(name),
        "image": str(one.get("Image") or ""),
        "state": str(one.get("State") or ""),
        "status": status,
        "health": health if isinstance(health, str) and health else health_of(status),
        "ports": ports_of(one.get("Ports")),
    }


def parse_ps(text: str) -> list[dict]:
    """The containers `ps -a --format json` printed: one object per line, or the
    array an older engine emits. Anything that is not a container is skipped."""
    stripped = text.strip()
    if not stripped:
        return []
    try:
        whole = json.loads(stripped)
    except ValueError:
        whole = None
    if isinstance(whole, list):
        objects = whole
    elif isinstance(whole, dict):
        objects = [whole]
    else:
        objects = []
        for line in stripped.splitlines():
            try:
                one = json.loads(line)
            except ValueError:
                continue
            if isinstance(one, dict):
                objects.append(one)
    return [entry for one in objects if isinstance(one, dict) and (entry := container(one)) is not None]


def state(run: Runner = run_text, option: str | None = None) -> dict:
    """The engine, how many containers are running and the containers themselves.
    No engine is an ordinary empty state; a listing that fails is an error."""
    name = engine(run, option)
    if name is None:
        return {"engine": None, "running": 0, "containers": [], "error": None}
    listing = run([name, "ps", "-a", "--format", "json"])
    if listing is None:
        return {"engine": name, "running": 0, "containers": [], "error": f"{name} ps failed"}
    containers = parse_ps(listing)
    return {
        "engine": name,
        "running": sum(1 for one in containers if one["state"] == "running"),
        "containers": containers,
        "error": None,
    }


def start(name: str, ident: str) -> list[str]:
    return [name, "start", ident]


def stop(name: str, ident: str) -> list[str]:
    return [name, "stop", ident]


def logs(name: str, ident: str) -> list[str]:
    return [name, "logs", "--tail", "200", ident]


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    option: str | None = None
    if args and args[0] == "state":
        rest = args[1:]
        if rest:
            if len(rest) == 2 and rest[0] == "--engine" and rest[1] in ENGINES + ("auto",):
                option = None if rest[1] == "auto" else rest[1]
            else:
                print("usage: containers state [--engine auto|docker|podman]", file=sys.stderr)
                return 2
        print(json.dumps(state(option=option), separators=(",", ":")))
        return 0
    print("usage: containers state [--engine auto|docker|podman]", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
