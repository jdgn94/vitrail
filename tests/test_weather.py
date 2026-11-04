"""The weather service: keyless Open-Meteo, a location from the IP or a city,
and a cache that keeps the last answer when the network is gone.

Every request is answered by a fake `get`, so these tests never touch the
network.
"""

from __future__ import annotations

import json
import tempfile
import unittest
from contextlib import redirect_stderr
from io import StringIO
from pathlib import Path

from vitrail import prefs, weather

IP_LOCATION = json.dumps(
    {
        "ip": "203.0.113.5",
        "city": "Madrid",
        "region": "Madrid",
        "country_name": "Spain",
        "latitude": 40.4168,
        "longitude": -3.7038,
        "timezone": "Europe/Madrid",
    }
)
GEOCODE = json.dumps(
    {
        "results": [
            {
                "name": "Valencia",
                "latitude": 39.4699,
                "longitude": -0.3763,
                "country": "Spain",
                "admin1": "Valencia",
                "timezone": "Europe/Madrid",
            }
        ]
    }
)
DAYS = ["2026-11-04", "2026-11-05", "2026-11-06", "2026-11-07", "2026-11-08", "2026-11-09", "2026-11-10"]
FORECAST = json.dumps(
    {
        "latitude": 40.42,
        "longitude": -3.7,
        "timezone": "Europe/Madrid",
        "current_units": {"temperature_2m": "°C", "relative_humidity_2m": "%", "wind_speed_10m": "km/h"},
        "current": {
            "time": "2026-11-04T15:00",
            "temperature_2m": 18.4,
            "relative_humidity_2m": 62,
            "wind_speed_10m": 11.2,
            "weather_code": 2,
        },
        "daily": {
            "time": DAYS,
            "temperature_2m_max": [21.0, 20.5, 19.0, 18.0, 17.5, 16.0, 15.5],
            "temperature_2m_min": [10.0, 9.5, 9.0, 8.0, 7.5, 6.0, 5.5],
            "weather_code": [2, 3, 61, 61, 80, 0, 1],
        },
    }
)
IMPERIAL = json.dumps(
    {
        "current_units": {"temperature_2m": "°F", "relative_humidity_2m": "%", "wind_speed_10m": "mph"},
        "current": {
            "time": "2026-11-04T15:00",
            "temperature_2m": 65.1,
            "relative_humidity_2m": 62,
            "wind_speed_10m": 7.0,
            "weather_code": 0,
        },
        "daily": {
            "time": DAYS,
            "temperature_2m_max": [70.0] * 7,
            "temperature_2m_min": [50.0] * 7,
            "weather_code": [0] * 7,
        },
    }
)


class Fake:
    """Answers by URL fragment and remembers what was asked."""

    def __init__(
        self,
        ip: str | Exception = IP_LOCATION,
        geocode: str | Exception = GEOCODE,
        forecast: str | Exception = FORECAST,
    ) -> None:
        self.answers = [
            ("ipapi.co", ip),
            ("geocoding-api", geocode),
            ("api.open-meteo.com/v1/forecast", forecast),
        ]
        self.calls: list[str] = []

    def __call__(self, url: str) -> str:
        self.calls.append(url)
        for part, body in self.answers:
            if part in url:
                if isinstance(body, Exception):
                    raise body
                return body
        raise OSError("no route")


class Fixture(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.config = self.root / "config" / "vitrail"
        self.cache = self.root / "cache" / "vitrail"
        self.config.mkdir(parents=True)

    def state(self, fake: Fake, now: float = 1_000_000.0) -> dict:
        return weather.state(self.config, self.cache, fake, now)

    def set(self, key: str, value: str) -> None:
        prefs.write_pref(self.config, key, value)


class ForecastTests(unittest.TestCase):
    def test_the_answer_becomes_the_flat_shape_the_bar_shows(self) -> None:
        data = weather.parse_forecast(FORECAST)
        self.assertEqual(
            data["current"],
            {
                "time": "2026-11-04T15:00",
                "temperature": 18.4,
                "humidity": 62,
                "wind": 11.2,
                "code": 2,
                "condition": "Partly cloudy",
            },
        )
        self.assertEqual(data["units"], {"temperature": "°C", "humidity": "%", "wind": "km/h"})
        self.assertEqual(
            data["daily"][0], {"date": "2026-11-04", "high": 21.0, "low": 10.0, "code": 2, "condition": "Partly cloudy"}
        )
        self.assertEqual(data["daily"][2]["condition"], "Light rain")
        self.assertEqual(len(data["daily"]), 7)

    def test_an_unknown_code_is_still_described(self) -> None:
        self.assertEqual(weather.describe(1234), "Unknown")

    def test_a_malformed_answer_is_refused(self) -> None:
        for body in (
            "not json",
            "[]",
            "{}",
            json.dumps({"current": {}}),
            json.dumps({"current": {"temperature_2m": "x"}}),
        ):
            with self.subTest(body=body), self.assertRaises(ValueError):
                weather.parse_forecast(body)


class LocationTests(unittest.TestCase):
    def test_the_ip_gives_the_first_location(self) -> None:
        fake = Fake()
        found = weather.ip_location(fake)
        self.assertEqual(
            found,
            {
                "name": "Madrid",
                "admin1": "Madrid",
                "country": "Spain",
                "latitude": 40.4168,
                "longitude": -3.7038,
                "timezone": "Europe/Madrid",
            },
        )
        self.assertIn("ipapi.co", fake.calls[0])

    def test_a_city_is_geocoded_on_open_meteo(self) -> None:
        fake = Fake()
        found = weather.geocode("Valencia", fake)
        self.assertEqual(found["name"], "Valencia")
        self.assertIn("geocoding-api.open-meteo.com/v1/search", fake.calls[0])
        self.assertIn("name=Valencia", fake.calls[0])

    def test_a_city_nobody_knows_is_an_error(self) -> None:
        with self.assertRaises(ValueError):
            weather.geocode("Nowhere", Fake(geocode=json.dumps({"results": []})))

    def test_an_ip_answer_without_coordinates_is_an_error(self) -> None:
        with self.assertRaises(ValueError):
            weather.ip_location(Fake(ip=json.dumps({"error": True})))

    def test_the_forecast_url_carries_the_fields_units_and_timezone(self) -> None:
        url = weather.forecast_url({"latitude": 1.5, "longitude": -2.5}, "imperial")
        for part in (
            "latitude=1.5",
            "longitude=-2.5",
            "timezone=auto",
            "temperature_unit=fahrenheit",
            "wind_speed_unit=mph",
            "relative_humidity_2m",
            "temperature_2m_max",
        ):
            self.assertIn(part, url)
        self.assertNotIn("temperature_unit", weather.forecast_url({"latitude": 1.5, "longitude": -2.5}, "metric"))


class StateTests(Fixture):
    def test_the_first_state_is_fetched_and_cached(self) -> None:
        fake = Fake()
        data = self.state(fake)
        self.assertEqual(data["location"]["name"], "Madrid")
        self.assertEqual(data["current"]["temperature"], 18.4)
        self.assertFalse(data["cached"])
        self.assertNotIn("error", data)
        self.assertEqual(len(fake.calls), 2)
        self.assertTrue((self.cache / weather.CACHE_FILE).is_file())

    def test_a_fresh_cache_answers_without_the_network(self) -> None:
        self.state(Fake())
        fake = Fake()
        data = self.state(fake, now=1_000_000.0 + weather.CACHE_SECONDS - 1)
        self.assertTrue(data["cached"])
        self.assertEqual(fake.calls, [])
        self.assertEqual(data["current"]["humidity"], 62)

    def test_an_expired_cache_is_fetched_again_but_the_location_is_kept(self) -> None:
        self.state(Fake())
        fake = Fake()
        self.state(fake, now=1_000_000.0 + weather.CACHE_SECONDS + 1)
        self.assertEqual(len(fake.calls), 1)
        self.assertIn("api.open-meteo.com/v1/forecast", fake.calls[0])
        self.assertFalse(any("ipapi" in url for url in fake.calls))

    def test_a_city_preference_is_geocoded_and_overrides_the_ip(self) -> None:
        self.set("weatherLocation", "Valencia")
        fake = Fake()
        data = self.state(fake)
        self.assertEqual(data["location"]["name"], "Valencia")
        self.assertFalse(any("ipapi" in url for url in fake.calls))
        self.assertIn("name=Valencia", fake.calls[0])

    def test_without_a_network_the_last_answer_comes_back_with_an_error(self) -> None:
        self.state(Fake())
        data = self.state(Fake(forecast=OSError("offline")), now=1_000_000.0 + weather.CACHE_SECONDS + 1)
        self.assertTrue(data["cached"])
        self.assertIn("offline", data["error"])
        self.assertEqual(data["current"]["temperature"], 18.4)

    def test_without_a_network_or_a_cache_only_the_error_is_returned(self) -> None:
        data = self.state(Fake(ip=OSError("offline")))
        self.assertEqual(set(data), {"error"})
        self.assertIn("offline", data["error"])

    def test_an_invalid_answer_is_an_error_not_a_crash(self) -> None:
        data = self.state(Fake(forecast="{broken"))
        self.assertIn("error", data)
        self.assertFalse((self.cache / weather.CACHE_FILE).exists())

    def test_the_units_preference_changes_the_request_and_the_answer(self) -> None:
        self.set("weatherUnits", "imperial")
        fake = Fake(forecast=IMPERIAL)
        data = self.state(fake)
        self.assertIn("temperature_unit=fahrenheit", fake.calls[-1])
        self.assertIn("wind_speed_unit=mph", fake.calls[-1])
        self.assertEqual(data["units"]["temperature"], "°F")
        self.assertEqual(data["current"]["temperature"], 65.1)

    def test_an_unknown_units_value_falls_back_to_metric(self) -> None:
        self.assertEqual(weather.units_of({"weatherUnits": "kelvin"}), "metric")
        self.assertEqual(weather.units_of({}), "metric")
        self.assertEqual(weather.units_of({"weatherUnits": "imperial"}), "imperial")

    def test_the_location_preference_is_written_and_trimmed(self) -> None:
        self.assertEqual(weather.set_location("  Valencia  ", self.config), "Valencia")
        self.assertEqual(prefs.read_prefs(self.config)["weatherLocation"], "Valencia")

    def test_an_empty_or_control_character_city_is_refused(self) -> None:
        for city in ("", "   ", "-x", "a\nb"):
            with self.subTest(city=city), self.assertRaises(ValueError):
                weather.set_location(city, self.config)


class MainTests(unittest.TestCase):
    def test_an_unknown_action_prints_the_usage(self) -> None:
        errors = StringIO()
        with redirect_stderr(errors):
            self.assertEqual(weather.main(["now"]), 2)
        self.assertIn("usage: weather state", errors.getvalue())


if __name__ == "__main__":
    unittest.main()
