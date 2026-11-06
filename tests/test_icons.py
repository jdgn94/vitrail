"""Every Material Symbol named in the QML renders as one glyph.

Icons are written as ligature names ("wifi"); a typo silently renders the
word itself. Qt measures each name in the icon font: a real icon is about
one em wide, a misspelt one is a whole word.
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path

from vitrail import icons

ROOT = Path(__file__).resolve().parent.parent
QML_DIRS = ("bar", "kit", "shell", "gallery")
RUNNER = Path("/usr/lib/qt6/bin/qmltestrunner")
# The value of an icon / glyph property, up to the next comma or brace, and
# the ternary branches that continue it on the following lines.
ICON_VALUE = re.compile(r"\b(?:icon|glyph|endIcon)\s*:\s*([^,}]*)")
GLYPH_LIST = re.compile(r"\bglyphs\s*=\s*\[(.*)\]")
# A table of icons: `icons: ({ left: "arrow", ... })`, possibly over several lines.
ICON_MAP = re.compile(r"\b\w*[iI]cons\s*:\s*\(\{(.*)")
CONTINUATION = re.compile(r"^\s*:\s*(.*)")
NAME = re.compile(r'"([a-z][a-z0-9_]*)"')
# Size tables reuse the `icon` key for a text variant.
NOT_ICONS = {"body", "subtitle", "title", "label", "content", "display"}


def icon_names() -> set[str]:
    names: set[str] = set()
    for folder in QML_DIRS:
        sources = list((ROOT / folder).rglob("*.qml"))
        if folder == "bar":
            sources += (ROOT / "bar" / "session").glob("*.js")
        for path in sources:
            if path.is_relative_to(ROOT / "bar" / "kit"):
                continue
            open_value = False
            in_map = False
            for line in path.read_text(encoding="utf-8").splitlines():
                if in_map or ICON_MAP.search(line):
                    names |= set(NAME.findall(line.split("({", 1)[-1]))
                    in_map = "})" not in line
                    continue
                match = ICON_VALUE.search(line) or GLYPH_LIST.search(line)
                if match:
                    names |= set(NAME.findall(match.group(1)))
                    open_value = line.rstrip().endswith(("?", ":")) or "?" in match.group(1)
                elif open_value and (match := CONTINUATION.match(line)):
                    names |= set(NAME.findall(match.group(1)))
                else:
                    open_value = False
    # The OSD's icon table returns its names.
    for line in (ROOT / "bar" / "osd" / "icons.js").read_text(encoding="utf-8").splitlines():
        if "return" in line:
            names |= set(NAME.findall(line))
    return names - NOT_ICONS


class IconTests(unittest.TestCase):
    def test_icon_tables_and_segmented_options_are_collected(self) -> None:
        names = icon_names()
        self.assertIn("left_panel_open", names)  # BarPage icons table
        self.assertIn("filter_frames", names)  # one-line table
        self.assertIn("light_mode", names)  # { key, icon, label } option
        self.assertIn("volume_off", names)  # bar/osd/icons.js

    def test_every_icon_name_is_a_material_symbol(self) -> None:
        if not RUNNER.exists() or not shutil.which("fc-list"):
            self.skipTest("qmltestrunner or fontconfig missing")
        names = sorted(icon_names())
        self.assertTrue(names)
        family = re.search(r'icons:\s*"([^"]+)"', (ROOT / "kit" / "tokens.js").read_text()).group(1)
        test = f"""
import QtQuick
import QtTest
TestCase {{
    name: "Icons"
    TextMetrics {{ id: metrics; font.family: "{family}"; font.pixelSize: 24 }}
    function test_names() {{
        var bad = []
        var names = {names!r}
        for (var i = 0; i < names.length; i++) {{
            metrics.text = names[i]
            if (metrics.advanceWidth > 30)
                bad.push(names[i])
        }}
        compare(bad, [])
    }}
}}
"""
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "tst_icons.qml"
            target.write_text(test, encoding="utf-8")
            result = subprocess.run(
                [str(RUNNER), "-input", str(target)],
                capture_output=True,
                text=True,
                timeout=60,
                env={**os.environ, "QT_QPA_PLATFORM": "offscreen"},
            )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


class IconZipTests(unittest.TestCase):
    """Importing an icon pack from a .zip and removing a user pack."""

    def setUp(self) -> None:
        self.tmp = tempfile.mkdtemp()
        self.root = Path(self.tmp)
        self.data_home = self.root / "data"
        self.home = self.root / "home"

    def tearDown(self) -> None:
        shutil.rmtree(self.tmp, ignore_errors=True)

    def make_zip(self, entries: dict[str, bytes | str], name: str = "pack.zip") -> Path:
        path = self.root / name
        with zipfile.ZipFile(path, "w") as archive:
            for member, content in entries.items():
                archive.writestr(member, content)
        return path

    def valid_zip(self, name: str = "Acme") -> Path:
        return self.make_zip(
            {
                f"{name}/index.theme": f"[Icon Theme]\nName={name}\nDirectories=48x48/apps\n",
                f"{name}/48x48/apps/editor.svg": "<svg/>",
                f"{name}/48x48/apps/folder.png": b"png",
            }
        )

    def test_a_valid_zip_installs_under_the_data_home(self) -> None:
        target = icons.import_zip(self.valid_zip(), data_home=self.data_home)
        self.assertEqual(target, self.data_home / "icons" / "Acme")
        self.assertTrue((target / "index.theme").is_file())
        self.assertTrue((target / "48x48" / "apps" / "editor.svg").is_file())
        self.assertEqual((target / "48x48" / "apps" / "folder.png").read_bytes(), b"png")

    def test_a_zip_without_index_theme_is_refused(self) -> None:
        path = self.make_zip({"Acme/48x48/apps/editor.svg": "<svg/>"})
        with self.assertRaisesRegex(ValueError, "index.theme"):
            icons.import_zip(path, data_home=self.data_home)
        self.assertFalse((self.data_home / "icons" / "Acme").exists())

    def test_a_zip_without_icons_is_refused(self) -> None:
        path = self.make_zip({"Acme/index.theme": "[Icon Theme]\n"})
        with self.assertRaisesRegex(ValueError, "icon"):
            icons.import_zip(path, data_home=self.data_home)

    def test_a_traversal_entry_is_refused_without_writing_outside(self) -> None:
        path = self.make_zip(
            {
                "Acme/index.theme": "[Icon Theme]\n",
                "Acme/48x48/apps/editor.svg": "<svg/>",
                "Acme/../../escaped.svg": "<svg/>",
            }
        )
        with self.assertRaisesRegex(ValueError, "path"):
            icons.import_zip(path, data_home=self.data_home)
        self.assertFalse((self.root / "escaped.svg").exists())

    def test_an_absolute_entry_is_refused(self) -> None:
        path = self.make_zip(
            {
                "Acme/index.theme": "[Icon Theme]\n",
                "Acme/48x48/apps/editor.svg": "<svg/>",
                "/tmp/escaped.svg": "<svg/>",
            }
        )
        with self.assertRaisesRegex(ValueError, "path"):
            icons.import_zip(path, data_home=self.data_home)

    def test_a_zip_over_the_size_limit_is_refused(self) -> None:
        path = self.make_zip(
            {
                "Acme/index.theme": "[Icon Theme]\n",
                "Acme/48x48/apps/editor.svg": "<svg/>",
                "Acme/48x48/apps/large.png": b"x" * 4096,
            }
        )
        with self.assertRaisesRegex(ValueError, "large"):
            icons.import_zip(path, data_home=self.data_home, max_bytes=1024)
        self.assertFalse((self.data_home / "icons" / "Acme").exists())

    def test_replacing_a_pack_keeps_a_backup(self) -> None:
        first = icons.import_zip(self.valid_zip(), data_home=self.data_home)
        (first / "48x48" / "apps" / "old.svg").write_text("<svg/>", encoding="utf-8")
        icons.import_zip(self.valid_zip(), data_home=self.data_home)
        self.assertFalse((first / "48x48" / "apps" / "old.svg").exists())
        backups = list((self.data_home / "icons" / icons.BACKUP_DIR).iterdir())
        self.assertEqual(len(backups), 1)
        self.assertTrue((backups[0] / "48x48" / "apps" / "old.svg").is_file())

    def test_remove_deletes_only_a_user_pack(self) -> None:
        target = self.data_home / "icons" / "Acme"
        (target / "48x48").mkdir(parents=True)
        (target / "index.theme").write_text("[Icon Theme]\n", encoding="utf-8")
        removed = icons.remove_pack("Acme", data_home=self.data_home, home=self.home)
        self.assertEqual(removed, target)
        self.assertFalse(target.exists())

    def test_remove_reads_the_legacy_home_icons_folder(self) -> None:
        target = self.home / ".icons" / "Acme"
        (target / "48x48").mkdir(parents=True)
        (target / "index.theme").write_text("[Icon Theme]\n", encoding="utf-8")
        self.assertEqual(icons.remove_pack("Acme", data_home=self.data_home, home=self.home), target)
        self.assertFalse(target.exists())

    def test_remove_refuses_a_pack_outside_the_user_roots(self) -> None:
        system = self.root / "usr" / "share" / "icons" / "Adwaita"
        (system / "48x48").mkdir(parents=True)
        (system / "index.theme").write_text("[Icon Theme]\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "user"):
            icons.remove_pack("Adwaita", data_home=self.data_home, home=self.home)
        self.assertTrue(system.exists())

    def test_remove_refuses_a_traversal_name(self) -> None:
        with self.assertRaisesRegex(ValueError, "name"):
            icons.remove_pack("../usr/share/icons/Adwaita", data_home=self.data_home, home=self.home)

    def test_apply_runs_an_import_request_and_refreshes_the_state(self) -> None:
        import json

        from vitrail import fonts

        config = self.root / "config"
        cache = self.root / "cache" / "fonts"
        pack = self.valid_zip()
        code = fonts.apply(
            {"fontSystem": "Roboto", "iconTheme": "Acme", "iconImport": f"123|{pack}"},
            config,
            run=lambda argv: "Roboto\t80\n",
            roots=[self.data_home / "icons"],
            hyprland=False,
            x11=False,
            data_home=self.data_home,
            cache=cache,
        )
        self.assertEqual(code, 0)
        self.assertTrue((self.data_home / "icons" / "Acme" / "index.theme").is_file())
        self.assertIn("iconImport=\n", (config / "vitrail" / "fonts.ini").read_text(encoding="utf-8"))
        result = json.loads((cache.parent / "icons-result.json").read_text(encoding="utf-8"))
        self.assertEqual((result["action"], result["ok"], result["nonce"]), ("import", True, "123"))
        state = json.loads((cache.parent / "fonts-state.json").read_text(encoding="utf-8"))
        self.assertIn("Acme", state["iconThemes"])
        self.assertIn("Acme", state["iconUser"])


if __name__ == "__main__":
    unittest.main()
