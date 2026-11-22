"""The bar element foundation: the sample's Python snapshot and the contract
every element ships with (docs/bar-elements.md)."""

from __future__ import annotations

import contextlib
import io
import json
import os
import re
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from vitrail import sample

ROOT = Path(__file__).resolve().parent.parent


class SampleSnapshotTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.cache = Path(self._tmp.name)

    def state(self, now: float) -> dict:
        return sample.state(cache=self.cache, now=now)

    def test_the_first_snapshot_is_numbers_only(self) -> None:
        self.assertEqual(self.state(1000), {"counter": 1, "updated": 1000})

    def test_the_cache_serves_the_same_snapshot_inside_its_window(self) -> None:
        first = self.state(1000)
        self.assertEqual(self.state(1000 + sample.CACHE_SECONDS - 1), first)

    def test_the_counter_moves_once_the_cache_expires(self) -> None:
        self.state(1000)
        later = self.state(1000 + sample.CACHE_SECONDS)
        self.assertEqual(later, {"counter": 2, "updated": 1000 + sample.CACHE_SECONDS})

    def test_a_clock_that_went_backwards_does_not_freeze_the_cache(self) -> None:
        self.state(5000)
        self.assertEqual(self.state(100)["counter"], 2)

    def test_a_broken_cache_is_replaced_not_raised(self) -> None:
        path = sample.cache_file(self.cache)
        for broken in ("{not json", "[]", '{"saved_at": "x"}', '{"saved_at": 1, "state": {"counter": "a"}}'):
            with self.subTest(broken=broken):
                path.write_text(broken, encoding="utf-8")
                self.assertEqual(self.state(1000)["counter"], 1)

    def test_an_unwritable_cache_is_an_error_in_the_data_not_a_traceback(self) -> None:
        blocked = self.cache / "file"
        blocked.write_text("", encoding="utf-8")
        result = sample.state(cache=blocked / "inside", now=1000)
        self.assertEqual(result, {"counter": 1, "updated": 1000, "error": "cache"})

    def run_main(self, args: list[str]) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        env = {"XDG_CACHE_HOME": str(self.cache)}
        with mock.patch.dict(os.environ, env), contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = sample.main(args)
        return code, out.getvalue(), err.getvalue()

    def test_state_prints_one_json_object_and_exits_zero(self) -> None:
        code, out, _ = self.run_main(["state"])
        self.assertEqual(code, 0)
        self.assertEqual(set(json.loads(out)), {"counter", "updated"})
        self.assertTrue((self.cache / "vitrail" / "sample.json").exists())

    def test_state_with_an_error_exits_one_and_still_prints_json(self) -> None:
        (self.cache / "vitrail").write_text("", encoding="utf-8")
        code, out, _ = self.run_main(["state"])
        self.assertEqual(code, 1)
        self.assertEqual(json.loads(out)["error"], "cache")

    def test_anything_else_is_usage_on_stderr_and_nothing_on_stdout(self) -> None:
        for args in (["bad"], [], ["state", "extra"]):
            with self.subTest(args=args):
                code, out, err = self.run_main(args)
                self.assertEqual((code, out), (2, ""))
                self.assertIn("usage", err)


def widget_ids() -> list[str]:
    source = (ROOT / "bar" / "widgets.js").read_text(encoding="utf-8")
    return re.findall(r'\{ id: "([\w-]+)", surfaces: \["bar"\]', source)


def element_ids() -> list[str]:
    """The widgets whose button extends BarElementBase (bar/<id>/*Button.qml)."""
    # The peripherals battery's element id is "peripherals", while its folder
    # is named for the area it reads (bar/battery/), so its files can sit next
    # to battery.js. Every other element's folder is its id.
    folders = {"battery": "peripherals"}
    found = []
    for widget in widget_ids():
        folder = ROOT / "bar" / widget
        if not folder.is_dir():
            continue
        element = folders.get(widget, widget)
        for path in folder.glob("*Button.qml"):
            if re.search(r"^BarElementBase\s*\{", path.read_text(encoding="utf-8"), re.M):
                if element not in found:
                    found.append(element)
    return found


def page_groups() -> list[tuple[str, list[str]]]:
    """Settings → Bar elements' groups, in order (bar/elements.js PAGE_GROUPS)."""
    source = (ROOT / "bar" / "elements.js").read_text(encoding="utf-8")
    block = re.search(r"var PAGE_GROUPS = \[(.*?)\n\]", source, re.S).group(1)
    return [
        (key, re.findall(r'"([\w-]+)"', ids))
        for key, ids in re.findall(r'\{ key: "(\w+)", ids: \[([^\]]*)\] \}', block)
    ]


def documented_order() -> list[tuple[str, list[str]]]:
    """The page order docs/bar-elements.md states: `| <group key> | `a`, `b` |`."""
    doc = (ROOT / "docs" / "bar-elements.md").read_text(encoding="utf-8")
    section = doc.split("## The settings page", 1)[1].split("\n## ", 1)[0]
    return [
        (key, re.findall(r"`([\w-]+)`", ids))
        for key, ids in re.findall(r"^\| `(\w+)` \| [^|]+ \| ([^|]+) \|$", section, re.M)
    ]


def registry_icons() -> dict[str, str]:
    source = (ROOT / "bar" / "widgets.js").read_text(encoding="utf-8")
    return dict(re.findall(r'\{ id: "([\w-]+)", surfaces: \["bar"\][^}]*?icon: "(\w+)"', source))


class SettingsPageTests(unittest.TestCase):
    """Settings → Bar elements: registry glyphs, a deliberate grouped order."""

    def test_every_element_is_in_exactly_one_group(self) -> None:
        placed = [element for _, ids in page_groups() for element in ids]
        self.assertEqual(len(placed), len(set(placed)), "an element in two groups")
        self.assertEqual(sorted(placed), sorted(element_ids()))

    def test_the_order_is_the_documented_one(self) -> None:
        self.assertEqual(page_groups(), documented_order())
        self.assertEqual(page_groups()[-1][0], "example", "the sample stays last")

    def test_every_element_wears_its_registry_icon(self) -> None:
        icons = registry_icons()
        table = (ROOT / "kit" / "icons.js").read_text(encoding="utf-8")
        for element in element_ids():
            with self.subTest(element=element):
                self.assertIn(element, icons, "no icon in bar/widgets.js")
                self.assertRegex(table, rf"(?m)^\s+{icons[element]}:", "icon missing from kit/icons.js")
        section = (ROOT / "shell" / "pages" / "BarElementSection.qml").read_text(encoding="utf-8")
        self.assertIn("icon: Elements.icon(section.elementId)", section)
        self.assertIn("Layout.row: section.row >= 0 ? section.row : Elements.pageRow(section.elementId)", section)
        # The registry is the one place: no section names its own glyph.
        page = (ROOT / "shell" / "pages" / "BarElementsPage.qml").read_text(encoding="utf-8")
        for block in re.findall(r"BarElementSection \{(.*?)elementId:", page, re.S):
            self.assertNotRegex(block, r"(?m)^\s+icon:")
        editor = (ROOT / "bar" / "desktop" / "BarEditTab.qml").read_text(encoding="utf-8")
        self.assertIn("Elements.icon(entry)", editor)
        self.assertNotIn("widget: {", editor, "a second icon table in the editor")

    def test_every_group_title_is_translated_in_every_language(self) -> None:
        files = sorted((ROOT / "kit" / "i18n").glob("*.json"))
        self.assertEqual(len(files), 6)
        for path in files:
            table = json.loads(path.read_text(encoding="utf-8"))
            for key, _ in page_groups():
                with self.subTest(language=path.stem, group=key):
                    self.assertTrue(table.get(f"bar.elements.group.{key}"))
            self.assertTrue(table.get("bar.editor.preview.hidden"), path.stem)


class ElementContractTests(unittest.TestCase):
    """What every BarElementBase element ships with, so the next one cannot forget."""

    def test_the_sample_is_found(self) -> None:
        self.assertIn("sample", element_ids())

    def test_every_element_is_hidden_by_default(self) -> None:
        layouts = (ROOT / "bar" / "layouts.js").read_text(encoding="utf-8")
        hidden = re.search(r"var DEFAULT_HIDDEN = \{ bar: \[([^\]]*)\]", layouts).group(1)
        for element in element_ids():
            with self.subTest(element=element):
                self.assertIn(f'"{element}"', hidden)

    def test_every_element_is_wired_in_the_shell_and_the_settings(self) -> None:
        shell = (ROOT / "bar" / "shell.qml").read_text(encoding="utf-8")
        page = (ROOT / "shell" / "pages" / "BarElementsPage.qml").read_text(encoding="utf-8")
        gear = (ROOT / "tests" / "test_popup_gear.py").read_text(encoding="utf-8")
        for element in element_ids():
            with self.subTest(element=element):
                self.assertIn(f'case "{element}": return', shell, "widgetComponent")
                self.assertIn(f'name: "{element}"', shell, "its Popout")
                self.assertIn(f'togglePopup("{element}"', shell)
                self.assertIn(f'hoverPopup("{element}"', shell)
                self.assertIn(f'openSettingsAt("bar-elements", "{element}")', shell)
                self.assertIn(f'elementId: "{element}"', page, "its block in Settings → Bar elements")
                self.assertIn(f'("bar-elements", "{element}")', gear)

    def test_every_element_has_its_words_in_every_language(self) -> None:
        for path in sorted((ROOT / "kit" / "i18n").glob("*.json")):
            table = json.loads(path.read_text(encoding="utf-8"))
            for element in element_ids():
                with self.subTest(language=path.stem, element=element):
                    self.assertIn(f"bar.widget.{element}", table)

    def test_the_only_while_active_preference_is_one_mapped_key(self) -> None:
        prefs_map = (ROOT / "vitrail" / "prefs.map").read_text(encoding="utf-8")
        self.assertRegex(prefs_map, r"(?m)^bar barActiveOnly$")
        self.assertNotIn("sampleShowMode", prefs_map)


if __name__ == "__main__":
    unittest.main()
