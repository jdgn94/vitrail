"""Windows cursors (`.cur`/`.ani`) become Xcursor themes.

The Material Design pack ships its pointers as Windows cursor files: type-2
`.cur` files (a PNG or a DIB with an AND mask and a hotspot) and RIFF `ACON`
`.ani` animations. Xcursor is the format every Wayland and X11 cursor stack
reads, so one conversion makes the pack usable and leaves the palette-adaptive
`vitrail-<pack>` build (`vitrail.cursor`) to do its usual tint.

Only the standard library is used: the DIB and PNG decoders are here, and the
Xcursor writer is `vitrail.cursor.write_cursor`, so the pipeline adds no
program to the installer.
"""

from __future__ import annotations

import re
import struct
import sys
import zlib
from pathlib import Path

from . import cursor as cursor_engine

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
DEFAULT_RATE = 6  # jiffies (1/60 s); Windows' own fallback, 100 ms per frame.
# Windows scheme names -> the Xcursor name a theme normally carries.
WINDOWS = {
    "arrow": "left_ptr",
    "hand": "pointer",
    "ibeam": "xterm",
    "wait": "watch",
    "appstarting": "left_ptr_watch",
    "help": "question_arrow",
    "no": "not-allowed",
    "sizeall": "fleur",
    "sizens": "sb_v_double_arrow",
    "sizewe": "sb_h_double_arrow",
    "sizenwse": "bd_double_arrow",
    "sizenesw": "fd_double_arrow",
    "uparrow": "up_arrow",
    "crosshair": "crosshair",
    "nwpen": "pencil",
    "person": "person",
    "pin": "pin",
}
# Extra names applications ask for. Each one is a byte-for-byte copy.
ALIASES = {
    "left_ptr": ("default", "arrow", "top_left_arrow"),
    "pointer": ("hand", "hand1", "hand2", "pointing_hand"),
    "xterm": ("text", "ibeam"),
    "watch": ("wait",),
    "left_ptr_watch": ("progress", "appstarting"),
    "question_arrow": ("help",),
    "not-allowed": ("no",),
    "fleur": ("sizeall", "move", "all-scroll"),
    "sb_v_double_arrow": ("sizens", "ns-resize", "size_ver"),
    "sb_h_double_arrow": ("sizewe", "ew-resize", "size_hor"),
    "bd_double_arrow": ("sizenwse", "nwse-resize", "size_fdiag"),
    "fd_double_arrow": ("sizenesw", "nesw-resize", "size_bdiag"),
    "up_arrow": ("uparrow",),
    "crosshair": ("cross",),
    "pencil": ("nwpen",),
}


def log(message: str) -> None:
    print(f"vitrail-wincursor: {message}", file=sys.stderr, flush=True)


def _argb(red: int, green: int, blue: int, alpha: int) -> int:
    """One Xcursor pixel: premultiplied ARGB, little-endian word."""
    if alpha == 0:
        return 0
    return (alpha << 24) | ((red * alpha // 255) << 16) | ((green * alpha // 255) << 8) | (blue * alpha // 255)


def _image(width: int, height: int, xhot: int, yhot: int, rgba: bytes, delay: int = 0) -> dict:
    words = bytearray()
    for index in range(0, len(rgba), 4):
        words += struct.pack("<I", _argb(*rgba[index : index + 4]))
    return {
        "subtype": max(width, height),
        "width": width,
        "height": height,
        "xhot": min(max(xhot, 0), width - 1),
        "yhot": min(max(yhot, 0), height - 1),
        "delay": delay,
        "pixels": bytes(words),
    }


# --- PNG ----------------------------------------------------------------------


def _paeth(left: int, above: int, corner: int) -> int:
    estimate = left + above - corner
    distance_left, distance_above, distance_corner = (
        abs(estimate - left),
        abs(estimate - above),
        abs(estimate - corner),
    )
    if distance_left <= distance_above and distance_left <= distance_corner:
        return left
    return above if distance_above <= distance_corner else corner


def _unfilter(raw: bytes, width: int, height: int, bits: int, channels: int) -> list[bytes]:
    stride = (width * bits * channels + 7) // 8
    count = max(1, (bits * channels + 7) // 8)
    if len(raw) < (stride + 1) * height:
        raise ValueError("truncated PNG pixel data")
    rows: list[bytearray] = []
    for row in range(height):
        kind = raw[row * (stride + 1)]
        line = bytearray(raw[row * (stride + 1) + 1 : (row + 1) * (stride + 1)])
        above = rows[-1] if rows else bytearray(stride)
        for x in range(stride):
            left = line[x - count] if x >= count else 0
            up = above[x]
            corner = above[x - count] if x >= count else 0
            if kind == 1:
                line[x] = (line[x] + left) & 0xFF
            elif kind == 2:
                line[x] = (line[x] + up) & 0xFF
            elif kind == 3:
                line[x] = (line[x] + (left + up) // 2) & 0xFF
            elif kind == 4:
                line[x] = (line[x] + _paeth(left, up, corner)) & 0xFF
            elif kind != 0:
                raise ValueError(f"unknown PNG filter {kind}")
        rows.append(line)
    return [bytes(row) for row in rows]


def _samples(row: bytes, width: int, bits: int, channels: int) -> list[int]:
    """One row's samples, scaled to 8 bits for low-bit-depth images."""
    if bits == 8:
        return list(row[: width * channels])
    if bits == 16:
        return list(row[0 : width * channels * 2 : 2])
    values: list[int] = []
    mask = (1 << bits) - 1
    for byte in row:
        for shift in range(8 - bits, -1, -bits):
            values.append((byte >> shift) & mask)
            if len(values) == width * channels:
                return values
    return values


def parse_png(data: bytes) -> tuple[int, int, bytes]:
    """(width, height, straight RGBA) of a PNG, without a dependency."""
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError("not a PNG")
    width = height = bits = colour = 0
    interlace = 0
    palette = b""
    transparency = b""
    compressed = bytearray()
    position = 8
    while position + 8 <= len(data):
        length = struct.unpack_from(">I", data, position)[0]
        kind = data[position + 4 : position + 8]
        body = data[position + 8 : position + 8 + length]
        if kind == b"IHDR":
            width, height, bits, colour, _compression, _filter, interlace = struct.unpack(">IIBBBBB", body[:13])
        elif kind == b"PLTE":
            palette = body
        elif kind == b"tRNS":
            transparency = body
        elif kind == b"IDAT":
            compressed += body
        elif kind == b"IEND":
            break
        position += 12 + length
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}.get(colour)
    if not width or not height or channels is None:
        raise ValueError("unsupported PNG")
    if interlace:
        raise ValueError("interlaced PNG cursors are not supported")
    rows = _unfilter(zlib.decompress(bytes(compressed)), width, height, bits, channels)
    low = (1 << bits) - 1
    out = bytearray()
    for row in rows:
        values = _samples(row, width, bits, channels)
        for x in range(width):
            if colour == 3:
                index = values[x] * 3
                red, green, blue = palette[index : index + 3] if index + 3 <= len(palette) else b"\0\0\0"
                alpha = transparency[values[x]] if values[x] < len(transparency) else 255
            elif colour == 0:
                sample = values[x]
                level = sample if bits in (8, 16) else sample * 255 // low
                red = green = blue = level
                transparent = struct.unpack(">H", transparency[:2])[0] if len(transparency) >= 2 else None
                if transparent is not None and sample == (transparent >> 8 if bits == 16 else transparent):
                    alpha = 0
                else:
                    alpha = 255
            elif colour == 4:
                red = green = blue = values[x * 2]
                alpha = values[x * 2 + 1]
            elif colour == 2:
                red, green, blue = values[x * 3 : x * 3 + 3]
                transparent = struct.unpack(">HHH", transparency[:6]) if len(transparency) >= 6 else None
                if transparent:
                    wanted = tuple(value >> 8 if bits == 16 else value for value in transparent)
                    alpha = 0 if (red, green, blue) == wanted else 255
                else:
                    alpha = 255
            else:
                red, green, blue, alpha = values[x * 4 : x * 4 + 4]
            out += bytes((red, green, blue, alpha))
    return width, height, bytes(out)


# --- DIB ----------------------------------------------------------------------


def _masked(value: int, mask: int) -> int:
    if not mask:
        return 0
    shift = (mask & -mask).bit_length() - 1
    highest = mask >> shift
    return ((value & mask) >> shift) * 255 // highest


def parse_dib(data: bytes) -> tuple[int, int, bytes]:
    """(width, height, straight RGBA) of a cursor's DIB and its AND mask."""
    if len(data) < 12:
        raise ValueError("truncated DIB")
    header = struct.unpack_from("<I", data, 0)[0]
    if header == 12:
        width, height, _planes, bits = struct.unpack_from("<HHHH", data, 4)
        compression, colours = 0, 0
        palette_at, palette_size = 12, 3
    elif header >= 40:
        width, height, _planes, bits, compression = struct.unpack_from("<iiHHI", data, 4)
        colours = struct.unpack_from("<I", data, 32)[0]
        palette_at, palette_size = header, 4
    else:
        raise ValueError(f"unsupported DIB header {header}")
    top_down = height < 0
    height = abs(height)
    if width <= 0 or height < 2:
        raise ValueError("invalid DIB size")
    # A cursor DIB is twice as tall as the image: XOR pixels and the AND mask.
    xor_height = height // 2 if height % 2 == 0 else height
    entries = colours or (1 << bits if bits <= 8 else 0)
    palette = [
        data[palette_at + index * palette_size : palette_at + (index + 1) * palette_size] for index in range(entries)
    ]
    masks_at = palette_at + entries * palette_size
    masks = (0, 0, 0, 0)
    if compression in (3, 6):
        if header >= 52:
            masks = struct.unpack_from("<IIII", data, 40)
        else:
            count = 4 if compression == 6 else 3
            masks = (*struct.unpack_from(f"<{count}I", data, masks_at), 0)[:4]
            masks_at += count * 4
    pixels_at = masks_at
    xor_stride = ((width * bits + 31) // 32) * 4
    mask_stride = ((width + 31) // 32) * 4
    xor_size = xor_stride * xor_height
    mask_size = mask_stride * xor_height
    if pixels_at + xor_size > len(data):
        raise ValueError("truncated DIB pixels")
    has_mask = pixels_at + xor_size + mask_size <= len(data)
    pixels: list[list[int]] = []
    for y in range(xor_height):
        row = xor_height - 1 - y if not top_down else y
        at = pixels_at + row * xor_stride
        line = data[at : at + xor_stride]
        for x in range(width):
            if bits == 32:
                blue, green, red, alpha = line[x * 4 : x * 4 + 4]
                if compression in (3, 6) and masks[2]:
                    value = struct.unpack_from("<I", line, x * 4)[0]
                    red, green, blue = _masked(value, masks[0]), _masked(value, masks[1]), _masked(value, masks[2])
                    alpha = _masked(value, masks[3]) if masks[3] else alpha
            elif bits == 24:
                blue, green, red = line[x * 3 : x * 3 + 3]
                alpha = 255
            elif bits == 16:
                value = struct.unpack_from("<H", line, x * 2)[0]
                if masks[2]:
                    red, green, blue = _masked(value, masks[0]), _masked(value, masks[1]), _masked(value, masks[2])
                else:
                    red = ((value >> 10) & 31) * 255 // 31
                    green = ((value >> 5) & 31) * 255 // 31
                    blue = (value & 31) * 255 // 31
                alpha = 255
            else:
                if bits == 8:
                    index = line[x]
                elif bits == 4:
                    index = (line[x // 2] >> (4 if x % 2 == 0 else 0)) & 0xF
                elif bits == 1:
                    index = (line[x // 8] >> (7 - x % 8)) & 1
                else:
                    raise ValueError(f"unsupported DIB depth {bits}")
                entry = palette[index] if index < len(palette) else b"\0\0\0"
                blue, green, red = (entry + b"\0\0\0")[:3]
                alpha = 255
            pixels.append([red, green, blue, alpha])
    if bits == 32 and not any(pixel[3] for pixel in pixels):
        for pixel in pixels:
            pixel[3] = 255
    if has_mask:
        mask_at = pixels_at + xor_size
        for y in range(xor_height):
            row = xor_height - 1 - y if not top_down else y
            at = mask_at + row * mask_stride
            for x in range(width):
                if data[at + x // 8] & (1 << (7 - x % 8)):
                    pixels[y * width + x][3] = 0
    return width, xor_height, bytes(channel for pixel in pixels for channel in pixel)


# --- .cur / .ani ---------------------------------------------------------------


def parse_cur(data: bytes) -> list[dict]:
    """Every image in a Windows cursor, as Xcursor image dictionaries."""
    if len(data) < 6:
        raise ValueError("truncated cursor")
    _reserved, kind, count = struct.unpack_from("<HHH", data, 0)
    if kind not in (1, 2):
        raise ValueError("not a Windows cursor")
    images: list[dict] = []
    for index in range(count):
        at = 6 + index * 16
        if at + 16 > len(data):
            raise ValueError("truncated cursor directory")
        width, height, _colours, _reserved, xhot, yhot, size, offset = struct.unpack_from("<BBBBHHII", data, at)
        payload = data[offset : offset + size]
        if not payload:
            raise ValueError("empty cursor image")
        if payload.startswith(PNG_SIGNATURE):
            real_width, real_height, rgba = parse_png(payload)
        else:
            real_width, real_height, rgba = parse_dib(payload)
        if kind == 1:
            xhot = yhot = 0
        images.append(
            _image(
                real_width or width or 256,
                real_height or height or 256,
                xhot,
                yhot,
                rgba,
            )
        )
    return images


def _chunks(body: bytes):
    at = 0
    while at + 8 <= len(body):
        kind = body[at : at + 4]
        size = struct.unpack_from("<I", body, at + 4)[0]
        yield kind, body[at + 8 : at + 8 + size]
        at += 8 + size + (size & 1)


def parse_ani(data: bytes) -> list[dict]:
    """The animation's frames in step order, with millisecond delays."""
    if len(data) < 12 or data[:4] != b"RIFF" or data[8:12] != b"ACON":
        raise ValueError("not a RIFF animation")
    header: tuple[int, ...] | None = None
    rates: list[int] = []
    sequence: list[int] = []
    frames: list[list[dict]] = []
    for kind, body in _chunks(data[12:]):
        if kind == b"anih" and len(body) >= 36:
            header = struct.unpack_from("<9I", body, 0)
        elif kind == b"rate" and len(body) >= 4:
            rates = list(struct.unpack_from(f"<{len(body) // 4}I", body, 0))
        elif kind == b"seq " and len(body) >= 4:
            sequence = list(struct.unpack_from(f"<{len(body) // 4}I", body, 0))
        elif kind == b"LIST" and body[:4] == b"fram":
            for nested, icon in _chunks(body[4:]):
                if nested == b"icon":
                    frames.append(parse_cur(icon))
    if not frames:
        raise ValueError("the animation has no frames")
    count = min(header[1], len(frames)) if header and header[1] else len(frames)
    steps = header[2] if header and header[2] else count
    indices = sequence[:steps] if sequence else list(range(steps))
    if not indices:
        indices = list(range(count))
    fallback = header[7] if header and len(header) > 7 and header[7] else DEFAULT_RATE
    images: list[dict] = []
    for step, index in enumerate(indices):
        if index >= count:
            index %= count
        frame = max(frames[index], key=lambda image: image["width"] * image["height"])
        jiffies = rates[step] if step < len(rates) else fallback
        delay = max(1, round((jiffies or fallback) * 1000 / 60))
        images.append(dict(frame, delay=delay))
    return images


def read_cursor_file(path: Path) -> list[dict]:
    """An Xcursor image list for one `.cur` or `.ani` file."""
    data = path.read_bytes()
    return parse_ani(data) if path.suffix.lower() == ".ani" else parse_cur(data)


# --- theme --------------------------------------------------------------------


def xcursor_name(path: Path) -> str:
    """The Xcursor name for a Windows cursor file's stem."""
    name = path.stem.strip().casefold()
    name = WINDOWS.get(name, re.sub(r"\s+", "_", name))
    return name


def build_theme(source: Path, target: Path, name: str | None = None) -> int:
    """Writes `target` as an Xcursor theme from the `.cur`/`.ani` files in `source`."""
    files = sorted(path for path in source.iterdir() if path.suffix.lower() in (".cur", ".ani"))
    if not files:
        raise ValueError(f"no .cur or .ani files in {source}")
    converted: dict[str, list[dict]] = {}
    for path in files:
        try:
            images = read_cursor_file(path)
        except (OSError, ValueError, struct.error, zlib.error) as error:
            log(f"skipping {path.name}: {error}")
            continue
        if images:
            converted[xcursor_name(path)] = images
    if not converted:
        raise ValueError(f"none of the cursors in {source} could be read")

    target_cursors = target / "cursors"
    target_cursors.mkdir(parents=True, exist_ok=True)
    written: set[str] = set()
    for cursor_name, images in converted.items():
        cursor_engine.write_cursor(images, target_cursors / cursor_name)
        written.add(cursor_name)
    for cursor_name, images in converted.items():
        for alias in ALIASES.get(cursor_name, ()):
            if alias not in written:
                cursor_engine.write_cursor(images, target_cursors / alias)
                written.add(alias)

    title = name or target.name
    (target / "index.theme").write_text(
        f"[Icon Theme]\nName={title}\nComment=Windows cursor pack converted to Xcursor\nInherits=Adwaita\n",
        encoding="utf-8",
    )
    return len(converted)


def main(argv: list[str] | None = None) -> int:
    """`wincursor build <source> <target> [--name NAME]`."""
    args = list(sys.argv[1:] if argv is None else argv)
    if len(args) >= 3 and args[0] == "build":
        name = None
        if "--name" in args:
            index = args.index("--name")
            if index + 1 >= len(args):
                print("usage: wincursor build <source> <target> [--name NAME]", file=sys.stderr)
                return 2
            name = args[index + 1]
        try:
            count = build_theme(Path(args[1]), Path(args[2]), name)
        except (OSError, ValueError) as error:
            log(str(error))
            return 2
        print(f"{Path(args[2]).name}: {count} cursor(s) at {args[2]}")
        return 0
    print("usage: wincursor build <source> <target> [--name NAME]", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
