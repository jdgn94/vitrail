"""Night light: the screen's colour temperature, and when it should apply.

    python3 -m vitrail.nightlight state [--mode off|fixed|sun] [--start HH:MM]
                                        [--end HH:MM] [--temperature K]
                                        [--sunrise HH:MM] [--sunset HH:MM]
    python3 -m vitrail.nightlight enable <K>
    python3 -m vitrail.nightlight disable
    python3 -m vitrail.nightlight set-temperature <K>
    python3 -m vitrail.nightlight apply [--mode …] [--temperature K]

The filter is applied by the `hyprsunset` daemon, which has no configuration
file to read: the temperature and identity flag it is applying come from its
IPC (`hyprctl hyprsunset temperature`, `hyprctl hyprsunset identity get`),
through the injected runner. A daemon that does not answer is a normal state,
not a failure: the filter is simply off.

`state` is one snapshot for the bar's popup. `temperature` is the configured
(value the user set), `enabled` is what the daemon is doing now, and `effective`
is what the schedule asks for at this instant. The popup can therefore show
"active now" or "scheduled for 20:00" without doing the schedule maths itself.

`plan` is the whole schedule rule, pure and clock-free: `now` is always an
argument. `fixed` uses `start`/`end`; `sun` uses `sunset`/`sunrise` (the night
window), falling back to the fixed hours when the weather has no sun times.
Windows may cross midnight. Outside the window the temperature is identity.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from collections.abc import Callable
from datetime import datetime, time

# hyprsunset accepts 1000-20000 K. Below 1000 the matrix is an unusable red and
# the colour maths saturates; above 10000 the filter is invisible. Keeping the
# public range to 1000-10000 makes every value the user can pick meaningful.
MIN_TEMPERATURE = 1000
MAX_TEMPERATURE = 10000
# Neutral daylight: at or above it the screen is left as it is.
IDENTITY_TEMPERATURE = 6500
DEFAULT_TEMPERATURE = 4000
DEFAULT_START = "20:00"
DEFAULT_END = "07:00"
MODES = ("off", "fixed", "sun")
TIMEOUT = 5

Run = Callable[[list[str]], subprocess.CompletedProcess]

CLOCK = re.compile(r"^(\d{1,2}):(\d{2})$")
NUMBER = re.compile(r"\d{3,5}")


def _run(argv: list[str]) -> subprocess.CompletedProcess:
    try:
        return subprocess.run(argv, capture_output=True, text=True, timeout=TIMEOUT)
    except (OSError, subprocess.SubprocessError):
        return subprocess.CompletedProcess(argv, 1, "", "")


def installed() -> bool:
    return shutil.which("hyprsunset") is not None


def clamp_temperature(value: object) -> int:
    """A temperature inside the range the UI and hyprsunset can use."""
    try:
        number = int(value)  # type: ignore[arg-type]
    except (TypeError, ValueError):
        return DEFAULT_TEMPERATURE
    return max(MIN_TEMPERATURE, min(MAX_TEMPERATURE, number))


def parse_clock(value: object) -> int | None:
    """Minutes since midnight for `HH:MM` or a `datetime.time`; None if invalid."""
    if isinstance(value, time):
        return value.hour * 60 + value.minute
    match = CLOCK.match(str(value or "").strip())
    if not match:
        return None
    hour, minute = int(match.group(1)), int(match.group(2))
    if hour > 23 or minute > 59:
        return None
    return hour * 60 + minute


def parse_temperature(text: str) -> int | None:
    """The kelvin a hyprsunset IPC answer carries; None when it carries none."""
    found = NUMBER.search(text or "")
    return int(found.group(0)) if found else None


def parse_identity(text: str) -> bool | None:
    """The identity flag of a hyprsunset IPC answer; None when it is absent."""
    word = (text or "").strip().lower()
    if word.startswith("true"):
        return True
    if word.startswith("false"):
        return False
    return None


def window(schedule: object, sunrise: object = None, sunset: object = None) -> tuple[int, int] | None:
    """The minute window the schedule uses, or None when it names none.

    `sun` uses sunset -> sunrise (the night window), falling back to the fixed
    hours when the weather has no sun times.
    """
    values = schedule if isinstance(schedule, dict) else {}
    mode = values.get("mode", "off")
    if mode == "off" or mode not in MODES:
        return None
    if mode == "sun":
        start = parse_clock(sunset if sunset is not None else values.get("sunset"))
        end = parse_clock(sunrise if sunrise is not None else values.get("sunrise"))
        if start is None or end is None:
            start = parse_clock(values.get("start"))
            end = parse_clock(values.get("end"))
    else:
        start = parse_clock(values.get("start"))
        end = parse_clock(values.get("end"))
    if start is None or end is None or start == end:
        return None
    return start, end


def plan(now: object, schedule: dict, sunrise: object = None, sunset: object = None) -> int:
    """The temperature the schedule asks for at `now`.

    `schedule` holds `mode`, `start`, `end` and `temperature`; the optional
    `sunrise`/`sunset` arguments (or the same keys in the schedule) drive `sun`
    mode. Anything missing or malformed leaves the screen at identity.
    """
    values = schedule if isinstance(schedule, dict) else {}
    mode = values.get("mode", "off")
    minutes = parse_clock(now)
    if mode == "off" or minutes is None:
        return IDENTITY_TEMPERATURE
    bounds = window(values, sunrise, sunset)
    if bounds is None:
        return IDENTITY_TEMPERATURE
    start, end = bounds
    inside = start <= minutes < end if start < end else minutes >= start or minutes < end
    return clamp_temperature(values.get("temperature", DEFAULT_TEMPERATURE)) if inside else IDENTITY_TEMPERATURE


def next_change(now: object, schedule: dict, sunrise: object = None, sunset: object = None) -> dict | None:
    """The next moment `plan` changes its answer, as the popup writes it.

    The candidate is always the window's other edge, so a schedule that crosses
    midnight needs no special case; when the clock sits exactly on an edge the
    following one is next. Off (or a broken window) has no next change.
    """
    values = schedule if isinstance(schedule, dict) else {}
    minutes = parse_clock(now)
    bounds = window(values, sunrise, sunset)
    if minutes is None or bounds is None:
        return None
    start, end = bounds
    edges = [start, end]
    ahead = [edge for edge in edges if edge > minutes]
    at = min(ahead) if ahead else min(edges)
    label = f"{at // 60:02d}:{at % 60:02d}"
    temperature = plan(label, values, sunrise, sunset)
    return {"at": label, "temperature": temperature, "active": temperature < IDENTITY_TEMPERATURE}


def enable_argv(temperature: object) -> list[str]:
    """`hyprsunset -t K`: apply a warmer-than-identity temperature."""
    return ["hyprsunset", "-t", str(clamp_temperature(temperature))]


def set_temperature_argv(temperature: object) -> list[str]:
    """Changing the temperature is the same command as enabling it."""
    return enable_argv(temperature)


def disable_argv() -> list[str]:
    """`hyprsunset -i`: reset the colour matrix to identity."""
    return ["hyprsunset", "-i"]


def enable(temperature: object, *, run: Run = _run) -> bool:
    return run(enable_argv(temperature)).returncode == 0


def disable(*, run: Run = _run) -> bool:
    return run(disable_argv()).returncode == 0


def set_temperature(temperature: object, *, run: Run = _run) -> bool:
    return run(set_temperature_argv(temperature)).returncode == 0


def apply(
    *,
    now: object = None,
    schedule: dict | None = None,
    temperature: object = None,
    sunrise: object = None,
    sunset: object = None,
    run: Run = _run,
) -> dict:
    """Make the daemon match the schedule now; one command, so the bar's timer
    never piles up. `off` means the switch alone decides: on at the configured
    temperature, since there is no window to follow."""
    values = schedule if isinstance(schedule, dict) else {}
    mode = values.get("mode") if values.get("mode") in MODES else "off"
    start = str(values.get("start") or DEFAULT_START)
    end = str(values.get("end") or DEFAULT_END)
    sunrise = sunrise if sunrise is not None else values.get("sunrise")
    sunset = sunset if sunset is not None else values.get("sunset")
    configured = clamp_temperature(
        temperature if temperature is not None else values.get("temperature", DEFAULT_TEMPERATURE)
    )
    when = datetime.now().time() if now is None else now
    if mode == "off":
        target = configured
    else:
        target = plan(
            when,
            {"mode": mode, "start": start, "end": end, "temperature": configured},
            sunrise,
            sunset,
        )

    wanted = target < IDENTITY_TEMPERATURE
    current = current_temperature(run)
    identity = current_identity(run) if current is not None else None
    enabled = current is not None and current < IDENTITY_TEMPERATURE and identity is not True
    changed = wanted != enabled or (wanted and current != target)
    if not changed:
        return {"ok": True, "active": wanted, "temperature": target, "changed": False}
    ok = enable(target, run=run) if wanted else disable(run=run)
    return {"ok": ok, "active": wanted, "temperature": target, "changed": ok}


def current_temperature(run: Run = _run) -> int | None:
    """What hyprsunset is applying now; None when the daemon does not answer."""
    done = run(["hyprctl", "hyprsunset", "temperature"])
    return parse_temperature(done.stdout) if done.returncode == 0 else None


def current_identity(run: Run = _run) -> bool | None:
    """Whether hyprsunset is at identity; None when the query is unavailable.

    `-i` leaves the remembered temperature alone, so the temperature only is
    not enough to tell that the filter was turned off.
    """
    done = run(["hyprctl", "hyprsunset", "identity", "get"])
    return parse_identity(done.stdout) if done.returncode == 0 else None


def state(
    *,
    schedule: dict | None = None,
    temperature: object = None,
    sunrise: object = None,
    sunset: object = None,
    now: object = None,
    run: Run = _run,
    installed: Callable[[], bool] = installed,
) -> dict:
    """One JSON-able snapshot: configured temperature, daemon state and plan.

    `schedule` is `{mode, start, end}` with optional `sunrise`/`sunset`;
    `temperature` is the setting. The daemon is asked for the temperature it is
    applying and its identity flag, which decide `enabled`; a missing program or
    daemon is reported in `error` while the schedule part still comes back.
    """
    values = schedule if isinstance(schedule, dict) else {}
    mode = values.get("mode") if values.get("mode") in MODES else "off"
    start = str(values.get("start") or DEFAULT_START)
    end = str(values.get("end") or DEFAULT_END)
    sunrise = sunrise if sunrise is not None else values.get("sunrise")
    sunset = sunset if sunset is not None else values.get("sunset")
    configured = clamp_temperature(
        temperature if temperature is not None else values.get("temperature", DEFAULT_TEMPERATURE)
    )
    when = datetime.now().time() if now is None else now

    effective = plan(
        when,
        {"mode": mode, "start": start, "end": end, "temperature": configured},
        sunrise,
        sunset,
    )
    upcoming = next_change(
        when,
        {"mode": mode, "start": start, "end": end, "temperature": configured},
        sunrise,
        sunset,
    )

    error = None
    current = None
    identity = None
    if not installed():
        error = "hyprsunset is not installed (package hyprsunset)"
    else:
        current = current_temperature(run)
        if current is None:
            error = "hyprsunset did not answer (is it running?)"
        else:
            identity = current_identity(run)

    return {
        "enabled": current is not None and current < IDENTITY_TEMPERATURE and identity is not True,
        "temperature": configured,
        "schedule": {
            "mode": mode,
            "start": start,
            "end": end,
            "sunrise": sunrise,
            "sunset": sunset,
        },
        "effective": {
            "temperature": effective,
            "active": effective < IDENTITY_TEMPERATURE,
        },
        "next": upcoming,
        "error": error,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="nightlight", description="Night light for the brightness popup.")
    commands = parser.add_subparsers(dest="command", required=True)
    snapshot = commands.add_parser("state", help="the night light state as JSON")
    snapshot.add_argument("--mode", choices=MODES, default="off")
    snapshot.add_argument("--start", default=DEFAULT_START)
    snapshot.add_argument("--end", default=DEFAULT_END)
    snapshot.add_argument("--temperature", type=int, default=DEFAULT_TEMPERATURE)
    snapshot.add_argument("--sunrise", default=None)
    snapshot.add_argument("--sunset", default=None)
    on = commands.add_parser("enable", help="apply a temperature")
    on.add_argument("temperature", type=int)
    commands.add_parser("disable", help="reset to identity")
    change = commands.add_parser("set-temperature", help="apply a temperature")
    change.add_argument("temperature", type=int)
    follow = commands.add_parser("apply", help="make the daemon match the schedule now")
    follow.add_argument("--mode", choices=MODES, default="off")
    follow.add_argument("--start", default=DEFAULT_START)
    follow.add_argument("--end", default=DEFAULT_END)
    follow.add_argument("--temperature", type=int, default=DEFAULT_TEMPERATURE)
    follow.add_argument("--sunrise", default=None)
    follow.add_argument("--sunset", default=None)
    args = parser.parse_args(argv)

    if args.command == "state":
        data = state(
            schedule={"mode": args.mode, "start": args.start, "end": args.end},
            temperature=args.temperature,
            sunrise=args.sunrise,
            sunset=args.sunset,
        )
        print(json.dumps(data, separators=(",", ":")))
        return 0

    if args.command == "apply":
        answer = apply(
            schedule={"mode": args.mode, "start": args.start, "end": args.end},
            temperature=args.temperature,
            sunrise=args.sunrise,
            sunset=args.sunset,
        )
        print(json.dumps(answer, separators=(",", ":")))
        return 0 if answer["ok"] else 1

    if args.command == "enable":
        ok = enable(args.temperature)
    elif args.command == "disable":
        ok = disable()
    else:
        ok = set_temperature(args.temperature)
    if not ok:
        print("nightlight: hyprsunset did not answer (is it installed and running?)", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
