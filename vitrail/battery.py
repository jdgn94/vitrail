"""The battery of every peripheral: mouse, keyboard, headphones and gamepad.

    python3 -m vitrail.battery state

UPower already reads every device that reports a battery, so nothing here talks
to the hardware: `upower -e` lists the object paths and `upower -i <path>` prints
one block of `key: value` lines per device. The machine's own battery
(`power supply: yes`), line power and UPower's synthetic `DisplayDevice` are left
out; what remains is a peripheral. A machine without `upower`, or with no
peripheral awake, is normal: `{"devices": [], "lowest": null, "error": null}`
and exit 0.

`lowest` is the one number the bar shows: the smallest percentage among the
devices that discharge, folding the charging (and full, and unknown) ones only
when nothing is discharging. A percentage UPower marks "should be ignored" is
an estimate from a coarse battery level, so it is reported as null.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
from collections.abc import Callable

Runner = Callable[[list[str]], "str | None"]

# UPower answers at once; a daemon that hangs must not hold the bar.
READ_TIMEOUT = 5

# A `key: value` line (UPower indents a battery's fields four spaces deep), the
# bare type line ("  mouse") and its percentages and durations.
FIELD = re.compile(r"^ +([a-z][a-z0-9 -]*):\s+(\S.*)$")
KIND = re.compile(r"^ {2}([a-z][a-z0-9-]*)$")
PERCENT = re.compile(r"^(\d+(?:\.\d+)?)%")
DURATION = re.compile(r"^(\d+(?:\.\d+)?)\s+(hour|hours|minute|minutes|second|seconds)$")

# UPower's device kinds, folded into the four icons the UI draws. A device of
# any other kind is still a peripheral when it does not power the machine.
KINDS = {
    "mouse": "mouse",
    "keyboard": "keyboard",
    "headset": "headphones",
    "headphones": "headphones",
    "gaming-input": "gamepad",
    "joystick": "gamepad",
    "gamepad": "gamepad",
}
STATES = {"charging": "charging", "discharging": "discharging", "fully-charged": "full", "full": "full"}
# The synthetic device for the machine as a whole, and line power (whose own
# block says `power supply: no` once the cable is out).
DISPLAY_DEVICE = "DisplayDevice"
LINE_POWER = "line-power"


def run_text(argv: list[str]) -> str | None:
    """Standard output of a command; None when it is missing, fails or hangs."""
    if shutil.which(argv[0]) is None:
        return None
    try:
        done = subprocess.run(argv, capture_output=True, text=True, check=False, timeout=READ_TIMEOUT)
    except (OSError, subprocess.SubprocessError):
        return None
    return done.stdout if done.returncode == 0 else None


def parse_paths(text: str) -> list[str]:
    """`upower -e`: one object path per line."""
    return [line.strip() for line in text.splitlines() if line.strip()]


def percentage(value: str) -> int | None:
    """0-100, or None when UPower says the number is only an estimate."""
    found = PERCENT.match(value)
    if found is None or "should be ignored" in value:
        return None
    return max(0, min(100, round(float(found.group(1)))))


def minutes(value: str) -> int | None:
    """A `time to empty` value as whole minutes; None when it says nothing usable."""
    found = DURATION.match(value)
    if found is None:
        return None
    amount, unit = float(found.group(1)), found.group(2)
    if unit.startswith("hour"):
        return round(amount * 60)
    if unit.startswith("minute"):
        return round(amount)
    return round(amount / 60)


def parse_info(text: str) -> dict:
    """One `upower -i` block: the fields the UI shows, with the type line as
    `kind`. A field UPower did not print keeps its empty value instead."""
    info: dict = {
        "native_path": "",
        "model": "",
        "serial": "",
        "power_supply": None,
        "kind": "",
        "state": "unknown",
        "percentage": None,
        "time_to_empty": None,
    }
    for line in text.splitlines():
        kind = KIND.match(line)
        if kind and not info["kind"]:
            info["kind"] = kind.group(1)
            continue
        field = FIELD.match(line)
        if field is None:
            continue
        key, value = field.group(1), field.group(2).strip()
        if value == "(null)":
            value = ""
        match key:
            case "native-path":
                info["native_path"] = value
            case "model":
                info["model"] = value
            case "serial":
                info["serial"] = value
            case "power supply":
                info["power_supply"] = value == "yes"
            case "percentage":
                info["percentage"] = percentage(value)
            case "state":
                info["state"] = STATES.get(value, "unknown")
            case "time to empty":
                info["time_to_empty"] = minutes(value)
    return info


def device(path: str, info: dict) -> dict | None:
    """A peripheral's entry; None for the machine's own battery, line power and
    the synthetic display device UPower reports for the machine as a whole."""
    name = path.rsplit("/", 1)[-1]
    if name == DISPLAY_DEVICE or info["kind"] == LINE_POWER or "line_power" in path:
        return None
    if info["power_supply"]:
        return None
    return {
        "path": path,
        "name": info["model"] or info["native_path"] or name,
        "kind": KINDS.get(info["kind"], "other"),
        "percentage": info["percentage"],
        "state": info["state"],
        "timeToEmpty": info["time_to_empty"],
        "model": info["model"],
        "serial": info["serial"],
    }


def lowest(devices: list[dict]) -> dict | None:
    """The lowest discharging percentage; else the lowest of the charging, full
    and unknown ones. None when nothing reports a percentage: one number for the
    bar, never an invented one."""
    known = [one for one in devices if one["percentage"] is not None]
    if not known:
        return None
    best = min(known, key=lambda one: (one["state"] != "discharging", one["percentage"], one["name"].casefold()))
    return {"name": best["name"], "percentage": best["percentage"]}


def state(run: Runner = run_text) -> dict:
    """Every peripheral UPower knows, and the lowest of them. A missing program
    or daemon leaves an empty list: no peripheral is not a failure."""
    devices = []
    seen = set()
    for path in parse_paths(run(["upower", "-e"]) or ""):
        if path in seen:
            continue
        seen.add(path)
        text = run(["upower", "-i", path])
        if text is None:
            continue
        found = device(path, parse_info(text))
        if found is not None:
            devices.append(found)
    devices.sort(key=lambda one: (one["name"].casefold(), one["path"]))
    return {"devices": devices, "lowest": lowest(devices), "error": None}


def main(argv: list[str] | None = None, run: Runner = run_text) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    if args == ["state"]:
        print(json.dumps(state(run), separators=(",", ":")))
        return 0
    print("usage: battery state", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
