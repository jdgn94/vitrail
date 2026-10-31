"""Wallpaper media: verification, resizing and the keep-or-not decisions."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

from vitrail import media


def done(stdout: str = "", stderr: str = "", code: int = 0):
    return SimpleNamespace(returncode=code, stdout=stdout, stderr=stderr)


class DecisionTests(unittest.TestCase):
    def test_fit_only_shrinks_and_keeps_the_aspect(self) -> None:
        self.assertEqual(media.fit(1920, 1080, 3840, 2160), (1920, 1080))
        self.assertEqual(media.fit(3840, 2160, 3840, 2160), (3840, 2160))
        self.assertEqual(media.fit(7680, 4320, 3840, 2160), (3840, 2160))
        self.assertEqual(media.fit(5376, 3072, 3840, 2160), (3780, 2160))
        self.assertEqual(media.fit(2160, 3840, 3840, 2160), (1216, 2160))

    def test_fit_gives_even_sizes(self) -> None:
        width, height = media.fit(4001, 2251, 3840, 2160)
        self.assertEqual((width % 2, height % 2), (0, 0))

    def test_images_over_the_long_edge_need_a_resize(self) -> None:
        self.assertTrue(media.needs_resize(5376, 3072))
        self.assertTrue(media.needs_resize(3000, 4000))
        self.assertFalse(media.needs_resize(3840, 2160))

    def test_webp_wins_only_when_smaller_and_alike(self) -> None:
        table = [
            # original, plain, webp, ssim, resized -> choice
            (1000, 900, 500, 0.99, False, "webp"),
            (1000, 900, 500, 0.97, False, "plain"),
            (1000, 900, 950, 0.99, False, "plain"),
            (1000, 1100, 1050, 0.99, False, "original"),
            (1000, 1100, 500, 0.97, False, "original"),
            (1000, 1100, 1200, 0.99, True, "plain"),
            (1000, None, 500, 0.99, False, "webp"),
            (1000, None, 500, 0.90, False, "original"),
        ]
        for original, plain, webp, ssim, resized, expected in table:
            self.assertEqual(media.choose_image(original, plain, webp, ssim, resized), expected, (original, plain, webp, ssim))

    def test_an_encode_is_kept_only_when_smaller_and_alike(self) -> None:
        self.assertTrue(media.keep_encode(1000, 500, 96.0))
        self.assertTrue(media.keep_encode(1000, 500, 95.0))
        self.assertFalse(media.keep_encode(1000, 500, 94.9))
        self.assertFalse(media.keep_encode(1000, 1000, 99.0))
        self.assertFalse(media.keep_encode(1000, 500, None))

    def test_scores_are_read_from_the_tools_output(self) -> None:
        self.assertAlmostEqual(media.parse_ssim("SSIM Y:0.99 (21.5) U:0.9 (1) V:0.9 (1) All:0.994589 (22.667134)"), 0.994589)
        self.assertIsNone(media.parse_ssim("nothing"))
        self.assertAlmostEqual(media.parse_vmaf("[Parsed_libvmaf_4 @ 0x7f] VMAF score: 97.457866"), 97.457866)
        self.assertIsNone(media.parse_vmaf(""))

    def test_progress_is_reported_in_steps(self) -> None:
        self.assertEqual(media.progress_percent("out_time_us=5000000", 20.0), 25)
        self.assertIsNone(media.progress_percent("frame=12", 20.0))
        self.assertEqual(media.progress_percent("out_time_us=99000000", 20.0), 100)

    def test_probe_reads_the_streams(self) -> None:
        text = json.dumps({
            "streams": [
                {"codec_type": "video", "codec_name": "h264", "width": 3840, "height": 2160, "r_frame_rate": "30000/1001"},
                {"codec_type": "audio", "codec_name": "aac"},
            ],
            "format": {"duration": "17.7"},
        })
        info = media.parse_probe(text)
        self.assertEqual((info.codec, info.width, info.height, info.has_audio), ("h264", 3840, 2160, True))
        self.assertAlmostEqual(info.fps, 29.97, places=2)
        self.assertAlmostEqual(info.duration, 17.7)

    def test_a_file_without_video_is_rejected(self) -> None:
        with self.assertRaises(media.MediaError):
            media.parse_probe(json.dumps({"streams": [{"codec_type": "audio"}], "format": {}}))
        with self.assertRaises(media.MediaError):
            media.parse_probe("not json")

    def test_the_encode_drops_audio_caps_the_size_and_uses_av1(self) -> None:
        info = media.VideoInfo("h264", 7680, 4320, 30.0, 10.0, True)
        command = media.encode_command(Path("in.mp4"), Path("out.webm"), info)
        self.assertIn("-an", command)
        self.assertEqual(command[command.index("-c:v") + 1], "libsvtav1")
        self.assertEqual(command[command.index("-crf") + 1], str(media.CRF))
        self.assertEqual(command[command.index("-pix_fmt") + 1], "yuv420p10le")
        self.assertEqual(command[command.index("-g") + 1], str(round(30 * media.KEYINT_SECONDS)))
        self.assertIn("scale=3840:2160", " ".join(command))
        self.assertEqual(command[-1], "out.webm")


class FakeTools:
    """Stands in for magick / ffmpeg / ffprobe: writes outputs of set sizes."""

    def __init__(self, sizes: dict[str, int], ssim: float = 0.995, vmaf: float = 97.0,
                 probe: dict | None = None, broken: bool = False) -> None:
        self.sizes, self.ssim, self.vmaf, self.broken = sizes, ssim, vmaf, broken
        self.probe = probe or {}
        self.commands: list[list[str]] = []

    def write(self, target: str) -> None:
        path = Path(target)
        path.write_bytes(b"x" * self.sizes.get(path.suffix, 100))

    def run(self, command, **_kwargs):
        self.commands.append(list(command))
        tool = command[0]
        if self.broken:
            return done(stderr="corrupt", code=1)
        if tool == "ffprobe":
            return done(json.dumps(self.probe))
        if tool == "magick" and command[1] == "identify":
            return done("3000 2000")
        if tool == "magick":
            self.write(command[-1])
            return done()
        if "ssim" in " ".join(command):
            return done(stderr=f"SSIM All:{self.ssim} (20.0)")
        if "libvmaf" in " ".join(command):
            return done(stderr=f"VMAF score: {self.vmaf}")
        if command[-1] == "-":
            return done()
        self.write(command[-1])
        return done()

    def stream(self, command, on_line):
        self.commands.append(list(command))
        on_line("out_time_us=10000000")
        self.write(command[-1])
        return 0


class OptimizeImageTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.work = self.root / "work"
        self.work.mkdir()
        self.source = self.root / "pic.png"
        self.source.write_bytes(b"x" * 1000)

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def optimize(self, tools: FakeTools, source: Path | None = None) -> media.Result:
        return media.optimize(source or self.source, "image", self.work, run=tools.run, stream=tools.stream)

    def test_a_close_smaller_webp_replaces_the_png(self) -> None:
        result = self.optimize(FakeTools({".png": 900, ".webp": 400}))
        self.assertEqual(result.path.suffix, ".webp")
        self.assertEqual(result.report.decision, "webp")
        self.assertEqual((result.report.before, result.report.after), (1000, 400))

    def test_a_lossy_looking_webp_is_refused(self) -> None:
        result = self.optimize(FakeTools({".png": 900, ".webp": 400}, ssim=0.95))
        self.assertEqual(result.path.suffix, ".png")
        self.assertEqual(result.report.decision, "plain")

    def test_nothing_changes_when_nothing_gains(self) -> None:
        result = self.optimize(FakeTools({".png": 1200, ".webp": 1300}))
        self.assertEqual(result.path, self.source)
        self.assertEqual(result.report.decision, "original")

    def test_a_broken_image_is_rejected(self) -> None:
        result = self.optimize(FakeTools({}, broken=True))
        self.assertIsNone(result.path)
        self.assertEqual(result.report.decision, "rejected")
        self.assertIn("pic.png", result.report.line())

    def test_metadata_is_stripped_and_the_edge_capped(self) -> None:
        tools = FakeTools({".png": 900, ".webp": 400})
        self.optimize(tools)
        reference = next(c for c in tools.commands if c[0] == "magick" and c[-1].endswith("ref.png"))
        self.assertIn("-strip", reference)
        self.assertIn("-auto-orient", reference)
        self.assertIn("3840x3840>", reference)


class OptimizeVideoTests(unittest.TestCase):
    PROBE = {
        "streams": [
            {"codec_type": "video", "codec_name": "h264", "width": 3840, "height": 2160, "r_frame_rate": "30/1"},
            {"codec_type": "audio", "codec_name": "aac"},
        ],
        "format": {"duration": "10"},
    }

    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.work = self.root / "work"
        self.work.mkdir()
        self.source = self.root / "clip.mp4"
        self.source.write_bytes(b"x" * 1000)

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def optimize(self, tools: FakeTools, probe: dict | None = None) -> media.Result:
        tools.probe = probe or self.PROBE
        return media.optimize(self.source, "video", self.work, run=tools.run, stream=tools.stream)

    def test_a_good_smaller_av1_is_kept(self) -> None:
        result = self.optimize(FakeTools({".webm": 300}, vmaf=96.0))
        self.assertEqual(result.path.suffix, ".webm")
        self.assertEqual(result.report.decision, "av1")
        self.assertIn("vmaf 96.0", result.report.line())

    def test_a_poor_encode_falls_back_to_a_copy_without_audio(self) -> None:
        tools = FakeTools({".webm": 300, ".mp4": 990}, vmaf=90.0)
        result = self.optimize(tools)
        self.assertEqual(result.report.decision, "copy")
        self.assertEqual(result.path.suffix, ".mp4")
        copy = tools.commands[-1]
        self.assertIn("-an", copy)
        self.assertEqual(copy[copy.index("-c:v") + 1], "copy")

    def test_a_bigger_encode_skips_the_vmaf_pass(self) -> None:
        tools = FakeTools({".webm": 1500, ".mp4": 990})
        self.optimize(tools)
        self.assertFalse(any("libvmaf" in " ".join(command) for command in tools.commands))

    def test_a_silent_clip_that_does_not_gain_stays_as_it_is(self) -> None:
        silent = {**self.PROBE, "streams": self.PROBE["streams"][:1]}
        result = self.optimize(FakeTools({".webm": 1500}), silent)
        self.assertEqual(result.path, self.source)
        self.assertEqual(result.report.decision, "original")

    def test_a_broken_clip_is_rejected(self) -> None:
        result = self.optimize(FakeTools({}, broken=True))
        self.assertIsNone(result.path)
        self.assertEqual(result.report.decision, "rejected")

    def test_progress_lines_are_said(self) -> None:
        said: list[str] = []
        tools = FakeTools({".webm": 300})
        tools.probe = self.PROBE
        media.optimize(self.source, "video", self.work, run=tools.run, stream=tools.stream, say=said.append)
        self.assertTrue(any("%" in line for line in said))


if __name__ == "__main__":
    unittest.main()
