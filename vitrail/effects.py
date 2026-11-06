"""Wallpaper effects: an ImageMagick recipe over the selected picture.

Every recipe is an argument list handed straight to `magick` — never a shell
string and never `eval`. The result is cached by the picture's content and the
effect name, so a rotation back to the same art costs nothing. Only pictures
take an effect: a video is decoded by its own engine, so it is shown as it is
(with a notice).
"""

from __future__ import annotations

import hashlib
import re
import subprocess
from pathlib import Path
from typing import Callable

# The eighteen effects, in the order the settings window lists them.
RECIPES: dict[str, list[str]] = {
    "none": [],
    "b&w": ["-colorspace", "Gray"],
    "blur": ["-blur", "0x8"],
    "charcoal": ["-charcoal", "2"],
    "edge": ["-edge", "1"],
    "emboss": ["-emboss", "0x1"],
    "raise": ["-raise", "10x10"],
    "sunken": ["-raise", "-10x-10"],
    "negate": ["-negate"],
    "paint": ["-paint", "4"],
    "posterize": ["-posterize", "4"],
    "polaroid": ["-polaroid", "0"],
    "sepia": ["-sepia-tone", "80%"],
    "solarize": ["-solarize", "50%"],
    "sharpen": ["-sharpen", "0x1"],
    "vignette": ["-vignette", "0x20"],
    "vignette-black": ["-background", "black", "-vignette", "0x20"],
    # Cut to its centre and grow it back: the picture keeps its size.
    "zoomed": ["-gravity", "center", "-crop", "80%x80%+0+0", "+repage", "-resize", "125%"],
}
IMAGE_SUFFIXES = (".png", ".jpg", ".jpeg", ".webp", ".bmp")
FOLDER = "effects"
# The picture the bar draws when an effect is on (a stable name: the bar cannot
# hash). One per output, for the per-monitor wallpapers.
SHOWN = "wallpaper-effect.png"
SAFE = re.compile(r"[^A-Za-z0-9._-]")

Run = Callable[..., subprocess.CompletedProcess]
Say = Callable[[str], None]


def _no_say(_line: str) -> None:
    pass


def run_magick(argv: list[str]) -> subprocess.CompletedProcess:
    """Runs `magick`; the caller sees a missing program as FileNotFoundError."""
    return subprocess.run(argv, check=True, capture_output=True, text=True)


def is_image(path: str | Path) -> bool:
    return Path(path).suffix.lower() in IMAGE_SUFFIXES


def apply(
    source: str | Path,
    name: str,
    target: str | Path,
    run: Run = run_magick,
) -> Path:
    """Writes the picture with `name` applied at `target`.

    `none` and an unknown name give the original, untouched.
    """
    source = Path(source)
    if name not in RECIPES or name == "none":
        return source
    target = Path(target)
    target.parent.mkdir(parents=True, exist_ok=True)
    run(["magick", str(source), *RECIPES[name], str(target)])
    return target


def cached(source: str | Path, name: str, cache: Path) -> Path:
    """Where the derived picture for this content and effect lives."""
    digest = hashlib.sha256(Path(source).read_bytes()).hexdigest()[:16]
    return cache / FOLDER / f"{digest}-{name}.png"


def derive(
    source: str | Path,
    name: str,
    cache: Path,
    run: Run = run_magick,
    say: Say = _no_say,
) -> Path:
    """The picture with `name` applied, built once and then taken from the
    cache. A file that is not a picture, `none` or an unknown name is returned
    as it is; another kind is skipped with a notice."""
    source = Path(source)
    if name in ("", "none") or name not in RECIPES:
        return source
    if not is_image(source):
        say(f"Effects are for images only: {name} skipped for {source.name}")
        return source
    target = cached(source, name, cache)
    if not target.exists():
        apply(source, name, target, run=run)
    return target


def shown(cache: Path, output: str = "") -> Path:
    """The stable copy the bar draws: one for the whole screen, or one per
    output for a per-monitor effect."""
    if not output:
        return cache / SHOWN
    return cache / f"{SHOWN[:-4]}-{SAFE.sub('_', output)}.png"
