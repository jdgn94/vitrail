"""Enforces the design-system contract from AGENTS.md."""

from __future__ import annotations

import json
import re
import unittest
from pathlib import Path

from vitrail import style

ROOT = Path(__file__).resolve().parent.parent
TOKENS = ROOT / "kit" / "tokens.js"
KIT = ROOT / "kit"
COMPOSED = KIT / "composed"
VARIANTS = KIT / "VitrailVariants.qml"
STYLE = KIT / "VitrailStyle.qml"

REQUIRED_SCALE = {"display", "title", "subtitle", "body", "content", "label"}
REQUIRED_RANGES = {"spacing", "radius", "blur", "opacity", "frame", "bar", "panel"}


def tokens_source() -> str:
    return TOKENS.read_text(encoding="utf-8")


class TokenContractTests(unittest.TestCase):
    def test_ranges_have_bounds_and_defaults(self) -> None:
        text = tokens_source()
        for name in REQUIRED_RANGES:
            with self.subTest(token=name):
                match = re.search(rf"{name}:\s*\{{([^}}]+)\}}", text)
                self.assertIsNotNone(match, f"{name} missing from tokens.js")
                body = match.group(1)
                for key in ("min", "max", "step", "value"):
                    self.assertIn(key, body)

    def test_typography_scale_is_complete(self) -> None:
        text = tokens_source()
        match = re.search(r"scale:\s*\{(.*?)\}", text, re.S)
        self.assertIsNotNone(match)
        names = set(re.findall(r"(\w+):\s*[\d.]+", match.group(1)))
        self.assertTrue(REQUIRED_SCALE <= names, REQUIRED_SCALE - names)

    def test_python_defaults_match_the_qml_tokens(self) -> None:
        text = tokens_source()
        for name in ("spacing", "radius", "blur", "opacity"):
            with self.subTest(token=name):
                match = re.search(rf"{name}:\s*\{{[^}}]*value:\s*([\d.]+)", text)
                self.assertIsNotNone(match, f"{name} value missing")
                self.assertAlmostEqual(float(match.group(1)), float(style.DEFAULTS[name]), places=2)

        base = re.search(r"base:\s*(\d+)", text)
        self.assertIsNotNone(base, "font base missing")
        self.assertEqual(int(base.group(1)), style.DEFAULTS["fontBase"])

    def test_style_roundtrip(self) -> None:
        sample = {
            "version": 1,
            "surface": "solid",
            "tokens": {"spacing": 9, "radius": 4, "blur": 2, "opacity": 0.75, "fontBase": 15},
        }
        parsed = json.loads(json.dumps(sample))
        self.assertEqual(parsed["tokens"]["fontBase"], 15)


def variant_names(family: str) -> set[str]:
    text = VARIANTS.read_text(encoding="utf-8")
    match = re.search(rf"property var {family}:\s*\(\{{(.*?)\n    \}}\)", text, re.S)
    if match is None:
        return set()
    return set(re.findall(r"^\s+(\w+):\s*\{", match.group(1), re.M))


def style_defaults() -> dict[str, str]:
    text = STYLE.read_text(encoding="utf-8")
    match = re.search(r"defaults:\s*\(\{(.*?)\}\)", text, re.S)
    assert match is not None, "VitrailStyle.defaults missing"
    return dict(re.findall(r"(\w+):\s*\"(\w+)\"", match.group(1)))


class VariantContractTests(unittest.TestCase):
    def test_frame_and_bar_variants_exist(self) -> None:
        self.assertEqual(variant_names("frame"), {"full", "corners", "none"})
        self.assertEqual(variant_names("bar"), {"docked", "floating", "islands", "floatingIslands"})

    def test_panel_and_wallpaper_variants_exist(self) -> None:
        self.assertEqual(variant_names("panel"), {"full", "overlay"})
        self.assertEqual(variant_names("wallpaper"), {"frame", "screen"})

    def test_the_three_approved_visualiser_looks_exist(self) -> None:
        self.assertEqual(variant_names("visualiser"), {"bars", "reflection", "panel"})

    def test_launcher_has_a_popout_and_a_fullscreen_variant_over_real_tokens(self) -> None:
        self.assertEqual(variant_names("launcher"), {"popout", "fullscreen"})
        text = VARIANTS.read_text(encoding="utf-8")
        tokens = tokens_source()
        for name in re.findall(r'metrics:\s*"(\w+)"', text):
            with self.subTest(metrics=name):
                self.assertRegex(tokens, rf"\b{name}:\s*\{{")

    def test_every_default_names_a_declared_variant(self) -> None:
        for family, name in style_defaults().items():
            with self.subTest(family=family):
                self.assertIn(name, variant_names(family))


class StyleFileTests(unittest.TestCase):
    def test_import_preserves_key_case(self) -> None:
        import tempfile
        from pathlib import Path

        with tempfile.TemporaryDirectory() as tmp:
            config = Path(tmp)
            (config / "appearance.ini").write_text("[appearance]\nsurfaceStyle=glass\nradius=14\n", encoding="utf-8")
            (config / "language.ini").write_text("[language]\nlanguage=es\n", encoding="utf-8")
            style.write_style(
                {"surface": "solid", "tokens": {"spacing": 8, "radius": 6}},
                config,
            )
            text = (config / "appearance.ini").read_text(encoding="utf-8")
            self.assertIn("surfaceStyle=solid", text)
            self.assertIn("radius=6", text)
            self.assertNotIn("surfacestyle", text)
            self.assertIn("language=es", (config / "language.ini").read_text(encoding="utf-8"))


class ComposedLayerTests(unittest.TestCase):
    """Composed components may not contain visual primitives."""

    def test_no_raw_primitives_in_composed(self) -> None:
        if not COMPOSED.is_dir():
            self.skipTest("kit/composed does not exist yet")
        for path in COMPOSED.rglob("*.qml"):
            text = path.read_text(encoding="utf-8")
            for primitive in ("Text {", "Rectangle {", "MouseArea {"):
                with self.subTest(file=path.name, primitive=primitive):
                    self.assertNotIn(primitive, text)


class GlassLayerRuleTests(unittest.TestCase):
    """Every translucent bar layer is blurred by the vitrail-glass rule, in
    the config and in the rule apply-settings.sh redefines."""

    def test_both_rules_cover_every_glass_namespace(self) -> None:
        layers = "".join(
            path.read_text(encoding="utf-8")
            for path in sorted((ROOT / "bar").rglob("*.qml"))
            if not path.is_relative_to(ROOT / "bar" / "kit")
        )
        used = set(re.findall(r'namespace:\s*"vitrail-(\w+)"', layers)) - {"wallpaper", "reserve"}
        for path in (ROOT / "dots" / ".config" / "hypr" / "hyprland.lua", ROOT / "scripts" / "apply-settings.sh"):
            match = re.search(r"\^vitrail-\(([\w|]+)\)", path.read_text(encoding="utf-8"))
            self.assertIsNotNone(match, path.name)
            with self.subTest(file=path.name):
                self.assertEqual(used - set(match.group(1).split("|")), set())


class SurfaceInheritanceTests(unittest.TestCase):
    """Every surface takes glass / solid and its opacity from one source."""

    def test_no_fixed_surface_alpha(self) -> None:
        files = [*KIT.rglob("*.qml"), *(ROOT / "bar").rglob("*.qml")]
        for path in files:
            if path.is_symlink() or any(p.is_symlink() for p in path.parents if p != ROOT):
                continue
            text = path.read_text(encoding="utf-8")
            with self.subTest(file=str(path.relative_to(ROOT))):
                self.assertNotRegex(
                    text, r"(?m)opacityLevel:\s*[0-9.]+\s*$", "use shell.barOpacity or VitrailTokens.opacity"
                )
                self.assertNotRegex(text, r"style:\s*\"(glass|solid)\"", "use VitrailTokens.surfaceMode")

    def test_surface_variants_define_the_raised_layer(self) -> None:
        text = VARIANTS.read_text(encoding="utf-8")
        for key in ("raised", "raisedHover"):
            self.assertEqual(len(re.findall(rf"\b{key}:", text)), 2, key)


if __name__ == "__main__":
    unittest.main()
