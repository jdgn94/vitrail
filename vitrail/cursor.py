"""The cursor, tinted with the live palette.

A Vitrail cursor is a pack (`Bibata-Modern-Classic`, `Adwaita`, …) recoloured
so the arrow and the text beam take `on_surface` and the active shapes (hand,
resize, move) take `primary`, both rimmed with `surface`. The shape, every
image size and every animation delay stay the pack's.

Xcursor files are read and written here with the standard library: the reader
`vitrail.fonts` already uses, plus a writer, so no `xorg-xcursorgen` is needed.

The generated theme lives in `~/.local/share/icons/vitrail-<pack>`, which
`vitrail.fonts state` lists like any installed theme and the picker offers.
"""

from __future__ import annotations

import hashlib
import json
import os
import struct
import sys
from pathlib import Path

PREFIX = "vitrail-"
XCURSOR_IMAGE = 0xFFFD0002
XCURSOR_COMMENT = 0xFFFE0001
# Cursor names that are "active" — they get the accent colour.
ACTIVE = {
    "hand",
    "hand1",
    "hand2",
    "pointer",
    "pointing_hand",
    "pointer_hand",
    "sb_h_double_arrow",
    "sb_v_double_arrow",
    "ew-resize",
    "ns-resize",
    "size_hor",
    "size_ver",
    "size_fdiag",
    "size_bdiag",
    "fleur",
    "move",
    "all-scroll",
    "grab",
    "grabbing",
    "crosshair",
    "crossed_circle",
}


def log(message: str) -> None:
    print(f"vitrail-cursor: {message}", file=sys.stderr, flush=True)


def design_name(pack: str) -> str:
    return PREFIX + pack


def source_of(name: str) -> str:
    """The pack a `vitrail-<pack>` theme is built from ("" otherwise)."""
    return name[len(PREFIX) :] if name.startswith(PREFIX) and len(name) > len(PREFIX) else ""


def output_root() -> Path:
    base = os.environ.get("XDG_DATA_HOME") or str(Path.home() / ".local" / "share")
    return Path(base) / "icons"


def roles(palette: dict) -> dict:
    """The inks a tinted cursor uses, from a matugen palette."""
    return {
        "ink": palette.get("on_surface") or "#e6e0e9",
        "paper": palette.get("surface") or "#141218",
        "accent": palette.get("primary") or "#a8c7ff",
    }


# --- Xcursor -----------------------------------------------------------------


def read_cursor(path: Path) -> list[dict]:
    """Every image of an Xcursor file; [] when it is not one."""
    try:
        data = path.read_bytes()
    except OSError:
        return []
    if len(data) < 16 or data[:4] != b"Xcur":
        return []
    try:
        _magic, header, _version, count = struct.unpack_from("<IIII", data, 0)
    except struct.error:
        return []
    images: list[dict] = []
    for index in range(count):
        try:
            kind, subtype, position = struct.unpack_from("<III", data, header + index * 12)
        except struct.error:
            break
        if kind != XCURSOR_IMAGE:
            continue
        try:
            _h, _k, _s, _v, width, height, xhot, yhot, delay = struct.unpack_from("<IIIIIIIII", data, position)
        except struct.error:
            continue
        size = width * height * 4
        if not (0 < width <= 512 and 0 < height <= 512) or position + 36 + size > len(data):
            continue
        images.append(
            {
                "subtype": subtype,
                "width": width,
                "height": height,
                "xhot": xhot,
                "yhot": yhot,
                "delay": delay,
                "pixels": data[position + 36 : position + 36 + size],
            }
        )
    return images


def write_cursor(images: list[dict], path: Path) -> None:
    """An Xcursor file with `images`, in the order given."""
    offset = 16 + 12 * len(images)
    positions = []
    for image in images:
        positions.append(offset)
        offset += 36 + image["width"] * image["height"] * 4
    data = bytearray(struct.pack("<IIII", 0x72756358, 16, 0x10000, len(images)))
    for image, position in zip(images, positions):
        data += struct.pack("<III", XCURSOR_IMAGE, image["subtype"], position)
    for image in images:
        data += struct.pack(
            "<IIIIIIIII",
            36,
            XCURSOR_IMAGE,
            image["subtype"],
            1,
            image["width"],
            image["height"],
            image["xhot"],
            image["yhot"],
            image["delay"],
        )
        data += image["pixels"]
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.part")
    temporary.write_bytes(bytes(data))
    os.replace(temporary, path)


# --- tint --------------------------------------------------------------------


def _rgb(colour: str) -> tuple[int, int, int]:
    value = colour.strip().lstrip("#")
    if len(value) == 3:
        value = "".join(char * 2 for char in value)
    try:
        return int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16)
    except (ValueError, IndexError):
        return 0, 0, 0


def _straight(word: int) -> tuple[int, int, int, int]:
    alpha = (word >> 24) & 0xFF
    if alpha == 0:
        return 0, 0, 0, 0
    red, green, blue = (word >> 16) & 0xFF, (word >> 8) & 0xFF, word & 0xFF
    if alpha < 255:
        red = min(255, red * 255 // alpha)
        green = min(255, green * 255 // alpha)
        blue = min(255, blue * 255 // alpha)
    return red, green, blue, alpha


def _premultiplied(red: int, green: int, blue: int, alpha: int) -> int:
    return (alpha << 24) | ((red * alpha // 255) << 16) | ((green * alpha // 255) << 8) | (blue * alpha // 255)


def tint(pixels: bytes, width: int, height: int, fill: str, outline: str) -> bytes:
    """Recolours an ARGB image between `outline` (rim) and `fill` (body).

    The pack's shape and alpha stay. The two dominant luminances are the body
    (the bigger cluster, painted `fill`) and the rim (painted `outline`), so a
    black-bodied pack and a white-bodied one both come out readable on the
    same palette. A single-colour pack becomes the fill colour.
    """
    count = width * height
    straight = [_straight(word) for word in struct.unpack_from(f"<{count}I", pixels, 0)]
    light = [sum(weight * channel for weight, channel in zip((299, 587, 114), rgba[:3])) // 1000 for rgba in straight]
    values = [value for value, rgba in zip(light, straight) if rgba[3] > 8]
    if not values:
        return pixels

    low, high = min(values), max(values)
    body: float = low
    rim: float = low
    if high - low >= 16:
        below, above = low, high
        low_values, high_values = [], []
        for _ in range(10):
            middle = (below + above) / 2
            low_values = [value for value in values if value < middle]
            high_values = [value for value in values if value >= middle]
            if low_values:
                below = sum(low_values) / len(low_values)
            if high_values:
                above = sum(high_values) / len(high_values)
        body, rim = (below, above) if len(low_values) >= len(high_values) else (above, below)

    fill_rgb, outline_rgb = _rgb(fill), _rgb(outline)
    out = bytearray()
    for value, (red, green, blue, alpha) in zip(light, straight):
        if alpha == 0:
            out += b"\0\0\0\0"
            continue
        if body == rim:
            target = fill_rgb
        else:
            ratio = min(1.0, max(0.0, (value - rim) / (body - rim)))
            target = tuple(round(outline_rgb[i] + (fill_rgb[i] - outline_rgb[i]) * ratio) for i in range(3))
        out += struct.pack("<I", _premultiplied(target[0], target[1], target[2], alpha))
    return bytes(out)


def update_xsettings(path: Path, theme: str, size: int) -> None:
    """Sets the two cursor keys in an xsettingsd config, keeping the rest.

    GTK apps on X11 read the cursor from XSETTINGS; merging instead of
    replacing matters because the same file carries the user's DPI and fonts.
    """
    keys = {"Gtk/CursorThemeName": f'"{theme}"', "Gtk/CursorThemeSize": str(size)}
    lines = path.read_text(encoding="utf-8").splitlines() if path.exists() else []
    backup = path.with_name(path.name + ".before-vitrail")
    if path.exists() and not backup.exists():
        backup.write_text("\n".join(lines) + "\n", encoding="utf-8")
    out, done = [], set()
    for line in lines:
        name = line.split(None, 1)[0] if line.strip() else ""
        if name in keys:
            out.append(f"{name} {keys[name]}")
            done.add(name)
        else:
            out.append(line)
    for name, value in keys.items():
        if name not in done:
            out.append(f"{name} {value}")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(out) + "\n", encoding="utf-8")


# --- building ----------------------------------------------------------------


def _stamp_value(pack: str, inks: dict) -> str:
    body = json.dumps({"pack": pack, "inks": inks}, sort_keys=True)
    return hashlib.sha256(body.encode("utf-8")).hexdigest()


def build(pack: Path, target: Path, palette: dict, cache: Path, force: bool = False) -> bool:
    """Writes `target` as the tinted `pack`; False when it was already current."""
    cursors = pack / "cursors"
    if not cursors.is_dir():
        return False
    inks = roles(palette)
    stamp = cache / "stamp"
    current = _stamp_value(str(pack), inks)
    if not force and (target / "index.theme").is_file() and stamp.is_file():
        try:
            if stamp.read_text(encoding="utf-8").strip() == current:
                return False
        except OSError:
            pass

    target_cursors = target / "cursors"
    target_cursors.mkdir(parents=True, exist_ok=True)
    for source in sorted(cursors.iterdir()):
        if not source.is_file():
            continue
        images = read_cursor(source)
        if not images:
            (target_cursors / source.name).write_bytes(source.read_bytes())
            continue
        fill = inks["accent"] if source.name in ACTIVE else inks["ink"]
        for image in images:
            image["pixels"] = tint(image["pixels"], image["width"], image["height"], fill, inks["paper"])
        write_cursor(images, target_cursors / source.name)

    (target / "index.theme").write_text(
        "[Icon Theme]\n"
        f"Name=Vitrail · {pack.name}\n"
        f"Comment=Vitrail's palette applied to {pack.name}\n"
        f"Inherits={pack.name}\n",
        encoding="utf-8",
    )
    try:
        cache.mkdir(parents=True, exist_ok=True)
        stamp.write_text(current, encoding="utf-8")
    except OSError:
        pass
    return True


def main(
    argv: list[str] | None = None,
    roots: list[Path] | None = None,
    palette: dict | None = None,
    output: Path | None = None,
    cache: Path | None = None,
) -> int:
    """`cursor build <pack> [--force]`: the pipeline without the window."""
    from . import fonts  # local: fonts imports this module

    args = list(sys.argv[1:] if argv is None else argv)
    if len(args) >= 2 and args[0] == "build":
        roots = roots or fonts.DEFAULT_ROOTS
        pack = fonts.theme_dir(args[1], roots)
        if pack is None:
            log(f"not an installed theme: {args[1]}")
            return 2
        design = design_name(pack.name)
        target = (output / design) if output else (output_root() / design)
        rebuilt = build(
            pack,
            target,
            palette if palette is not None else fonts.active_palette(),
            cache or (fonts.preview_cache() / "themes"),
            force="--force" in args,
        )
        print(f"{design}: {'rebuilt' if rebuilt else 'up to date'} at {target}")
        return 0
    print("usage: cursor build <pack> [--force]", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
