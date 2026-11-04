"""Vitrail's own busy cursor, drawn from the shell's shape library.

`kit/shapes.js` is the single source of the expressive shapes; this module is
its Python mirror (pinned by `tests/test_spinner.py` against the JavaScript
output). A busy cursor is one of those shapes turning in the palette's accent,
rasterised with ImageMagick — no spinner is imported from a cursor pack.

`cursor.build` writes the frames as `wait`, `progress` and `left_ptr_watch`
after tinting the pack, so the pointer matches the shell's busy indicator.
"""

from __future__ import annotations

import subprocess
import sys

# The generator's parameters, copied from kit/shapes.js (n points, inner
# radius ratio, corner roundness, start angle).
SPEC = {
    "circle": (20, 1, 0.5, -90),
    "square": (4, 1, 0.3, -45),
    "triangle": (3, 1, 0.3, -90),
    "pentagon": (5, 1, 0.3, -90),
    "gem": (6, 1, 0.25, -90),
    "cookie4": (4, 0.8, 0.5, -90),
    "cookie6": (6, 0.86, 0.5, -90),
    "cookie9": (9, 0.9, 0.5, -90),
    "cookie12": (12, 0.93, 0.5, -90),
    "clover4": (4, 0.42, 0.5, -90),
    "clover8": (8, 0.6, 0.5, -90),
    "flower": (6, 0.55, 0.5, -90),
    "sunny": (8, 0.75, 0.3, -90),
    "burst": (12, 0.7, 0.15, -90),
}
# The busy shape: four lobes read as "turning" at 16–32 px.
SHAPE = "clover4"
SIZE = 32
FRAMES = 12
STEP = 30
DELAY = 120
BUSY_NAMES = ("wait", "progress", "left_ptr_watch")


def _round(value: float) -> float:
    return round(value * 100) / 100


def _number(value: float) -> str:
    value = _round(value)
    return str(int(value)) if value == int(value) else repr(value)


def _vertices(spec: tuple[int, float, float, float]) -> list[tuple[float, float]]:
    import math

    count, inner, _t, start = spec
    total = count if inner == 1 else count * 2
    points = []
    for index in range(total):
        angle = math.radians(start + index * 360 / total)
        radius = 1 if inner == 1 or index % 2 == 0 else inner
        points.append((radius * math.cos(angle), radius * math.sin(angle)))
    return points


def _corners(points: list[tuple[float, float]], t: float) -> list[dict]:
    corners = []
    for index, (x, y) in enumerate(points):
        previous = points[(index - 1) % len(points)]
        following = points[(index + 1) % len(points)]
        corners.append(
            {
                "from": (x + (previous[0] - x) * t, y + (previous[1] - y) * t),
                "bend": (x, y),
                "to": (x + (following[0] - x) * t, y + (following[1] - y) * t),
            }
        )
    return corners


def _quad_at(corner: dict, s: float) -> tuple[float, float]:
    a = (1 - s) * (1 - s)
    b = 2 * s * (1 - s)
    d = s * s
    return (
        a * corner["from"][0] + b * corner["bend"][0] + d * corner["to"][0],
        a * corner["from"][1] + b * corner["bend"][1] + d * corner["to"][1],
    )


def path(name: str, size: int) -> str:
    """The SVG path of a shape, scaled to fill a size × size box."""
    spec = SPEC.get(name, SPEC["circle"])
    corners = _corners(_vertices(spec), spec[2])
    low = [float("inf"), float("inf")]
    high = [float("-inf"), float("-inf")]
    for corner in corners:
        for step in range(9):
            x, y = _quad_at(corner, step / 8)
            low = [min(low[0], x), min(low[1], y)]
            high = [max(high[0], x), max(high[1], y)]
    scale = size / max(high[0] - low[0], high[1] - low[1])

    def place(point: tuple[float, float]) -> str:
        x = (point[0] - (low[0] + high[0]) / 2) * scale + size / 2
        y = (point[1] - (low[1] + high[1]) / 2) * scale + size / 2
        return f"{_number(max(0, min(size, x)))} {_number(max(0, min(size, y)))}"

    out = ""
    for index, corner in enumerate(corners):
        out += (
            ("M " if index == 0 else "L ")
            + place(corner["from"])
            + " Q "
            + place(corner["bend"])
            + " "
            + place(corner["to"])
            + " "
        )
    return out + "Z"


def frame_svg(name: str, size: int, angle: float, colour: str) -> str:
    """One frame: the shape, centred and turned `angle` degrees."""
    half = size / 2
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" '
        f'viewBox="0 0 {size} {size}">'
        f'<g transform="rotate({angle} {_number(half)} {_number(half)})">'
        f'<path d="{path(name, size)}" fill="{colour}"/></g></svg>'
    )


def rasterise(svg: str) -> bytes | None:
    """Straight RGBA bytes of the frame, 8 bits per channel."""
    try:
        found = subprocess.run(
            ["magick", "svg:-", "-background", "none", "-depth", "8", "rgba:-"],
            input=svg.encode("utf-8"),
            capture_output=True,
            check=False,
        )
    except OSError:
        return None
    return found.stdout if found.returncode == 0 else None


def _argb(rgba: bytes) -> bytes:
    """Premultiplied ARGB words, the order Xcursor stores."""
    out = bytearray()
    for index in range(0, len(rgba), 4):
        red, green, blue, alpha = rgba[index : index + 4]
        out += (
            (alpha << 24) | ((red * alpha // 255) << 16) | ((green * alpha // 255) << 8) | (blue * alpha // 255)
        ).to_bytes(4, "little")
    return bytes(out)


def frames(
    name: str = SHAPE,
    size: int = SIZE,
    count: int = FRAMES,
    step: float = STEP,
    delay: int = DELAY,
    colour: str = "#ffffff",
    run=rasterise,
) -> list[dict]:
    """The Xcursor images of the busy cursor, or [] when nothing renders."""
    images = []
    for index in range(count):
        rgba = run(frame_svg(name, size, index * step, colour))
        if not rgba or len(rgba) != size * size * 4:
            sys.stderr.write("vitrail-spinner: no frame rendered\n")
            return []
        images.append(
            {
                "subtype": size,
                "width": size,
                "height": size,
                "xhot": size // 2,
                "yhot": size // 2,
                "delay": delay,
                "pixels": _argb(rgba),
            }
        )
    return images
