"""The Monitors page's data: Hyprland's outputs in, safe `hl.monitor` rules out.

The window cannot run commands, so `vitrail.monitors` reads `hyprctl monitors
-j` for the settings window and applies the document the page writes. Every
field is validated before it becomes Lua: a preference file is user data, not
code for the compositor.
"""

from __future__ import annotations

import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from vitrail import monitors

ROOT = Path(__file__).resolve().parent.parent

MONITORS = json.dumps(
    [
        {
            "name": "DP-1",
            "description": "Microstep MSI MAG 275QF",
            "width": 2560,
            "height": 1440,
            "refreshRate": 180.0,
            "x": 0,
            "y": 0,
            "scale": 1.0,
            "transform": 0,
            "disabled": False,
            "mirrorOf": "none",
            "focused": True,
            "availableModes": [
                "2560x1440@59.95Hz",
                "2560x1440@180.00Hz",
                "1920x1080@60.00Hz",
            ],
        },
        {
            "name": "HDMI-A-1",
            "description": "Dell U2415",
            "width": 1920,
            "height": 1200,
            "refreshRate": 59.95,
            "x": 2560,
            "y": 0,
            "scale": 1.25,
            "transform": 1,
            "disabled": False,
            "mirrorOf": "none",
            "focused": False,
            "availableModes": ["1920x1200@59.95Hz"],
        },
        {"description": "no name"},
    ]
)


def fake(text: str | None = MONITORS, record: list | None = None):
    def run(argv):
        if record is not None:
            record.append(argv)
        if argv[:2] == ["hyprctl", "eval"]:
            return "ok"
        if argv[:2] == ["hyprctl", "dispatch"]:
            return "ok"
        if argv[:3] == ["hyprctl", "monitors", "-j"]:
            return text
        return None

    return run


def document() -> dict:
    return {
        "DP-1": {
            "mode": "2560x1440@180.00",
            "position": "0x0",
            "scale": 1.0,
            "transform": 0,
            "disabled": False,
            "mirror": "",
        },
        "HDMI-A-1": {
            "mode": "1920x1200@59.95",
            "position": "2560x0",
            "scale": 1.25,
            "transform": 1,
            "disabled": False,
            "mirror": "",
        },
    }


def with_primary(name: str = "DP-1") -> dict:
    data = document()
    data[name]["primary"] = True
    return data


class ParseTests(unittest.TestCase):
    def test_monitors_are_read_and_normalised(self) -> None:
        data = monitors.state(run=fake())
        self.assertTrue(data["available"])
        first, second = data["monitors"]
        self.assertEqual((first["name"], first["width"], first["height"]), ("DP-1", 2560, 1440))
        self.assertEqual(first["refresh"], 180.0)
        self.assertEqual(first["mode"], "2560x1440@180.00")
        self.assertEqual(first["x"], 0)
        self.assertEqual(first["scale"], 1.0)
        self.assertEqual(first["transform"], 0)
        self.assertFalse(first["disabled"])
        self.assertTrue(first["focused"])
        self.assertEqual(first["modes"][0], "2560x1440@59.95")
        self.assertEqual((second["name"], second["scale"], second["transform"]), ("HDMI-A-1", 1.25, 1))
        self.assertEqual(len(data["monitors"]), 2, "a monitor without a name is dropped")

    def test_no_hyprctl_means_no_live_state(self) -> None:
        self.assertEqual(monitors.state(run=fake(None)), {"available": False, "monitors": [], "overrides": {}})

    def test_a_broken_answer_is_not_a_crash(self) -> None:
        self.assertFalse(monitors.state(run=fake("not json"))["available"])

    def test_the_current_mode_is_the_closest_listed_one(self) -> None:
        first = monitors.state(run=fake())["monitors"][0]
        self.assertEqual(first["mode"], "2560x1440@180.00")


class DocumentTests(unittest.TestCase):
    def test_a_document_must_be_an_object_of_monitors(self) -> None:
        self.assertEqual(monitors.document("{}"), {})
        self.assertEqual(monitors.document(""), {})
        for text in ("[]", "null", '"x"', "not json", '{"DP-1": 1}'):
            with self.subTest(text=text), self.assertRaises(ValueError):
                monitors.document(text)

    def test_every_field_is_validated(self) -> None:
        bad = [
            {"mode": "preferred; os.exit()"},
            {"mode": "2560x1440@999"},
            {"position": "0x0; os.exit()"},
            {"position": "left"},
            {"scale": 0},
            {"scale": 99},
            {"transform": 8},
            {"transform": "1"},
            {"disabled": "yes"},
            {"mirror": "a b"},
            {"unknown": True},
        ]
        for patch in bad:
            with self.subTest(patch=patch), self.assertRaises(ValueError):
                monitors.document(json.dumps({"DP-1": {**document()["DP-1"], **patch}}))

    def test_a_valid_document_round_trips(self) -> None:
        text = json.dumps(document())
        self.assertEqual(monitors.document(text), document())

    def test_primary_is_a_boolean_and_only_one_output_may_have_it(self) -> None:
        self.assertEqual(monitors.document(json.dumps(with_primary()))["DP-1"]["primary"], True)
        two = with_primary()
        two["HDMI-A-1"]["primary"] = True
        for patch in ({"primary": "yes"}, {"primary": 1}, {"primary": None}):
            with self.subTest(patch=patch), self.assertRaises(ValueError):
                monitors.document(json.dumps({"DP-1": {**document()["DP-1"], **patch}}))
        with self.assertRaises(ValueError):
            monitors.document(json.dumps(two))

    def test_a_mirror_cannot_name_itself(self) -> None:
        with self.assertRaises(ValueError):
            monitors.document(json.dumps({"DP-1": {**document()["DP-1"], "mirror": "DP-1"}}))

    def test_an_output_name_is_a_hyprland_name(self) -> None:
        for name in ("DP-1", "HDMI-A-1", "eDP-1", "desc:Dell U2415"):
            monitors.document(json.dumps({name: document()["DP-1"]}))
        for name in ("", "a b", 'a"; os.exit()', "x/y"):
            with self.subTest(name=name), self.assertRaises(ValueError):
                monitors.document(json.dumps({name: document()["DP-1"]}))


class RuleTests(unittest.TestCase):
    def test_the_rule_sets_every_field(self) -> None:
        self.assertEqual(
            monitors.rule("DP-1", document()["DP-1"]),
            'hl.monitor({ output = "DP-1", mode = "2560x1440@180.00", position = "0x0", scale = 1.0, transform = 0 })',
        )

    def test_a_mirror_needs_only_its_target(self) -> None:
        self.assertEqual(
            monitors.rule("HDMI-A-1", {"mirror": "DP-1"}),
            'hl.monitor({ output = "HDMI-A-1", mirror = "DP-1" })',
        )

    def test_a_disabled_output_is_disabled(self) -> None:
        self.assertEqual(
            monitors.rule("DP-1", {"disabled": True}),
            'hl.monitor({ output = "DP-1", disabled = true })',
        )

    def test_reset_is_a_default_rule(self) -> None:
        self.assertEqual(
            monitors.rule("DP-1", None),
            'hl.monitor({ output = "DP-1", mode = "preferred", position = "auto", scale = 1 })',
        )

    def test_primary_is_not_a_monitor_rule(self) -> None:
        self.assertEqual(
            monitors.rule("DP-1", {**document()["DP-1"], "primary": True}),
            'hl.monitor({ output = "DP-1", mode = "2560x1440@180.00", position = "0x0", scale = 1.0, transform = 0 })',
        )


class ApplyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.config = self.root / "config"
        self.config.mkdir()
        self.cache = self.root / "cache"

    def apply(self, text: str, **kwargs):
        return monitors.apply(text, config=self.config, cache=self.cache, run=fake(), **kwargs)

    def test_each_monitor_becomes_one_eval(self) -> None:
        calls: list[list[str]] = []
        code = monitors.apply(json.dumps(document()), config=self.config, cache=self.cache, run=fake(record=calls))
        self.assertEqual(code, 0)
        evaluated = [call[2] for call in calls if call[:2] == ["hyprctl", "eval"]]
        self.assertEqual(len(evaluated), 2)
        self.assertIn('output = "DP-1"', evaluated[0] + evaluated[1])
        state = json.loads((self.config / "monitor-state.json").read_text(encoding="utf-8"))
        self.assertEqual(state["result"]["code"], 0)
        self.assertTrue(state["available"])
        self.assertEqual(len(state["monitors"]), 2)

    def test_the_same_document_is_not_applied_twice(self) -> None:
        text = json.dumps(document())
        self.assertEqual(self.apply(text), 0)
        calls: list[list[str]] = []
        self.assertEqual(monitors.apply(text, config=self.config, cache=self.cache, run=fake(record=calls)), 0)
        self.assertEqual([call for call in calls if call[:2] == ["hyprctl", "eval"]], [])

    def test_force_applies_again(self) -> None:
        text = json.dumps(document())
        self.assertEqual(self.apply(text), 0)
        calls: list[list[str]] = []
        monitors.apply(text, config=self.config, cache=self.cache, run=fake(record=calls), force=True)
        self.assertEqual(len([call for call in calls if call[:2] == ["hyprctl", "eval"]]), 2)

    def test_an_invalid_document_is_refused_and_nothing_runs(self) -> None:
        calls: list[list[str]] = []
        code = monitors.apply(
            json.dumps({"DP-1": {"mode": "preferred; os.exit()"}}),
            config=self.config,
            cache=self.cache,
            run=fake(record=calls),
        )
        self.assertEqual(code, 2)
        self.assertEqual(calls, [])

    def test_an_empty_document_resets_nothing(self) -> None:
        self.assertEqual(self.apply("{}"), 0)
        self.assertFalse((self.config / "monitor-state.json").exists())

    def test_the_primary_output_gets_workspace_one(self) -> None:
        calls: list[list[str]] = []
        code = monitors.apply(json.dumps(with_primary()), config=self.config, cache=self.cache, run=fake(record=calls))
        self.assertEqual(code, 0)
        dispatched = [call for call in calls if call[:2] == ["hyprctl", "dispatch"]]
        self.assertEqual(dispatched, [["hyprctl", "dispatch", "moveworkspacetomonitor", "1", "DP-1"]])
        state = json.loads((self.config / "monitor-state.json").read_text(encoding="utf-8"))
        self.assertEqual(state["primary"], "DP-1")
        self.assertEqual(state["overrides"]["DP-1"]["primary"], True)
        self.assertEqual(state["result"]["workspace"], {"monitor": "DP-1", "workspace": 1, "moved": True})

    def test_a_refused_workspace_makes_the_apply_fail(self) -> None:
        def refusing(argv):
            if argv[:2] == ["hyprctl", "eval"]:
                return "ok"
            if argv[:2] == ["hyprctl", "dispatch"]:
                return "error"
            if argv[:3] == ["hyprctl", "monitors", "-j"]:
                return MONITORS
            return None

        code = monitors.apply(json.dumps(with_primary()), config=self.config, cache=self.cache, run=refusing)
        self.assertEqual(code, 1)
        state = json.loads((self.config / "monitor-state.json").read_text(encoding="utf-8"))
        self.assertFalse(state["result"]["workspace"]["moved"])

    def test_the_previous_document_can_be_applied_again(self) -> None:
        before = json.dumps(with_primary())
        after = monitors.document(before)
        after["DP-1"]["position"] = "-1920x0"
        after["HDMI-A-1"]["position"] = "0x0"
        calls: list[list[str]] = []
        self.assertEqual(
            monitors.apply(json.dumps(after), config=self.config, cache=self.cache, run=fake(record=calls)), 0
        )
        calls.clear()
        self.assertEqual(
            monitors.apply(before, config=self.config, cache=self.cache, run=fake(record=calls), force=True), 0
        )
        evaluated = [call[2] for call in calls if call[:2] == ["hyprctl", "eval"]]
        self.assertTrue(any('position = "0x0"' in rule and 'output = "DP-1"' in rule for rule in evaluated))
        self.assertTrue(any('position = "2560x0"' in rule and 'output = "HDMI-A-1"' in rule for rule in evaluated))

    def test_a_draft_never_rewrites_the_preference_file(self) -> None:
        (self.config / "monitors.ini").write_text(
            "[monitors]\nmonitorOverrides=" + json.dumps(document()) + "\n", encoding="utf-8"
        )
        before = (self.config / "monitors.ini").read_text(encoding="utf-8")
        self.assertEqual(self.apply(json.dumps(with_primary())), 0)
        self.assertEqual((self.config / "monitors.ini").read_text(encoding="utf-8"), before)


class CommandTests(unittest.TestCase):
    def test_the_cli_reads_the_preference(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            config = Path(tmp) / "vitrail"
            config.mkdir()
            (config / "monitors.ini").write_text(
                "[General]\nmonitorOverrides=" + json.dumps(document()) + "\n", encoding="utf-8"
            )
            cache = Path(tmp) / "cache"
            calls: list[list[str]] = []
            with mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(config.parent), "XDG_CACHE_HOME": str(cache)}):
                code = monitors.main(["apply"], run=fake(record=calls))
            self.assertEqual(code, 0)
            self.assertEqual(len([call for call in calls if call[:2] == ["hyprctl", "eval"]]), 2)
            state = json.loads((config / "monitor-state.json").read_text(encoding="utf-8"))
            self.assertEqual(state["result"]["code"], 0)


class WiringTests(unittest.TestCase):
    """The page's state, the apply hook and the login hook stay connected."""

    def test_the_settings_launcher_injects_the_state(self) -> None:
        text = (ROOT / "bin" / "vitrail-settings").read_text(encoding="utf-8")
        self.assertIn("vitrail.monitors state", text)
        self.assertIn('--monitors "${monitors}"', text)

    def test_applying_a_preference_applies_the_layout(self) -> None:
        text = (ROOT / "scripts" / "apply-settings.sh").read_text(encoding="utf-8")
        self.assertIn("python3 -m vitrail.monitors apply", text)

    def test_the_login_hook_applies_the_layout(self) -> None:
        text = (ROOT / "dots" / ".config" / "hypr" / "hyprland.lua").read_text(encoding="utf-8")
        self.assertIn('hl.exec_cmd(home .. "/.local/bin/vitrail-monitors apply --force")', text)

    def test_the_installer_links_the_launcher(self) -> None:
        text = (ROOT / "install.sh").read_text(encoding="utf-8")
        self.assertRegex(text, r"for name in [^\n]*\bvitrail-monitors\b")


if __name__ == "__main__":
    unittest.main()
