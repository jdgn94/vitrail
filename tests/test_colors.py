"""Tests for color extraction and theme generation."""

from __future__ import annotations

import colorsys
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


# Real matugen output (wallpaper of the user's session): (dark, light) pairs.
REAL_BASE16 = {
    "base00": ("#16131e", "#b4b0be"),
    "base01": ("#2c2935", "#9d99a8"),
    "base02": ("#433f4c", "#878391"),
    "base03": ("#595663", "#706c7a"),
    "base04": ("#706c7a", "#595663"),
    "base05": ("#878391", "#433f4c"),
    "base06": ("#9d99a8", "#2c2935"),
    "base07": ("#b4b0be", "#16131e"),
    "base08": ("#ff5b85", "#ff5b85"),
    "base09": ("#d07d9b", "#d07d9b"),
    "base0a": ("#9e8bd2", "#9e8bd2"),
    "base0b": ("#c38c00", "#c38c00"),
    "base0c": ("#d17d99", "#d17d99"),
    "base0d": ("#a380ff", "#a380ff"),
    "base0e": ("#ff569e", "#ff569e"),
    "base0f": ("#615d66", "#615d66"),
}
REAL_ROLES = {
    "surface": ("#141218", "#fdf7ff"),
    "on_surface": ("#e6e0e9", "#1d1b20"),
    "primary": ("#cfbdfe", "#65558f"),
    "primary_container": ("#4d3d75", "#e9ddff"),
    "on_primary_container": ("#e9ddff", "#201047"),
}


def real_theme(dark: bool) -> colors.Theme:
    return colors.Theme(
        raw={
            "is_dark_mode": dark,
            "colors": {name: role(*pair) for name, pair in REAL_ROLES.items()},
            "base16": {name: role(*pair) for name, pair in REAL_BASE16.items()},
        }
    )


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
        "primary_container": role("#004786", "#d3e3fd"),
        "on_primary_container": role("#d3e3fd", "#001c3a"),
        "error": role("#ffb4ab", "#ba1a1a"),
    },
    "base16": {name: role(*pair) for name, pair in REAL_BASE16.items()},
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

            path = colors.fetch_image("https://example.com/wall.png", Path(tmp), opener)
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
        result = SimpleNamespace(returncode=0, stdout=json.dumps(THEME_JSON), stderr="")
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
            self.assertRegex(conf, rf"(?m)^color{index} #[0-9a-f]{{6}}$")
        self.assertIn("\nforeground #e2e2e9\n", conf)
        self.assertIn("\nbackground #111318\n", conf)


def hex_hue(value: str) -> float:
    red, green, blue = (channel / 255 for channel in colors._rgb(value))
    return colorsys.rgb_to_hls(red, green, blue)[0] * 360


class ContrastTests(unittest.TestCase):
    def test_contrast_follows_wcag(self) -> None:
        self.assertAlmostEqual(colors.contrast("#000000", "#ffffff"), 21.0)
        self.assertAlmostEqual(colors.contrast("#ffffff", "#000000"), 21.0)
        self.assertAlmostEqual(colors.contrast("#777777", "#777777"), 1.0)
        self.assertAlmostEqual(colors.contrast("#767676", "#ffffff"), 4.54, places=2)

    def test_a_passing_color_is_left_alone(self) -> None:
        self.assertEqual(colors.ensure_contrast("#e2e2e9", "#111318", 7.0), "#e2e2e9")

    def test_dark_backgrounds_lighten_the_color_and_keep_its_hue(self) -> None:
        fixed = colors.ensure_contrast("#2c2935", "#16131e", 4.5)
        self.assertGreaterEqual(colors.contrast(fixed, "#16131e"), 4.5)
        self.assertLess(abs(hex_hue(fixed) - hex_hue("#2c2935")), 3)

    def test_light_backgrounds_darken_the_color(self) -> None:
        fixed = colors.ensure_contrast("#ffb4ab", "#fdf7ff", 4.5)
        self.assertGreaterEqual(colors.contrast(fixed, "#fdf7ff"), 4.5)
        self.assertLess(colors.luminance(fixed), colors.luminance("#ffb4ab"))
        self.assertLess(abs(hex_hue(fixed) - hex_hue("#ffb4ab")), 3)


class TerminalPaletteTests(unittest.TestCase):
    def test_ansi_slots_follow_the_base16_convention(self) -> None:
        # Colors that already read well on black: nothing gets adjusted.
        picks = {
            "base00": "#101010",
            "base03": "#909090",
            "base05": "#d0d0d0",
            "base07": "#f0f0f0",
            "base08": "#ff6060",
            "base0b": "#60ff60",
            "base0a": "#ffff60",
            "base0d": "#6060ff",
            "base0e": "#ff60ff",
            "base0c": "#60ffff",
        }
        base = {f"base{i:02x}": role("#808080") for i in range(16)}
        base.update({key: role(value) for key, value in picks.items()})
        theme = colors.Theme(
            raw={
                "is_dark_mode": True,
                "colors": {"surface": role("#000000")}
                | {n: role("#ffffff") for n in ("on_surface", "primary", "primary_container", "on_primary_container")},
                "base16": base,
            }
        )
        ansi = colors.terminal_palette(theme)["colors"]
        expected = {
            0: "base00",
            1: "base08",
            2: "base0b",
            3: "base0a",
            4: "base0d",
            5: "base0e",
            6: "base0c",
            7: "base05",
            8: "base03",
            15: "base07",
        }
        for slot, key in expected.items():
            self.assertEqual(ansi[slot], picks[key], slot)

    def test_bright_variants_are_lighter_in_dark_and_darker_in_light(self) -> None:
        dark = colors.terminal_palette(real_theme(True))["colors"]
        light = colors.terminal_palette(real_theme(False))["colors"]
        for index in range(1, 7):
            self.assertGreater(colors.luminance(dark[index + 8]), colors.luminance(dark[index]), index)
            self.assertLess(colors.luminance(light[index + 8]), colors.luminance(light[index]), index)

    def test_main_colors_come_from_the_theme_roles(self) -> None:
        for dark, mode in ((True, 0), (False, 1)):
            palette = colors.terminal_palette(real_theme(dark))
            self.assertEqual(palette["background"], REAL_ROLES["surface"][mode])
            self.assertEqual(palette["foreground"], REAL_ROLES["on_surface"][mode])
            self.assertEqual(palette["cursor"], REAL_ROLES["primary"][mode])
            self.assertEqual(palette["selection_background"], REAL_ROLES["primary_container"][mode])
            self.assertEqual(palette["selection_foreground"], REAL_ROLES["on_primary_container"][mode])

    def test_everything_is_legible_in_both_modes(self) -> None:
        for dark in (True, False):
            palette = colors.terminal_palette(real_theme(dark))
            bg, ansi = palette["background"], palette["colors"]
            self.assertEqual(len(ansi), 16)
            self.assertGreaterEqual(colors.contrast(palette["foreground"], bg), 7.0)
            for index in (*range(1, 8), *range(9, 16)):
                self.assertGreaterEqual(colors.contrast(ansi[index], bg), 4.5, (dark, index))
            self.assertGreaterEqual(colors.contrast(ansi[8], bg), 3.0, dark)

    def test_hues_survive_the_adjustment(self) -> None:
        palette = colors.terminal_palette(real_theme(False))["colors"]
        self.assertLess(abs(hex_hue(palette[1]) - hex_hue("#ff5b85")), 5)

    def test_kitty_file_uses_the_palette(self) -> None:
        theme = real_theme(True)
        conf = colors.render_kitty(theme, {})
        self.assertIn("\nbackground #141218\n", conf)
        self.assertIn("\nforeground #e6e0e9\n", conf)
        self.assertIn("\nselection_background #4d3d75\n", conf)
        self.assertIn("\ncursor #cfbdfe\n", conf)


class WriteOutputsTests(unittest.TestCase):
    def test_writes_every_artifact(self) -> None:
        theme = colors.Theme(raw=THEME_JSON)
        with tempfile.TemporaryDirectory() as tmp:
            written = colors.write_outputs(theme, Path(tmp))
            names = {path.relative_to(tmp).as_posix() for path in written}
            self.assertEqual(names, set(colors.RENDERERS) | {"theme.json", "colors.json"})
            self.assertEqual(json.loads((Path(tmp) / "theme.json").read_text())["is_dark"], True)


class ReloadTests(unittest.TestCase):
    def test_hyprland_reload_only_when_running(self) -> None:
        self.assertEqual(colors.reload_commands({}, which=lambda _: "/usr/bin/x"), [])
        self.assertEqual(
            colors.reload_commands({"HYPRLAND_INSTANCE_SIGNATURE": "x"}, which=lambda _: "/usr/bin/x"),
            [["hyprctl", "reload"]],
        )


if __name__ == "__main__":
    unittest.main()


class SchemeSettingsTests(unittest.TestCase):
    def test_the_default_is_tonal(self) -> None:
        self.assertEqual(colors.scheme_settings({}), ("tonal", 0.0))

    def test_an_unknown_scheme_falls_back(self) -> None:
        self.assertEqual(colors.scheme_settings({"colorScheme": "nope"})[0], "tonal")

    def test_the_contrast_is_clamped(self) -> None:
        self.assertEqual(colors.scheme_settings({"colorContrast": 4})[1], 1.0)
        self.assertEqual(colors.scheme_settings({"colorContrast": "-4"})[1], -1.0)

    def test_a_bad_contrast_is_zero(self) -> None:
        self.assertEqual(colors.scheme_settings({"colorContrast": "x"})[1], 0.0)

    def test_a_stored_scheme_is_kept(self) -> None:
        self.assertEqual(colors.scheme_settings({"colorScheme": "vibrant", "colorContrast": "0.5"}), ("vibrant", 0.5))
