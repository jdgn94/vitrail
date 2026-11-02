"""The file manager the desktop names, not a hardcoded one."""

from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from vitrail import files

DESKTOP = """[Desktop Entry]
Name=Files
Exec=nautilus --new-window %U
"""


class DesktopTests(unittest.TestCase):
    def test_the_exec_line_becomes_an_argv(self) -> None:
        self.assertEqual(files.exec_argv("nautilus --new-window %U"), ["nautilus", "--new-window"])
        self.assertEqual(files.exec_argv("dolphin %u"), ["dolphin"])
        self.assertEqual(files.exec_argv('sh -c "echo %f"'), ["sh", "-c", "echo %f"])
        self.assertEqual(files.exec_argv("app --pattern=%%x %f"), ["app", "--pattern=%x"])

    def test_only_a_desktop_entry_in_the_data_folders_is_read(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            apps = root / "share" / "applications"
            apps.mkdir(parents=True)
            (apps / "org.gnome.Nautilus.desktop").write_text(DESKTOP, encoding="utf-8")
            env = {"XDG_DATA_HOME": str(root / "share"), "XDG_DATA_DIRS": str(root / "none")}
            with mock.patch.dict(os.environ, env):
                self.assertEqual(files.desktop_path("org.gnome.Nautilus.desktop"),
                                 apps / "org.gnome.Nautilus.desktop")
                self.assertIsNone(files.desktop_path("/etc/passwd"))
                self.assertIsNone(files.desktop_path("missing.desktop"))
                self.assertEqual(files.exec_of(apps / "org.gnome.Nautilus.desktop"),
                                 ["nautilus", "--new-window"])

    def test_the_configured_manager_wins(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            apps = root / "applications"
            apps.mkdir()
            (apps / "org.gnome.Nautilus.desktop").write_text(DESKTOP, encoding="utf-8")
            with mock.patch.dict(os.environ, {"XDG_DATA_HOME": str(root), "XDG_DATA_DIRS": ""}):
                self.assertEqual(files.file_manager(lambda argv: "org.gnome.Nautilus.desktop\n"),
                                 ["nautilus", "--new-window"])

    def test_without_a_configured_entry_the_fallback_is_used_in_order(self) -> None:
        with mock.patch.object(files.shutil, "which", return_value=None):
            self.assertEqual(files.file_manager(lambda argv: None), ["xdg-open"])
        with mock.patch.object(files.shutil, "which", return_value="/usr/bin/nautilus"):
            self.assertEqual(files.file_manager(lambda argv: ""), ["nautilus"])

    def test_open_path_runs_the_manager_on_the_path(self) -> None:
        ran: list[list[str]] = []
        with mock.patch.object(files.shutil, "which", return_value="/usr/bin/nautilus"):
            argv = files.open_path(Path("/home/me/Downloads/x.iso"), run=lambda argv: "", spawn=ran.append)
        self.assertEqual(argv, ["nautilus", "/home/me/Downloads/x.iso"])
        self.assertEqual(ran, [["nautilus", "/home/me/Downloads/x.iso"]])


if __name__ == "__main__":
    unittest.main()
