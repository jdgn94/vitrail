"""The system resources: CPU between two readings, memory, the hottest thermal
zone, the network counters and the root filesystem.

Every path is injected, so the tests read fixture files in a temporary folder
and never look at the real /proc.
"""

from __future__ import annotations

import json
import os
import tempfile
import time
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path
from unittest import mock

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
        self.assertEqual(self.state()["disk"], {"used": 50, "total": 200, "free": 150, "percent": 25.0})

    def test_a_failing_usage_leaves_zeros(self) -> None:
        data = resources.state(
            None,
            proc=self.proc,
            thermal=self.thermal,
            disk="/nowhere",
            usage=lambda _path: (_ for _ in ()).throw(OSError("boom")),
        )
        self.assertEqual(data["disk"], {"used": 0, "total": 0, "free": 0, "percent": 0.0})


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


def process_stat(name: str, utime: int, stime: int, rss_pages: int) -> str:
    # pid (name) state ppid ... utime(14) stime(15) ... rss(24)
    fields = ["S", "1", "1", "1", "0", "-1", "0", "0", "0", "0", "0", str(utime), str(stime)]
    fields += ["0"] * 6 + ["1", "0", str(rss_pages)]
    return f"42 ({name}) " + " ".join(fields) + " 0 0\n"


class DayTests(unittest.TestCase):
    """Today's usage: the baseline is the day's first reading, and no total can
    go below zero (a new day, a missed day, a reboot)."""

    def test_the_first_reading_of_a_day_is_the_baseline_and_reads_zero(self) -> None:
        baseline, used = resources.today(None, {"rx": 100, "tx": 50}, "2026-11-22")
        self.assertEqual(baseline, {"date": "2026-11-22", "rx": 100, "tx": 50})
        self.assertEqual(used, {"rx": 0, "tx": 0})

    def test_a_later_reading_counts_the_difference(self) -> None:
        baseline = {"date": "2026-11-22", "rx": 100, "tx": 50}
        kept, used = resources.today(baseline, {"rx": 300, "tx": 70}, "2026-11-22")
        self.assertEqual(kept, baseline)
        self.assertEqual(used, {"rx": 200, "tx": 20})

    def test_a_new_day_and_a_missed_day_both_start_over(self) -> None:
        for previous_date in ("2026-11-21", "2026-11-19"):
            with self.subTest(previous=previous_date):
                previous = {"date": previous_date, "rx": 100, "tx": 50}
                baseline, used = resources.today(previous, {"rx": 300, "tx": 70}, "2026-11-22")
                self.assertEqual(baseline, {"date": "2026-11-22", "rx": 300, "tx": 70})
                self.assertEqual(used, {"rx": 0, "tx": 0})

    def test_a_reboot_restarts_only_the_counter_that_went_back(self) -> None:
        baseline = {"date": "2026-11-22", "rx": 9000, "tx": 50}
        kept, used = resources.today(baseline, {"rx": 200, "tx": 70}, "2026-11-22")
        self.assertEqual(kept, {"date": "2026-11-22", "rx": 200, "tx": 50})
        self.assertEqual(used, {"rx": 0, "tx": 20})

    def test_a_broken_baseline_is_a_new_day(self) -> None:
        for previous in (None, {}, {"date": "2026-11-22"}, {"date": "2026-11-22", "rx": "x", "tx": -1}):
            with self.subTest(previous=previous):
                baseline, used = resources.today(previous, {"rx": 10, "tx": 5}, "2026-11-22")
                self.assertGreaterEqual(baseline["rx"], 0)
                self.assertGreaterEqual(baseline["tx"], 0)
                self.assertEqual(used, {"rx": 0, "tx": 0})

    def test_the_day_file_lives_under_the_cache_folder(self) -> None:
        with mock.patch.dict(os.environ, {"XDG_CACHE_HOME": "/tmp/here"}):
            self.assertEqual(resources.day_path(), Path("/tmp/here") / "vitrail" / "netusage.json")


class TickTests(Fixture):
    def tick(self, now: float, with_top: bool = False) -> dict:
        return resources.tick(
            with_top,
            cache=self.root / "cache.json",
            day_file=self.root / "netusage.json",
            clock=lambda: now,
            proc=self.proc,
            thermal=self.thermal,
            disk="/nowhere",
            usage=lambda _path: (200, 50, 150),
            page_size=4096,
            skip=(),
        )

    def process(self, pid: int, name: str, utime: int, stime: int, rss_pages: int) -> None:
        (self.proc / str(pid)).mkdir(exist_ok=True)
        (self.proc / str(pid) / "stat").write_text(process_stat(name, utime, stime, rss_pages), encoding="utf-8")

    def test_the_first_tick_has_no_cpu_and_no_rate(self) -> None:
        data = self.tick(1000.0)
        self.assertIsNone(data["cpu"])
        self.assertIsNone(data["rate"])
        self.assertEqual(data["at"], 1000.0)
        self.assertNotIn("cpuTicks", data)
        self.assertEqual(data["disk"]["free"], 150)

    def test_the_second_tick_carries_the_counters_over(self) -> None:
        self.tick(1000.0)
        self.write("stat", STAT_LATER)
        self.write("net/dev", NET_DEV.replace("5000 ", "9000 ").replace("3000 ", "5000 "))
        data = self.tick(1002.0)
        self.assertEqual(data["cpu"], 50.0)
        self.assertEqual(data["rate"], {"rx": 2000, "tx": 1000})
        self.assertEqual(data["today"], {"rx": 4000, "tx": 2000})

    def test_the_day_file_holds_the_date_and_the_first_totals(self) -> None:
        self.tick(1000.0)
        stored = json.loads((self.root / "netusage.json").read_text(encoding="utf-8"))
        self.assertEqual(set(stored), {"date", "rx", "tx"})
        self.assertEqual((stored["rx"], stored["tx"]), (7000, 4000))

    def test_the_first_tick_reads_zero_today(self) -> None:
        self.assertEqual(self.tick(1000.0)["today"], {"rx": 0, "tx": 0})

    def test_a_tick_on_the_next_day_starts_today_over(self) -> None:
        self.tick(1732233600.0)
        later = resources.tick(
            cache=self.root / "cache.json",
            day_file=self.root / "netusage.json",
            clock=lambda: 1732233600.0 + 86400,
            proc=self.proc,
            thermal=self.thermal,
            disk="/nowhere",
            usage=lambda _path: (200, 50, 150),
        )
        self.assertEqual(later["today"], {"rx": 0, "tx": 0})
        stored = json.loads((self.root / "netusage.json").read_text(encoding="utf-8"))
        self.assertNotEqual(stored["date"], time.strftime("%Y-%m-%d", time.localtime(1732233600.0)))

    def test_a_counter_that_went_back_never_reads_below_zero(self) -> None:
        self.tick(1000.0)
        self.write("net/dev", NET_DEV.replace("5000 ", "1 ").replace("3000 ", "1 "))
        data = self.tick(1002.0)
        self.assertGreaterEqual(data["today"]["rx"], 0)
        self.assertGreaterEqual(data["today"]["tx"], 0)
        self.assertEqual(data["today"], {"rx": 0, "tx": 0})

    def test_a_counter_that_went_back_gives_no_rate(self) -> None:
        self.write("net/dev", NET_DEV.replace("5000 ", "9000 "))
        self.tick(1000.0)
        self.write("net/dev", NET_DEV)
        self.assertIsNone(self.tick(1002.0)["rate"])

    def test_a_stale_cache_is_ignored(self) -> None:
        self.tick(1000.0)
        self.write("stat", STAT_LATER)
        data = self.tick(1000.0 + resources.CACHE_MAX_AGE + 1)
        self.assertIsNone(data["cpu"])
        self.assertIsNone(data["rate"])

    def test_a_broken_cache_is_replaced(self) -> None:
        (self.root / "cache.json").write_text("{nope", encoding="utf-8")
        self.assertIsNone(self.tick(1000.0)["cpu"])
        self.assertEqual(self.tick(1001.0)["cpu"], None)  # nothing moved, still no delta
        json.loads((self.root / "cache.json").read_text(encoding="utf-8"))

    def test_an_unwritable_cache_is_not_an_error(self) -> None:
        data = resources.tick(
            cache=self.root / "missing" / "cache.json",
            day_file=self.root / "missing" / "netusage.json",
            clock=lambda: 1.0,
            proc=self.proc,
            thermal=self.thermal,
            usage=lambda _path: (200, 50, 150),
        )
        self.assertIn("memory", data)

    def test_the_top_is_absent_unless_asked(self) -> None:
        self.assertNotIn("top", self.tick(1000.0))

    def test_the_top_has_no_cpu_until_a_process_was_seen_twice(self) -> None:
        self.process(10, "busy", 100, 0, 500)
        first = self.tick(1000.0, with_top=True)["top"]
        self.assertEqual([row["pid"] for row in first], [10])
        self.assertIsNone(first[0]["cpu"])
        self.assertEqual(first[0]["memory"], 500 * 4096)
        self.assertEqual(first[0]["percent"], round(100 * 500 * 4096 / (8000000 * 1024), 1))

    def test_the_top_ranks_by_cpu_share_of_one_core(self) -> None:
        self.process(10, "idle", 10, 0, 900)
        self.process(11, "busy", 10, 0, 100)
        self.tick(1000.0, with_top=True)
        self.write("stat", STAT_LATER)  # all CPUs gained 200 ticks; one cpu line: 1 core
        self.process(10, "idle", 10, 0, 900)
        self.process(11, "busy", 130, 0, 100)
        rows = self.tick(1002.0, with_top=True)["top"]
        self.assertEqual([row["name"] for row in rows], ["busy", "idle"])
        self.assertEqual(rows[0]["cpu"], 60.0)
        self.assertEqual(rows[1]["cpu"], 0.0)

    def test_the_top_is_cut_to_five(self) -> None:
        for pid in range(10, 20):
            self.process(pid, f"p{pid}", 1, 0, pid)
        self.assertEqual(len(self.tick(1000.0, with_top=True)["top"]), 5)

    def test_this_program_is_not_in_the_top(self) -> None:
        self.process(10, "other", 1, 0, 1)
        rows = resources.top(resources.read_processes(self.proc, 4096), None, 0, 1, 1000, skip=(10,))
        self.assertEqual(rows, [])


class ProcessParserTests(unittest.TestCase):
    def test_a_name_with_spaces_and_parentheses(self) -> None:
        found = resources.parse_process(42, process_stat("Web Content (x)", 7, 3, 25), 4096)
        self.assertEqual(found, {"pid": 42, "name": "Web Content (x)", "ticks": 10, "rss": 25 * 4096})

    def test_a_short_or_broken_line_is_none(self) -> None:
        self.assertIsNone(resources.parse_process(1, "", 4096))
        self.assertIsNone(resources.parse_process(1, "1 (a) S 1 2", 4096))
        self.assertIsNone(resources.parse_process(1, "1 (a) " + " ".join(["x"] * 30), 4096))

    def test_a_missing_proc_folder_is_empty(self) -> None:
        self.assertEqual(resources.read_processes(Path("/nowhere/proc"), 4096), {})


class KillTests(unittest.TestCase):
    def test_terminate_is_the_default(self) -> None:
        import signal

        self.assertEqual(resources.kill_plan(500, own=(7,)), {"signal": int(signal.SIGTERM)})

    def test_kill_only_when_forced(self) -> None:
        import signal

        self.assertEqual(resources.kill_plan(500, True, own=(7,)), {"signal": int(signal.SIGKILL)})

    def test_pid_one_and_below_are_refused(self) -> None:
        for pid in (1, 0, -5):
            with self.subTest(pid=pid):
                self.assertEqual(resources.kill_plan(pid, True, own=()), {"error": "refused"})

    def test_this_program_and_its_parent_are_refused(self) -> None:
        import os

        self.assertEqual(resources.kill_plan(os.getpid(), False), {"error": "refused"})
        self.assertEqual(resources.kill_plan(os.getppid(), False), {"error": "refused"})

    def test_a_pid_that_is_not_an_integer_is_refused(self) -> None:
        for pid in ("12", None, 1.5, True):
            with self.subTest(pid=pid):
                self.assertEqual(resources.kill_plan(pid, own=()), {"error": "refused"})

    def test_a_refusal_never_reaches_the_sender(self) -> None:
        sent = []
        resources.kill(1, True, sender=lambda *a: sent.append(a), own=())
        self.assertEqual(sent, [])

    def test_the_signal_is_sent_once(self) -> None:
        import signal

        sent = []
        self.assertEqual(resources.kill(500, sender=lambda *a: sent.append(a), own=()), {"ok": True})
        self.assertEqual(sent, [(500, int(signal.SIGTERM))])

    def test_failures_are_codes_not_tracebacks(self) -> None:
        def raiser(error: Exception):
            def send(_pid: int, _signal: int) -> None:
                raise error

            return send

        cases = {ProcessLookupError(): "gone", PermissionError(): "denied", OSError(): "failed"}
        for error, code in cases.items():
            with self.subTest(code=code):
                self.assertEqual(resources.kill(500, sender=raiser(error), own=()), {"error": code})

    def test_the_command_line_refuses_pid_one(self) -> None:
        out = StringIO()
        with redirect_stdout(out):
            self.assertEqual(resources.main(["kill", "1"]), 1)
        self.assertEqual(json.loads(out.getvalue()), {"error": "refused"})

    def test_a_malformed_kill_is_usage(self) -> None:
        for args in (["kill"], ["kill", "abc"], ["kill", "5", "--hard"]):
            with self.subTest(args=args), redirect_stderr(StringIO()):
                self.assertEqual(resources.main(args), 2)


class MainTests(unittest.TestCase):
    def test_an_unknown_action_prints_the_usage(self) -> None:
        errors = StringIO()
        with redirect_stderr(errors):
            self.assertEqual(resources.main(["now"]), 2)
        self.assertIn("usage: resources state", errors.getvalue())


if __name__ == "__main__":
    unittest.main()
