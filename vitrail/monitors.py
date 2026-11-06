"""Monitors: read Hyprland's outputs and apply Vitrail's per-monitor overrides.

The settings window cannot run commands, so this module does both halves:

    python3 -m vitrail.monitors state   prints the monitors as JSON
    python3 -m vitrail.monitors apply   applies `monitorOverrides` from
                                        monitors.ini, then rewrites
                                        monitor-state.json

`bin/vitrail-settings` injects `state` at launch; `scripts/apply-settings.sh`
runs `apply` when a preference changes, and the Hyprland start hook runs
`vitrail-monitors apply --force`, so the layout survives a logout without the
bar being involved.

The document is one JSON object in `monitors.ini` (`monitorOverrides`), keyed by
output name:

    { "DP-1": { "mode": "2560x1440@180", "position": "0x0", "scale": 1,
                "transform": 0, "disabled": false, "mirror": "",
                "primary": true } }

`primary` is not a monitor rule: it names the one output that receives
workspace 1 when the document is applied. At most one output may carry it.

Every value is validated before it becomes Lua: the rule is assembled here,
never taken from the file as text.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import Callable

from . import prefs

STATE_FILE = "monitor-state.json"
# hyprctl answers at once; a hung compositor must not hang the settings watcher.
READ_TIMEOUT = 5
# An output name: Hyprland uses the connector (DP-1, HDMI-A-1, eDP-1) or, when
# asked for, a `desc:` prefix followed by the description (spaces allowed).
NAME = re.compile(r"^[A-Za-z0-9._-]+$|^desc:[A-Za-z0-9._: -]+$")
# A mode: "preferred"/"highres"… or WxH with an optional refresh.
MODE = re.compile(r"^(preferred|highres|highrr|highhh|\d{2,5}x\d{2,5}(@\d+(\.\d+)?)?)$")
POSITION = re.compile(r"^(auto(-(left|right|up|down))?|-?\d+x-?\d+)$")

Runner = Callable[[list[str]], str | None]

FIELDS = {"mode", "position", "scale", "transform", "disabled", "mirror", "primary"}


def log(message: str) -> None:
    print(f"vitrail-monitors: {message}", file=sys.stderr, flush=True)


def run_text(argv: list[str], timeout: int = READ_TIMEOUT) -> str | None:
    """A command's stdout, or None when it is missing, failed or timed out."""
    try:
        found = subprocess.run(argv, capture_output=True, text=True, timeout=timeout, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return found.stdout if found.returncode == 0 else None


def config_dir() -> Path:
    return prefs.config_dir()


def cache_dir() -> Path:
    base = os.environ.get("XDG_CACHE_HOME") or str(Path.home() / ".cache")
    return Path(base) / "vitrail" / "system"


# --- reading -----------------------------------------------------------------


def _mode_of(monitor: dict) -> str:
    """The listed mode that matches the current resolution and refresh."""
    width, height = monitor.get("width"), monitor.get("height")
    refresh = monitor.get("refreshRate")
    best, distance = "", None
    for raw in monitor.get("availableModes") or []:
        if not isinstance(raw, str):
            continue
        size, _, rate = raw.partition("@")
        try:
            w, h = (int(part) for part in size.split("x", 1))
        except ValueError:
            continue
        if (w, h) != (width, height):
            continue
        try:
            hertz = float(rate.removesuffix("Hz"))
        except ValueError:
            hertz = 0.0
        if not isinstance(refresh, (int, float)) or isinstance(refresh, bool):
            return size
        gap = abs(hertz - float(refresh))
        if distance is None or gap < distance:
            best, distance = size if not rate else f"{size}@{hertz:.2f}", gap
    return best


def parse_monitors(text: str | None) -> list[dict]:
    try:
        data = json.loads(text or "[]")
    except (TypeError, ValueError):
        return []
    if not isinstance(data, list):
        return []
    monitors = []
    for one in data:
        if not isinstance(one, dict) or not isinstance(one.get("name"), str) or not one["name"]:
            continue
        r = one.get("refreshRate")
        modes = [raw.removesuffix("Hz") for raw in one.get("availableModes") or [] if isinstance(raw, str)]
        monitor = {
            "name": one["name"],
            "description": one.get("description") or "",
            "width": int(one.get("width") or 0),
            "height": int(one.get("height") or 0),
            "refresh": float(r) if isinstance(r, (int, float)) and not isinstance(r, bool) else 0.0,
            "x": int(one.get("x") or 0),
            "y": int(one.get("y") or 0),
            "scale": float(one.get("scale") or 1.0),
            "transform": int(one.get("transform") or 0),
            "disabled": bool(one.get("disabled")),
            "mirror": "" if one.get("mirrorOf") in (None, "", "none") else str(one["mirrorOf"]),
            "focused": bool(one.get("focused")),
            "modes": modes,
        }
        monitor["mode"] = _mode_of(one) or "preferred"
        monitors.append(monitor)
    return monitors


def state(run: Runner = run_text, overrides: dict | None = None) -> dict:
    """The live outputs plus the document the page may edit."""
    text = run(["hyprctl", "monitors", "-j"])
    try:
        answer = json.loads(text or "")
    except ValueError:
        answer = None
    available = isinstance(answer, list)
    return {"available": available, "monitors": parse_monitors(text) if available else [], "overrides": overrides or {}}


# --- the document ------------------------------------------------------------


def _number(value: object, low: float, high: float, what: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError(f"{what} is not a number")
    number = float(value)
    if not low <= number <= high:
        raise ValueError(f"{what} is out of range")
    return number


def _one(name: str, spec: object) -> dict:
    if not NAME.match(name):
        raise ValueError(f"not an output name: {name!r}")
    if not isinstance(spec, dict):
        raise ValueError(f"{name}: the override is not an object")
    unknown = set(spec) - FIELDS
    if unknown:
        raise ValueError(f"{name}: unknown field {sorted(unknown)[0]}")
    cleaned: dict = {}
    if "mode" in spec:
        if not isinstance(spec["mode"], str) or not MODE.match(spec["mode"]):
            raise ValueError(f"{name}: bad mode")
        if "@" in spec["mode"] and not 1 <= float(spec["mode"].split("@", 1)[1]) <= 500:
            raise ValueError(f"{name}: bad refresh")
        cleaned["mode"] = spec["mode"]
    if "position" in spec:
        if not isinstance(spec["position"], str) or not POSITION.match(spec["position"]):
            raise ValueError(f"{name}: bad position")
        cleaned["position"] = spec["position"]
    if "scale" in spec:
        cleaned["scale"] = _number(spec["scale"], 0.25, 4.0, f"{name}: scale")
    if "transform" in spec:
        if (
            isinstance(spec["transform"], bool)
            or not isinstance(spec["transform"], int)
            or not 0 <= spec["transform"] <= 7
        ):
            raise ValueError(f"{name}: bad transform")
        cleaned["transform"] = spec["transform"]
    if "disabled" in spec:
        if not isinstance(spec["disabled"], bool):
            raise ValueError(f"{name}: disabled is not a boolean")
        cleaned["disabled"] = spec["disabled"]
    if "mirror" in spec:
        if not isinstance(spec["mirror"], str) or (spec["mirror"] and not NAME.match(spec["mirror"])):
            raise ValueError(f"{name}: bad mirror")
        if spec["mirror"] == name:
            raise ValueError(f"{name}: cannot mirror itself")
        cleaned["mirror"] = spec["mirror"]
    if "primary" in spec:
        if not isinstance(spec["primary"], bool):
            raise ValueError(f"{name}: primary is not a boolean")
        cleaned["primary"] = spec["primary"]
    return cleaned


def primary_of(data: dict) -> str:
    """The output that owns workspace 1, or "" when the document names none."""
    return next((name for name in sorted(data) if data[name].get("primary")), "")


def document(text: str | None) -> dict:
    """The validated overrides document; ValueError when it is not one."""
    if text is None or not text.strip():
        return {}
    try:
        data = json.loads(text)
    except ValueError as error:
        raise ValueError("not JSON") from error
    if not isinstance(data, dict):
        raise ValueError("the document is not an object")
    cleaned = {name: _one(name, spec) for name, spec in data.items()}
    if len([name for name, spec in cleaned.items() if spec.get("primary")]) > 1:
        raise ValueError("only one output may be primary")
    return cleaned


# --- applying ----------------------------------------------------------------


def rule(name: str, spec: dict | None) -> str:
    """The Lua rule for one output; a missing override is the default layout."""
    parts = [f'output = "{name}"']
    if spec is None:
        return "hl.monitor({ " + ", ".join(parts + ['mode = "preferred"', 'position = "auto"', "scale = 1"]) + " })"
    if spec.get("mirror"):
        return "hl.monitor({ " + ", ".join(parts + [f'mirror = "{spec["mirror"]}"']) + " })"
    if spec.get("disabled"):
        return "hl.monitor({ " + ", ".join(parts + ["disabled = true"]) + " })"
    parts.append(f'mode = "{spec.get("mode", "preferred")}"')
    parts.append(f'position = "{spec.get("position", "auto")}"')
    parts.append(f"scale = {float(spec.get('scale', 1))}")
    if "transform" in spec:
        parts.append(f"transform = {spec['transform']}")
    return "hl.monitor({ " + ", ".join(parts) + " })"


def _write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.part")
    temporary.write_text(text, encoding="utf-8")
    os.replace(temporary, path)


def apply(
    text: str | None, config: Path | None = None, cache: Path | None = None, run: Runner = run_text, force: bool = False
) -> int:
    """Applies the overrides; 0 when it ran (or was already applied), 2 when
    the document is invalid, 1 when the compositor refused a rule."""
    config = config or config_dir()
    cache = cache or cache_dir()
    try:
        data = document(text)
    except ValueError as error:
        log(f"refused: {error}")
        return 2
    if not data:
        return 0

    primary = primary_of(data)
    canonical = json.dumps(data, sort_keys=True, separators=(",", ":"))
    stamp = cache / "monitors"
    if not force and stamp.is_file():
        try:
            if stamp.read_text(encoding="utf-8").strip() == canonical:
                _write(
                    config / STATE_FILE,
                    json.dumps(
                        state(run=run, overrides=data)
                        | {
                            "updated": int(time.time() * 1000),
                            "primary": primary,
                            "result": {"code": 0, "skipped": True},
                        },
                        separators=(",", ":"),
                    ),
                )
                return 0
        except OSError:
            pass

    failed = []
    for name in sorted(data):
        answer = run(["hyprctl", "eval", rule(name, data[name])])
        if (answer or "").strip() != "ok":
            failed.append(name)
    # The primary output owns workspace 1. The rule is applied at every
    # login by the start hook; this moves the workspace now.
    workspace = None
    if primary:
        moved = (run(["hyprctl", "dispatch", "moveworkspacetomonitor", "1", primary]) or "").strip() == "ok"
        workspace = {"monitor": primary, "workspace": 1, "moved": moved}
        if not moved:
            log(f"the compositor refused workspace 1 on {primary}")
    stamp.parent.mkdir(parents=True, exist_ok=True)
    _write(stamp, canonical)
    code = 1 if failed or (workspace is not None and not workspace["moved"]) else 0
    if failed:
        log(f"the compositor refused {', '.join(failed)}")
    result: dict = {"code": code, "failed": failed}
    if workspace is not None:
        result["workspace"] = workspace
    _write(
        config / STATE_FILE,
        json.dumps(
            state(run=run, overrides=data)
            | {
                "updated": int(time.time() * 1000),
                "primary": primary,
                "result": result,
            },
            separators=(",", ":"),
        ),
    )
    return code


def load_document() -> str:
    return prefs.read_prefs(config_dir()).get("monitorOverrides", "{}")


def main(argv: list[str] | None = None, run: Runner = run_text) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    if args == ["state"]:
        try:
            overrides = document(load_document())
        except ValueError:
            overrides = {}
        print(json.dumps(state(run=run, overrides=overrides), separators=(",", ":")))
        return 0
    if args[:1] == ["apply"]:
        return apply(load_document(), run=run, force="--force" in args)
    print("usage: monitors state | monitors apply [--force]", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
