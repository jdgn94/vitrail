"""The dock's preference file: every key in dock.ini, round-tripped by key."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from vitrail import prefs

ROOT = Path(__file__).resolve().parent.parent
DOCK_KEYS = {
    "dockEnabled",
    "dockEdge",
    "dockAutohide",
    "dockAttached",
    "dockMagnify",
    "dockMagnifyRange",
    "dockMagnifyScale",
    "dockPinned",
    "dockWidgets",
}
DEFAULTS = {
    "dockEnabled": "false",
    "dockEdge": "bottom",
    "dockAutohide": "false",
    "dockAttached": "true",
    "dockMagnify": "planet",
    "dockMagnifyRange": "2",
    "dockMagnifyScale": "1.32",
    "dockPinned": "[]",
    "dockWidgets": "[]",
}


class DockClickTests(unittest.TestCase):
    """A dock click lands where the window (or the pointer) is."""

    def setUp(self) -> None:
        self.shell = (ROOT / "bar" / "shell.qml").read_text(encoding="utf-8")

    def test_an_open_app_activates_its_workspace(self) -> None:
        self.assertIn('Hyprland.dispatch("workspace " + Number(app.workspace))', self.shell)
        self.assertIn("Number(app.workspace) > 0", self.shell)

    def test_a_closed_app_opens_on_the_dock_s_output(self) -> None:
        # The pointer is over the dock, so the dock's output is the one under
        # the mouse; focusing it puts the new window on its active workspace.
        self.assertIn('Hyprland.dispatch("focusmonitor " + screen.name)', self.shell)


class DockMapTests(unittest.TestCase):
    def test_every_dock_key_lives_in_dock_ini(self) -> None:
        for key in DOCK_KEYS:
            with self.subTest(key=key):
                self.assertEqual(prefs.file_of(key), "dock")

    def test_dock_ini_is_a_watched_file(self) -> None:
        self.assertIn("dock", prefs.FILES)
        unit = (ROOT / "dots/.config/systemd/user/vitrail-settings.path").read_text(encoding="utf-8")
        self.assertIn("%h/.config/vitrail/dock.ini", unit)

    def test_the_readme_lists_every_dock_key(self) -> None:
        text = (ROOT / "README.md").read_text(encoding="utf-8")
        row = next(line for line in text.splitlines() if line.startswith("| `dock.ini` |"))
        for key in DOCK_KEYS:
            with self.subTest(key=key):
                self.assertIn(f"`{key}`", row)


class DockLauncherTests(unittest.TestCase):
    def test_the_launcher_menu_uses_the_shared_dock_row(self) -> None:
        text = (ROOT / "bar" / "launcher" / "Launcher.qml").read_text(encoding="utf-8")
        self.assertIn("Dock.menuRow(", text)
        self.assertIn('case "dockPin":', text)
        self.assertIn("dockPinRequested", text)

    def test_the_shell_wires_the_dock_layer_and_its_pin_action(self) -> None:
        text = (ROOT / "bar" / "shell.qml").read_text(encoding="utf-8")
        self.assertIn("DockLayer {", text)
        self.assertIn("toggleDockPin(item)", text)
        self.assertIn("shell.dockPinnedList", text)


class DockRoundTripTests(unittest.TestCase):
    def test_writing_and_reading_every_key_returns_the_same_values(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            config = Path(tmp)
            pinned = json.dumps(
                [
                    {"id": "firefox.desktop", "desktop": "firefox.desktop", "name": "Firefox", "icon": "firefox"},
                    {"id": "kitty.desktop", "desktop": "kitty.desktop", "name": "Kitty", "icon": "kitty"},
                ]
            )
            values = dict(DEFAULTS)
            values.update(
                {
                    "dockEnabled": "true",
                    "dockEdge": "left",
                    "dockAutohide": "true",
                    "dockAttached": "false",
                    "dockMagnify": "individual",
                    "dockMagnifyRange": "4",
                    "dockMagnifyScale": "1.75",
                    "dockPinned": pinned,
                }
            )
            for key, value in values.items():
                prefs.write_pref(config, key, value)

            read = prefs.read_prefs(config)
            self.assertEqual({key: read[key] for key in DOCK_KEYS}, values)
            self.assertEqual(json.loads(read["dockPinned"])[1]["name"], "Kitty")
            self.assertEqual(prefs.validate(config), [])

    def test_old_magnification_values_are_migrated_to_planet(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            config = Path(tmp)
            for old in ("scale", "lift"):
                with self.subTest(old=old):
                    prefs.write_pref(config, "dockMagnify", old)
                    self.assertTrue(prefs.migrate(config))
                    self.assertEqual(prefs.read_prefs(config)["dockMagnify"], "planet")
            self.assertFalse(prefs.migrate(config))

    def test_a_dock_document_survives_a_qsettings_quoted_value(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            config = Path(tmp)
            path = config / "dock.ini"
            document = json.dumps([{"id": "a.desktop", "name": "A", "icon": "a"}])
            quoted = '"' + document.replace("\\", "\\\\").replace('"', '\\"') + '"'
            path.write_text(f"[dock]\ndockPinned={quoted}\n", encoding="utf-8")
            self.assertEqual(prefs.read_prefs(config)["dockPinned"], document)


if __name__ == "__main__":
    unittest.main()
