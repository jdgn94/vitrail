"""The in-place editor opens on every monitor and shares its global documents.

The bar, dock and panel tabs edit one global document (so every monitor's
editor shows the same changes); the desktop tab keeps the monitor that started
the edit. `desktopSync` decides whether the desktop is one shared list or one
per monitor, and only the placements (bar edge, notification side and OSD edge)
may differ per output.
"""

from __future__ import annotations

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
I18N = ("de", "en", "es", "fr", "it", "pt")


class EditorWiringTests(unittest.TestCase):
    def setUp(self) -> None:
        self.shell = (ROOT / "bar/shell.qml").read_text(encoding="utf-8")
        self.layer = (ROOT / "bar/desktop/DesktopEditLayer.qml").read_text(encoding="utf-8")
        self.mode = (ROOT / "bar/desktop/DesktopEditMode.qml").read_text(encoding="utf-8")

    def test_the_editor_opens_on_the_monitor_that_started_it(self) -> None:
        self.assertIn("requested: shell.editMode", self.shell)
        self.assertIn("initiating: shell.editScreen === monitor.modelData", self.shell)
        self.assertIn("focused: shell.editScreen === monitor.modelData", self.shell)
        self.assertIn("keyboardFocus: root.focused", self.layer)

    def test_the_other_monitors_only_carry_the_desktop_tab(self) -> None:
        # With the desktop shared there is one document: the monitor that
        # opened the editor is enough. With sync off each monitor has its own,
        # so the others show the editor too, but only while the desktop tab is
        # up: bar, dock and panel documents are global.
        self.assertIn('desktopShared: shell.prefBool("desktopSync", true)', self.shell)
        self.assertIn('(!root.desktopShared && root.tab === "desktop")', self.layer)

    def test_the_desktop_tab_keeps_the_initiating_monitor(self) -> None:
        self.assertIn("monitorName: shell.editScreen ? shell.editScreen.name : monitor.modelData.name", self.shell)
        self.assertIn("screenMonitor: monitor.modelData.name", self.shell)

    def test_the_editor_screen_is_not_shadowed_by_its_own_property(self) -> None:
        # `screen: monitor.modelData` means the per-screen scope's screen only
        # while the layer has no property called `monitor`: with one, the
        # binding reads the layer's own string and every editor lands on the
        # default output (two editors stacked on one monitor).
        self.assertNotIn("property string monitor:", self.layer)
        self.assertIn("property string monitorName:", self.layer)
        self.assertIn("screen: monitor.modelData", self.shell)

    def test_the_global_documents_reach_every_editor(self) -> None:
        for marker in (
            "barLayout: shell.barEditLayout",
            "panelLayout: shell.panelEditLayout",
            "positions: shell.barMonitorsEditLayout",
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, self.shell)
        self.assertIn("onBarLayoutChanged: root.barText = root.barLayout", self.mode)
        self.assertIn("onPanelLayoutChanged: root.panelText = root.panelLayout", self.mode)

    def test_the_position_selectors_write_the_edited_screen(self) -> None:
        bar = (ROOT / "bar/desktop/BarEditTab.qml").read_text(encoding="utf-8")
        panel = (ROOT / "bar/desktop/PanelEditTab.qml").read_text(encoding="utf-8")
        self.assertIn('objectName: "editorBarPosition"', bar)
        self.assertIn('objectName: "editorBarOsdEdge"', bar)
        self.assertIn('setPosition("edge", key)', bar)
        self.assertIn('setPosition("osdEdge", key)', bar)
        self.assertIn('objectName: "editorPanelSide"', panel)
        self.assertIn("notificationSide: key", panel)

    def test_the_bar_panel_and_osd_read_the_monitor_override(self) -> None:
        self.assertIn("readonly property var barPosition: BarView.forMonitor(", self.shell)
        self.assertIn("edge: monitor.osdEdge", self.shell)
        self.assertIn("side: monitor.notificationSide", self.shell)
        self.assertIn("BarView.override(", self.shell)


class DesktopSyncTests(unittest.TestCase):
    def setUp(self) -> None:
        self.layouts = (ROOT / "bar/layouts.js").read_text(encoding="utf-8")
        self.layer = (ROOT / "bar/desktop/DesktopLayer.qml").read_text(encoding="utf-8")
        self.mode = (ROOT / "bar/desktop/DesktopEditMode.qml").read_text(encoding="utf-8")
        self.shell = (ROOT / "bar/shell.qml").read_text(encoding="utf-8")

    def test_the_document_has_a_shared_list_and_per_monitor_lists(self) -> None:
        self.assertIn("doc.shared = placed", self.layouts)
        self.assertIn("doc.monitors[monitor] = { widgets: placed }", self.layouts)
        self.assertIn("values.shared", self.layouts)

    def test_the_layer_and_editor_follow_the_sync_preference(self) -> None:
        self.assertIn('sync: shell.prefBool("desktopSync", true)', self.shell)
        self.assertIn('Layouts.effective(root.layoutText, root.monitor, null, "desktop",', self.layer)
        self.assertIn('Layouts.effective(root.layoutText, root.monitor, null, "desktop", root.sync)', self.mode)
        self.assertIn("root.sync)", self.mode)

    def test_the_desktop_tab_has_the_switch(self) -> None:
        self.assertIn('objectName: "desktopEditSync"', self.mode)
        self.assertIn('root.prefChanged("desktopSync", value)', self.mode)

    def test_the_preference_is_mapped_declared_and_documented(self) -> None:
        prefs_map = (ROOT / "vitrail/prefs.map").read_text(encoding="utf-8")
        prefs = (ROOT / "shell/Prefs.qml").read_text(encoding="utf-8")
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        self.assertIn("bar desktopSync", prefs_map)
        self.assertIn("property alias desktopSync: barFile.desktopSync", prefs)
        self.assertIn("property bool desktopSync: true", prefs)
        self.assertIn("`desktopSync`", readme)


class LocalisationTests(unittest.TestCase):
    KEYS = (
        "desktop.edit.sync",
        "desktop.edit.sync.help",
        "bar.editor.position",
        "bar.editor.position.help",
        "bar.editor.osdPosition",
        "panel.editor.position",
    )

    def test_every_new_string_exists_in_all_six_languages(self) -> None:
        reference = None
        for code in I18N:
            table = json.loads((ROOT / f"kit/i18n/{code}.json").read_text(encoding="utf-8"))
            if reference is None:
                reference = set(table)
            self.assertEqual(set(table), reference, code)
            for key in self.KEYS:
                with self.subTest(language=code, key=key):
                    self.assertTrue(table[key].strip())


if __name__ == "__main__":
    unittest.main()
