"""Screenshots and recording: the commands, the names and the state file."""

from __future__ import annotations

import base64
import contextlib
import html
import io
import json
import re
import signal
import tempfile
import time
import unittest
from unittest import mock
from pathlib import Path

from vitrail import capture

NOW = 1_700_000_000  # 2023-11-14 22:13:20 UTC


def runner(answer: str | None = ""):
    calls: list[list[str]] = []

    def run(argv: list[str]) -> str | None:
        calls.append(argv)
        return answer

    return run, calls


class ClipboardTests(unittest.TestCase):
    def test_a_background_process_left_by_the_command_does_not_block_it(self) -> None:
        # wl-copy forks to keep the selection and inherits its pipes: waiting
        # on them hung the caller (the bar never heard back from the capture).
        started = time.monotonic()
        self.assertTrue(capture.run_bytes(["sh", "-c", "cat >/dev/null; sleep 3 &"], b"data"))
        self.assertLess(time.monotonic() - started, 2)

    def test_a_failing_command_is_false(self) -> None:
        self.assertFalse(capture.run_bytes(["false"], b"x"))
        self.assertFalse(capture.run_bytes(["no-such-program-vitrail"], b"x"))


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


SCREENS = [
    {"name": "DP-1", "x": 0, "y": 0, "width": 1920, "height": 1080, "scale": 1.0},
    {"name": "HDMI-A-1", "x": 1920, "y": 0, "width": 1280, "height": 1024, "scale": 1.5},
]


def screen_runner(
    calls: list[list[str]], screens: list[dict] | None = None, grim: bool = True, pointer: str = "960,540"
):
    def run(argv: list[str]) -> str | None:
        calls.append(argv)
        if argv[:2] == ["hyprctl", "monitors"]:
            return json.dumps(SCREENS if screens is None else screens)
        if argv[:2] == ["hyprctl", "cursorpos"]:
            return pointer
        if not grim:
            return None
        Path(argv[-1]).write_bytes(b"png")
        return ""

    return run


class FreezeTests(unittest.TestCase):
    def test_every_monitor_is_captured_into_the_runtime_folder(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            calls: list[list[str]] = []
            result = capture.freeze(Path(tmp), run=screen_runner(calls))
            self.assertNotIn("error", result)
            self.assertEqual(
                [argv[:2] for argv in calls],
                [["hyprctl", "monitors"], ["grim", "-o"], ["grim", "-o"], ["hyprctl", "cursorpos"]],
            )
            self.assertEqual([one["name"] for one in result["monitors"]], ["DP-1", "HDMI-A-1"])
            for one in result["monitors"]:
                self.assertEqual(Path(one["image"]).parent, Path(tmp) / "capture")
                self.assertTrue(Path(one["image"]).is_file())

    def test_the_bounds_cover_every_monitor(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = capture.freeze(Path(tmp), run=screen_runner([]))
            self.assertEqual(result["bounds"], {"x": 0, "y": 0, "w": 3200, "h": 1080})

    def test_the_pointer_comes_with_the_freeze(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = capture.freeze(Path(tmp), run=screen_runner([], pointer="2000,300"))
            self.assertEqual(result["pointer"], {"x": 2000, "y": 300})
            unknown = capture.freeze(Path(tmp), run=screen_runner([], pointer=""))
            self.assertIsNone(unknown["pointer"])

    def test_a_failing_grim_stops_the_freeze(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = capture.freeze(Path(tmp), run=screen_runner([], grim=False))
            self.assertEqual(result, {"error": "grim failed"})

    def test_previous_images_are_removed(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            stale = Path(tmp) / "capture" / "frozen-gone.png"
            stale.parent.mkdir(parents=True)
            stale.write_bytes(b"old")
            capture.freeze(Path(tmp), run=screen_runner([]))
            self.assertFalse(stale.exists())

    def test_without_monitors_the_freeze_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = capture.freeze(Path(tmp), run=screen_runner([], screens=[]))
            self.assertEqual(result, {"error": "no monitors"})

    def test_the_freeze_is_written_for_the_next_call(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = capture.freeze(Path(tmp), run=screen_runner([]))
            self.assertEqual(capture.read_frozen(Path(tmp)), result)

    def test_without_a_freeze_there_is_nothing_to_read(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(capture.read_frozen(Path(tmp)), {})

    def test_a_monitor_without_a_scale_counts_as_one(self) -> None:
        screen = [{"name": "eDP-1", "x": 0, "y": 0, "width": 800, "height": 600}]
        with tempfile.TemporaryDirectory() as tmp:
            result = capture.freeze(Path(tmp), run=screen_runner([], screens=screen))
            self.assertEqual(result["monitors"][0]["scale"], 1.0)


class CropTests(unittest.TestCase):
    flat = [
        {"name": "DP-1", "x": 0, "y": 0, "width": 1920, "height": 1080, "scale": 1.0, "image": "a.png"},
        {"name": "HDMI-A-1", "x": 1920, "y": 0, "width": 1280, "height": 1024, "scale": 1.0, "image": "b.png"},
    ]

    def test_one_monitor_is_one_piece(self) -> None:
        canvas, pieces = capture.crop_pieces({"x": 10, "y": 20, "w": 300, "h": 200}, self.flat)
        self.assertEqual(canvas, {"w": 300, "h": 200})
        self.assertEqual(pieces, [{"image": "a.png", "crop": [10, 20, 300, 200], "offset": [0, 0]}])

    def test_a_selection_across_monitors_is_two_pieces(self) -> None:
        canvas, pieces = capture.crop_pieces({"x": 1800, "y": 0, "w": 200, "h": 100}, self.flat)
        self.assertEqual(canvas, {"w": 200, "h": 100})
        self.assertEqual(
            pieces,
            [
                {"image": "a.png", "crop": [1800, 0, 120, 100], "offset": [0, 0]},
                {"image": "b.png", "crop": [0, 0, 80, 100], "offset": [120, 0]},
            ],
        )

    def test_the_scale_of_the_starting_monitor_sizes_the_canvas(self) -> None:
        screens = [self.flat[0], {**self.flat[1], "scale": 1.5}]
        canvas, pieces = capture.crop_pieces({"x": 1800, "y": 0, "w": 200, "h": 100}, screens)
        self.assertEqual(canvas, {"w": 200, "h": 100})
        self.assertEqual(pieces[1]["crop"], [0, 0, 120, 150])
        self.assertEqual(pieces[1]["offset"], [120, 0])

    def test_a_scaled_neighbour_is_cropped_at_its_own_scale(self) -> None:
        screens = [self.flat[0], {**self.flat[1], "scale": 2.0}]
        canvas, pieces = capture.crop_pieces({"x": 1820, "y": 10, "w": 200, "h": 100}, screens)
        self.assertEqual(canvas, {"w": 200, "h": 100})
        self.assertEqual(pieces[0]["crop"], [1820, 10, 100, 100])
        self.assertEqual(pieces[1]["crop"], [0, 20, 200, 200])
        self.assertEqual(pieces[1]["offset"], [100, 0])
        del pieces

    def test_a_reversed_drag_is_normalized(self) -> None:
        canvas, pieces = capture.crop_pieces({"x": 100, "y": 100, "w": -50, "h": -80}, self.flat)
        self.assertEqual(canvas, {"w": 50, "h": 80})
        self.assertEqual(pieces[0]["crop"], [50, 20, 50, 80])

    def test_an_empty_selection_is_refused(self) -> None:
        with self.assertRaises(ValueError):
            capture.crop_pieces({"x": 10, "y": 10, "w": 0, "h": 40}, self.flat)
        with self.assertRaises(ValueError):
            capture.crop_pieces({"x": 4000, "y": 0, "w": 100, "h": 100}, self.flat)

    def test_the_selection_is_clamped_to_the_layout(self) -> None:
        canvas, pieces = capture.crop_pieces({"x": 1900, "y": 0, "w": 1400, "h": 100}, self.flat)
        self.assertEqual(canvas, {"w": 1300, "h": 100})
        self.assertEqual([piece["crop"][2] for piece in pieces], [20, 1280])


class GrabTests(unittest.TestCase):
    flat = CropTests.flat

    def magick(self, calls: list[list[str]]):
        def run(argv: list[str]) -> str:
            calls.append(argv)
            Path(argv[-1]).write_bytes(b"png")
            return ""

        return run

    def test_copy_only_writes_nothing_in_the_folder(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            calls: list[list[str]] = []
            copied: list[bytes] = []
            result = capture.grab(
                {"x": 0, "y": 0, "w": 10, "h": 10},
                self.flat,
                Path(tmp),
                copy=True,
                run=self.magick(calls),
                copy_run=lambda argv, data: copied.append(data) or True,
                now=NOW,
            )
            self.assertEqual(result, {"copied": True})
            self.assertEqual(copied, [b"png"])
            self.assertEqual([Path(one.name).name for one in (Path(tmp) / "capture").glob("Screenshot_*")], [])

    def test_save_writes_the_named_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            shots = Path(tmp) / "shots"
            result = capture.grab(
                {"x": 0, "y": 0, "w": 10, "h": 10},
                self.flat,
                Path(tmp),
                directory=str(shots),
                now=NOW,
                run=self.magick([]),
            )
            self.assertRegex(Path(result["path"]).name, r"^Screenshot_\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}\.png$")
            self.assertEqual(Path(result["path"]).read_bytes(), b"png")

    def test_the_composition_lays_every_piece_on_the_canvas(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            calls: list[list[str]] = []
            capture.grab({"x": 1800, "y": 0, "w": 200, "h": 100}, self.flat, Path(tmp), run=self.magick(calls))
            argv = calls[0]
            self.assertEqual(argv[:4], ["magick", "-size", "200x100", "xc:none"])
            self.assertIn("120x100+1800+0", argv)
            self.assertIn("80x100+0+0", argv)
            self.assertIn("-composite", argv)

    def test_without_imagemagick_nothing_ran(self) -> None:
        with mock.patch.object(capture.shutil, "which", return_value=None):
            self.assertEqual(
                capture.grab({"x": 0, "y": 0, "w": 10, "h": 10}, self.flat), {"error": "imagemagick is missing"}
            )

    def test_an_empty_selection_is_reported(self) -> None:
        self.assertEqual(
            capture.grab({"x": 0, "y": 0, "w": 0, "h": 10}, self.flat, run=self.magick([])),
            {"error": "empty selection"},
        )

    def test_a_monitor_without_its_image_is_refused(self) -> None:
        screens = [{key: value for key, value in one.items() if key != "image"} for one in self.flat]
        self.assertEqual(
            capture.grab({"x": 0, "y": 0, "w": 10, "h": 10}, screens, run=self.magick([])),
            {"error": "the screen is not frozen"},
        )

    def test_a_failing_magick_is_reported(self) -> None:
        self.assertEqual(
            capture.grab({"x": 0, "y": 0, "w": 10, "h": 10}, self.flat, run=lambda argv: None),
            {"error": "magick failed"},
        )

    def test_a_refused_clipboard_is_visible(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = capture.grab(
                {"x": 0, "y": 0, "w": 10, "h": 10},
                self.flat,
                Path(tmp),
                copy=True,
                run=self.magick([]),
                copy_run=lambda argv, data: False,
            )
            self.assertEqual(result, {"copied": False})


class GeometryTextTests(unittest.TestCase):
    def test_the_grim_form_is_understood(self) -> None:
        self.assertEqual(capture.parse_geometry("800x600+10+20"), {"x": 10, "y": 20, "w": 800, "h": 600})

    def test_the_internal_form_is_understood(self) -> None:
        self.assertEqual(capture.parse_geometry("10,20,800,600"), {"x": 10, "y": 20, "w": 800, "h": 600})

    def test_a_negative_origin_is_understood(self) -> None:
        self.assertEqual(capture.parse_geometry("800x600+-100+-20"), {"x": -100, "y": -20, "w": 800, "h": 600})

    def test_the_text_form_round_trips(self) -> None:
        self.assertEqual(capture.geometry_text({"x": -5, "y": 7, "w": 30, "h": 40}), "30x40+-5+7")

    def test_nonsense_is_refused(self) -> None:
        for text in ("", "800x", "a,b,c,d", "800x600"):
            with self.subTest(text=text), self.assertRaises(ValueError):
                capture.parse_geometry(text)


class WindowTests(unittest.TestCase):
    def clients(self, answer: str | dict | None):
        def run(argv: list[str]) -> str | None:
            self.assertEqual(argv, ["hyprctl", "clients", "-j"])
            return answer if isinstance(answer, str) or answer is None else json.dumps(answer)

        return run

    def client(self, at, size, focus=0, **extra) -> dict:
        return {"at": at, "size": size, "focusHistoryID": focus, "hidden": False, "mapped": True, **extra}

    def test_the_window_under_the_point_is_returned(self) -> None:
        run = self.clients([self.client([100, 200], [300, 400])])
        self.assertEqual(capture.window_at(150, 250, run), {"x": 100, "y": 200, "w": 300, "h": 400})

    def test_the_most_recently_focused_client_wins(self) -> None:
        run = self.clients(
            [
                self.client([0, 0], [500, 500], focus=3),
                self.client([100, 100], [200, 200], focus=0),
            ]
        )
        self.assertEqual(capture.window_at(150, 150, run)["w"], 200)

    def test_a_point_in_no_window_is_none(self) -> None:
        run = self.clients([self.client([0, 0], [10, 10])])
        self.assertIsNone(capture.window_at(50, 50, run))

    def test_a_hidden_window_is_ignored(self) -> None:
        run = self.clients([self.client([0, 0], [500, 500], hidden=True)])
        self.assertIsNone(capture.window_at(10, 10, run))

    def test_an_empty_size_is_ignored(self) -> None:
        run = self.clients([self.client([0, 0], [0, 0])])
        self.assertIsNone(capture.window_at(10, 10, run))

    def test_a_broken_answer_is_none(self) -> None:
        self.assertIsNone(capture.window_at(0, 0, self.clients("not json")))
        self.assertIsNone(capture.window_at(0, 0, self.clients(None)))


class AnnotateTests(unittest.TestCase):
    def test_swappy_opens_the_file_in_the_vitrail_theme_when_it_is_installed(self) -> None:
        calls: list[tuple[list[str], dict]] = []
        with (
            mock.patch.object(capture.shutil, "which", return_value="/usr/bin/swappy"),
            mock.patch("vitrail.swappy.environment", return_value={"GTK_THEME": "Vitrail-Swappy"}) as prepared,
        ):
            self.assertTrue(
                capture.annotate(
                    "/tmp/a.png",
                    values={"annotatePanel": "false"},
                    spawner=lambda argv, log, env=None: calls.append((argv, env)) or 1,
                )
            )
        prepared.assert_called_once_with({"annotatePanel": "false"})
        self.assertEqual(calls, [(["swappy", "-f", "/tmp/a.png"], {"GTK_THEME": "Vitrail-Swappy"})])

    def test_without_swappy_nothing_opens(self) -> None:
        calls: list[list[str]] = []
        with mock.patch.object(capture.shutil, "which", return_value=None):
            self.assertFalse(
                capture.annotate("/tmp/a.png", spawner=lambda argv, log, env=None: calls.append(argv) or 1)
            )
        self.assertEqual(calls, [])


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

    def test_the_overlay_geometry_reaches_wf_recorder(self) -> None:
        spawned: list[list[str]] = []
        self.record(
            "start",
            geometry="640x480+120+80",
            run=lambda argv: None,
            spawner=lambda argv, log: spawned.append(argv) or self.running.add(4242) or 4242,
        )
        self.assertIn("-g", spawned[0])
        # wf-recorder wants the area as `x,y wxh`, not grim's `WxH+X+Y`.
        self.assertIn("120,80 640x480", spawned[0])

    def test_an_area_across_monitors_is_recorded_on_the_one_it_starts(self) -> None:
        spawned: list[list[str]] = []
        screens = [
            {"name": "DP-1", "x": 0, "y": 0, "width": 1920, "height": 1080, "scale": 1.0},
            {"name": "DP-2", "x": 1920, "y": 0, "width": 1280, "height": 1024, "scale": 1.0},
        ]
        self.record(
            "start",
            geometry="500x300+1800+100",
            monitors=screens,
            run=lambda argv: None,
            spawner=lambda argv, log: spawned.append(argv) or self.running.add(4242) or 4242,
        )
        # 1800..1920 is DP-1: the ten pixels before its right edge.
        self.assertIn("1800,100 120x300", spawned[0])

    def test_an_area_inside_one_monitor_keeps_its_size(self) -> None:
        spawned: list[list[str]] = []
        screens = [{"name": "DP-1", "x": 0, "y": 0, "width": 1920, "height": 1080, "scale": 1.0}]
        self.record(
            "start",
            geometry="500x300+100+100",
            monitors=screens,
            run=lambda argv: None,
            spawner=lambda argv, log: spawned.append(argv) or self.running.add(4242) or 4242,
        )
        self.assertIn("100,100 500x300", spawned[0])

    def test_audio_adds_the_flag(self) -> None:
        spawned: list[list[str]] = []
        self.record(
            "start", audio=True, spawner=lambda argv, log: spawned.append(argv) or self.running.add(4242) or 4242
        )
        self.assertIn("-a", spawned[0])

    def test_a_dead_pid_is_not_recording(self) -> None:
        capture.status_file(self.runtime).write_text('{"pid": 999999, "path": "x"}', encoding="utf-8")
        self.assertEqual(capture.status(self.runtime, alive=lambda pid: False), {})


TESSERACT_LANGS = 'List of available languages in "/usr/share/tessdata/" (3):\neng\nosd\nspa\n'


class OcrLanguageTests(unittest.TestCase):
    def test_the_installed_languages_are_read_without_the_osd_helper(self) -> None:
        run, calls = runner(TESSERACT_LANGS)
        self.assertEqual(capture.installed_languages(run), ["eng", "spa"])
        self.assertEqual(calls, [["tesseract", "--list-langs"]])

    def test_a_failing_tesseract_has_no_languages(self) -> None:
        self.assertEqual(capture.installed_languages(lambda argv: None), [])

    def test_the_default_follows_the_system_language_plus_english(self) -> None:
        self.assertEqual(capture.default_languages("es"), "spa+eng")
        self.assertEqual(capture.default_languages("de_DE.UTF-8"), "deu+eng")
        self.assertEqual(capture.default_languages("pt-BR"), "por+eng")
        self.assertEqual(capture.default_languages("en"), "eng")

    def test_an_unknown_system_language_reads_english(self) -> None:
        self.assertEqual(capture.default_languages("xx"), "eng")
        self.assertEqual(capture.default_languages(""), "eng")

    def test_only_installed_languages_are_used_in_the_asked_order(self) -> None:
        self.assertEqual(capture.pick_languages("spa+eng", ["eng", "spa"]), "spa+eng")
        self.assertEqual(capture.pick_languages("deu, spa eng", ["eng", "spa"]), "spa+eng")
        self.assertEqual(capture.pick_languages("eng+eng", ["eng"]), "eng")

    def test_when_none_is_installed_english_then_any_installed_one_is_used(self) -> None:
        self.assertEqual(capture.pick_languages("deu", ["eng", "spa"]), "eng")
        self.assertEqual(capture.pick_languages("deu", ["afr"]), "afr")
        self.assertEqual(capture.pick_languages("deu", []), "")

    def test_the_preference_wins_over_the_system_language(self) -> None:
        self.assertEqual(capture.wanted_languages({"ocrLanguages": "fra+eng", "language": "es"}), "fra+eng")
        self.assertEqual(capture.wanted_languages({"ocrLanguages": " ", "language": "es"}), "spa+eng")
        self.assertEqual(capture.wanted_languages({"language": "es"}), "spa+eng")
        self.assertEqual(capture.wanted_languages({}), "eng")


class OcrTextTests(unittest.TestCase):
    def test_the_text_is_tidied(self) -> None:
        raw = "  Hello  \r\nworld \n\n\n\n\nnext\x0c\n"
        self.assertEqual(capture.clean_text(raw), "Hello\nworld\n\nnext")

    def test_whitespace_only_is_no_text(self) -> None:
        self.assertEqual(capture.clean_text(" \n\x0c\n \t"), "")

    def test_the_preview_is_one_short_escaped_line(self) -> None:
        self.assertEqual(capture.preview("a <b> & c\nsecond", 100), "a &lt;b&gt; &amp; c second")
        long = capture.preview("word " * 100, 40)
        self.assertTrue(long.endswith("…"))
        self.assertLessEqual(len(long), 41)

    def test_small_areas_are_enlarged_and_big_ones_are_not(self) -> None:
        self.assertEqual(capture.ocr_scale(300, 40), 3)
        self.assertEqual(capture.ocr_scale(900, 500), 2)
        self.assertEqual(capture.ocr_scale(2560, 1440), 1)

    def test_one_line_areas_are_read_as_a_line_and_the_rest_as_a_block(self) -> None:
        self.assertEqual(capture.ocr_psm(400, 30), 7)
        self.assertEqual(capture.ocr_psm(400, 300), 6)


class OcrReadTests(unittest.TestCase):
    flat = CropTests.flat

    def tools(self, calls: list[list[str]], text: str | None = "Hello\nworld\n"):
        def run(argv: list[str]) -> str | None:
            calls.append(argv)
            if argv[:2] == ["tesseract", "--list-langs"]:
                return TESSERACT_LANGS
            if argv[0] == "tesseract":
                return text
            Path(argv[-1]).write_bytes(b"png")
            return ""

        return run

    def read(self, text: str | None = "Hello\nworld\n", **extra) -> tuple[dict, list[list[str]], list[bytes]]:
        calls: list[list[str]] = []
        copied: list[bytes] = []
        with tempfile.TemporaryDirectory() as tmp:
            result = capture.read_text(
                {"x": 0, "y": 0, "w": 400, "h": 300},
                self.flat,
                extra.pop("wanted", "spa+eng"),
                Path(tmp),
                run=self.tools(calls, text),
                copy_run=lambda argv, data: copied.append(data) or extra.pop("copied", True),
            )
        return result, calls, copied

    def test_the_text_is_read_copied_and_returned(self) -> None:
        result, calls, copied = self.read()
        self.assertEqual(result["text"], "Hello\nworld")
        self.assertEqual(result["languages"], "spa+eng")
        self.assertTrue(result["copied"])
        self.assertEqual(copied, [b"Hello\nworld"])
        reading = next(argv for argv in calls if argv[0] == "tesseract" and "stdout" in argv)
        self.assertEqual(reading[2:], ["stdout", "--psm", "6", "-l", "spa+eng"])

    def test_the_picture_is_enlarged_in_grey_before_it_is_read(self) -> None:
        _, calls, _ = self.read()
        prepare = next(argv for argv in calls if argv[0] == "magick" and "-colorspace" in argv)
        self.assertIn("Gray", prepare)
        self.assertEqual(prepare[prepare.index("-resize") + 1], "200%")

    def test_an_empty_reading_copies_nothing(self) -> None:
        result, _, copied = self.read(" \n\x0c")
        self.assertEqual(result["text"], "")
        self.assertNotIn("error", result)
        self.assertEqual(copied, [])

    def test_a_refused_clipboard_is_reported(self) -> None:
        result, _, _ = self.read(copied=False)
        self.assertFalse(result["copied"])
        self.assertEqual(result["text"], "Hello\nworld")

    def test_a_failing_tesseract_is_an_error(self) -> None:
        result, _, _ = self.read(None)
        self.assertEqual(result, {"error": "tesseract failed"})

    def test_without_tesseract_nothing_ran(self) -> None:
        real = capture.shutil.which
        with mock.patch.object(
            capture.shutil, "which", side_effect=lambda name: None if name == "tesseract" else real(name)
        ):
            result, calls, _ = self.read()
        self.assertEqual(result, {"error": "tesseract is missing"})
        self.assertEqual(calls, [])

    def test_a_bad_selection_is_reported_without_reading(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = capture.read_text(
                {"x": 0, "y": 0, "w": 0, "h": 5}, self.flat, "eng", Path(tmp), run=self.tools([])
            )
        self.assertEqual(result, {"error": "empty selection"})


class AskUrlTests(unittest.TestCase):
    def test_the_upload_url_carries_the_question(self) -> None:
        url = capture.lens_url("what is this & why?", 1234)
        self.assertTrue(url.startswith("https://lens.google.com/v3/upload?"))
        self.assertIn("q=what+is+this+%26+why%3F", url)
        self.assertIn("st=1234", url)

    def test_without_a_question_there_is_no_q(self) -> None:
        self.assertNotIn("q=", capture.lens_url("", 1234))

    def test_the_question_is_tidied_and_capped(self) -> None:
        self.assertEqual(capture.question("  a\n  b\tc  "), "a b c")
        self.assertEqual(len(capture.question("x" * 2000)), capture.QUESTION_MAX)


class AskPageTests(unittest.TestCase):
    def test_the_page_posts_the_image_to_lens_and_nowhere_else(self) -> None:
        page = capture.lens_page(b"\x89PNGdata", "hola", 99)
        self.assertIn('enctype="multipart/form-data"', page)
        self.assertIn('name="encoded_image"', page)
        self.assertIn("DataTransfer", page)
        self.assertIn(base64.b64encode(b"\x89PNGdata").decode(), page)
        self.assertEqual(
            [html.unescape(url) for url in re.findall(r"https?://[^\"' <>]+", page)], [capture.lens_url("hola", 99)]
        )
        self.assertNotIn("<script src", page)

    def test_the_action_is_escaped_in_the_attribute(self) -> None:
        page = capture.lens_page(b"x", 'say "hi" & <go>', 1)
        self.assertNotIn('say "hi"', page)
        self.assertNotIn("<go>", page)


class AskTests(unittest.TestCase):
    flat = CropTests.flat

    def tools(self, calls: list[list[str]]):
        def run(argv: list[str]) -> str | None:
            calls.append(argv)
            Path(argv[-1]).write_bytes(b"png")
            return ""

        return run

    def ask(self, text: str = "what is this?", **extra):
        calls: list[list[str]] = []
        spawned: list[list[str]] = []
        real = capture.shutil.which

        def found(name: str) -> str | None:
            if name == "xdg-open":
                return "/usr/bin/xdg-open" if extra.get("opener", True) else None
            return real(name)

        with tempfile.TemporaryDirectory() as tmp, mock.patch.object(capture.shutil, "which", side_effect=found):
            result = capture.ask(
                {"x": 0, "y": 0, "w": 400, "h": 300},
                self.flat,
                text,
                Path(tmp),
                run=extra.get("run", self.tools(calls)),
                spawner=lambda argv, log, env=None: spawned.append(argv) or 1,
                now=1.5,
            )
            page = Path(result["page"]) if "page" in result else None
            body = page.read_text(encoding="utf-8") if page and page.exists() else ""
            mode = page.stat().st_mode & 0o777 if page and page.exists() else 0
            folder = (page.parent.stat().st_mode & 0o777) if page and page.exists() else 0
        return result, calls, spawned, body, mode, folder

    def test_the_default_browser_opens_a_private_page_with_the_image(self) -> None:
        result, calls, spawned, body, mode, folder = self.ask()
        self.assertTrue(result["opened"])
        self.assertEqual(spawned[0][0], "xdg-open")
        self.assertTrue(spawned[0][1].startswith("file://"))
        self.assertTrue(spawned[0][1].endswith("lens.html"))
        self.assertIn(base64.b64encode(b"png").decode(), body)
        self.assertIn("q=what+is+this%3F", body)
        self.assertEqual(mode, 0o600)
        self.assertEqual(folder, 0o700)

    def test_the_image_is_shrunk_to_a_size_google_takes(self) -> None:
        _, calls, _, _, _, _ = self.ask()
        shrink = next(argv for argv in calls if "-resize" in argv)
        self.assertEqual(shrink[shrink.index("-resize") + 1], f"{capture.ASK_PIXELS}x{capture.ASK_PIXELS}>")

    def test_the_files_are_forgotten_after_a_delay(self) -> None:
        result, _, spawned, _, _, _ = self.ask()
        forget = spawned[1]
        self.assertEqual(forget[1:5], ["-m", "vitrail.capture", "forget", "--after"])
        self.assertEqual(forget[5], str(capture.ASK_KEEP))
        self.assertIn(result["page"], forget[6:])

    def test_a_bad_selection_sends_nothing(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            spawned: list = []
            result = capture.ask(
                {"x": 0, "y": 0, "w": 0, "h": 5},
                self.flat,
                "x",
                Path(tmp),
                run=self.tools([]),
                spawner=lambda *args, **kwargs: spawned.append(args),
            )
        self.assertEqual(result, {"error": "empty selection"})
        self.assertEqual(spawned, [])

    def test_a_failing_magick_sends_nothing(self) -> None:
        result, _, spawned, _, _, _ = self.ask(run=lambda argv: None)
        self.assertEqual(result, {"error": "magick failed"})
        self.assertEqual(spawned, [])

    def test_without_xdg_open_nothing_is_written(self) -> None:
        result, _, spawned, body, _, _ = self.ask(opener=False)
        self.assertEqual(result, {"error": "xdg-open is missing"})
        self.assertEqual((spawned, body), ([], ""))

    def test_forget_removes_the_files_after_the_delay(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            one = Path(tmp) / "a.png"
            one.write_bytes(b"x")
            slept: list[float] = []
            capture.forget([str(one), str(Path(tmp) / "missing")], 7, sleep=slept.append)
            self.assertFalse(one.exists())
            self.assertEqual(slept, [7])


ZBAR_XML = (
    "<barcodes xmlns='http://zbar.sourceforge.net/2008/barcode'><source href='a.png'>"
    "<index num='0'><symbol type='QR-Code' quality='1' orientation='UP'>"
    "<polygon points='1,1 1,9 9,9 9,1'/><data><![CDATA[https://example.org/a?b=1&c=2]]></data></symbol></index>"
    "<index num='1'><symbol type='EAN-13' quality='1'><data>4006381333931</data></symbol></index>"
    "</source></barcodes>"
)


class CodeTests(unittest.TestCase):
    def test_zbar_output_is_parsed_into_types_and_data(self) -> None:
        self.assertEqual(
            capture.parse_codes(ZBAR_XML),
            [
                {"type": "QR-Code", "data": "https://example.org/a?b=1&c=2"},
                {"type": "EAN-13", "data": "4006381333931"},
            ],
        )

    def test_garbage_has_no_codes(self) -> None:
        self.assertEqual(capture.parse_codes("not xml"), [])
        self.assertEqual(capture.parse_codes(""), [])

    def test_the_scan_runs_zbarimg_quietly_on_the_image(self) -> None:
        run, calls = runner(ZBAR_XML)
        self.assertEqual(len(capture.scan_codes("/x/a.png", run)), 2)
        self.assertEqual(calls, [["zbarimg", "--quiet", "--xml", "/x/a.png"]])

    def test_zbar_failing_means_no_code(self) -> None:
        self.assertEqual(capture.scan_codes("/x/a.png", lambda argv: None), [])

    def test_only_web_links_are_links(self) -> None:
        self.assertTrue(capture.is_url("https://example.org/a"))
        self.assertTrue(capture.is_url("http://example.org"))
        for text in ("example.org", "file:///etc/passwd", "javascript:alert(1)", "https://a.b c", "-https://a.b", ""):
            with self.subTest(text=text):
                self.assertFalse(capture.is_url(text))

    def test_a_link_opens_with_xdg_open_and_anything_else_does_not(self) -> None:
        spawned: list[list[str]] = []
        real = capture.shutil.which
        with mock.patch.object(
            capture.shutil, "which", side_effect=lambda n: "/usr/bin/" + n if n == "xdg-open" else real(n)
        ):
            done = capture.open_link(
                "https://example.org/x", Path("/tmp/x.log"), lambda argv, log, env=None: spawned.append(argv) or 1
            )
            refused = capture.open_link(
                "file:///etc/passwd", Path("/tmp/x.log"), lambda *a, **k: spawned.append(a) or 1
            )
        self.assertEqual(done, {"opened": True})
        self.assertEqual(spawned, [["xdg-open", "https://example.org/x"]])
        self.assertEqual(refused, {"error": "not a web link"})


class DetectTests(unittest.TestCase):
    flat = CropTests.flat

    def tools(self, calls: list[list[str]], text: str | None, codes: str | None = None):
        def run(argv: list[str]) -> str | None:
            calls.append(argv)
            if argv[:2] == ["tesseract", "--list-langs"]:
                return TESSERACT_LANGS
            if argv[0] == "tesseract":
                return text
            if argv[0] == "zbarimg":
                return codes
            Path(argv[-1]).write_bytes(b"png")
            return ""

        return run

    def detect(self, text: str | None, codes: str | None = None, selection: dict | None = None):
        calls: list[list[str]] = []
        with tempfile.TemporaryDirectory() as tmp:
            result = capture.detect(
                selection or {"x": 0, "y": 0, "w": 400, "h": 300},
                self.flat,
                "eng",
                Path(tmp),
                run=self.tools(calls, text, codes),
            )
        return result, calls

    def test_text_and_codes_are_reported_without_the_text_itself_leaving(self) -> None:
        result, calls = self.detect("Hello world\n", ZBAR_XML)
        self.assertEqual(result, {"text": True, "codes": 2})
        self.assertNotIn("wl-copy", [argv[0] for argv in calls])

    def test_noise_is_not_text(self) -> None:
        result, _ = self.detect("|\n.. \n", None)
        self.assertEqual(result, {"text": False, "codes": 0})

    def test_a_failing_tesseract_is_no_text(self) -> None:
        result, _ = self.detect(None, None)
        self.assertEqual(result, {"text": False, "codes": 0})

    def test_it_composes_into_its_own_file_so_actions_do_not_race_it(self) -> None:
        _, calls = self.detect("hello there", None)
        composed = [argv[-1] for argv in calls if argv[0] == "magick" and "xc:none" in argv]
        self.assertTrue(composed[0].endswith("detect.png"))

    def test_a_bad_selection_is_an_error(self) -> None:
        result, _ = self.detect("x", None, {"x": 0, "y": 0, "w": 0, "h": 3})
        self.assertEqual(result, {"error": "empty selection"})

    def test_text_needs_a_few_letters(self) -> None:
        self.assertTrue(capture.has_text("ab c"))
        self.assertFalse(capture.has_text("a ."))
        self.assertFalse(capture.has_text(""))


class ReadCodesTests(unittest.TestCase):
    flat = CropTests.flat

    def read(self, codes: str | None, copied: bool = True):
        calls: list[list[str]] = []
        copies: list[bytes] = []

        def run(argv: list[str]) -> str | None:
            calls.append(argv)
            if argv[0] == "zbarimg":
                return codes
            Path(argv[-1]).write_bytes(b"png")
            return ""

        with tempfile.TemporaryDirectory() as tmp:
            result = capture.read_codes(
                {"x": 0, "y": 0, "w": 400, "h": 300},
                self.flat,
                Path(tmp),
                run=run,
                copy_run=lambda argv, data: copies.append(data) or copied,
            )
        return result, copies

    def test_the_first_code_is_copied_and_all_are_returned(self) -> None:
        result, copies = self.read(ZBAR_XML)
        self.assertEqual(len(result["codes"]), 2)
        self.assertEqual(copies, [b"https://example.org/a?b=1&c=2"])
        self.assertTrue(result["copied"])
        self.assertEqual(result["url"], "https://example.org/a?b=1&c=2")

    def test_a_plain_code_has_no_url(self) -> None:
        xml = ZBAR_XML.replace("https://example.org/a?b=1&amp;c=2", "hello")
        xml = xml.replace("<![CDATA[https://example.org/a?b=1&c=2]]>", "hello")
        result, _ = self.read(xml)
        self.assertEqual(result["url"], "")

    def test_no_code_is_an_empty_list_and_copies_nothing(self) -> None:
        result, copies = self.read(None)
        self.assertEqual((result["codes"], copies), ([], []))


class TranslateTests(unittest.TestCase):
    flat = CropTests.flat

    def test_the_target_is_the_preference_then_the_system_language(self) -> None:
        self.assertEqual(capture.target_language({"translateTarget": "fr", "language": "es"}), "fr")
        self.assertEqual(capture.target_language({"translateTarget": "", "language": "es"}), "es")
        self.assertEqual(capture.target_language({}), "en")

    def test_a_target_that_is_not_a_language_code_is_dropped(self) -> None:
        self.assertEqual(capture.target_language({"translateTarget": "-x; rm", "language": "de"}), "de")
        self.assertEqual(capture.target_language({"translateTarget": "zh-CN"}), "zh-CN")

    def tools(self, calls: list[list[str]], seen: str | None = "Hello there", translated: str | None = "Hola"):
        def run(argv: list[str]) -> str | None:
            calls.append(argv)
            if argv[:2] == ["tesseract", "--list-langs"]:
                return TESSERACT_LANGS
            if argv[0] == "tesseract":
                return seen
            if argv[0] == "trans":
                return translated
            Path(argv[-1]).write_bytes(b"png")
            return ""

        return run

    def translate(self, which_trans: bool = True, **extra):
        calls: list[list[str]] = []
        real = capture.shutil.which

        def found(name: str) -> str | None:
            if name == "trans":
                return "/usr/bin/trans" if which_trans else None
            return real(name)

        with tempfile.TemporaryDirectory() as tmp, mock.patch.object(capture.shutil, "which", side_effect=found):
            result = capture.translate(
                {"x": 0, "y": 0, "w": 400, "h": 300},
                self.flat,
                "es",
                "eng",
                Path(tmp),
                run=self.tools(calls, **extra),
            )
        return result, calls

    def test_the_text_of_the_area_is_translated_with_trans(self) -> None:
        result, calls = self.translate()
        self.assertEqual(result, {"source": "Hello there", "text": "Hola"})
        argv = next(argv for argv in calls if argv[0] == "trans")
        self.assertEqual(argv[:3], ["trans", "-b", ":es"])
        self.assertEqual(argv[3], "-i")

    def test_the_text_travels_in_a_private_file_not_the_command_line(self) -> None:
        _, calls = self.translate()
        argv = next(argv for argv in calls if argv[0] == "trans")
        self.assertNotIn("Hello there", " ".join(argv))

    def test_without_translate_shell_it_says_so_and_reads_nothing(self) -> None:
        result, calls = self.translate(which_trans=False)
        self.assertEqual(result, {"error": "translate-shell is missing"})
        self.assertEqual(calls, [])

    def test_no_text_is_reported(self) -> None:
        result, _ = self.translate(seen="  ")
        self.assertEqual(result, {"error": "no text"})

    def test_a_failing_translation_is_reported(self) -> None:
        result, _ = self.translate(translated=None)
        self.assertEqual(result, {"error": "translation failed"})
        result, _ = self.translate(translated="  \n")
        self.assertEqual(result, {"error": "translation failed"})


class PinTests(unittest.TestCase):
    flat = CropTests.flat

    def test_the_composed_area_is_kept_in_the_pins_folder_outside_the_capture_one(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:

            def run(argv: list[str]) -> str:
                Path(argv[-1]).write_bytes(b"png")
                return ""

            first = capture.pin_image({"x": 0, "y": 0, "w": 50, "h": 50}, self.flat, Path(tmp), run=run, now=1.0)
            second = capture.pin_image({"x": 0, "y": 0, "w": 50, "h": 50}, self.flat, Path(tmp), run=run, now=2.0)
            self.assertEqual(Path(first["image"]).parent, Path(tmp) / "pins")
            self.assertNotEqual(first["image"], second["image"])
            self.assertEqual(Path(first["image"]).read_bytes(), b"png")
            self.assertEqual(Path(first["image"]).stat().st_mode & 0o777, 0o600)

    def test_a_bad_selection_is_an_error(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = capture.pin_image({"x": 0, "y": 0, "w": 0, "h": 5}, self.flat, Path(tmp), run=lambda argv: "")
        self.assertEqual(result, {"error": "empty selection"})


class PaletteTests(unittest.TestCase):
    flat = CropTests.flat
    histogram = (
        "   608: (255,255,255) #FFFFFF white\n"
        "   250: (200, 30, 40) #C81E28 srgb(200,30,40)\n"
        "   100: (203, 33, 42) #CB212A srgb(203,33,42)\n"
        "    30: ( 20,120,230) #1478E6 srgb(20,120,230)\n"
        "     8: (  0,  0,  0) #000000 black\n"
        "     4: (120,120,120) #787878 srgb(120,120,120)\n"
    )

    def test_the_histogram_lines_become_hex_and_count(self) -> None:
        self.assertEqual(
            capture.parse_histogram(self.histogram)[:3],
            [("#FFFFFF", 608), ("#C81E28", 250), ("#CB212A", 100)],
        )

    def test_garbage_has_no_histogram(self) -> None:
        self.assertEqual(capture.parse_histogram("nonsense\n\n"), [])

    def test_the_perceptual_distance_tells_close_reds_from_red_and_blue(self) -> None:
        close = capture.oklab_distance(capture.oklab((200, 30, 40)), capture.oklab((203, 33, 42)))
        far = capture.oklab_distance(capture.oklab((200, 30, 40)), capture.oklab((20, 120, 230)))
        self.assertLess(close, 0.01)
        self.assertGreater(far, 0.3)

    def test_colours_are_ranked_by_share_and_near_duplicates_merge(self) -> None:
        ranked = capture.rank_palette(capture.parse_histogram(self.histogram), 6)
        self.assertEqual([one["hex"] for one in ranked], ["#FFFFFF", "#C81E28", "#1478E6"])
        # The two reds are one colour with their pixels added (350 of 1000).
        self.assertAlmostEqual(ranked[1]["share"], 0.35, places=3)

    def test_tiny_shares_are_dropped_but_the_first_colour_always_stays(self) -> None:
        ranked = capture.rank_palette([("#FFFFFF", 995), ("#000000", 5)], 6)
        self.assertEqual([one["hex"] for one in ranked], ["#FFFFFF"])
        self.assertEqual(capture.rank_palette([("#336699", 3)], 6, floor=2), [{"hex": "#336699", "share": 1.0}])

    def test_the_palette_is_capped_at_the_asked_size(self) -> None:
        entries = [
            (f"#{value:02X}{value:02X}{value:02X}", 100 - index) for index, value in enumerate(range(0, 256, 40))
        ]
        self.assertEqual(len(capture.rank_palette(entries, 3)), 3)

    def test_an_empty_histogram_is_an_empty_palette(self) -> None:
        self.assertEqual(capture.rank_palette([], 6), [])

    def test_the_size_is_the_preference_inside_its_bounds(self) -> None:
        self.assertEqual(capture.palette_size({}), 6)
        self.assertEqual(capture.palette_size({"capturePaletteSize": "8"}), 8)
        self.assertEqual(capture.palette_size({"capturePaletteSize": "99"}), 10)
        self.assertEqual(capture.palette_size({"capturePaletteSize": "1"}), 3)
        self.assertEqual(capture.palette_size({"capturePaletteSize": "many"}), 6)

    def read(self, histogram: str | None, size: int = 6):
        calls: list[list[str]] = []

        def run(argv: list[str]) -> str | None:
            calls.append(argv)
            if "histogram:info:" in argv:
                return histogram
            Path(argv[-1]).write_bytes(b"png")
            return ""

        with tempfile.TemporaryDirectory() as tmp:
            result = capture.palette({"x": 0, "y": 0, "w": 400, "h": 300}, self.flat, size, Path(tmp), run=run)
        return result, calls

    def test_the_area_is_shrunk_quantized_without_dithering_and_counted_locally(self) -> None:
        result, calls = self.read(self.histogram)
        command = calls[-1]
        self.assertEqual(command[0], "magick")
        self.assertTrue(command[1].endswith("/capture/palette.png"))
        for word in ("-scale", "-dither", "None", "-colors", "-format", "%c"):
            self.assertIn(word, command)
        self.assertEqual([one["hex"] for one in result["colors"]], ["#FFFFFF", "#C81E28", "#1478E6"])

    def test_a_failing_magick_is_an_error(self) -> None:
        self.assertEqual(self.read(None)[0], {"error": "magick failed"})

    def test_an_unreadable_histogram_is_an_error(self) -> None:
        self.assertEqual(self.read("garbage")[0], {"error": "no colours"})

    def test_a_bad_selection_is_an_error(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = capture.palette({"x": 0, "y": 0, "w": 0, "h": 5}, self.flat, 6, Path(tmp), run=lambda argv: "")
        self.assertEqual(result, {"error": "empty selection"})


class ComposeNameTests(unittest.TestCase):
    def test_the_composition_can_go_to_a_named_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:

            def run(argv: list[str]) -> str:
                Path(argv[-1]).write_bytes(b"png")
                return ""

            result = capture.compose({"x": 0, "y": 0, "w": 10, "h": 10}, CropTests.flat, Path(tmp), run, name="detect")
            self.assertTrue(result["image"].endswith("/capture/detect.png"))


class EntryTests(unittest.TestCase):
    def test_an_unknown_action_is_refused(self) -> None:
        self.assertEqual(capture.main([]), 2)

    def test_the_old_shot_command_is_gone(self) -> None:
        # Nothing calls it: PRINT opens the overlay through the bar, and the
        # panel does too.
        self.assertFalse(hasattr(capture, "shot"))

    def test_grab_needs_a_geometry(self) -> None:
        self.assertEqual(capture.main(["grab"]), 2)

    def test_ocr_and_ask_need_a_geometry(self) -> None:
        self.assertEqual(capture.main(["ocr"]), 2)
        self.assertEqual(capture.main(["ask", "--text", "x"]), 2)

    def test_every_area_command_needs_a_geometry(self) -> None:
        for command in ("detect", "qr", "translate", "pin", "palette"):
            with self.subTest(command=command):
                self.assertEqual(capture.main([command]), 2)

    def test_open_needs_a_link(self) -> None:
        self.assertEqual(capture.main(["open"]), 2)

    def test_ask_is_refused_while_ai_mode_is_off(self) -> None:
        with (
            mock.patch.object(capture, "_preferences", return_value={"captureAi": "false"}),
            contextlib.redirect_stdout(io.StringIO()) as out,
        ):
            self.assertEqual(capture.main(["ask", "--geometry", "0,0,10,10", "--text", "x"]), 1)
        self.assertEqual(json.loads(out.getvalue()), {"error": "ai mode is off"})


if __name__ == "__main__":
    unittest.main()
