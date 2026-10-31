"""Display brightness: ddcutil output, monitor mapping and the device list."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

from vitrail import brightness

DETECT = """\
Display 1
   I2C bus:          /dev/i2c-6
   DRM connector:    card1-DP-1
   drm_connector_id: 114
   Monitor:          MSI:MSI MAG 275QF:CE2M145801082

Display 2
   I2C bus:          /dev/i2c-7
   DRM connector:    card1-DP-2
   drm_connector_id: 124
   Monitor:          MSI:MSI MAG 275QF:CE2M145801322

Invalid display
   I2C bus:          /dev/i2c-4
   DRM connector:    card1-HDMI-A-1
   drm_connector_id: 130
   EDID synopsis:
      Mfg id:        ABC
"""

MONITORS = [
    {"name": "DP-1", "make": "Microstep", "model": "MSI MAG 275QF", "serial": "CE2M145801082"},
    {"name": "DP-2", "make": "Microstep", "model": "MSI MAG 275QF", "serial": "CE2M145801322"},
]


def done(stdout: str = "", code: int = 0):
    return SimpleNamespace(returncode=code, stdout=stdout, stderr="")


class ParseTests(unittest.TestCase):
    def test_detect_lists_the_valid_displays(self) -> None:
        displays = brightness.parse_detect(DETECT)
        self.assertEqual([d.bus for d in displays], [6, 7])
        self.assertEqual(displays[0].connector, "DP-1")
        self.assertEqual(displays[0].serial, "CE2M145801082")
        self.assertEqual(displays[0].model, "MSI MAG 275QF")
        self.assertEqual(displays[0].make, "MSI")

    def test_detect_of_nothing_is_empty(self) -> None:
        self.assertEqual(brightness.parse_detect(""), [])
        self.assertEqual(brightness.parse_detect("No displays found.\n"), [])

    def test_a_model_may_hold_a_colon(self) -> None:
        text = "Display 1\n   I2C bus: /dev/i2c-3\n   DRM connector: card0-DP-1\n   Monitor: DEL:U27: 4K:ABC123\n"
        display = brightness.parse_detect(text)[0]
        self.assertEqual((display.model, display.serial), ("U27: 4K", "ABC123"))

    def test_the_connector_loses_the_card(self) -> None:
        self.assertEqual(brightness.connector("card1-DP-1"), "DP-1")
        self.assertEqual(brightness.connector("card0-HDMI-A-2"), "HDMI-A-2")
        self.assertEqual(brightness.connector("eDP-1"), "eDP-1")

    def test_getvcp_gives_value_and_maximum(self) -> None:
        self.assertEqual(brightness.parse_getvcp("VCP 10 C 70 100\n"), (70, 100))
        self.assertEqual(brightness.parse_getvcp("VCP 10 C 12 255"), (12, 255))

    def test_getvcp_failures_give_nothing(self) -> None:
        self.assertIsNone(brightness.parse_getvcp(""))
        self.assertIsNone(brightness.parse_getvcp("VCP 10 ERR\n"))
        self.assertIsNone(brightness.parse_getvcp("Display not found\n"))

    def test_brightnessctl_machine_output_lists_backlights(self) -> None:
        text = "intel_backlight,backlight,5000,50%,10000\nacpi_video0,backlight,3,60%,5\n"
        lights = brightness.parse_backlights(text)
        self.assertEqual([(l.device, l.value, l.maximum) for l in lights],
                         [("intel_backlight", 5000, 10000), ("acpi_video0", 3, 5)])

    def test_brightnessctl_without_backlights_is_empty(self) -> None:
        self.assertEqual(brightness.parse_backlights(""), [])
        self.assertEqual(brightness.parse_backlights("Failed to read any devices of class 'backlight'.\n"), [])

    def test_percent_rounds_and_guards_the_scale(self) -> None:
        self.assertEqual(brightness.percent(70, 100), 70)
        self.assertEqual(brightness.percent(5000, 10000), 50)
        self.assertEqual(brightness.percent(1, 3), 33)
        self.assertEqual(brightness.percent(5, 0), 0)
        self.assertEqual(brightness.percent(300, 100), 100)


class MappingTests(unittest.TestCase):
    def test_displays_map_to_monitors_by_connector(self) -> None:
        mapped = brightness.match_displays(brightness.parse_detect(DETECT), MONITORS)
        self.assertEqual({name: d.bus for name, d in mapped.items()}, {"DP-1": 6, "DP-2": 7})

    def test_the_serial_maps_when_the_connector_differs(self) -> None:
        displays = brightness.parse_detect(DETECT)
        renamed = [dict(MONITORS[0], name="DP-9"), MONITORS[1]]
        mapped = brightness.match_displays(displays, renamed)
        self.assertEqual(mapped["DP-9"].bus, 6)
        self.assertEqual(mapped["DP-2"].bus, 7)

    def test_a_monitor_without_a_display_is_left_out(self) -> None:
        mapped = brightness.match_displays(brightness.parse_detect(DETECT), [dict(MONITORS[0], name="X-1", serial="")])
        self.assertEqual(mapped, {})

    def test_one_display_serves_one_monitor(self) -> None:
        twin = [MONITORS[0], dict(MONITORS[0], name="DP-1b")]
        mapped = brightness.match_displays(brightness.parse_detect(DETECT), twin)
        self.assertEqual(list(mapped), ["DP-1"])

    def test_internal_panels_are_recognised(self) -> None:
        self.assertTrue(brightness.is_internal("eDP-1"))
        self.assertTrue(brightness.is_internal("LVDS-1"))
        self.assertFalse(brightness.is_internal("DP-1"))
        self.assertFalse(brightness.is_internal("HDMI-A-1"))


class Runner:
    """A fake `run` that answers per program and counts the calls."""

    def __init__(self, detect: str = DETECT, vcp: dict[int, str] | None = None, backlight: str = "") -> None:
        self.detect = detect
        self.vcp = vcp if vcp is not None else {6: "VCP 10 C 70 100", 7: "VCP 10 C 30 100"}
        self.backlight = backlight
        self.calls: list[list[str]] = []

    def __call__(self, cmd: list[str]):
        self.calls.append(cmd)
        if cmd[0] == "hyprctl":
            return done(json.dumps(MONITORS))
        if cmd[0] == "brightnessctl":
            return done(self.backlight)
        if cmd[:2] == ["ddcutil", "detect"]:
            return done(self.detect)
        if cmd[:2] == ["ddcutil", "getvcp"]:
            bus = int(cmd[cmd.index("--bus") + 1])
            text = self.vcp.get(bus, "")
            return done(text, 0 if text else 1)
        raise AssertionError(cmd)

    def detects(self) -> int:
        return sum(1 for c in self.calls if c[:2] == ["ddcutil", "detect"])


class CollectTests(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.dir.cleanup)
        self.cache = Path(self.dir.name) / "ddc.json"

    def collect(self, runner: Runner, access: str = "ok", have: bool = True):
        return brightness.collect(runner, self.cache, access=lambda: access, installed=lambda: have)

    def test_each_external_monitor_reports_its_brightness(self) -> None:
        result = self.collect(Runner())
        self.assertEqual(result["status"], "ok")
        self.assertEqual(result["devices"], [
            {"name": "DP-1", "kind": "ddc", "bus": 6, "percent": 70, "max": 100},
            {"name": "DP-2", "kind": "ddc", "bus": 7, "percent": 30, "max": 100},
        ])

    def test_detection_runs_once_then_comes_from_the_cache(self) -> None:
        runner = Runner()
        self.collect(runner)
        self.collect(runner)
        self.assertEqual(runner.detects(), 1)
        self.assertTrue(self.cache.exists())

    def test_a_changed_monitor_set_detects_again(self) -> None:
        runner = Runner()
        self.collect(runner)
        self.cache.write_text(json.dumps({"key": ["DP-1|OTHER"], "displays": []}))
        self.collect(runner)
        self.assertEqual(runner.detects(), 2)

    def test_a_stale_cache_detects_again_when_a_read_fails(self) -> None:
        runner = Runner()
        self.collect(runner)
        runner.vcp = {6: "VCP 10 C 10 100", 7: "VCP 10 C 20 100"}
        runner.detect = DETECT.replace("i2c-7", "i2c-8")
        runner.vcp = {6: "VCP 10 C 10 100", 8: "VCP 10 C 20 100"}
        result = self.collect(runner)
        self.assertEqual(runner.detects(), 2)
        self.assertEqual([d["bus"] for d in result["devices"]], [6, 8])

    def test_no_displays_are_not_cached(self) -> None:
        runner = Runner(detect="No displays found.\n")
        self.collect(runner)
        self.collect(runner)
        self.assertEqual(runner.detects(), 2)

    def test_a_display_that_does_not_answer_is_left_out(self) -> None:
        result = self.collect(Runner(vcp={6: "VCP 10 C 70 100"}))
        self.assertEqual([d["name"] for d in result["devices"]], ["DP-1"])

    def test_without_i2c_access_there_is_a_reason_and_no_ddcutil_call(self) -> None:
        runner = Runner()
        result = self.collect(runner, access="access")
        self.assertEqual(result, {"status": "access", "devices": []})
        self.assertFalse([c for c in runner.calls if c[0] == "ddcutil"])

    def test_without_ddcutil_it_says_so(self) -> None:
        result = self.collect(Runner(), have=False)
        self.assertEqual(result, {"status": "missing", "devices": []})

    def test_no_displays_at_all_is_none(self) -> None:
        result = self.collect(Runner(detect="No displays found.\n"))
        self.assertEqual(result, {"status": "none", "devices": []})

    def test_a_laptop_panel_uses_its_backlight(self) -> None:
        monitors = [{"name": "eDP-1", "make": "", "model": "", "serial": ""}] + MONITORS

        class Laptop(Runner):
            def __call__(self, cmd):
                if cmd[0] == "hyprctl":
                    self.calls.append(cmd)
                    return done(json.dumps(monitors))
                return super().__call__(cmd)

        result = self.collect(Laptop(backlight="intel_backlight,backlight,5000,50%,10000\n"))
        self.assertEqual(result["devices"][0],
                         {"name": "eDP-1", "kind": "backlight", "device": "intel_backlight", "percent": 50, "max": 10000})
        self.assertEqual(len(result["devices"]), 3)

    def test_a_laptop_works_without_i2c_access(self) -> None:
        monitors = [{"name": "eDP-1", "make": "", "model": "", "serial": ""}]

        class Laptop(Runner):
            def __call__(self, cmd):
                if cmd[0] == "hyprctl":
                    return done(json.dumps(monitors))
                return super().__call__(cmd)

        result = self.collect(Laptop(backlight="intel_backlight,backlight,5000,50%,10000\n"), access="access")
        self.assertEqual(result["status"], "ok")
        self.assertEqual([d["kind"] for d in result["devices"]], ["backlight"])


class CommandTests(unittest.TestCase):
    def test_the_list_is_printed_as_json(self) -> None:
        import contextlib
        import io
        from unittest import mock

        from vitrail import cli

        answer = {"status": "none", "devices": []}
        out = io.StringIO()
        with mock.patch.object(brightness, "collect", return_value=answer), contextlib.redirect_stdout(out):
            self.assertEqual(cli.main(["brightness", "list"]), 0)
        self.assertEqual(json.loads(out.getvalue()), answer)


class AccessTests(unittest.TestCase):
    def test_no_i2c_devices_is_no_access(self) -> None:
        self.assertEqual(brightness.i2c_access([], lambda path: True), "access")

    def test_one_usable_bus_is_access(self) -> None:
        self.assertEqual(brightness.i2c_access(["/dev/i2c-1", "/dev/i2c-6"], lambda path: path.endswith("6")), "ok")

    def test_buses_the_user_cannot_use_are_no_access(self) -> None:
        self.assertEqual(brightness.i2c_access(["/dev/i2c-1"], lambda path: False), "access")


if __name__ == "__main__":
    unittest.main()
