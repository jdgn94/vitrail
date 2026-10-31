"""Time zones for the settings window's world map.

`zone1970.tab` (fallback `zone.tab`) lists every zone with the coordinates of
its main city. The window cannot read tzdata or run commands, so this prints
the list as JSON with each zone's UTC offset right now, and the window only
draws and filters it.
"""

from __future__ import annotations

import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

SHORT = [Path("/usr/share/zoneinfo/zone1970.tab")]
FULL = [Path("/usr/share/zoneinfo/zone.tab")]
COORDINATES = re.compile(r"^([+-])(\d{2})(\d{2})(\d{2})?([+-])(\d{3})(\d{2})(\d{2})?$")


def parse_coordinates(text: str) -> tuple[float, float]:
    """`+4024-00341` or `+554521+0373704` to (latitude, longitude) in degrees."""
    match = COORDINATES.match(text)
    if match is None:
        raise ValueError(f"bad coordinates: {text!r}")
    lat_sign, lat_deg, lat_min, lat_sec, lon_sign, lon_deg, lon_min, lon_sec = match.groups()
    lat = int(lat_deg) + int(lat_min) / 60 + int(lat_sec or 0) / 3600
    lon = int(lon_deg) + int(lon_min) / 60 + int(lon_sec or 0) / 3600
    return (-lat if lat_sign == "-" else lat), (-lon if lon_sign == "-" else lon)


def offset_minutes(zone: str, now: datetime) -> int | None:
    try:
        offset = now.astimezone(ZoneInfo(zone)).utcoffset()
    except (ZoneInfoNotFoundError, ValueError, OSError):
        return None
    return None if offset is None else round(offset.total_seconds() / 60)


def load(paths: list[Path], now: datetime) -> list[dict]:
    """Zones of the first readable table; unknown or malformed rows are skipped."""
    for path in paths:
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except OSError:
            continue
        zones: list[dict] = []
        for line in lines:
            if not line or line.startswith("#"):
                continue
            fields = line.split("\t")
            if len(fields) < 3:
                continue
            try:
                lat, lon = parse_coordinates(fields[1])
            except ValueError:
                continue
            offset = offset_minutes(fields[2], now)
            if offset is None:
                continue
            zones.append({
                "id": fields[2],
                "lat": round(lat, 3),
                "lon": round(lon, 3),
                "offset": offset,
                "note": fields[3] if len(fields) > 3 else "",
            })
        return zones
    return []


def index(
    now: datetime | None = None,
    current: str = "",
    short: list[Path] | None = None,
    full: list[Path] | None = None,
) -> list[dict]:
    """Every zone of the short table, plus `current` when only the full one has it."""
    now = now or datetime.now(timezone.utc)
    zones = load(SHORT if short is None else short, now)
    if current and all(zone["id"] != current for zone in zones):
        zones += [zone for zone in load(FULL if full is None else full, now) if zone["id"] == current]
    return zones


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    if args and args[0] != "index":
        print("usage: timezones index [current-zone]", file=sys.stderr)
        return 2
    print(json.dumps(index(current=args[1] if len(args) > 1 else ""), separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
