"""The keybind cheatsheet: Hyprland's binds, ready for the overlay.

`hyprctl binds -j` reports a bitfield of modifiers, the key and the bind's
description. The rows are the same data with the modifiers spelled out and the
key written the way a person reads it; without Hyprland the state says so
instead of failing.
"""

from __future__ import annotations

import json
import unittest
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
from unittest.mock import patch

from vitrail import binds, cli

ROOT = Path(__file__).resolve().parent.parent

SAMPLE = json.dumps([
    {"modmask": 64, "key": "Q", "dispatcher": "__lua", "arg": "5", "description": "window/close"},
    {"modmask": 65, "key": "left", "dispatcher": "__lua", "arg": "41", "description": "move/left"},
    {"modmask": 72, "key": "period", "dispatcher": "__lua", "arg": "25", "description": "shell/clipboard-colors"},
    {"modmask": 0, "key": "XF86AudioRaiseVolume", "dispatcher": "__lua", "arg": "93", "description": "media/volume-up"},
    {"modmask": 64, "key": "mouse:272", "dispatcher": "__lua", "arg": "89", "description": "mouse/drag"},
    {"modmask": 64, "key": "mouse_down", "dispatcher": "__lua", "arg": "85", "description": "workspace/next"},
])


class ModifierTests(unittest.TestCase):
    def test_the_modmask_is_spelled_out(self) -> None:
        self.assertEqual(binds.mods_of(64), "Super")
        self.assertEqual(binds.mods_of(65), "Super+Shift")
        self.assertEqual(binds.mods_of(72), "Super+Alt")
        self.assertEqual(binds.mods_of(68), "Super+Ctrl")
        self.assertEqual(binds.mods_of(0), "")

    def test_modifiers_keep_the_readable_order(self) -> None:
        self.assertEqual(binds.mods_of(64 | 4 | 8 | 1), "Super+Ctrl+Alt+Shift")
        self.assertEqual(binds.mods_of(3), "Shift+Caps")

    def test_unknown_bits_are_ignored(self) -> None:
        self.assertEqual(binds.mods_of(512), "")
        self.assertEqual(binds.mods_of(64 | 512), "Super")


class KeyTests(unittest.TestCase):
    def test_letters_and_digits_are_upper_case(self) -> None:
        self.assertEqual(binds.key_label("q"), "Q")
        self.assertEqual(binds.key_label("Q"), "Q")
        self.assertEqual(binds.key_label("1"), "1")
        self.assertEqual(binds.key_label("F5"), "F5")

    def test_named_keys_read_like_the_keyboard(self) -> None:
        self.assertEqual(binds.key_label("return"), "Enter")
        self.assertEqual(binds.key_label("slash"), "/")
        self.assertEqual(binds.key_label("comma"), ",")
        self.assertEqual(binds.key_label("period"), ".")
        self.assertEqual(binds.key_label("space"), "Space")
        self.assertEqual(binds.key_label("escape"), "Esc")

    def test_special_keys_are_spelled_out(self) -> None:
        self.assertEqual(binds.key_label("left"), "←")
        self.assertEqual(binds.key_label("right"), "→")
        self.assertEqual(binds.key_label("up"), "↑")
        self.assertEqual(binds.key_label("down"), "↓")
        self.assertEqual(binds.key_label("mouse_down"), "Wheel Down")
        self.assertEqual(binds.key_label("mouse_up"), "Wheel Up")
        self.assertEqual(binds.key_label("mouse:272"), "Left Click")
        self.assertEqual(binds.key_label("mouse:273"), "Right Click")
        self.assertEqual(binds.key_label("XF86AudioRaiseVolume"), "Volume Up")


class RowTests(unittest.TestCase):
    def test_rows_carry_everything_the_overlay_shows(self) -> None:
        rows = binds.rows(SAMPLE)
        self.assertEqual(len(rows), 6)
        self.assertEqual(rows[0], {
            "mods": "Super", "key": "Q", "dispatcher": "__lua", "arg": "5", "description": "window/close",
        })
        self.assertEqual(rows[1]["mods"], "Super+Shift")
        self.assertEqual(rows[1]["key"], "←")
        self.assertEqual(rows[2]["mods"], "Super+Alt")
        self.assertEqual(rows[2]["key"], ".")
        self.assertEqual(rows[3]["mods"], "")
        self.assertEqual(rows[3]["key"], "Volume Up")
        self.assertEqual(rows[4]["key"], "Left Click")
        self.assertEqual(rows[5]["key"], "Wheel Down")

    def test_a_bind_without_a_description_falls_back_to_its_dispatcher(self) -> None:
        rows = binds.rows(json.dumps([{"modmask": 64, "key": "Q", "dispatcher": "killactive"}]))
        self.assertEqual(rows[0]["description"], "killactive")
        self.assertEqual(rows[0]["arg"], "")

    def test_a_bind_without_a_key_is_skipped(self) -> None:
        rows = binds.rows(json.dumps([{"modmask": 64, "key": "", "description": "nothing"}]))
        self.assertEqual(rows, [])

    def test_invalid_or_foreign_json_is_no_rows(self) -> None:
        for text in ("", "not json", "{}", '"a string"', "null", "42"):
            with self.subTest(text=text):
                self.assertEqual(binds.rows(text), [])


class StateTests(unittest.TestCase):
    def test_hyprlands_answer_becomes_the_state(self) -> None:
        self.assertEqual(binds.state(run=lambda: SAMPLE), {"available": True, "rows": binds.rows(SAMPLE)})

    def test_an_empty_list_is_available_and_empty(self) -> None:
        self.assertEqual(binds.state(run=lambda: "[]"), {"available": True, "rows": []})

    def test_broken_json_is_unavailable(self) -> None:
        self.assertEqual(binds.state(run=lambda: "not json"), {"available": False, "rows": []})

    def test_without_hyprland_the_state_is_empty(self) -> None:
        self.assertEqual(binds.state(run=lambda: ""), {"available": False, "rows": []})

        def missing() -> str:
            raise OSError("hyprctl not found")

        self.assertEqual(binds.state(run=missing), {"available": False, "rows": []})

    def test_the_state_reads_hyprctl_by_default(self) -> None:
        with patch.object(binds, "run_text", return_value=SAMPLE):
            self.assertEqual(binds.state(), {"available": True, "rows": binds.rows(SAMPLE)})

    def test_the_cli_prints_the_state(self) -> None:
        buffer = StringIO()
        with patch.object(binds, "run_text", return_value=SAMPLE), redirect_stdout(buffer):
            self.assertEqual(cli.main(["binds", "state"]), 0)
        self.assertEqual(json.loads(buffer.getvalue()), {"available": True, "rows": binds.rows(SAMPLE)})


class PackagingTests(unittest.TestCase):
    def test_the_binary_toggles_the_popup_through_the_bar(self) -> None:
        text = (ROOT / "bin" / "vitrail-binds").read_text(encoding="utf-8")
        self.assertIn("ipc call binds toggle", text)

    def test_the_installer_links_the_binary(self) -> None:
        text = (ROOT / "install.sh").read_text(encoding="utf-8")
        self.assertIn("vitrail-binds", text)

    def test_super_slash_opens_the_cheatsheet(self) -> None:
        text = (ROOT / "dots" / ".config" / "hypr" / "hyprland.lua").read_text(encoding="utf-8")
        self.assertIn('mod .. " + slash"', text)
        self.assertIn("vitrail-binds", text)


if __name__ == "__main__":
    unittest.main()
