"""Zone list for the settings window's world map."""

from __future__ import annotations

import json
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

from vitrail import timezones

JANUARY = datetime(2026, 1, 15, 12, 0, tzinfo=timezone.utc)
JULY = datetime(2026, 7, 15, 12, 0, tzinfo=timezone.utc)

TAB = """\
# tzdb timezone descriptions
#
ES\t+4024-00341\tEurope/Madrid\tmainland
VE\t+1030-06656\tAmerica/Caracas
AU,CC\t+3352+15113\tAustralia/Sydney\tNew South Wales
RU\t+554521+0373704\tEurope/Moscow\tMoscow+00 - west Russia
XX\t+0000+00000\tNowhere/Land
"""


class CoordinateTests(unittest.TestCase):
    def test_degrees_and_minutes(self) -> None:
        lat, lon = timezones.parse_coordinates("+4024-00341")
        self.assertAlmostEqual(lat, 40.4, places=3)
        self.assertAlmostEqual(lon, -3.683, places=3)

    def test_degrees_minutes_and_seconds(self) -> None:
        lat, lon = timezones.parse_coordinates("+554521+0373704")
        self.assertAlmostEqual(lat, 55.7558, places=3)
        self.assertAlmostEqual(lon, 37.6178, places=3)

    def test_southern_and_western_hemispheres_are_negative(self) -> None:
        lat, lon = timezones.parse_coordinates("-3352-07040")
        self.assertLess(lat, 0)
        self.assertLess(lon, 0)

    def test_rejects_malformed_values(self) -> None:
        for bad in ("", "4024-00341", "+40-003", "+4024+0034x"):
            with self.subTest(value=bad):
                with self.assertRaises(ValueError):
                    timezones.parse_coordinates(bad)


class LoadTests(unittest.TestCase):
    def write(self, text: str) -> Path:
        folder = Path(tempfile.mkdtemp())
        self.addCleanup(lambda: [p.unlink() for p in folder.iterdir()] or folder.rmdir())
        target = folder / "zone1970.tab"
        target.write_text(text, encoding="utf-8")
        return target

    def test_skips_comments_and_unknown_zones(self) -> None:
        zones = timezones.load([self.write(TAB)], JANUARY)
        self.assertEqual([z["id"] for z in zones],
                         ["Europe/Madrid", "America/Caracas", "Australia/Sydney", "Europe/Moscow"])

    def test_carries_coordinates_note_and_offset(self) -> None:
        zones = {z["id"]: z for z in timezones.load([self.write(TAB)], JANUARY)}
        madrid = zones["Europe/Madrid"]
        self.assertEqual(madrid["note"], "mainland")
        self.assertAlmostEqual(madrid["lat"], 40.4, places=2)
        self.assertEqual(madrid["offset"], 60)
        self.assertEqual(zones["America/Caracas"]["offset"], -240)
        self.assertEqual(zones["America/Caracas"]["note"], "")

    def test_offset_follows_daylight_saving_time(self) -> None:
        summer = {z["id"]: z for z in timezones.load([self.write(TAB)], JULY)}
        self.assertEqual(summer["Europe/Madrid"]["offset"], 120)
        self.assertEqual(summer["Australia/Sydney"]["offset"], 600)

    def test_first_readable_file_wins(self) -> None:
        zones = timezones.load([Path("/nonexistent/zone1970.tab"), self.write(TAB)], JANUARY)
        self.assertTrue(zones)

    def test_no_file_gives_no_zones(self) -> None:
        self.assertEqual(timezones.load([Path("/nonexistent/zone.tab")], JANUARY), [])


class IndexTests(unittest.TestCase):
    def test_a_zone_missing_from_the_list_is_added_from_the_full_table(self) -> None:
        folder = Path(tempfile.mkdtemp())
        self.addCleanup(lambda: [p.unlink() for p in folder.iterdir()] or folder.rmdir())
        short = folder / "zone1970.tab"
        short.write_text("ES\t+4024-00341\tEurope/Madrid\n", encoding="utf-8")
        full = folder / "zone.tab"
        full.write_text(
            "ES\t+4024-00341\tEurope/Madrid\nNL\t+5222+00454\tEurope/Amsterdam\n", encoding="utf-8")
        ids = [z["id"] for z in timezones.index(JANUARY, current="Europe/Amsterdam",
                                                  short=[short], full=[full])]
        self.assertEqual(ids, ["Europe/Madrid", "Europe/Amsterdam"])

    def test_system_tables_load_and_serialise(self) -> None:
        data = json.loads(json.dumps(timezones.index(JANUARY)))
        if not data:
            self.skipTest("no tzdata on this machine")
        self.assertTrue(all({"id", "lat", "lon", "offset", "note"} <= set(z) for z in data))
        self.assertIn("Europe/Madrid", [z["id"] for z in data])


if __name__ == "__main__":
    unittest.main()
