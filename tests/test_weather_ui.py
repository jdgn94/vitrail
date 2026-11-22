"""The weather element's wiring: its preferences, its words, the one snapshot
the button and popup share, and how the city switcher reaches the module (the
logic itself is tested in tests/qml/tst_weather.qml and tests/test_weather.py)."""

from __future__ import annotations

import json
import re
import unittest
from pathlib import Path

from vitrail import weather

ROOT = Path(__file__).resolve().parent.parent


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class WeatherWiringTests(unittest.TestCase):
    def test_the_four_preferences_are_mapped_and_declared(self) -> None:
        for key in ("weatherLocation", "weatherUnits", "weatherCities", "weatherInterval"):
            with self.subTest(key=key):
                self.assertRegex(read("vitrail/prefs.map"), rf"(?m)^weather {key}$")
                self.assertIn(f"property alias {key}: weatherFile.{key}", read("shell/Prefs.qml"))

    def test_the_cities_start_empty_and_the_interval_at_fifteen_minutes(self) -> None:
        prefs = read("shell/Prefs.qml")
        self.assertIn('property string weatherCities: "[]"', prefs)
        self.assertIn("property int weatherInterval: 15", prefs)
        self.assertIn("var INTERVAL_DEFAULT = 15", read("bar/weather/weather.js"))

    def test_the_units_the_shell_offers_match_the_module(self) -> None:
        self.assertEqual(set(weather.UNITS), {"metric", "imperial"})
        page = read("shell/pages/BarElementsPage.qml")
        for unit in weather.UNITS:
            with self.subTest(unit=unit):
                self.assertIn(f'objectName: "weatherUnits"', page)
                self.assertIn(f'{{ key: "{unit}"', page)

    def test_it_is_a_hidden_bar_element(self) -> None:
        self.assertRegex(read("bar/widgets.js"), r'\{ id: "weather", surfaces: \["bar"\]')
        self.assertRegex(read("bar/layouts.js"), r'DEFAULT_HIDDEN = \{ bar: \[[^\]]*"weather"')

    def test_the_settings_block_has_the_cities_the_units_and_the_interval(self) -> None:
        page = read("shell/pages/BarElementsPage.qml")
        self.assertIn('elementId: "weather"', page)
        for name in ("weatherCityAdd", "weatherCityRemove", "weatherUnits", "weatherInterval"):
            with self.subTest(name=name):
                self.assertIn(f'objectName: "{name}"', page)
        self.assertIn("Weather.withCities", page)
        self.assertIn("Weather.intervalMinutes", page)

    def test_every_word_exists_in_every_language_with_the_same_placeholders(self) -> None:
        reference = json.loads(read("kit/i18n/en.json"))
        keys = [key for key in reference if key.startswith("bar.weather.") or key == "bar.widget.weather"]
        self.assertGreaterEqual(len(keys), 18)
        for path in sorted((ROOT / "kit" / "i18n").glob("*.json")):
            table = json.loads(path.read_text(encoding="utf-8"))
            for key in keys:
                with self.subTest(language=path.stem, key=key):
                    self.assertIn(key, table)
                    self.assertEqual(sorted(re.findall(r"%\d", table[key])), sorted(re.findall(r"%\d", reference[key])))

    def test_the_snapshot_is_the_one_the_button_and_the_popup_use(self) -> None:
        shell = read("bar/shell.qml")
        block = re.search(r"BarSnapshot \{\s*id: weatherData(.*?)\n    \}", shell, re.S).group(1)
        self.assertIn('module: "weather"', block)
        self.assertIn("interval: Weather.intervalMs(shell.prefs.weatherInterval)", block)
        self.assertIn('active: shell.barShows("weather") || shell.barShows("brightness") || shell.nightLightOn', block)
        self.assertIn("snapshot: weatherData.snapshot", shell)
        self.assertEqual(shell.count("id: weatherData"), 1, "one snapshot per tick")
        self.assertNotRegex(read("bar/weather/WeatherPanel.qml"), r"\bProcess\s*\{")
        self.assertNotRegex(read("bar/weather/WeatherButton.qml"), r"\bTimer\s*\{")

    def test_the_city_switcher_writes_the_preference_the_module_reads(self) -> None:
        shell = read("bar/shell.qml")
        self.assertIn("onCitySelected: function (city)", shell)
        block = re.search(r"onCitySelected: function \(city\) \{(.*?)\n                        \}", shell, re.S).group(
            1
        )
        self.assertIn("shell.prefs.weatherLocation = city", block)
        self.assertIn("weatherData.refresh()", block)
        self.assertIn('"weatherLocation"', read("vitrail/weather.py"))

    def test_the_popup_refreshes_when_it_opens(self) -> None:
        self.assertRegex(read("bar/shell.qml"), r'kind === "weather"\)\s+weatherData\.refresh\(\)')

    def test_the_module_asks_for_the_hourly_strip(self) -> None:
        source = read("vitrail/weather.py")
        self.assertIn("HOURLY_FIELDS", source)
        self.assertEqual(weather.HOUR_COUNT, 12)


if __name__ == "__main__":
    unittest.main()
