"""The system resources: CPU between two readings, memory, the hottest thermal
zone, the network counters and the root filesystem.

Every path is injected, so the tests read fixture files in a temporary folder
and never look at the real /proc.
"""

from __future__ import annotations

import json
import tempfile
import unittest
from contextlib import redirect_stderr
from io import StringIO
from pathlib import Path

from vitrail import resources

STAT = "cpu  100 0 100 800 0 0 0 0 0 0\ncpu0 100 0 100 800 0 0 0 0 0 0\nintr 1\n"
STAT_LATER = "cpu  150 0 150 900 0 0 0 0 0 0\ncpu0 150 0 150 900 0 0 0 0 0 0\n"
MEMINFO = (
    "MemTotal:        8000000 kB\n"
    "MemFree:         1000000 kB\n"
    "MemAvailable:    6000000 kB\n"
    "Buffers:          200000 kB\n"
    "Cached:          2000000 kB\n"
)
NET_DEV = (
    "Inter-|   Receive                                                |  Transmit\n"
    " face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed\n"
    "    lo:  1000      10    0    0    0     0          0         0   1000      10    0    0    0     0       0          0\n"
    "  eth0:  5000      50    0    0    0     0          0         0   3000      30    0    0    0     0       0          0\n"
    " wlan0:  2000      20    0    0    0     0          0         0   1000      10    0    0    0     0       0          0\n"
)


class Fixture(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.proc = self.root / "proc"
        self.thermal = self.root / "thermal"
        (self.proc / "net").mkdir(parents=True)
        self.thermal.mkdir()
        self.write("stat", STAT)
        self.write("meminfo", MEMINFO)
        self.write("net/dev", NET_DEV)
        self.zone("thermal_zone0", "45000\n")
        self.zone("thermal_zone1", "52000\n")

    def write(self, name: str, text: str) -> None:
        (self.proc / name).write_text(text, encoding="utf-8")

    def zone(self, name: str, text: str) -> None:
        (self.thermal / name).mkdir()
        (self.thermal / name / "temp").write_text(text, encoding="utf-8")

    def state(self, previous: dict | None = None) -> dict:
        return resources.state(
            previous,
            proc=self.proc,
            thermal=self.thermal,
            disk="/nowhere",
            usage=lambda _path: (200, 50, 150),
        )


class CpuTests(Fixture):
    def test_the_first_reading_has_no_delta(self) -> None:
        data = self.state()
        self.assertIsNone(data["cpu"])
        self.assertEqual(data["cpuTicks"], {"total": 1000, "idle": 800})

    def test_the_second_reading_gives_the_busy_percentage(self) -> None:
        first = self.state()
        self.write("stat", STAT_LATER)
        data = self.state(first)
        self.assertEqual(data["cpu"], 50.0)
        self.assertEqual(data["cpuTicks"], {"total": 1200, "idle": 900})

    def test_a_reading_that_does_not_move_gives_no_percentage(self) -> None:
        first = self.state()
        self.assertIsNone(self.state(first)["cpu"])

    def test_a_malformed_stat_file_is_tolerated(self) -> None:
        self.write("stat", "not a cpu line\n")
        data = self.state()
        self.assertIsNone(data["cpu"])
        self.assertIsNone(data["cpuTicks"])


class MemoryTests(Fixture):
    def test_memory_uses_available_not_free(self) -> None:
        self.assertEqual(
            self.state()["memory"],
            {"used": 2_000_000 * 1024, "total": 8_000_000 * 1024, "percent": 25.0},
        )

    def test_without_mem_available_the_free_buffers_and_cached_add_up(self) -> None:
        text = "MemTotal: 1000 kB\nMemFree: 100 kB\nBuffers: 50 kB\nCached: 250 kB\n"
        self.assertEqual(resources.parse_meminfo(text), {"used": 600 * 1024, "total": 1000 * 1024, "percent": 60.0})

    def test_no_meminfo_is_all_zero(self) -> None:
        self.assertEqual(resources.parse_meminfo(""), {"used": 0, "total": 0, "percent": 0.0})


class TemperatureTests(Fixture):
    def test_the_hottest_zone_wins(self) -> None:
        self.assertEqual(self.state()["temperature"], 52.0)

    def test_a_zone_that_says_nothing_is_skipped(self) -> None:
        self.zone("thermal_zone2", "garbage\n")
        self.zone("thermal_zone3", "0\n")
        self.assertEqual(self.state()["temperature"], 52.0)

    def test_without_sensors_the_temperature_is_none(self) -> None:
        for zone in self.thermal.iterdir():
            (zone / "temp").unlink()
            zone.rmdir()
        self.assertIsNone(self.state()["temperature"])

    def test_a_missing_thermal_folder_is_none(self) -> None:
        self.assertEqual(
            resources.temperature(self.root / "missing"),
            None,
        )


class NetworkTests(Fixture):
    def test_the_counters_add_up_loopback_aside(self) -> None:
        self.assertEqual(self.state()["network"], {"rx": 7000, "tx": 4000})

    def test_a_malformed_line_is_skipped(self) -> None:
        self.write("net/dev", "  eth0: 10 20\n  bad: x y z\n")
        self.assertEqual(
            resources.parse_network((self.proc / "net/dev").read_text(encoding="utf-8")), {"rx": 0, "tx": 0}
        )


class DiskTests(Fixture):
    def test_the_root_filesystem_percentage(self) -> None:
        self.assertEqual(self.state()["disk"], {"used": 50, "total": 200, "percent": 25.0})

    def test_a_failing_usage_leaves_zeros(self) -> None:
        data = resources.state(
            None,
            proc=self.proc,
            thermal=self.thermal,
            disk="/nowhere",
            usage=lambda _path: (_ for _ in ()).throw(OSError("boom")),
        )
        self.assertEqual(data["disk"], {"used": 0, "total": 0, "percent": 0.0})


class StateTests(Fixture):
    def test_the_state_has_exactly_the_documented_shape(self) -> None:
        data = self.state()
        self.assertEqual(set(data), {"cpu", "cpuTicks", "memory", "temperature", "network", "disk"})
        json.dumps(data)

    def test_every_missing_source_is_tolerated(self) -> None:
        data = resources.state(
            None,
            proc=self.root / "missing",
            thermal=self.root / "missing",
            disk="/nowhere",
            usage=lambda _path: (0, 0, 0),
        )
        self.assertIsNone(data["cpu"])
        self.assertIsNone(data["cpuTicks"])
        self.assertEqual(data["memory"], {"used": 0, "total": 0, "percent": 0.0})
        self.assertIsNone(data["temperature"])
        self.assertEqual(data["network"], {"rx": 0, "tx": 0})


class MainTests(unittest.TestCase):
    def test_an_unknown_action_prints_the_usage(self) -> None:
        errors = StringIO()
        with redirect_stderr(errors):
            self.assertEqual(resources.main(["now"]), 2)
        self.assertIn("usage: resources state", errors.getvalue())


if __name__ == "__main__":
    unittest.main()
