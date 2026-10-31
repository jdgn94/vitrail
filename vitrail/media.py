"""Wallpaper media on its way into the library: verify, shrink, keep only wins.

Every decision is a small pure function; magick / ffmpeg / ffprobe run through
an injectable `run` (like colors.generate) so the flow is tested without them.

- Images: the long edge is capped, metadata stripped, and WebP replaces the
  original only when smaller and visually alike (SSIM). Qt reads WebP through
  its imageformats plugin and matugen extracts from it, so it is safe here.
- Videos: audio is always dropped, the size capped, and an AV1 re-encode
  (hardware decodable) replaces the original only when smaller and
  VMAF-alike; otherwise the video stream is copied without audio.
"""

from __future__ import annotations

import json
import re
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

MAX_EDGE = 3840
MAX_WIDTH, MAX_HEIGHT = 3840, 2160
WEBP_QUALITY = 90
JPEG_QUALITY = 92
MIN_SSIM = 0.98
MIN_VMAF = 95.0
CRF = 30
PRESET = 6
KEYINT_SECONDS = 4
# VMAF is trained on 1080p and slow on 4K: both sides are scaled and sampled.
VMAF_WIDTH = 1920
VMAF_SUBSAMPLE = 5
PROGRESS_STEP = 10

Run = Callable[..., subprocess.CompletedProcess]


class MediaError(Exception):
    """The file does not decode, or a tool failed."""


@dataclass
class VideoInfo:
    codec: str
    width: int
    height: int
    fps: float
    duration: float
    has_audio: bool


@dataclass
class Report:
    name: str
    kind: str
    before: int
    after: int
    codec: str
    size: str
    decision: str
    score: str = ""
    note: str = ""

    def line(self) -> str:
        if self.decision == "rejected":
            return f"  {self.name}: rejected ({self.note})"
        parts = [
            f"{self.name}: {_mb(self.before)} -> {_mb(self.after)}",
            f"{self.codec} {self.size}",
            self.score,
            self.decision,
        ]
        return "  " + ", ".join(part for part in parts if part)


@dataclass
class Result:
    path: Path | None
    report: Report


def _mb(size: int) -> str:
    return f"{size / (1024 * 1024):.2f} MB"


def fit(width: int, height: int, max_width: int, max_height: int) -> tuple[int, int]:
    """The size inside the cap, keeping the aspect, never upscaling, even."""
    scale = min(1.0, max_width / width, max_height / height)
    if scale == 1.0:
        return width, height
    return 2 * round(width * scale / 2), 2 * round(height * scale / 2)


def needs_resize(width: int, height: int) -> bool:
    return max(width, height) > MAX_EDGE


def choose_image(original: int, plain: int | None, webp: int | None,
                 ssim: float | None, resized: bool) -> str:
    """"webp", "plain" (same format, resized / stripped) or "original"."""
    # The original only stands in when nothing forces a resize.
    sizes = [size for size in (plain, None if resized else original) if size is not None]
    baseline = min(sizes) if sizes else original
    if webp is not None and ssim is not None and ssim >= MIN_SSIM and webp < baseline:
        return "webp"
    if plain is not None and (resized or plain < original):
        return "plain"
    return "original"


def keep_encode(before: int, after: int, vmaf: float | None) -> bool:
    return after < before and vmaf is not None and vmaf >= MIN_VMAF


def parse_ssim(text: str) -> float | None:
    match = re.search(r"All:([\d.]+)", text)
    return float(match.group(1)) if match else None


def parse_vmaf(text: str) -> float | None:
    match = re.search(r"VMAF score:\s*([\d.]+)", text)
    return float(match.group(1)) if match else None


def progress_percent(line: str, duration: float) -> int | None:
    match = re.match(r"out_time_us=(\d+)", line)
    if not match or duration <= 0:
        return None
    return min(100, int(int(match.group(1)) / 1_000_000 / duration * 100))


def parse_probe(text: str) -> VideoInfo:
    try:
        data = json.loads(text)
    except json.JSONDecodeError as error:
        raise MediaError("not a media file") from error
    streams = data.get("streams", [])
    video = next((s for s in streams if s.get("codec_type") == "video"), None)
    if not video or not video.get("width") or not video.get("height"):
        raise MediaError("no video stream")
    numerator, _, denominator = str(video.get("r_frame_rate", "30/1")).partition("/")
    fps = float(numerator) / float(denominator or 1) if float(denominator or 1) else 30.0
    duration = float(video.get("duration") or data.get("format", {}).get("duration") or 0)
    return VideoInfo(
        video.get("codec_name", "?"), int(video["width"]), int(video["height"]),
        fps or 30.0, duration, any(s.get("codec_type") == "audio" for s in streams),
    )


def encode_command(source: Path, target: Path, info: VideoInfo) -> list[str]:
    width, height = fit(info.width, info.height, MAX_WIDTH, MAX_HEIGHT)
    return [
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-nostats", "-progress", "pipe:1", "-y",
        "-i", str(source), "-map", "0:v:0", "-an", "-sn", "-dn",
        "-map_metadata", "-1", "-map_chapters", "-1",
        "-vf", f"scale={width}:{height}:flags=lanczos",
        "-c:v", "libsvtav1", "-crf", str(CRF), "-preset", str(PRESET),
        "-pix_fmt", "yuv420p10le", "-g", str(round(info.fps * KEYINT_SECONDS)),
        str(target),
    ]


def stream_lines(command: list[str], on_line: Callable[[str], None]) -> int:
    """Runs a command, handing each line of its output to `on_line`."""
    with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True) as process:
        for line in process.stdout or []:
            on_line(line.strip())
    return process.returncode


def _run(run: Run, command: list[str]) -> subprocess.CompletedProcess:
    try:
        return run(command, capture_output=True, text=True)
    except OSError as error:
        raise MediaError(f"{command[0]} is missing: {error}") from error


def _ssim(run: Run, reference: Path, candidate: Path) -> float | None:
    result = _run(run, ["ffmpeg", "-hide_banner", "-i", str(reference), "-i", str(candidate),
                        "-lavfi", "ssim", "-f", "null", "-"])
    return parse_ssim(result.stderr or "")


def _optimize_image(source: Path, work: Path, run: Run) -> Result:
    original = source.stat().st_size
    probe = _run(run, ["magick", "identify", "-regard-warnings", "-format", "%w %h", f"{source}[0]"])
    if probe.returncode != 0:
        raise MediaError("the image does not decode")
    width, height = (int(value) for value in probe.stdout.split()[:2])
    resized = needs_resize(width, height)

    reference = work / "ref.png"
    made = _run(run, ["magick", f"{source}[0]", "-regard-warnings", "-auto-orient",
                      "-resize", f"{MAX_EDGE}x{MAX_EDGE}>", "-strip", str(reference)])
    if made.returncode != 0:
        raise MediaError("the image does not decode")
    out_width, out_height = fit(width, height, MAX_EDGE, MAX_EDGE) if resized else (width, height)

    suffix = source.suffix.lower()
    plain_suffix = suffix if suffix in (".png", ".jpg", ".jpeg") else (".png" if suffix != ".webp" else None)
    plain = None
    if plain_suffix:
        plain = work / f"plain{plain_suffix}"
        options = ["-quality", str(JPEG_QUALITY)] if plain_suffix != ".png" else ["-define", "png:compression-level=9"]
        _run(run, ["magick", str(reference), *options, str(plain)])
    webp = work / "out.webp"
    _run(run, ["magick", str(reference), "-quality", str(WEBP_QUALITY), "-define", "webp:method=6", str(webp)])

    plain_size = plain.stat().st_size if plain and plain.exists() else None
    webp_size = webp.stat().st_size if webp.exists() else None
    ssim = _ssim(run, reference, webp) if webp_size is not None else None
    choice = choose_image(original, plain_size, webp_size, ssim, resized)
    path, after, codec = {
        "webp": (webp, webp_size, "webp"),
        "plain": (plain, plain_size, (plain_suffix or "").lstrip(".")),
        "original": (source, original, suffix.lstrip(".")),
    }[choice]
    score = f"ssim {ssim:.3f}" if ssim is not None else ""
    size = f"{out_width}x{out_height}" if choice != "original" else f"{width}x{height}"
    return Result(path, Report(source.name, "image", original, after, codec, size, choice, score))


def _optimize_video(source: Path, work: Path, run: Run, stream: Callable, say: Callable[[str], None]) -> Result:
    original = source.stat().st_size
    probed = _run(run, ["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(source)])
    if probed.returncode != 0:
        raise MediaError("the video does not decode")
    info = parse_probe(probed.stdout)
    decoded = _run(run, ["ffmpeg", "-v", "error", "-t", "1", "-i", str(source), "-map", "0:v:0", "-f", "null", "-"])
    if decoded.returncode != 0 or (decoded.stderr or "").strip():
        raise MediaError("the video does not decode")

    target = work / "out.webm"
    say(f"  {source.name}: encoding AV1 ({info.width}x{info.height}, {info.duration:.0f} s)")
    last = [-PROGRESS_STEP]

    def on_line(line: str) -> None:
        percent = progress_percent(line, info.duration)
        if percent is not None and percent >= last[0] + PROGRESS_STEP:
            last[0] = percent - percent % PROGRESS_STEP
            say(f"    {source.name}: {percent}%")

    code = stream(encode_command(source, target, info), on_line)
    encoded = target.stat().st_size if code == 0 and target.exists() else None
    width, height = fit(info.width, info.height, MAX_WIDTH, MAX_HEIGHT)
    vmaf = None
    if encoded is not None and encoded < original:
        say(f"    {source.name}: measuring VMAF")
        filters = (
            f"[0:v]scale={VMAF_WIDTH}:-2:flags=bicubic,setpts=PTS-STARTPTS[d];"
            f"[1:v]scale={VMAF_WIDTH}:-2:flags=bicubic,setpts=PTS-STARTPTS[r];"
            f"[d][r]libvmaf=n_subsample={VMAF_SUBSAMPLE}:n_threads=16"
        )
        scored = _run(run, ["ffmpeg", "-hide_banner", "-i", str(target), "-i", str(source),
                            "-lavfi", filters, "-f", "null", "-"])
        vmaf = parse_vmaf(scored.stderr or "")
    score = f"vmaf {vmaf:.1f}" if vmaf is not None else ""
    if encoded is not None and keep_encode(original, encoded, vmaf):
        return Result(target, Report(source.name, "video", original, encoded, "av1", f"{width}x{height}", "av1", score))

    if info.has_audio:
        copy = work / f"copy{source.suffix.lower()}"
        copied = _run(run, ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(source),
                            "-map", "0:v:0", "-an", "-c:v", "copy", "-map_metadata", "-1", str(copy)])
        if copied.returncode != 0 or not copy.exists():
            raise MediaError("could not remove the audio")
        return Result(copy, Report(source.name, "video", original, copy.stat().st_size, info.codec,
                                   f"{info.width}x{info.height}", "copy", score, "audio removed"))
    return Result(source, Report(source.name, "video", original, original, info.codec,
                                 f"{info.width}x{info.height}", "original", score))


def optimize(source: Path, kind: str, work: Path, run: Run = subprocess.run,
             stream: Callable = stream_lines, say: Callable[[str], None] = lambda _line: None) -> Result:
    """Verifies `source` and returns the file to keep (in `work`, or the source
    itself when nothing gains) with its report; path None when it is broken."""
    try:
        if kind == "video":
            return _optimize_video(source, work, run, stream, say)
        return _optimize_image(source, work, run)
    except MediaError as error:
        size = source.stat().st_size if source.exists() else 0
        return Result(None, Report(source.name, kind, size, 0, "", "", "rejected", note=str(error)))
