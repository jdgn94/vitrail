"""The Lua file Hyprland loads at login: the saved settings, safely quoted."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from vitrail import hyprsettings

ROOT = Path(__file__).resolve().parent.parent


class KeyboardTests(unittest.TestCase):
    def test_two_layouts_become_a_list_and_empty_variants(self) -> None:
        self.assertEqual(hyprsettings.keyboard("latam:|us:"), ("latam,us", ","))

    def test_a_variant_stays_aligned_with_its_layout(self) -> None:
        self.assertEqual(hyprsettings.keyboard("us:|es:nodeadkeys"), ("us,es", ",nodeadkeys"))

    def test_nothing_saved_is_english(self) -> None:
        self.assertEqual(hyprsettings.keyboard(""), ("us", ""))


class RenderTests(unittest.TestCase):
    def test_the_saved_layouts_reach_the_input_block(self) -> None:
        text = hyprsettings.render(
            {"keyboardLayouts": "latam:|us:", "keyboardSwitch": "grp:alt_shift_toggle", "numlockOnStart": "false"}
        )
        self.assertIn('kb_layout = "latam,us"', text)
        self.assertIn('kb_variant = ","', text)
        self.assertIn('kb_options = "grp:alt_shift_toggle"', text)
        self.assertIn("numlock_by_default = false", text)

    def test_the_look_reaches_the_file(self) -> None:
        text = hyprsettings.render(
            {
                "radius": "16",
                "borderWidth": "3",
                "opacityFocused": "0.95",
                "opacityUnfocused": "0.85",
                "blurStrength": "8",
                "surfaceStyle": "solid",
                "windowLayout": "scrolling",
                "visibleColumns": "2",
                "focusFollowsMouse": "false",
            }
        )
        for line in (
            "rounding = 16",
            "border_size = 3",
            "active_opacity = 0.95",
            "inactive_opacity = 0.85",
            "enabled = false",
            "size = 8",
            'layout = "scrolling"',
            "column_width = 0.5000",
            "follow_mouse = 0",
        ):
            self.assertIn(line, text)

    def test_defaults_match_the_apply_script(self) -> None:
        text = hyprsettings.render({})
        self.assertIn('kb_layout = "us"', text)
        self.assertIn("rounding = 14", text)
        self.assertIn("active_opacity = 0.97", text)
        self.assertIn("enabled = true", text)

    def test_a_value_cannot_leave_its_string(self) -> None:
        text = hyprsettings.render({"keyboardSwitch": 'x"})\nos.execute("id")--', "keyboardLayouts": 'us:a"b|de:\\'})
        self.assertNotIn("\nos.execute", text)
        self.assertIn('kb_options = "x\\"})\\010os.execute(\\"id\\")--"', text)
        self.assertIn('kb_variant = "a\\"b,\\\\"', text)

    def test_a_number_that_is_not_one_falls_back(self) -> None:
        text = hyprsettings.render({"radius": "1)}os.exit()", "opacityFocused": "9", "borderWidth": "x"})
        self.assertIn("rounding = 14", text)
        self.assertIn("active_opacity = 0.97", text)
        self.assertIn("border_size = 2", text)
        self.assertNotIn("os.exit", text)

    def test_an_unknown_layout_mode_falls_back(self) -> None:
        self.assertIn('layout = "dwindle"', hyprsettings.render({"windowLayout": '"; evil'}))


class WriteTests(unittest.TestCase):
    def test_write_reads_the_preference_files(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            config = Path(tmp) / "vitrail"
            config.mkdir()
            (config / "input.ini").write_text("[input]\nkeyboardLayouts=latam:|us:\n", encoding="utf-8")
            out = Path(tmp) / "hypr" / hyprsettings.FILE
            hyprsettings.write(config, out)
            self.assertIn('kb_layout = "latam,us"', out.read_text(encoding="utf-8"))

    def test_the_hyprland_config_loads_it_after_its_own_defaults(self) -> None:
        text = (ROOT / "dots" / ".config" / "hypr" / "hyprland.lua").read_text(encoding="utf-8")
        loaded = text.index("vitrail-settings.lua")
        self.assertGreater(loaded, text.index("hl.config({"))
        self.assertLess(loaded, text.index("hl.on("))

    def test_the_apply_script_writes_it_before_checking_for_hyprland(self) -> None:
        text = (ROOT / "scripts" / "apply-settings.sh").read_text(encoding="utf-8")
        self.assertLess(text.index("vitrail.hyprsettings"), text.index("if command -v hyprctl"))


if __name__ == "__main__":
    unittest.main()
