"""The palette-adaptive icon layer: folder hues follow the wallpaper."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from vitrail import icons

SVG = """<svg xmlns="http://www.w3.org/2000/svg">
 <path style="fill:#5294e2" d="M0 0"/>
 <path style="fill:#4877b1" d="M0 0"/>
 <rect style="opacity:0.2;fill:#e4e4e4" width="1" height="1"/>
</svg>"""

PRIMARY = "#ff0000"


class TintTests(unittest.TestCase):
    def test_the_body_is_the_most_frequent_saturated_colour(self) -> None:
        self.assertEqual(icons.body(SVG), "#5294e2")

    def test_a_symbolic_icon_has_no_body(self) -> None:
        self.assertIsNone(icons.body('<path style="fill:currentColor"/>'))

    def test_the_folder_hue_moves_to_the_palette_while_the_shading_stays(self) -> None:
        out = icons.tint_svg(SVG, {"primary": PRIMARY})
        self.assertNotIn("#5294e2", out)
        self.assertNotIn("#4877b1", out)
        self.assertIn("#e4e4e4", out)  # the paper stays grey
        for value in icons.colours(out):
            if value in ("#e4e4e4",):
                continue
            hue, _lightness, _saturation = icons._hsl(value)
            self.assertLess(hue, 0.04)  # red

    def test_a_colour_far_from_the_body_is_left_alone(self) -> None:
        text = '<path style="fill:#5294e2"/><path style="fill:#2ec27e"/>'
        out = icons.tint_svg(text, {"primary": PRIMARY})
        self.assertIn("#2ec27e", out)

    def test_without_a_primary_colour_nothing_changes(self) -> None:
        self.assertEqual(icons.tint_svg(SVG, {}), SVG)


class BuildTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.icons = self.root / "icons"
        self.pack = self.icons / "Papirus"
        (self.pack / "48x48" / "places").mkdir(parents=True)
        (self.pack / "48x48" / "places" / "folder.svg").write_text(SVG, encoding="utf-8")
        (self.pack / "48x48" / "places" / "folder-symbolic.svg").write_text(SVG, encoding="utf-8")
        (self.pack / "48x48" / "places" / "text-x-generic.svg").write_text(SVG, encoding="utf-8")
        (self.pack / "index.theme").write_text(
            "[Icon Theme]\nDirectories=48x48/places\nInherits=hicolor\n\n[48x48/places]\nSize=48\n", encoding="utf-8"
        )
        self.base = self.icons / "hicolor"
        (self.base / "48x48" / "places").mkdir(parents=True)
        (self.base / "48x48" / "places" / "folder-open.svg").write_text(SVG, encoding="utf-8")
        (self.base / "index.theme").write_text(
            "[Icon Theme]\nDirectories=48x48/places\n\n[48x48/places]\nSize=48\n", encoding="utf-8"
        )
        self.target = self.icons / "vitrail-icons-Papirus"
        self.cache = self.root / "cache"

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def build(self, primary: str = PRIMARY) -> bool:
        return icons.build(self.pack, self.target, {"primary": primary}, self.cache, [self.icons])

    def test_only_the_folder_svgs_are_written(self) -> None:
        self.assertTrue(self.build())
        self.assertTrue((self.target / "48x48" / "places" / "folder.svg").is_file())
        self.assertTrue((self.target / "48x48" / "places" / "folder-open.svg").is_file())
        self.assertFalse((self.target / "48x48" / "places" / "folder-symbolic.svg").exists())
        self.assertFalse((self.target / "48x48" / "places" / "text-x-generic.svg").exists())

    def test_the_theme_inherits_the_pack(self) -> None:
        self.build()
        theme = (self.target / "index.theme").read_text(encoding="utf-8")
        self.assertIn("Inherits=Papirus", theme)
        self.assertIn("Directories=48x48/places", theme)

    def test_a_current_theme_is_not_rebuilt(self) -> None:
        self.build()
        stamp = (self.target / "index.theme").stat().st_mtime_ns
        self.assertFalse(self.build())
        self.assertEqual((self.target / "index.theme").stat().st_mtime_ns, stamp)

    def test_a_new_primary_rebuilds_it(self) -> None:
        self.build()
        self.assertTrue(self.build(primary="#00ff00"))

    def test_a_pack_without_folders_is_not_built(self) -> None:
        bare = self.icons / "Bare"
        bare.mkdir()
        (bare / "index.theme").write_text("[Icon Theme]\n", encoding="utf-8")
        self.assertFalse(
            icons.build(bare, bare.with_name("vitrail-icons-Bare"), {"primary": PRIMARY}, self.cache, [self.icons])
        )

    def test_the_cli_builds_an_installed_pack(self) -> None:
        code = icons.main(
            ["build", "Papirus"], roots=[self.icons], palette={"primary": PRIMARY}, output=self.icons, cache=self.cache
        )
        self.assertEqual(code, 0)
        self.assertTrue((self.icons / "vitrail-icons-Papirus" / "index.theme").is_file())

    def test_the_cli_refuses_a_missing_pack(self) -> None:
        self.assertEqual(
            icons.main(
                ["build", "Nope"], roots=[self.icons], palette={"primary": PRIMARY}, output=self.icons, cache=self.cache
            ),
            2,
        )

    def test_the_name_round_trips(self) -> None:
        self.assertEqual(icons.design_name("Papirus"), "vitrail-icons-Papirus")
        self.assertEqual(icons.source_of("vitrail-icons-Papirus"), "Papirus")
        self.assertEqual(icons.source_of("Adwaita"), "")


if __name__ == "__main__":
    unittest.main()
