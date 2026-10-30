"""Validates the per-language files that feed the QML bundle."""

from __future__ import annotations

import importlib.util
import json
import re
import shutil
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
I18N_DIR = ROOT / "kit" / "i18n"
QML_DIRS = ("shell", "kit", "login", "lock", "bar")
REFERENCE = "en"


def bundle_module():
    spec = importlib.util.spec_from_file_location(
        "i18n_bundle", ROOT / "scripts" / "i18n-bundle.py"
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class TranslationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.module = bundle_module()
        self.languages = self.module.load()

    def test_every_file_has_a_label(self) -> None:
        for code, table in self.languages.items():
            with self.subTest(language=code):
                self.assertTrue(table["_label"].strip())

    def test_languages_share_the_same_keys(self) -> None:
        reference = set(self.languages[REFERENCE])
        for code, table in self.languages.items():
            with self.subTest(language=code):
                self.assertEqual(set(table), reference)

    def test_no_empty_values(self) -> None:
        for code, table in self.languages.items():
            for key, value in table.items():
                with self.subTest(language=code, key=key):
                    self.assertTrue(value.strip())

    def test_there_is_no_generated_bundle_in_the_repo(self) -> None:
        self.assertFalse((ROOT / "kit" / "i18n.js").exists())

    def test_bundle_lists_every_language(self) -> None:
        data = self.module.bundle()
        self.assertEqual(
            sorted(entry["key"] for entry in data["languages"]),
            sorted(self.languages),
        )
        for entry in data["languages"]:
            self.assertEqual(entry["label"], self.languages[entry["key"]]["_label"])

    def test_adding_a_file_adds_a_language(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp)
            shutil.copy(I18N_DIR / "en.json", source / "en.json")
            dutch = json.loads((I18N_DIR / "en.json").read_text(encoding="utf-8"))
            dutch["_label"] = "Nederlands"
            (source / "nl.json").write_text(json.dumps(dutch), encoding="utf-8")

            self.module.SOURCE_DIR = source
            keys = [entry["key"] for entry in self.module.bundle()["languages"]]
            self.assertIn("nl", keys)
            self.assertIn("Nederlands", (source / "nl.json").read_text(encoding="utf-8"))

    def test_every_key_used_in_qml_exists(self) -> None:
        used: set[str] = set()
        for folder in QML_DIRS:
            for path in (ROOT / folder).rglob("*.qml"):
                used |= set(re.findall(r'\.t\("([^"]+)"\)', path.read_text(encoding="utf-8")))
        self.assertTrue(used)
        self.assertEqual(used - set(self.languages[REFERENCE]), set())


if __name__ == "__main__":
    unittest.main()
