"""Wallpaper effects: an ImageMagick recipe over the selected picture.

Every recipe is an argument list handed straight to `magick` — never a shell
string and never `eval`. Two styles cannot be an argument list: a dot grid and
a character grid are drawn, so `STYLED` holds their renderers instead. The
result is cached by the picture's content, the effect name and the mode and
detail it was drawn with, so a rotation back to the same art costs nothing.
Only pictures take an effect: a video is decoded by its own engine, so it is
shown as it is (with a notice).

Two of them follow the light/dark mode: charcoal turns its paper over, and the
drawn styles paint their ground on the theme's canvas. `NAMES` is the order the
settings window lists; the settings window cannot run `magick`, so `publish()`
leaves one small copy per effect under `previews/<slot>/`.
"""

from __future__ import annotations

import hashlib
import math
import re
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Callable
from xml.sax.saxutils import escape

# The plain effects, in the order the settings window lists them.
RECIPES: dict[str, list[str]] = {
    "none": [],
    "b&w": ["-colorspace", "Gray"],
    "blur": ["-blur", "0x8"],
    "charcoal": ["-charcoal", "2"],
    "edge": ["-edge", "1"],
    "emboss": ["-emboss", "0x1"],
    "raise": ["-raise", "10x10"],
    # ImageMagick 7 refuses a negative bevel (`-raise -10x-10`), so the inverse
    # bevel comes from raising the picture upside down.
    "sunken": ["-rotate", "180", "-raise", "10x10", "-rotate", "180"],
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
# The effects whose picture changes with the light/dark mode.
MODED = ("charcoal", "dots", "pointillism", "ascii")
# The effects whose picture changes with the detail setting.
DETAILED = ("dots", "pointillism", "ascii")
DETAILS = ("fine", "normal", "bold")
# The canvas the drawn styles sit on: the theme's ground, cream or black.
CANVAS = {"light": "#f5efe4", "dark": "#0b0b0c"}
# A dot is this fraction of the picture's width; more dots, less detail.
DOT_CELL = {"fine": 10 / 1920, "normal": 16 / 1920, "bold": 24 / 1920}
# Pointillism packs many more, much smaller dabs so the picture stays sharp.
POINT_CELL = {"fine": 6 / 1920, "normal": 9 / 1920, "bold": 13 / 1920}
# Pure pigments, not a grey blend: the dabs carry a little more colour.
POINT_SATURATION = 115
# How many characters span the picture, so the size stays the same on any screen.
ASCII_COLUMNS = {"fine": 260, "normal": 180, "bold": 120}
# A preview is a tile a tenth of the screen wide: at the picture's own scale a
# dot would be a quarter of a pixel and a character a smudge. The thumbnail
# pulls back to this many dots or characters across, so the picker shows the
# style instead of noise.
PREVIEW_ACROSS = 14
# Bumped whenever an effect is added or a drawn style changes: the stamp names
# it, so the next apply rewrites the copies the settings window has on disk.
VERSION = 4
# Dark to light, the glyph for each cell's brightness.
RAMP = " .:-=+*#%@"

IMAGE_SUFFIXES = (".png", ".jpg", ".jpeg", ".webp", ".bmp")
FOLDER = "effects"
# The picture the bar draws when an effect is on (a stable name: the bar cannot
# hash). One per output, for the per-monitor wallpapers.
SHOWN = "wallpaper-effect.png"
# Small copies for the settings window's grid, one folder per output.
PREVIEWS = "previews"
PREVIEW_WIDTH = 320
SAFE = re.compile(r"[^A-Za-z0-9._-]")

Run = Callable[..., subprocess.CompletedProcess]
Say = Callable[[str], None]


def _no_say(_line: str) -> None:
    pass


def run_magick(argv: list[str], **_: object) -> subprocess.CompletedProcess:
    """Runs `magick`; the caller sees a missing program as FileNotFoundError."""
    return subprocess.run(argv, check=True, capture_output=True, text=True)


def _read(argv: list[str], run: Run) -> str:
    """Runs a command whose answer is its stdout. The wallpaper's own run
    leaves stdout to the terminal, so it has to be asked for here."""
    return run(argv, capture_output=True, text=True).stdout or ""


def is_image(path: str | Path) -> bool:
    return Path(path).suffix.lower() in IMAGE_SUFFIXES


def detail_of(value: str | None) -> str:
    """A stored detail; anything the renderers do not know reads as normal."""
    return value if value in DETAILS else "normal"


def mode_of(value: str | None) -> str:
    """A stored mode; only "dark" is dark."""
    return "dark" if value == "dark" else "light"


def style(name: str, mode: str, detail: str) -> str:
    """The part of a cache name that says how the picture was drawn: only the
    effects that depend on it carry one, so the others keep their files."""
    parts = []
    if name in DETAILED:
        parts.append(detail_of(detail))
    if name in MODED:
        parts.append(mode_of(mode))
    if name in STYLED:
        # A drawn style is our own code: a new version must not read the old
        # picture back from the cache.
        parts.append(f"v{VERSION}")
    return "-" + "-".join(parts) if parts else ""


def _arguments(name: str, mode: str) -> list[str]:
    """The magick arguments for `name`: charcoal turns its paper over in dark."""
    recipe = list(RECIPES.get(name, []))
    if name == "charcoal" and mode_of(mode) == "dark":
        recipe.append("-negate")
    return recipe


def _size(source: Path, run: Run) -> tuple[int, int]:
    """The picture's width and height, as magick reports them."""
    said = _read(["magick", "identify", "-format", "%w %h", str(source)], run)
    try:
        width, height = (int(value) for value in said.split()[:2])
    except ValueError:
        raise OSError(f"cannot read the size of {source}") from None
    return width, height


def _scaled(source: Path, width: int | None, temp: Path, run: Run) -> tuple[Path, int, int]:
    """A copy of `source` no wider than `width`, with its own size when it fits."""
    wide, high = _size(source, run)
    if width is None or width >= wide:
        return source, wide, high
    target = temp / "small.png"
    run(["magick", str(source), "-resize", f"{width}x", str(target)])
    small, height = _size(target, run)
    return target, small, height


def _monospace(run: Run) -> tuple[str, str]:
    """The family and the file fontconfig offers for a monospaced face."""

    def ask(pattern: str) -> str:
        command = ["fc-match", "-f", pattern, "monospace"]
        return _read(command, run).strip()

    return ask("%{family}").split(",")[0] or "monospace", ask("%{file}") or "monospace"


def _advance(font: str, run: Run) -> float:
    """How wide one character is at one point, so a cell fits exactly one."""
    said = _read(["magick", "-font", font, "-pointsize", "100", "label:MMMMMMMMMM", "-format", "%w", "info:"], run)
    try:
        return max(0.1, int(said.strip()) / 10 / 100)
    except ValueError:
        return 0.6


def _dotted(
    source: Path,
    target: Path,
    width: int | None,
    mode: str,
    detail: str,
    run: Run,
    ratios: dict[str, float],
    gap: float,
    saturation: int,
    pure: bool = False,
) -> None:
    """The picture as round dots of its own colours, one per cell, with the
    ground showing in the gaps.

    Every dot is one flat colour and one cell wide: the grid of colours is the
    grid of dots, so nothing is ever split between two dots. `pure` takes that
    colour from one pixel of the cell instead of its average — the painters'
    rule that a dab is a single pigment, never a mixture.
    """
    with tempfile.TemporaryDirectory(dir=target.parent) as folder:
        temp = Path(folder)
        picture, wide, high = _scaled(source, width, temp, run)
        if width is None:
            cell = max(1, round(wide * ratios[detail_of(detail)]))
        else:
            cell = max(1, round(wide / PREVIEW_ACROSS))
        # Whole cells, rounded up: the grid covers the picture, and the crop
        # below takes back the overhang, so a dot never straddles two cells.
        columns, rows = max(1, math.ceil(wide / cell)), max(1, math.ceil(high / cell))
        grid_w, grid_h = columns * cell, rows * cell
        pixels = temp / "pixels.png"
        run(
            [
                "magick",
                str(picture),
                "-sample" if pure else "-resize",
                f"{columns}x{rows}!",
                "-modulate",
                f"100,{saturation},100",
                "-filter",
                "point",
                "-resize",
                f"{grid_w}x{grid_h}!",
                str(pixels),
            ]
        )
        # A dot that stops short of its cell leaves the ground visible.
        middle = cell / 2
        dot = temp / "dot.png"
        run(
            [
                "magick",
                "-size",
                f"{cell}x{cell}",
                "xc:black",
                "-fill",
                "white",
                "-draw",
                f"circle {middle:g},{middle:g} {middle:g},{middle + cell / 2 - gap:g}",
                str(dot),
            ]
        )
        mask = temp / "mask.png"
        run(["magick", "-size", f"{grid_w}x{grid_h}", f"tile:{dot}", str(mask)])
        cut = temp / "cut.png"
        run(
            [
                "magick",
                str(pixels),
                "-alpha",
                "off",
                "(",
                str(mask),
                "-alpha",
                "off",
                ")",
                "-compose",
                "CopyOpacity",
                "-composite",
                str(cut),
            ]
        )
        # The picture keeps its own size: the whole cells overflow by under one.
        run(
            [
                "magick",
                str(cut),
                "-background",
                CANVAS[mode_of(mode)],
                "-flatten",
                "-alpha",
                "off",
                "-gravity",
                "northwest",
                "-crop",
                f"{wide}x{high}+0+0",
                "+repage",
                str(target),
            ]
        )


def _draw_dots(source: Path, target: Path, width: int | None, mode: str, detail: str, run: Run) -> None:
    """Big dabs: the picture as a mosaic of round dots with a wide canvas."""
    _dotted(source, target, width, mode, detail, run, DOT_CELL, gap=1, saturation=100)


def _draw_pointillism(source: Path, target: Path, width: int | None, mode: str, detail: str, run: Run) -> None:
    """Pointillism as the painters did it: many small, close dabs of colour
    that the eye blends, so the picture stays sharp. Each dab is one pigment,
    taken from a single pixel — never an average of its neighbours."""
    _dotted(source, target, width, mode, detail, run, POINT_CELL, gap=0.5, saturation=POINT_SATURATION, pure=True)


def _grid(dump: str, columns: int, rows: int) -> dict[tuple[int, int], tuple[str, int, int, int]]:
    """The characters and colours of an `txt:` dump, one per cell."""
    cells = {}
    for line in dump.splitlines():
        match = re.match(r"(\d+),(\d+): \((\d+),(\d+),(\d+)", line)
        if match is None:
            continue
        x, y, red, green, blue = (int(value) for value in match.groups())
        light = (0.299 * red + 0.587 * green + 0.114 * blue) / 255
        cells[(x, y)] = (RAMP[min(len(RAMP) - 1, int(light * len(RAMP)))], red, green, blue)
    return cells


def _draw_ascii(source: Path, target: Path, width: int | None, mode: str, detail: str, run: Run) -> None:
    """The picture drawn with coloured characters on the theme's ground."""
    with tempfile.TemporaryDirectory(dir=target.parent) as folder:
        temp = Path(folder)
        picture, wide, high = _scaled(source, width, temp, run)
        if width is None:
            columns = max(1, round(wide / 1920 * ASCII_COLUMNS[detail_of(detail)]))
        else:
            columns = PREVIEW_ACROSS
        cell = wide / columns
        family, font = _monospace(run)
        points = cell / _advance(font, run)
        rows = max(1, round(high / (points * 1.15)))
        dump = _read(
            ["magick", str(picture), "-resize", f"{columns}x{rows}!", "-colorspace", "sRGB", "-depth", "8", "txt:-"],
            run,
        )
        cells = _grid(dump, columns, rows)
        svg = temp / "grid.svg"
        svg.write_text(_svg(cells, columns, rows, wide, high, family, points, CANVAS[mode_of(mode)]), encoding="utf-8")
        run(["magick", str(svg), str(target)])


def _svg(
    cells: dict[tuple[int, int], tuple[str, int, int, int]],
    columns: int,
    rows: int,
    width: int,
    height: int,
    family: str,
    points: float,
    ground: str,
) -> str:
    """The character grid as an SVG magick can rasterise: one text row each."""
    step = height / rows
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        f'<rect width="{width}" height="{height}" fill="{ground}"/>',
        f'<g font-family="{family}" font-size="{points:.2f}" xml:space="preserve">',
    ]
    for y in range(rows):
        spans = []
        for x in range(columns):
            char, red, green, blue = cells.get((x, y), (" ", 0, 0, 0))
            if char == " ":
                spans.append(" ")
            else:
                spans.append(f'<tspan fill="#{red:02x}{green:02x}{blue:02x}">{escape(char)}</tspan>')
        parts.append(f'<text x="0" y="{(y + 0.82) * step:.1f}">{"".join(spans)}</text>')
    parts.append("</g></svg>")
    return "".join(parts)


# The two styles that are drawn, not filtered: a dot grid and a character grid.
STYLED: dict[str, Callable[[Path, Path, int | None, str, str, Run], None]] = {
    "dots": _draw_dots,
    "pointillism": _draw_pointillism,
    "ascii": _draw_ascii,
}
# Every effect, in the order the settings window lists them.
NAMES = (
    "none",
    "ascii",
    "b&w",
    "blur",
    "charcoal",
    "dots",
    "edge",
    "emboss",
    "raise",
    "sunken",
    "negate",
    "paint",
    "pointillism",
    "posterize",
    "polaroid",
    "sepia",
    "solarize",
    "sharpen",
    "vignette",
    "vignette-black",
    "zoomed",
)


def apply(
    source: str | Path,
    name: str,
    target: str | Path,
    run: Run = run_magick,
    mode: str = "light",
    detail: str = "normal",
) -> Path:
    """Writes the picture with `name` applied at `target`.

    `none` and an unknown name give the original, untouched.
    """
    source = Path(source)
    if name not in NAMES or name == "none":
        return source
    target = Path(target)
    target.parent.mkdir(parents=True, exist_ok=True)
    if name in STYLED:
        STYLED[name](source, target, None, mode_of(mode), detail_of(detail), run)
    else:
        run(["magick", str(source), *_arguments(name, mode), str(target)])
    if not target.exists():
        # Never hand back a picture that magick did not write: the caller would
        # point the screen at a missing file.
        raise subprocess.CalledProcessError(1, ["magick", name], "", "magick wrote nothing")
    return target


def cached(source: str | Path, name: str, cache: Path, mode: str = "light", detail: str = "normal") -> Path:
    """Where the derived picture for this content, effect, mode and detail lives."""
    digest = hashlib.sha256(Path(source).read_bytes()).hexdigest()[:16]
    return cache / FOLDER / f"{digest}-{name}{style(name, mode, detail)}.png"


def derive(
    source: str | Path,
    name: str,
    cache: Path,
    run: Run = run_magick,
    say: Say = _no_say,
    mode: str = "light",
    detail: str = "normal",
) -> Path:
    """The picture with `name` applied, built once and then taken from the
    cache. A file that is not a picture, `none` or an unknown name is returned
    as it is; another kind is skipped with a notice."""
    source = Path(source)
    if name in ("", "none") or name not in NAMES:
        return source
    if not is_image(source):
        say(f"Effects are for images only: {name} skipped for {source.name}")
        return source
    target = cached(source, name, cache, mode=mode, detail=detail)
    if not target.exists():
        apply(source, name, target, run=run, mode=mode, detail=detail)
    return target


def shown(cache: Path, output: str = "") -> Path:
    """The stable copy the bar draws: one for the whole screen, or one per
    output for a per-monitor effect."""
    if not output:
        return cache / SHOWN
    return cache / f"{SHOWN[:-4]}-{SAFE.sub('_', output)}.png"


def preview(
    source: str | Path,
    name: str,
    cache: Path,
    run: Run = run_magick,
    mode: str = "light",
    detail: str = "normal",
) -> Path | None:
    """A small copy of `source` with `name` applied, cached by content, effect,
    mode and detail. `none` and an unknown name give the plain picture; anything
    that is not a picture gives nothing."""
    source = Path(source)
    if not source.is_file() or not is_image(source):
        return None
    digest = hashlib.sha256(source.read_bytes()).hexdigest()[:16]
    target = cache / PREVIEWS / "derived" / f"{digest}-{SAFE.sub('_', name)}{style(name, mode, detail)}.png"
    if not target.exists():
        target.parent.mkdir(parents=True, exist_ok=True)
        if name in STYLED:
            STYLED[name](source, target, PREVIEW_WIDTH, mode_of(mode), detail_of(detail), run)
        else:
            run(["magick", str(source), "-resize", f"{PREVIEW_WIDTH}x", *_arguments(name, mode), str(target)])
    return target if target.exists() else None


def publish(
    source: str | Path,
    cache: Path,
    run: Run = run_magick,
    mode: str = "light",
    detail: str = "normal",
) -> bool:
    """Fills `previews/global/` with one plainly named copy per effect, the URLs
    the settings window's effect picker points at. False when the picture cannot
    take an effect (a video, or a file that is gone); an effect magick refuses is
    simply left out."""
    source = Path(source)
    if not source.is_file() or not is_image(source):
        return False
    folder = cache / PREVIEWS / "global"
    for effect_name in NAMES:
        made = preview(source, effect_name, cache, run=run, mode=mode, detail=detail)
        if made is not None:
            folder.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(made, folder / f"{effect_name}.png")
    return True
