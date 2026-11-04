"""Screenshots and recording: the commands, the names and the state file."""

from __future__ import annotations

import json
import signal
import tempfile
import unittest
from pathlib import Path

from vitrail import capture

NOW = 1_700_000_000  # 2023-11-14 22:13:20 UTC


def runner(answer: str | None = ""):
    calls: list[list[str]] = []

    def run(argv: list[str]) -> str | None:
        calls.append(argv)
        return answer

    return run, calls


class NamingTests(unittest.TestCase):
    def test_the_file_is_named_after_the_moment(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = capture.target(tmp, NOW)
            self.assertEqual(path.parent, Path(tmp))
            self.assertRegex(path.name, r"^Screenshot_\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}\.png$")

    def test_the_folder_is_created(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp) / "a" / "b"
            capture.target(str(folder), NOW)
            self.assertTrue(folder.is_dir())


class GeometryTests(unittest.TestCase):
    def test_the_whole_screen_needs_no_geometry(self) -> None:
        self.assertEqual(capture.geometry("full"), "")

    def test_the_region_comes_from_slurp(self) -> None:
        run, calls = runner("512,256 800x600\n")
        self.assertEqual(capture.geometry("region", run), "512,256 800x600")
        self.assertEqual(calls, [["slurp"]])

    def test_a_cancelled_region_has_no_geometry(self) -> None:
        self.assertIsNone(capture.geometry("region", lambda argv: None))

    def test_the_window_comes_from_hyprland(self) -> None:
        window = json.dumps({"at": [10, 20], "size": [800, 600]})
        self.assertEqual(capture.geometry("window", lambda argv: window), "800x600+10+20")

    def test_a_window_without_a_size_is_refused(self) -> None:
        window = json.dumps({"at": [0, 0], "size": [0, 0]})
        self.assertIsNone(capture.geometry("window", lambda argv: window))


class ShotTests(unittest.TestCase):
    def test_a_full_shot_is_saved_and_copied(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            calls: list[list[str]] = []

            def grim(argv: list[str]) -> str:
                calls.append(argv)
                Path(argv[-1]).write_bytes(b"fake png")
                return ""

            copied: list[bytes] = []
            result = capture.shot(
                "full", tmp, now=NOW, run=grim, copy_run=lambda argv, data: copied.append(data) or True
            )
            self.assertTrue(result["path"].endswith(".png"))
            self.assertEqual(Path(result["path"]).read_bytes(), b"fake png")
            self.assertEqual(calls[0][0], "grim")
            self.assertNotIn("-g", calls[0])
            self.assertEqual(copied, [b"fake png"])

    def test_a_region_shot_passes_the_geometry(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            run, calls = runner("512,256 800x600")
            capture.shot("region", tmp, copy=False, now=NOW, run=run)
            self.assertEqual(calls[-1][:3], ["grim", "-g", "512,256 800x600"])

    def test_a_cancelled_selection_writes_nothing(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(capture.shot("region", tmp, run=lambda argv: None), {"error": "cancelled"})
            self.assertEqual(list(Path(tmp).iterdir()), [])

    def test_a_failing_grim_is_reported(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(capture.shot("full", tmp, run=lambda argv: None), {"error": "grim failed"})


class RecordTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.runtime = self.root / "run"
        self.runtime.mkdir()
        self.killed: list[tuple[int, int]] = []
        self.running: set[int] = set()

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def record(self, action: str, **kwargs) -> dict:
        kwargs.setdefault("runtime", self.runtime)
        kwargs.setdefault("now", NOW)
        kwargs.setdefault("spawner", lambda argv, log: self.running.add(4242) or 4242)
        kwargs.setdefault("killer", lambda pid, sig: (self.killed.append((pid, sig)), self.running.discard(pid)))
        kwargs.setdefault("alive", lambda pid: pid in self.running)
        kwargs.setdefault("directory", str(self.root / "videos"))
        return capture.record(action, **kwargs)

    def test_start_spawns_wf_recorder_and_writes_the_state(self) -> None:
        spawned: list[list[str]] = []
        result = self.record("start", spawner=lambda argv, log: spawned.append(argv) or self.running.add(4242) or 4242)
        self.assertTrue(result["recording"])
        self.assertEqual(spawned[0][0], "wf-recorder")
        self.assertIn("-f", spawned[0])
        self.assertTrue(spawned[0][-1].endswith(".mp4"))
        document = json.loads(capture.status_file(self.runtime).read_text(encoding="utf-8"))
        self.assertEqual(document["pid"], 4242)

    def test_a_second_start_does_not_spawn_again(self) -> None:
        spawned: list[list[str]] = []
        self.record("start", spawner=lambda argv, log: spawned.append(argv) or self.running.add(4242) or 4242)
        self.record("start", spawner=lambda argv, log: spawned.append(argv) or self.running.add(4243) or 4243)
        self.assertEqual(len(spawned), 1)

    def test_stop_signals_wf_recorder_and_clears_the_state(self) -> None:
        self.record("start", spawner=lambda argv, log: self.running.add(4242) or 4242)
        result = self.record("stop")
        self.assertFalse(result["recording"])
        self.assertEqual(self.killed, [(4242, signal.SIGINT)])
        self.assertEqual(capture.status(self.runtime), {})

    def test_toggle_starts_then_stops(self) -> None:
        self.assertTrue(self.record("toggle")["recording"])
        self.assertFalse(self.record("toggle")["recording"])

    def test_region_recording_uses_slurp(self) -> None:
        spawned: list[list[str]] = []
        self.record(
            "start",
            region=True,
            run=lambda argv: "0,0 640x480",
            spawner=lambda argv, log: spawned.append(argv) or self.running.add(4242) or 4242,
        )
        self.assertIn("-g", spawned[0])
        self.assertIn("0,0 640x480", spawned[0])

    def test_a_cancelled_region_does_not_start(self) -> None:
        self.assertEqual(self.record("start", region=True, run=lambda argv: None), {"error": "cancelled"})

    def test_audio_adds_the_flag(self) -> None:
        spawned: list[list[str]] = []
        self.record(
            "start", audio=True, spawner=lambda argv, log: spawned.append(argv) or self.running.add(4242) or 4242
        )
        self.assertIn("-a", spawned[0])

    def test_a_dead_pid_is_not_recording(self) -> None:
        capture.status_file(self.runtime).write_text('{"pid": 999999, "path": "x"}', encoding="utf-8")
        self.assertEqual(capture.status(self.runtime, alive=lambda pid: False), {})


class EntryTests(unittest.TestCase):
    def test_an_unknown_action_is_refused(self) -> None:
        self.assertEqual(capture.main([]), 2)


if __name__ == "__main__":
    unittest.main()
