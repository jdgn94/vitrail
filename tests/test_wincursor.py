"""Windows cursors (.cur/.ani) become Xcursor themes.

The fixtures are built here with the standard library so the reader is checked
against the format, not against one vendor's writer. The real pack is then
converted twice (light and dark) and both generated themes are inspected.
"""

from __future__ import annotations

import struct
import tempfile
import unittest
import zipfile
import zlib
from pathlib import Path

from vitrail import cursor, fonts, wincursor

ROOT = Path(__file__).resolve().parent.parent
ZIP = ROOT / "assets" / "cursors" / "material-design" / "source" / "material-design-cursor-concept-free.zip"
LIGHT = ROOT / "assets" / "cursors" / "MaterialDesign-Light"
DARK = ROOT / "assets" / "cursors" / "MaterialDesign-Dark"


def png(width: int, height: int, pixels: list[tuple[int, int, int, int]]) -> bytes:
    """An 8-bit RGBA PNG with filter 0 on every row."""

    def chunk(kind: bytes, body: bytes) -> bytes:
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

    raw = b"".join(
        b"\0" + b"".join(bytes(pixel) for pixel in pixels[row * width : (row + 1) * width]) for row in range(height)
    )
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw))
        + chunk(b"IEND", b"")
    )


def dib(width: int, height: int, pixels: list[tuple[int, int, int, int]], bpp: int) -> bytes:
    """A bottom-up DIB plus its AND mask, as a .cur image holds them."""
    xor = bytearray()
    mask = bytearray(((width + 31) // 32) * 4 * height)
    for y in range(height - 1, -1, -1):
        row = bytearray()
        for x in range(width):
            red, green, blue, alpha = pixels[y * width + x]
            if bpp == 32:
                row += bytes((blue, green, red, alpha))
            else:
                row += bytes((blue, green, red))
            if alpha < 128:
                mask[y * ((width + 31) // 32) * 4 + x // 8] |= 1 << (7 - x % 8)
        row += bytes((-len(row)) % 4)
        xor += row
    header = struct.pack("<IiiHHIIiiII", 40, width, height * 2, 1, bpp, 0, len(xor), 0, 0, 0, 0)
    return header + bytes(xor) + bytes(mask)


def indexed_dib(width: int, height: int, indices: list[int], palette: list[tuple[int, int, int]], bpp: int) -> bytes:
    """A palette DIB at 1, 4 or 8 bits per pixel."""
    xor = bytearray()
    for y in range(height - 1, -1, -1):
        row = bytearray((width * bpp + 7) // 8)
        for x in range(width):
            index = indices[y * width + x]
            if bpp == 8:
                row[x] = index
            elif bpp == 4:
                row[x // 2] |= index << (4 if x % 2 == 0 else 0)
            else:
                row[x // 8] |= index << (7 - x % 8)
        xor += row + bytes((-len(row)) % 4)
    colours = b"".join(bytes((blue, green, red, 0)) for red, green, blue in palette)
    header = struct.pack("<IiiHHIIiiII", 40, width, height * 2, 1, bpp, 0, len(xor), 0, 0, len(palette), 0)
    mask = bytes(((width + 31) // 32) * 4 * height)
    return header + colours + bytes(xor) + mask


def cur(images: list[dict]) -> bytes:
    """A type-2 cursor from {"png"|"dib", "xhot", "yhot"} entries."""
    offset = 6 + 16 * len(images)
    entries = bytearray()
    data = bytearray()
    for image in images:
        payload = image["payload"]
        width, height = image["width"], image["height"]
        entries += struct.pack(
            "<BBBBHHII",
            width if width < 256 else 0,
            height if height < 256 else 0,
            0,
            0,
            image["xhot"],
            image["yhot"],
            len(payload),
            offset,
        )
        data += payload
        offset += len(payload)
    return struct.pack("<HHH", 0, 2, len(images)) + bytes(entries) + bytes(data)


def cur_image(
    pixels: list[tuple[int, int, int, int]] | None = None,
    width: int = 1,
    height: int = 1,
    xhot: int = 0,
    yhot: int = 0,
    bpp: int = 32,
    coded: str = "dib",
) -> bytes:
    pixels = pixels or [(255, 0, 0, 255)] * (width * height)
    payload = png(width, height, pixels) if coded == "png" else dib(width, height, pixels, bpp)
    return cur([{"payload": payload, "width": width, "height": height, "xhot": xhot, "yhot": yhot}])


def ani(frames: list[bytes], rates: list[int] | None = None, seq: list[int] | None = None) -> bytes:
    """A RIFF ACON file with one icon chunk per frame."""

    def chunk(kind: bytes, body: bytes) -> bytes:
        return kind + struct.pack("<I", len(body)) + body + (b"\0" if len(body) % 2 else b"")

    anih = struct.pack("<9I", 36, len(frames), len(seq) if seq else len(frames), 0, 0, 0, 0, 0, 1)
    body = chunk(b"anih", anih)
    if rates is not None:
        body += chunk(b"rate", struct.pack(f"<{len(rates)}I", *rates))
    if seq is not None:
        body += chunk(b"seq ", struct.pack(f"<{len(seq)}I", *seq))
    icons = b"".join(chunk(b"icon", frame) for frame in frames)
    body += chunk(b"LIST", b"fram" + icons)
    return b"RIFF" + struct.pack("<I", len(body) + 4) + b"ACON" + body


class CurTests(unittest.TestCase):
    def test_a_32bpp_dib_keeps_the_hotspot_and_premultiplies(self) -> None:
        raw = cur_image([(255, 0, 0, 255), (0, 0, 0, 0)], width=2, xhot=1, yhot=0)
        images = wincursor.parse_cur(raw)
        self.assertEqual(len(images), 1)
        image = images[0]
        self.assertEqual((image["width"], image["height"], image["xhot"], image["yhot"]), (2, 1, 1, 0))
        self.assertEqual(struct.unpack("<II", image["pixels"]), (0xFFFF0000, 0))

    def test_a_24bpp_dib_takes_transparency_from_the_and_mask(self) -> None:
        raw = cur_image([(0, 0, 255, 0), (0, 255, 0, 255)], width=2, yhot=1, bpp=24)
        image = wincursor.parse_cur(raw)[0]
        self.assertEqual(struct.unpack("<II", image["pixels"]), (0, 0xFF00FF00))

    def test_palette_dibs_at_1_4_and_8_bits_use_their_palette(self) -> None:
        for bpp in (1, 4, 8):
            with self.subTest(bpp=bpp):
                payload = indexed_dib(2, 1, [0, 1], [(255, 0, 0), (0, 0, 255)], bpp)
                raw = cur([{"payload": payload, "width": 2, "height": 1, "xhot": 0, "yhot": 0}])
                image = wincursor.parse_cur(raw)[0]
                self.assertEqual(struct.unpack("<II", image["pixels"]), (0xFFFF0000, 0xFF0000FF))

    def test_a_png_image_is_decoded(self) -> None:
        raw = cur_image([(0, 255, 0, 255), (0, 0, 0, 0)], width=2, xhot=1, coded="png")
        image = wincursor.parse_cur(raw)[0]
        self.assertEqual((image["width"], image["xhot"]), (2, 1))
        self.assertEqual(struct.unpack("<II", image["pixels"]), (0xFF00FF00, 0))

    def test_a_foreign_file_is_not_a_cursor(self) -> None:
        with self.assertRaises(ValueError):
            wincursor.parse_cur(b"not a cursor")


class AniTests(unittest.TestCase):
    def test_rate_and_sequence_are_applied_to_the_frames(self) -> None:
        red = cur_image([(255, 0, 0, 255)])
        blue = cur_image([(0, 0, 255, 255)])
        images = wincursor.parse_ani(ani([red, blue], rates=[3, 6], seq=[1, 0]))
        self.assertEqual([image["delay"] for image in images], [50, 100])
        self.assertEqual(struct.unpack("<II", b"".join(image["pixels"] for image in images)), (0xFF0000FF, 0xFFFF0000))

    def test_without_a_rate_chunk_the_default_is_used(self) -> None:
        images = wincursor.parse_ani(ani([cur_image(), cur_image()]))
        self.assertEqual([image["delay"] for image in images], [100, 100])

    def test_a_foreign_file_is_not_an_animation(self) -> None:
        with self.assertRaises(ValueError):
            wincursor.parse_ani(b"not an ani")


class ThemeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.source = self.root / "source"
        self.source.mkdir()
        self.target = self.root / "MaterialDesign-Test"

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def test_names_map_to_xcursor_names_and_standard_aliases(self) -> None:
        (self.source / "arrow.cur").write_bytes(cur_image([(255, 0, 0, 255)]))
        (self.source / "hand.cur").write_bytes(cur_image([(0, 255, 0, 255)]))
        count = wincursor.build_theme(self.source, self.target, "MaterialDesign-Test")
        self.assertEqual(count, 2)
        for name in ("left_ptr", "default", "arrow", "pointer", "hand", "hand1", "hand2"):
            with self.subTest(name=name):
                self.assertTrue((self.target / "cursors" / name).is_file(), name)
        self.assertEqual(
            (self.target / "cursors" / "left_ptr").read_bytes(),
            (self.target / "cursors" / "default").read_bytes(),
        )
        theme = (self.target / "index.theme").read_text(encoding="utf-8")
        self.assertIn("[Icon Theme]", theme)
        self.assertIn("Name=MaterialDesign-Test", theme)

    def test_an_animation_is_written_as_frames_with_delays(self) -> None:
        (self.source / "wait.ani").write_bytes(
            ani([cur_image([(255, 0, 0, 255)]), cur_image([(0, 0, 255, 255)])], rates=[3, 6])
        )
        wincursor.build_theme(self.source, self.target)
        images = cursor.read_cursor(self.target / "cursors" / "watch")
        self.assertEqual([image["delay"] for image in images], [50, 100])


@unittest.skipUnless(ZIP.is_file(), "the Material Design source zip is not present")
class MaterialDesignTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def convert(self) -> tuple[Path, Path]:
        with zipfile.ZipFile(ZIP) as archive:
            archive.extractall(self.root / "source")
        light = self.root / "MaterialDesign-Light"
        dark = self.root / "MaterialDesign-Dark"
        wincursor.build_theme(self.root / "source" / "light", light, "MaterialDesign-Light")
        wincursor.build_theme(self.root / "source" / "dark", dark, "MaterialDesign-Dark")
        return light, dark

    def test_both_themes_have_the_same_cursors_and_the_committed_copy(self) -> None:
        light, dark = self.convert()
        light_names = sorted(path.name for path in (light / "cursors").iterdir())
        dark_names = sorted(path.name for path in (dark / "cursors").iterdir())
        self.assertEqual(light_names, dark_names)
        self.assertGreater(len(light_names), 17)
        committed = sorted(path.name for path in (LIGHT / "cursors").iterdir())
        self.assertEqual(committed, light_names)
        self.assertEqual(sorted(path.name for path in (DARK / "cursors").iterdir()), dark_names)
        self.assertTrue((ZIP.parent / "LICENSE").is_file())

    def test_every_hotspot_is_inside_its_image(self) -> None:
        light, _dark = self.convert()
        for path in (light / "cursors").iterdir():
            for image in cursor.read_cursor(path):
                with self.subTest(cursor=path.name, width=image["width"], height=image["height"]):
                    self.assertLess(image["xhot"], image["width"])
                    self.assertLess(image["yhot"], image["height"])

    def test_animated_cursors_keep_their_frames(self) -> None:
        light, _dark = self.convert()
        for name in ("watch", "left_ptr_watch"):
            with self.subTest(name=name):
                images = cursor.read_cursor(light / "cursors" / name)
                self.assertGreater(len(images), 1)
                self.assertTrue(all(image["delay"] > 0 for image in images))

    def test_the_committed_assets_are_normal_themes_and_adapt(self) -> None:
        icons, cursors = fonts.themes([ROOT / "assets" / "cursors"])
        for name in ("MaterialDesign-Light", "MaterialDesign-Dark"):
            self.assertIn(name, cursors)
        state = fonts.state(
            run=lambda argv: "",
            roots=[LIGHT.parent],
            cache=self.root / "cache",
            user_roots=[],
            palette={},
        )
        for name in ("MaterialDesign-Light", "MaterialDesign-Dark"):
            self.assertIn(name, state["cursorThemes"])
            self.assertIn(name, state["cursorDesigns"])

        palette = {"on_surface": "#e6e0e9", "surface": "#141218", "primary": "#a8c7ff"}
        target = self.root / "icons" / "vitrail-MaterialDesign-Light"
        self.assertTrue(cursor.build(LIGHT, target, palette, self.root / "cache" / "themes", spinner=False))
        self.assertTrue((target / "index.theme").is_file())
        self.assertIn("Inherits=MaterialDesign-Light", (target / "index.theme").read_text(encoding="utf-8"))
        self.assertGreater(len(list((target / "cursors").iterdir())), 17)


if __name__ == "__main__":
    unittest.main()
