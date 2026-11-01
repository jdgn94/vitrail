"""The bundled emoji set: built by scripts/build-emoji.py from Unicode data."""

from __future__ import annotations

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "assets" / "emoji.json"
GROUPS = {
    "Smileys & Emotion", "People & Body", "Animals & Nature", "Food & Drink",
    "Travel & Places", "Activities", "Objects", "Symbols", "Flags",
}


class EmojiDataTests(unittest.TestCase):
    def setUp(self) -> None:
        self.rows = json.loads(DATA.read_text(encoding="utf-8"))

    def test_the_set_is_complete_enough(self) -> None:
        self.assertGreater(len(self.rows), 3000)

    def test_every_row_has_a_character_group_and_words(self) -> None:
        for row in self.rows:
            self.assertTrue(row["e"])
            self.assertTrue(row["n"])
            self.assertIn(row["g"], GROUPS)
            self.assertTrue(row["k"])

    def test_the_nine_groups_are_all_represented(self) -> None:
        self.assertEqual({row["g"] for row in self.rows}, GROUPS)

    def test_the_words_carry_both_languages(self) -> None:
        grin = next(row for row in self.rows if row["e"] == "😀")
        self.assertIn("grin", grin["k"])
        self.assertIn("sonrisa", grin["k"])
