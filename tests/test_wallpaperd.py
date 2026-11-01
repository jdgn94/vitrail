"""Wallpaper supervisor: which engine runs, with which arguments."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

from vitrail import wallpaperd


class Fake:
    """Records every command and answers awww query."""

    def __init__(self, awww: bool = False) -> None:
        self.calls: list[list[str]] = []
        self.awww = awww
        self.kwargs: list[dict] = []
        self.spawned: list[list[str]] = []

    def spawn(self, argv: list[str]) -> None:
        self.spawned.append(list(argv))
        if argv[:1] == ["awww-daemon"]:
            self.awww = True

    def __call__(self, argv, **kwargs):
        self.calls.append(list(argv))
        self.kwargs.append(kwargs)
        if argv[:2] == ["awww", "query"]:
            return SimpleNamespace(returncode=0 if self.awww else 1)
        if argv[:1] == ["awww-daemon"]:
            self.awww = True
        return SimpleNamespace(returncode=0)

    def issued(self, *prefix: str) -> list[list[str]]:
        return [call for call in self.calls if call[: len(prefix)] == list(prefix)]


class EngineTests(unittest.TestCase):
    def test_kinds_pick_their_engine(self) -> None:
        self.assertEqual(wallpaperd.engine_for("image"), "awww")
        self.assertEqual(wallpaperd.engine_for("svg"), "awww")
        self.assertEqual(wallpaperd.engine_for("video"), "mpvpaper")
        self.assertIsNone(wallpaperd.engine_for("pdf"))


class ShowTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.cache = Path(self.tmp.name)

    def touch(self, name: str) -> str:
        path = self.cache / name
        path.write_bytes(b"x")
        return str(path)

    def test_a_still_starts_the_daemon_and_sends_the_image(self) -> None:
        run = Fake()
        image = self.touch("wall.png")
        state = wallpaperd.show(
            image, self.cache, run=run, sleep=lambda _s: None, spawn=run.spawn
        )

        self.assertEqual(state["engine"], "awww")
        self.assertEqual(wallpaperd.read_state(self.cache)["path"], image)
        self.assertEqual(run.spawned, [["awww-daemon"]])
        sent = run.issued("awww", "img")
        self.assertEqual(len(sent), 1)
        self.assertIn(image, sent[0])
        self.assertIn("--transition-type", sent[0])

    def test_a_running_daemon_is_not_started_twice(self) -> None:
        run = Fake(awww=True)
        wallpaperd.show(
            self.touch("wall.png"), self.cache, run=run, sleep=lambda _s: None,
            spawn=run.spawn,
        )
        self.assertEqual(run.spawned, [])

    def test_a_video_goes_to_mpvpaper_with_hardware_decoding(self) -> None:
        run = Fake(awww=True)
        video = self.touch("loop.mp4")
        state = wallpaperd.show(
            video, self.cache, run=run, sleep=lambda _s: None, spawn=run.spawn
        )

        self.assertEqual(state["engine"], "mpvpaper")
        started = run.issued("mpvpaper")
        self.assertEqual(len(started), 1)
        self.assertIn(video, started[0])
        self.assertIn("hwdec=vaapi", " ".join(started[0]))
        # The still engine is stopped first, so both never draw at once.
        self.assertEqual(len(run.issued("awww", "kill")), 1)

    def test_a_file_that_is_not_a_wallpaper_is_rejected(self) -> None:
        with self.assertRaises(ValueError):
            wallpaperd.show(self.touch("notes.txt"), self.cache, run=Fake())


class StopTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.cache = Path(self.tmp.name)

    def test_stop_kills_both_engines_and_forgets_the_state(self) -> None:
        wallpaperd.write_state(self.cache, "mpvpaper", "/tmp/x.mp4", "video")
        run = Fake(awww=True)
        wallpaperd.stop(self.cache, run=run)

        self.assertEqual(len(run.issued("pkill", "-x", "mpvpaper")), 1)
        self.assertEqual(len(run.issued("awww", "kill")), 1)
        self.assertEqual(wallpaperd.read_state(self.cache), {})

    def test_stop_is_idempotent(self) -> None:
        run = Fake(awww=False)
        wallpaperd.stop(self.cache, run=run)
        wallpaperd.stop(self.cache, run=run)
        self.assertEqual(run.issued("awww", "kill"), [])

    def test_a_broken_state_file_reads_as_empty(self) -> None:
        wallpaperd.state_path(self.cache).write_text("{not json", encoding="utf-8")
        self.assertEqual(wallpaperd.read_state(self.cache), {})

    def test_state_round_trips(self) -> None:
        wallpaperd.write_state(self.cache, "awww", "/tmp/a.png", "image")
        stored = json.loads(wallpaperd.state_path(self.cache).read_text())
        self.assertEqual(stored["kind"], "image")


if __name__ == "__main__":
    unittest.main()
