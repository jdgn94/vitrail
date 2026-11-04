"""The weather, keyless: Open-Meteo's forecast for the user's place.

    python3 -m vitrail.weather state            the weather as JSON
    python3 -m vitrail.weather set-location <city>

The place comes from the IP the first time (ipapi.co) and, when that fails or
the user typed one, from `weatherLocation` (geocoded on Open-Meteo). The answer
is cached in ~/.cache/vitrail/weather.json for 15 minutes; without a network the
last answer comes back with an `error`, and with no cache at all the state is
only `{"error": ...}`. Nothing here holds a key or runs a program.
"""

from __future__ import annotations

import http.client
import json
import os
import sys
import time
import urllib.parse
import urllib.request
from collections.abc import Callable
from pathlib import Path

from vitrail import prefs

FORECAST = "https://api.open-meteo.com/v1/forecast"
GEOCODE = "https://geocoding-api.open-meteo.com/v1/search"
IP_LOOKUP = "https://ipapi.co/json/"
CACHE_FILE = "weather.json"
CACHE_SECONDS = 15 * 60
TIMEOUT = 8
MAX_BYTES = 1024 * 1024
# The fields the bar and the dashboard show, and nothing else.
CURRENT_FIELDS = "temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code"
DAILY_FIELDS = "temperature_2m_max,temperature_2m_min,weather_code"
DAY_COUNT = 7
UNITS = {
    "metric": {},
    "imperial": {"temperature_unit": "fahrenheit", "wind_speed_unit": "mph"},
}
# Open-Meteo's WMO weather codes. The number stays in the state so a translation
# can describe it again later; these words are the English fallback.
CONDITIONS = {
    0: "Clear sky",
    1: "Mainly clear",
    2: "Partly cloudy",
    3: "Overcast",
    45: "Fog",
    48: "Rime fog",
    51: "Light drizzle",
    53: "Drizzle",
    55: "Heavy drizzle",
    56: "Freezing drizzle",
    57: "Freezing drizzle",
    61: "Light rain",
    63: "Rain",
    65: "Heavy rain",
    66: "Freezing rain",
    67: "Freezing rain",
    71: "Light snow",
    73: "Snow",
    75: "Heavy snow",
    77: "Snow grains",
    80: "Light showers",
    81: "Showers",
    82: "Violent showers",
    85: "Snow showers",
    86: "Heavy snow showers",
    95: "Thunderstorm",
    96: "Thunderstorm with hail",
    99: "Thunderstorm with heavy hail",
}

Fetcher = Callable[[str], str]


def cache_file(folder: Path | None = None) -> Path:
    """The cache file, under ~/.cache/vitrail unless a folder is given."""
    base = folder or Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "vitrail"
    return base / CACHE_FILE


def http_get(url: str) -> str:
    """The body of a URL; OSError when it cannot be reached."""
    request = urllib.request.Request(url, headers={"User-Agent": "vitrail"})
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT) as answer:
            return answer.read(MAX_BYTES).decode("utf-8", "replace")
    except http.client.HTTPException as error:
        raise OSError(str(error)) from error


def units_of(values: dict[str, str]) -> str:
    """The units the preference asks for; anything but "imperial" is metric."""
    return "imperial" if values.get("weatherUnits") == "imperial" else "metric"


def describe(code: int) -> str:
    """The words for a WMO weather code."""
    return CONDITIONS.get(code, "Unknown")


def _number(value: object, field: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError(f"missing {field}")
    return float(value)


def _place(
    name: object, latitude: object, longitude: object, timezone: object = "", admin1: object = "", country: object = ""
) -> dict:
    return {
        "name": str(name or ""),
        "admin1": str(admin1 or ""),
        "country": str(country or ""),
        "latitude": _number(latitude, "latitude"),
        "longitude": _number(longitude, "longitude"),
        "timezone": str(timezone or ""),
    }


def parse_forecast(text: str) -> dict:
    """Open-Meteo's answer as `units`, `current` and `daily`.

    A ValueError when the answer is not the document the request asked for,
    which is how a captive portal or a changed API is reported.
    """
    try:
        data = json.loads(text)
    except ValueError as error:
        raise ValueError("the forecast is not JSON") from error
    if not isinstance(data, dict):
        raise ValueError("the forecast is not an object")
    current, daily = data.get("current"), data.get("daily")
    if not isinstance(current, dict) or not isinstance(daily, dict):
        raise ValueError("the forecast has no current or daily section")

    code = int(_number(current.get("weather_code"), "weather code"))
    now = {
        "time": str(current.get("time") or ""),
        "temperature": _number(current.get("temperature_2m"), "temperature"),
        "humidity": int(_number(current.get("relative_humidity_2m"), "humidity")),
        "wind": _number(current.get("wind_speed_10m"), "wind"),
        "code": code,
        "condition": describe(code),
    }
    days = daily.get("time")
    highs = daily.get("temperature_2m_max")
    lows = daily.get("temperature_2m_min")
    codes = daily.get("weather_code")
    if not all(isinstance(one, list) for one in (days, highs, lows, codes)) or len(days) != len(highs) != len(
        lows
    ) != len(codes):
        raise ValueError("the daily forecast is incomplete")
    if not days:
        raise ValueError("the daily forecast is empty")

    forecast = []
    for date, high, low, day_code in zip(days, highs, lows, codes):
        number = int(_number(day_code, "weather code"))
        forecast.append(
            {
                "date": str(date or ""),
                "high": _number(high, "high"),
                "low": _number(low, "low"),
                "code": number,
                "condition": describe(number),
            }
        )
    units = data.get("current_units") if isinstance(data.get("current_units"), dict) else {}
    return {
        "units": {
            "temperature": str(units.get("temperature_2m") or "°C"),
            "humidity": str(units.get("relative_humidity_2m") or "%"),
            "wind": str(units.get("wind_speed_10m") or "km/h"),
        },
        "current": now,
        "daily": forecast,
    }


def forecast_url(location: dict, unit_kind: str) -> str:
    query = {
        "latitude": location["latitude"],
        "longitude": location["longitude"],
        "current": CURRENT_FIELDS,
        "daily": DAILY_FIELDS,
        "forecast_days": DAY_COUNT,
        "timezone": "auto",
    } | UNITS.get(unit_kind, {})
    return f"{FORECAST}?{urllib.parse.urlencode(query)}"


def ip_location(get: Fetcher = http_get) -> dict:
    """The place ipapi.co guesses from the address; ValueError when it cannot."""
    try:
        data = json.loads(get(IP_LOOKUP))
    except ValueError as error:
        raise ValueError("the IP location is not JSON") from error
    if not isinstance(data, dict) or data.get("error"):
        raise ValueError("the IP location service did not answer")
    return _place(
        data.get("city") or data.get("region") or data.get("country_name"),
        data.get("latitude"),
        data.get("longitude"),
        data.get("timezone"),
        data.get("region"),
        data.get("country_name"),
    )


def geocode(city: str, get: Fetcher = http_get) -> dict:
    """The first place Open-Meteo's geocoder finds for a name."""
    query = urllib.parse.urlencode({"name": city, "count": 1, "language": "en", "format": "json"})
    try:
        data = json.loads(get(f"{GEOCODE}?{query}"))
    except ValueError as error:
        raise ValueError("the geocoder answer is not JSON") from error
    results = data.get("results") if isinstance(data, dict) else None
    if not isinstance(results, list) or not results or not isinstance(results[0], dict):
        raise ValueError(f"no place found for {city!r}")
    first = results[0]
    return _place(
        first.get("name"),
        first.get("latitude"),
        first.get("longitude"),
        first.get("timezone"),
        first.get("admin1"),
        first.get("country"),
    )


def resolve_location(source: str, stored: dict | None, get: Fetcher = http_get) -> dict:
    """The place to ask about: the city the user typed, else the cached one,
    else the address's. The cache saves the geocoder and the IP service."""
    cached = stored.get("location") if stored and stored.get("source") == source else None
    if isinstance(cached, dict) and "latitude" in cached:
        return cached
    return geocode(source, get) if source else ip_location(get)


def load_cache(path: Path) -> dict | None:
    try:
        stored = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    return stored if isinstance(stored, dict) else None


def save_cache(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    partial = path.with_name(f".{path.name}.part")
    partial.write_text(json.dumps(payload, separators=(",", ":")), encoding="utf-8")
    os.replace(partial, path)


def _fresh(stored: dict | None, now: float, source: str, unit_kind: str) -> bool:
    if not stored or not isinstance(stored.get("state"), dict):
        return False
    if stored.get("source") != source or stored.get("units") != unit_kind:
        return False
    saved = stored.get("saved_at")
    return isinstance(saved, (int, float)) and 0 <= now - saved < CACHE_SECONDS


def state(
    config: Path | None = None,
    cache: Path | None = None,
    get: Fetcher = http_get,
    now: float | None = None,
) -> dict:
    """The weather for the configured place.

    `location`, `units`, `current`, `daily` and `updated` (epoch seconds), plus
    `cached` for whether it came from disk. Without a network the last answer is
    returned with `error`; without a cache, the state is only `{"error": ...}`.
    """
    config = config or prefs.config_dir()
    values = prefs.read_prefs(config)
    unit_kind = units_of(values)
    source = values.get("weatherLocation", "").strip()
    path = cache_file(cache)
    stored = load_cache(path)
    now = time.time() if now is None else now

    if _fresh(stored, now, source, unit_kind):
        return {**stored["state"], "cached": True}

    try:
        location = resolve_location(source, stored, get)
        answer = parse_forecast(get(forecast_url(location, unit_kind)))
        result = {"location": location, **answer, "updated": int(now)}
        save_cache(
            path,
            {"saved_at": now, "source": source, "units": unit_kind, "location": location, "state": result},
        )
        return {**result, "cached": False}
    except (OSError, ValueError, http.client.HTTPException) as error:
        if stored and isinstance(stored.get("state"), dict):
            return {**stored["state"], "cached": True, "error": str(error)}
        return {"error": str(error)}


def set_location(city: str, config: Path | None = None) -> str:
    """Stores the city the weather is asked for; ValueError for anything empty
    or carrying control characters."""
    name = str(city).strip()
    if not name or len(name) > 80 or name.startswith("-") or any(ord(char) < 32 or ord(char) == 127 for char in name):
        raise ValueError("a city needs 1 to 80 printable characters")
    prefs.write_pref(config or prefs.config_dir(), "weatherLocation", name)
    return name


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    if args == ["state"]:
        data = state()
        print(json.dumps(data, separators=(",", ":")))
        return 0 if "current" in data else 1
    if len(args) == 2 and args[0] == "set-location":
        try:
            city = set_location(args[1])
        except ValueError as error:
            print(f"weather: {error}", file=sys.stderr)
            return 2
        print(f"Weather location: {city}")
        return 0
    print("usage: weather state | set-location <city>", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
