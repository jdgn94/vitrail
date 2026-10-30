"""Tests for color extraction and theme generation."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

from vitrail import colors

def role(dark: str, light: str | None = None) -> dict:
    """Forma real de matugen 4: {dark: {color}, default: {color}, light: {color}}."""
    return {
        "dark": {"color": dark},
        "default": {"color": dark},
        "light": {"color": light or dark},
    }


THEME_JSON = {
    "is_dark_mode": True,
    "colors": {
        "surface": role("#111318", "#f6fafe"),
        "surface_container": role("#1d2024", "#e9eef3"),
        "surface_container_high": role("#282a2f", "#dde3e9"),
        "on_surface": role("#e2e2e9", "#181c20"),
        "on_surface_variant": role("#c4c6d0", "#43474e"),
        "primary": role("#a8c7fa", "#1c6586"),
        "on_primary": role("#002f65", "#ffffff"),
        "error": role("#ffb4ab", "#ba1a1a"),
    },
    "base16": {
        **{
            f"base{i:02x}": {"default": {"color": f"#0000{i:02x}"}}
            for i in range(16)
        }
    },
}


class FakeResponse:
    def __init__(self, data: bytes) -> None:
        self.data = data

    def read(self, _size: int = -1) -> bytes:
        return self.data

    def __enter__(self) -> "FakeResponse":
        return self

    def __exit__(self, *_exc: object) -> bool:
        return False


class CommandTests(unittest.TestCase):
    def test_maps_scheme_and_mode(self) -> None:
        command = colors.build_command(Path("/tmp/w.png"), "content", "light", 0.2)
        self.assertIn("scheme-content", command)
        self.assertIn("light", command)
        self.assertIn("--prefer", command)
        self.assertEqual(command[-2:], ["hex", "-q"])

    def test_rejects_unknown_scheme(self) -> None:
        with self.assertRaises(ValueError):
            colors.build_command(Path("/tmp/w.png"), "inventado")


class FetchImageTests(unittest.TestCase):
    def test_local_path_is_returned(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            image = Path(tmp) / "wall.png"
            image.write_bytes(b"x")
            self.assertEqual(colors.fetch_image(str(image)), image)

    def test_missing_local_file_raises(self) -> None:
        with self.assertRaises(FileNotFoundError):
            colors.fetch_image("/no/existe.png")

    def test_downloads_url_into_cache(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            requested: list[str] = []

            def opener(request, timeout):
                requested.append(request.full_url)
                return FakeResponse(b"PNGDATA")

            path = colors.fetch_image(
                "https://example.com/wall.png", Path(tmp), opener
            )
            self.assertEqual(path.read_bytes(), b"PNGDATA")
            self.assertEqual(path.parent.name, "wallpapers")
            self.assertEqual(requested, ["https://example.com/wall.png"])
            self.assertEqual(path.suffix, ".png")

    def test_second_call_uses_cache_without_downloading(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            calls: list[int] = []

            def opener(_request, timeout):
                calls.append(1)
                return FakeResponse(b"PNGDATA")

            url = "https://example.com/wall.png"
            colors.fetch_image(url, Path(tmp), opener)
            colors.fetch_image(url, Path(tmp), opener)
            self.assertEqual(len(calls), 1)

    def test_rejects_oversized_image(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            big = b"x" * (colors.MAX_IMAGE_BYTES + 1)
            with self.assertRaises(ValueError):
                colors.fetch_image(
                    "https://example.com/big.png",
                    Path(tmp),
                    lambda _r, timeout: FakeResponse(big),
                )


class GenerateTests(unittest.TestCase):
    def test_parses_matugen_json(self) -> None:
        result = SimpleNamespace(
            returncode=0, stdout=json.dumps(THEME_JSON), stderr=""
        )
        theme = colors.generate(Path("/tmp/w.png"), run=lambda *_a, **_k: result)
        self.assertEqual(theme.colors["primary"], "#a8c7fa")
        self.assertTrue(theme.is_dark)

    def test_failure_reports_last_stderr_line(self) -> None:
        result = SimpleNamespace(returncode=1, stdout="", stderr="boom\ndetalle")
        with self.assertRaises(colors.ColorExtractionError) as caught:
            colors.generate(Path("/tmp/w.png"), run=lambda *_a, **_k: result)
        self.assertIn("detalle", str(caught.exception))

    def test_missing_binary_is_reported(self) -> None:
        def run(*_args, **_kwargs):
            raise FileNotFoundError("matugen")

        with self.assertRaises(colors.ColorExtractionError) as caught:
            colors.generate(Path("/tmp/w.png"), run=run)
        self.assertIn("matugen", str(caught.exception))


class TokenTests(unittest.TestCase):
    def setUp(self) -> None:
        self.theme = colors.Theme(raw=THEME_JSON)

    def test_flattens_dark_variant(self) -> None:
        self.assertEqual(self.theme.colors["surface"], "#111318")

    def test_flattens_light_variant(self) -> None:
        light = {**THEME_JSON, "is_dark_mode": False}
        self.assertEqual(colors.Theme(raw=light).colors["surface"], "#f6fafe")

    def test_rgba_formats_for_css(self) -> None:
        self.assertEqual(colors.rgba("#111318", 0.58), "rgba(17, 19, 24, 0.58)")

    def test_qss_uses_argb_order(self) -> None:
        self.assertEqual(colors.qss_rgba("#111318", 0.58), "#94111318")

    def test_glass_tokens_cover_surface_and_border(self) -> None:
        tokens = colors.glass_tokens(self.theme)
        self.assertTrue(tokens["glass_base"].startswith("rgba("))
        self.assertEqual(tokens["accent"], "#a8c7fa")
        self.assertEqual(tokens["text"], "#e2e2e9")


class RenderTests(unittest.TestCase):
    def setUp(self) -> None:
        self.theme = colors.Theme(raw=THEME_JSON)
        self.tokens = colors.glass_tokens(self.theme)

    def test_gtk_defines_colors(self) -> None:
        css = colors.render_gtk(self.theme, self.tokens)
        self.assertIn("@define-color window_bg_color rgba(", css)
        self.assertIn("@define-color accent_bg_color #a8c7fa", css)

    def test_qss_is_valid_qt(self) -> None:
        qss = colors.render_qss(self.theme, self.tokens)
        self.assertIn("#94111318", qss)
        self.assertIn("QPushButton", qss)

    def test_qml_is_singleton_with_glass(self) -> None:
        qml = colors.render_qml(self.theme, self.tokens)
        self.assertIn("pragma Singleton", qml)
        self.assertIn("readonly property color primary", qml)
        self.assertIn("readonly property int blurRadius", qml)

    def test_hypr_uses_rgb_functions(self) -> None:
        conf = colors.render_hypr(self.theme, self.tokens)
        self.assertIn("$vitrail_accent = rgb(a8c7fa)", conf)
        self.assertIn("rgba(", conf)

    def test_kitty_has_all_sixteen_colors(self) -> None:
        conf = colors.render_kitty(self.theme, self.tokens)
        for index in range(16):
            self.assertIn(f"color{index} #0000{index:02x}", conf)


class WriteOutputsTests(unittest.TestCase):
    def test_writes_every_artifact(self) -> None:
        theme = colors.Theme(raw=THEME_JSON)
        with tempfile.TemporaryDirectory() as tmp:
            written = colors.write_outputs(theme, Path(tmp))
            names = {path.relative_to(tmp).as_posix() for path in written}
            self.assertEqual(names, set(colors.RENDERERS) | {"theme.json", "colors.json"})
            self.assertEqual(
                json.loads((Path(tmp) / "theme.json").read_text())["is_dark"], True
            )


class ReloadTests(unittest.TestCase):
    def test_hyprland_reload_only_when_running(self) -> None:
        self.assertEqual(colors.reload_commands({}, which=lambda _: "/usr/bin/x"), [])
        self.assertEqual(
            colors.reload_commands(
                {"HYPRLAND_INSTANCE_SIGNATURE": "x"}, which=lambda _: "/usr/bin/x"
            ),
            [["hyprctl", "reload"]],
        )


if __name__ == "__main__":
    unittest.main()
