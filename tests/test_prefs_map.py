"""vitrail/prefs.map is the one place that says which file holds a preference.

These tests read the Python, QML, shell and systemd sources and fail when a key
is used that the map does not list, when the settings window declares a key in
the wrong file, or when the path unit watches a different set of files.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path

from vitrail import prefs, style

ROOT = Path(__file__).resolve().parent.parent
KEYS = {key for _name, key in prefs.PAIRS}
# Read by the migration of old settings, never shown in the window.
LEGACY_ONLY = {"wallpaperSeed"}


def sources(folders: list[str], suffixes: tuple[str, ...]) -> list[Path]:
    return [
        path for folder in folders for path in (ROOT / folder).rglob("*")
        if path.suffix in suffixes and "__pycache__" not in path.parts
    ]


def used(pattern: str, files: list[Path]) -> dict[str, set[str]]:
    """Each key matched by `pattern` (group 1) and the files that use it."""
    found: dict[str, set[str]] = {}
    for path in files:
        for key in re.findall(pattern, path.read_text(encoding="utf-8")):
            found.setdefault(key, set()).add(str(path.relative_to(ROOT)))
    return found


class MapTests(unittest.TestCase):
    def test_every_key_is_in_exactly_one_file(self) -> None:
        keys = [key for _name, key in prefs.PAIRS]
        self.assertEqual(len(keys), len(set(keys)))

    def test_misc_holds_the_smoke_test_key(self) -> None:
        self.assertEqual(prefs.file_of("selftest"), "misc")
        self.assertIn("misc.ini", (ROOT / "tests" / "qml_smoke.sh").read_text(encoding="utf-8"))

    def assert_known(self, found: dict[str, set[str]]) -> None:
        self.assertTrue(found, "the scan found no keys: its pattern is stale")
        unknown = {key: sorted(where) for key, where in found.items() if key not in KEYS}
        self.assertEqual(unknown, {}, "keys missing from vitrail/prefs.map")

    def test_qml_and_js_only_read_mapped_keys(self) -> None:
        files = sources(["shell", "bar", "kit", "gallery", "login", "lock"], (".qml", ".js"))
        self.assert_known(used(r"\bprefs\.(?!map\b|js\b)([A-Za-z]\w*)", files))

    def test_the_apply_script_only_reads_mapped_keys(self) -> None:
        files = sources(["scripts"], (".sh",))
        self.assert_known(used(r"\$\(read_ini\s+(\w+)", files))

    def test_python_only_uses_mapped_keys(self) -> None:
        files = sources(["vitrail"], (".py",))
        self.assert_known(used(r"\bprefs\.get\(\"(\w+)\"", files))
        self.assert_known(used(r"\b(?:write_pref|remove_pref)\([^,]+,\s*\"(\w+)\"", files))
        self.assert_known({key: {"style.INI_KEYS"} for key in [*style.INI_KEYS.values(), "surfaceStyle"]})
        self.assert_known({key: {"prefs.CHOICES"} for key in prefs.CHOICES})


class SettingsWindowTests(unittest.TestCase):
    """shell/Prefs.qml declares one Settings per file."""

    def declared(self) -> dict[str, str]:
        """Key -> file, as declared in the window's preferences object."""
        text = (ROOT / "shell" / "Prefs.qml").read_text(encoding="utf-8")
        found: dict[str, str] = {}
        for block in re.split(r"\n    property Settings ", text)[1:]:
            name = re.search(r'fileName: root\.directory \+ "/(\w+)\.ini"', block).group(1)
            self.assertIn(f'category: "{name}"', block)
            for key in re.findall(r"^        property \w+ (\w+):", block, re.M):
                self.assertNotIn(key, found, f"{key} declared twice")
                found[key] = name
        return found

    def test_every_key_is_declared_in_its_own_file(self) -> None:
        declared = self.declared()
        self.assertEqual(
            {key: prefs.file_of(key) for key in declared}, declared,
            "a key is declared in a different file than prefs.map says")

    def test_every_key_but_the_legacy_ones_is_declared(self) -> None:
        self.assertEqual(KEYS - LEGACY_ONLY, set(self.declared()))

    def test_every_key_is_aliased_for_the_pages(self) -> None:
        text = (ROOT / "shell" / "Prefs.qml").read_text(encoding="utf-8")
        aliases = set(re.findall(r"property alias (\w+):", text))
        self.assertEqual(aliases, set(self.declared()))


class ReadmeTests(unittest.TestCase):
    def test_the_readme_table_lists_each_key_in_its_file(self) -> None:
        rows = {
            match.group(1): match.group(2)
            for match in re.finditer(
                r"^\| `(\w+)\.ini` \| (.*) \|$",
                (ROOT / "README.md").read_text(encoding="utf-8"), re.M)
        }
        self.assertEqual(set(rows), set(prefs.FILES))
        for name, key in prefs.PAIRS:
            self.assertIn(f"`{key}`", rows[name], f"{key} is missing from {name}.ini in the README")


class PathUnitTests(unittest.TestCase):
    def test_the_unit_watches_every_file_and_nothing_else(self) -> None:
        unit = (ROOT / "dots/.config/systemd/user/vitrail-settings.path").read_text(encoding="utf-8")
        watched = re.findall(r"^PathChanged=%h/\.config/vitrail/(\w+)\.ini$", unit, re.M)
        self.assertEqual(sorted(watched), sorted(prefs.FILES))
        self.assertNotIn("settings.ini", unit)


if __name__ == "__main__":
    unittest.main()
