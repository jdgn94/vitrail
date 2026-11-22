"""The clock popup's widgets are a preference, a gear and a settings section.

`dashboardWidgets` (bar.ini) is one JSON array of widget keys in the order the
popup shows them; the popup builds its tabs from it, the gear opens its section
and the section writes it back.
"""

from __future__ import annotations

import json
import unittest
from pathlib import Path

from vitrail import prefs

ROOT = Path(__file__).resolve().parent.parent
DASHBOARD = ROOT / "bar" / "dashboard" / "Dashboard.qml"
POPOUT = ROOT / "bar" / "dashboard" / "DashboardPopout.qml"
PAGE = ROOT / "shell" / "pages" / "BarElementsPage.qml"
SEARCH = ROOT / "shell" / "search.js"

WIDGETS = ["calendar", "weather", "performance", "focus", "media"]
KEYS = (
    "bar.clock.widgets.help",
    "bar.clock.moveUp",
    "bar.clock.moveDown",
    *(f"bar.clock.widget.{widget}" for widget in WIDGETS),
)


class PreferenceTests(unittest.TestCase):
    def test_the_preference_lives_in_bar_ini(self) -> None:
        self.assertEqual(prefs.file_of("dashboardWidgets"), "bar")

    def test_the_window_declares_and_aliases_it(self) -> None:
        text = (ROOT / "shell" / "Prefs.qml").read_text(encoding="utf-8")
        self.assertIn("property alias dashboardWidgets: barFile.dashboardWidgets", text)
        self.assertIn("property string dashboardWidgets:", text)

    def test_the_readme_lists_it(self) -> None:
        row = next(
            line
            for line in (ROOT / "README.md").read_text(encoding="utf-8").splitlines()
            if line.startswith("| `bar.ini` |")
        )
        self.assertIn("`dashboardWidgets`", row)


class PopupTests(unittest.TestCase):
    def test_the_content_builds_its_tabs_from_the_preference(self) -> None:
        text = DASHBOARD.read_text(encoding="utf-8")
        self.assertIn('property string dashboardWidgets: ""', text)
        self.assertIn("Dash.shownWidgets(root.dashboardWidgets)", text)
        for key in ("calendarPage", "weatherPage", "performancePage", "focusPage", "mediaPage"):
            with self.subTest(page=key):
                self.assertIn(key, text)

    def test_the_host_passes_it_and_reports_the_gear(self) -> None:
        text = POPOUT.read_text(encoding="utf-8")
        self.assertIn('property string dashboardWidgets: ""', text)
        self.assertIn("dashboardWidgets: root.dashboardWidgets", text)
        self.assertIn("signal settingsRequested()", text)
        self.assertIn("onSettingsRequested: root.settingsRequested()", text)

    def test_the_shell_feeds_it_and_opens_the_clock_section(self) -> None:
        text = (ROOT / "bar" / "shell.qml").read_text(encoding="utf-8")
        self.assertIn('dashboardWidgets: shell.prefs.dashboardWidgets || ""', text)
        self.assertIn('onSettingsRequested: shell.openSettingsAt("bar-elements", "clock")', text)


class SettingsTests(unittest.TestCase):
    def test_the_clock_section_reuses_the_shared_component(self) -> None:
        text = PAGE.read_text(encoding="utf-8")
        self.assertIn('elementId: "clock"', text)
        self.assertIn("Dash.widgetRows(page.prefs.dashboardWidgets)", text)
        self.assertIn("Dash.withWidget(page.prefs.dashboardWidgets", text)
        self.assertIn("Dash.moveWidget(page.prefs.dashboardWidgets", text)

    def test_the_settings_search_finds_it(self) -> None:
        text = SEARCH.read_text(encoding="utf-8")
        self.assertRegex(text, r'category: "bar-elements", tab: "clock"')
        self.assertIn('"bar.widget.clock"', text)


class TranslationTests(unittest.TestCase):
    def test_all_six_files_name_the_widgets_and_the_actions(self) -> None:
        for path in sorted((ROOT / "kit" / "i18n").glob("*.json")):
            table = json.loads(path.read_text(encoding="utf-8"))
            with self.subTest(language=path.stem):
                for key in KEYS:
                    self.assertIn(key, table)
                    self.assertTrue(table[key].strip())


if __name__ == "__main__":
    unittest.main()
