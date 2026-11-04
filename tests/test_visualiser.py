"""The audio visualiser: cava's configuration, its frames, and the supervisor.

The supervisor runs cava in raw mode and turns its frames into one small JSON
file the bar reads (``$XDG_RUNTIME_DIR/vitrail/cava.json``). The process is
injected here, so no cava is needed and no audio is played.
"""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from vitrail import visualiser


class ConfigTests(unittest.TestCase):
    def test_the_config_is_raw_64_bars_at_60_fps(self) -> None:
        text = visualiser.config_text()
        self.assertIn("[output]", text)
        self.assertRegex(text, r"(?m)^method = raw$")
        self.assertRegex(text, r"(?m)^data_format = ascii$")
        self.assertRegex(text, r"(?m)^raw_target = /dev/stdout$")
        self.assertRegex(text, r"(?m)^bars = 64$")
        self.assertRegex(text, r"(?m)^framerate = 60$")
        # cava separates bars with ';' and frames with a newline (ASCII 59/10).
        self.assertRegex(text, r"(?m)^bar_delimiter = 59$")
        self.assertRegex(text, r"(?m)^frame_delimiter = 10$")

    def test_the_files_live_under_the_runtime_directory(self) -> None:
        runtime = Path("/run/user/1000/vitrail")
        self.assertEqual(visualiser.config_path(runtime), runtime / "cava.conf")
        self.assertEqual(visualiser.state_path(runtime), runtime / "cava.json")
        self.assertEqual(visualiser.pid_path(runtime), runtime / "cava.pid")


class FrameTests(unittest.TestCase):
    def test_a_frame_is_split_padded_and_truncated(self) -> None:
        values = visualiser.parse_frame("10;200;-4;oops\n", bars=6)
        self.assertEqual(values, [10, 100, 0, 0, 0, 0])
        self.assertEqual(len(visualiser.parse_frame("1;2;3", bars=2)), 2)

    def test_a_frame_defaults_to_the_bar_count(self) -> None:
        self.assertEqual(len(visualiser.parse_frame("1;2;3")), visualiser.BARS)

    def test_empty_and_broken_frames_read_as_silence(self) -> None:
        self.assertEqual(visualiser.parse_frame("", bars=3), [0, 0, 0])
        self.assertEqual(visualiser.parse_frame("nan;inf", bars=2), [0, 0])

    def test_the_state_is_one_json_object_of_values(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            runtime = Path(tmp)
            written = visualiser.write_state(runtime, [1, 2, 3])
            self.assertEqual(written, {"values": [1, 2, 3]})
            stored = json.loads(visualiser.state_path(runtime).read_text(encoding="utf-8"))
            self.assertEqual(stored, {"values": [1, 2, 3]})

    def test_a_broken_state_file_reads_as_empty(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            runtime = Path(tmp)
            visualiser.state_path(runtime).write_text("{not json", encoding="utf-8")
            self.assertEqual(visualiser.read_state(runtime), {})


class FakeClock:
    def __init__(self, ticks: list[float]) -> None:
        self.ticks = iter(ticks)

    def __call__(self) -> float:
        return next(self.ticks, 1e9)


class FakeProcess:
    pid = 4242

    def __init__(self, lines: list[str]) -> None:
        self.stdout = lines
        self.terminated = False

    def terminate(self) -> None:
        self.terminated = True

    def wait(self, timeout: float | None = None) -> int:
        return 0


class FakePopen:
    def __init__(self, lines: list[str]) -> None:
        self.lines = lines
        self.calls: list[tuple[list[str], dict]] = []
        self.process = FakeProcess(lines)

    def __call__(self, argv: list[str], **kwargs):
        self.calls.append((list(argv), kwargs))
        return self.process


class ConsumeTests(unittest.TestCase):
    def test_frames_are_written_at_the_interval(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            runtime = Path(tmp)
            writes, values = visualiser.consume(
                ["10;20\n", "30;40\n", "50;60\n"],
                runtime,
                clock=FakeClock([0.0, 0.02, 0.08]),
                bars=2,
            )
            self.assertEqual(writes, 2)
            self.assertEqual(values, [50, 60])
            stored = json.loads(visualiser.state_path(runtime).read_text(encoding="utf-8"))
            self.assertEqual(stored, {"values": [50, 60]})


class StartTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.runtime = Path(self.tmp.name)

    def test_start_runs_cava_with_the_written_config(self) -> None:
        popen = FakePopen(["1;2\n", "3;4\n"])
        state = visualiser.start(
            self.runtime,
            popen=popen,
            clock=FakeClock([0.0, 0.01]),
            alive=lambda _pid: False,
        )

        self.assertEqual(state["values"][:2], [1, 2])
        self.assertEqual(state["values"][2:], [0] * (visualiser.BARS - 2))
        self.assertEqual(len(popen.calls), 1)
        argv, kwargs = popen.calls[0]
        self.assertEqual(argv[:2], ["cava", "-p"])
        self.assertEqual(argv[2], str(visualiser.config_path(self.runtime)))
        self.assertTrue(kwargs.get("text"))
        self.assertTrue(visualiser.config_path(self.runtime).is_file())
        self.assertFalse(visualiser.pid_path(self.runtime).exists())
        self.assertTrue(popen.process.terminated)
        self.assertTrue(visualiser.state_path(self.runtime).is_file())

    def test_start_does_not_spawn_a_second_cava(self) -> None:
        visualiser.pid_path(self.runtime).parent.mkdir(parents=True, exist_ok=True)
        visualiser.pid_path(self.runtime).write_text("4242\n", encoding="utf-8")
        popen = FakePopen([])

        visualiser.start(
            self.runtime,
            popen=popen,
            clock=FakeClock([0.0]),
            alive=lambda pid: pid == 4242,
        )

        self.assertEqual(popen.calls, [])


class StopTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.runtime = Path(self.tmp.name)

    def test_stop_signals_the_child_and_clears_the_state(self) -> None:
        visualiser.pid_path(self.runtime).write_text("4242\n", encoding="utf-8")
        visualiser.write_state(self.runtime, [7])
        killed: list[tuple[int, int]] = []

        def kill(pid: int, number: int) -> None:
            killed.append((pid, number))

        visualiser.stop(self.runtime, kill=kill, alive=lambda pid: not killed)
        self.assertEqual(killed, [(4242, visualiser.signal.SIGTERM)])
        self.assertFalse(visualiser.pid_path(self.runtime).exists())
        self.assertFalse(visualiser.state_path(self.runtime).exists())

    def test_stop_is_idempotent(self) -> None:
        visualiser.stop(self.runtime, kill=lambda *_args: None, alive=lambda _pid: False)
        visualiser.stop(self.runtime, kill=lambda *_args: None, alive=lambda _pid: False)
        self.assertFalse(visualiser.state_path(self.runtime).exists())


class StateTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.runtime = Path(self.tmp.name)

    def test_state_reports_the_process_and_the_last_frame(self) -> None:
        visualiser.pid_path(self.runtime).write_text("4242\n", encoding="utf-8")
        visualiser.write_state(self.runtime, [5, 6])
        report = visualiser.state(self.runtime, alive=lambda _pid: True)
        self.assertEqual(report, {"running": True, "values": [5, 6]})

    def test_a_dead_child_is_not_running(self) -> None:
        visualiser.pid_path(self.runtime).write_text("4242\n", encoding="utf-8")
        report = visualiser.state(self.runtime, alive=lambda _pid: False)
        self.assertEqual(report["running"], False)


class CliTests(unittest.TestCase):
    def test_state_prints_json(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            runtime = Path(tmp)
            visualiser.write_state(runtime, [9])
            printed: list[str] = []
            code = visualiser.main(
                ["state", "--runtime", tmp],
                print_=printed.append,
                alive=lambda _pid: False,
            )
            self.assertEqual(code, 0)
            self.assertEqual(json.loads(printed[-1]), {"running": False, "values": [9]})

    def test_stop_accepts_a_runtime_directory(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            runtime = Path(tmp)
            visualiser.write_state(runtime, [9])
            code = visualiser.main(
                ["stop", "--runtime", tmp],
                print_=lambda _line: None,
                kill=lambda *_args: None,
                alive=lambda _pid: False,
            )
            self.assertEqual(code, 0)
            self.assertFalse(visualiser.state_path(runtime).exists())


if __name__ == "__main__":
    unittest.main()
