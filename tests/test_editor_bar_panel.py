"""The bar and panel are edited in place, not in Settings.

Settings keeps the bar's non-placement options; the in-place editor owns the
bar's groups, chips, dividers, density, monitor overrides and the panel's
widgets. One source of truth for the document, one page for the dock.
"""

from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


class BarPageTests(unittest.TestCase):
    def setUp(self) -> None:
        self.text = (ROOT / "shell/pages/BarPage.qml").read_text(encoding="utf-8")

    def test_it_no_longer_imports_the_layout_document(self) -> None:
        self.assertNotIn("layouts.js", self.text)
        self.assertNotIn("widgets.js", self.text)

    def test_it_no_longer_edits_placement(self) -> None:
        for marker in (
            "barEditorGroup",
            "barAddChip",
            "barAddDivider",
            "editorSurface",
            "panelLayout",
            "desktopLayout",
            "desktopTypography",
            "desktopFontPicker",
        ):
            with self.subTest(marker=marker):
                self.assertNotIn(marker, self.text)

    def test_it_points_at_the_in_place_editor(self) -> None:
        self.assertIn('page.t("bar.editor.moved.title")', self.text)
        self.assertIn('page.t("bar.editor.moved")', self.text)

    def test_it_keeps_the_non_placement_bar_options(self) -> None:
        for key in (
            "bar.frame",
            "bar.notifications.max",
            "bar.osd.keys",
            "bar.widgets.pomodoroWork",
            "bar.visualiser.enabled",
            "bar.capture.dir",
        ):
            with self.subTest(key=key):
                self.assertIn(f'page.t("{key}")', self.text)


class SettingsPagesTests(unittest.TestCase):
    def setUp(self) -> None:
        self.main = (ROOT / "shell/main.qml").read_text(encoding="utf-8")

    def test_the_dock_category_is_gone(self) -> None:
        self.assertNotIn('key: "dock"', self.main)
        self.assertNotIn("DockPage", self.main)
        self.assertFalse((ROOT / "shell/pages/DockPage.qml").exists())


class InPlaceEditorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.mode = (ROOT / "bar/desktop/DesktopEditMode.qml").read_text(encoding="utf-8")
        self.layer = (ROOT / "bar/desktop/DesktopEditLayer.qml").read_text(encoding="utf-8")
        self.shell = (ROOT / "bar/shell.qml").read_text(encoding="utf-8")

    def test_the_editor_takes_both_documents_and_the_bar_preferences(self) -> None:
        for marker in (
            "property string barLayout",
            "property string panelLayout",
            "property var monitors",
            "property var bar:",
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, self.mode)

    def test_the_layout_signal_names_the_surface(self) -> None:
        self.assertIn("signal layoutChanged(string surface, string text)", self.mode)
        self.assertIn("signal layoutChanged(string surface, string text)", self.layer)

    def test_the_editor_loads_the_two_tabs(self) -> None:
        self.assertIn("BarEditTab {", self.mode)
        self.assertIn("PanelEditTab {", self.mode)

    def test_the_shell_persists_each_surface(self) -> None:
        self.assertIn('shell.setPref("barLayout", text)', self.shell)
        self.assertIn('shell.setPref("panelLayout", text)', self.shell)
        self.assertIn('shell.setPref("desktopLayout", text)', self.shell)


if __name__ == "__main__":
    unittest.main()
