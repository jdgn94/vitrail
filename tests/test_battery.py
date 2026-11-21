"""Peripherals' batteries: what `upower -i` says about mouse, headphones and gamepad."""

from __future__ import annotations

import contextlib
import io
import json
import unittest

from vitrail import battery

# `upower -i` of a wireless mouse (hidpp): a real percentage and time left.
MOUSE = """\
  native-path:          hidpp_battery_0
  model:                Logitech G305
  serial:               46-f4-18-ad
  power supply:         no
  updated:              Sat 21 Nov 2026 04:01:19 PM -04 (26 seconds ago)
  has history:          yes
  has statistics:       yes
  mouse
    present:             yes
    rechargeable:        yes
    state:               discharging
    warning-level:       none
    battery-level:       good
    time to empty:       4.5 hours
    percentage:          55%
    icon-name:           'battery-good-symbolic'
"""

# Bluetooth headphones while they charge: no time left until they are empty.
HEADPHONES = """\
  native-path:          /org/bluez/hci0/dev_AC_80_0A_12_34_56
  model:                WH-1000XM4
  serial:               AC:80:0A:12:34:56
  power supply:         no
  updated:              Sat 21 Nov 2026 04:02:10 PM -04 (11 seconds ago)
  has history:          no
  has statistics:       no
  headphones
    present:             yes
    rechargeable:        yes
    state:               charging
    warning-level:       none
    battery-level:       good
    percentage:          30%
    icon-name:           'battery-good-charging-symbolic'
"""

GAMEPAD = """\
  native-path:          /org/bluez/hci0/dev_E4_17_D8_AA_BB_CC
  model:                Xbox Wireless Controller
  serial:               E4:17:D8:AA:BB:CC
  power supply:         no
  updated:              Sat 21 Nov 2026 04:03:00 PM -04 (5 seconds ago)
  has history:          no
  has statistics:       no
  gaming-input
    present:             yes
    rechargeable:        yes
    state:               discharging
    warning-level:       none
    battery-level:       good
    time to empty:       12.0 hours
    percentage:          80%
    icon-name:           'battery-good-symbolic'
"""

# The machine's own battery: `power supply: yes`, never a peripheral.
LAPTOP = """\
  native-path:          BAT0
  vendor:               LGC
  model:                DELL 5TF10
  serial:               ABC-123
  power supply:         yes
  updated:              Sat 21 Nov 2026 04:00:00 PM -04 (2 minutes ago)
  has history:          yes
  has statistics:       yes
  battery
    present:             yes
    rechargeable:        yes
    state:               discharging
    warning-level:       none
    energy:              32.1 Wh
    time to empty:       3.2 hours
    percentage:          63%
    icon-name:           'battery-good-symbolic'
"""

# Line power says `power supply: no` on this machine, so its type excludes it.
LINE_POWER = """\
  native-path:          AC
  power supply:         no
  updated:              Sat 21 Nov 2026 03:58:00 PM -04 (4 minutes ago)
  has history:          no
  has statistics:       no
  line-power
    online:              no
    icon-name:           'ac-adapter-symbolic'
"""

# UPower's synthetic total for the machine, not a device of its own.
DISPLAY_DEVICE = """\
  power supply:         no
  updated:              Sat 21 Nov 2026 12:57:36 PM -04 (11049 seconds ago)
  has history:          no
  has statistics:       no
  unknown
    warning-level:       none
    percentage:          0%
    icon-name:           'battery-missing-symbolic'
"""

# A keyboard that reports a coarse level only: UPower estimates the percentage
# and marks it as one to ignore.
KEYBOARD = """\
  native-path:          hidpp_battery_1
  model:                Logitech MX Keys
  serial:               12-ab-34-cd
  power supply:         no
  updated:              Sat 21 Nov 2026 04:04:00 PM -04 (1 minute ago)
  has history:          no
  has statistics:       no
  keyboard
    present:             yes
    rechargeable:        yes
    state:               unknown
    warning-level:       none
    battery-level:       full
    percentage:          100% (should be ignored)
    icon-name:           'battery-full-charged-symbolic'
"""

MOUSE_PATH = "/org/freedesktop/UPower/devices/mouse_hidpp_battery_0"
HEADPHONES_PATH = "/org/freedesktop/UPower/devices/headset_dev_AC_80_0A_12_34_56"
GAMEPAD_PATH = "/org/freedesktop/UPower/devices/gaming_input_dev_E4_17_D8_AA_BB_CC"
LAPTOP_PATH = "/org/freedesktop/UPower/devices/battery_BAT0"
LINE_POWER_PATH = "/org/freedesktop/UPower/devices/line_power_AC"
DISPLAY_DEVICE_PATH = "/org/freedesktop/UPower/devices/DisplayDevice"
KEYBOARD_PATH = "/org/freedesktop/UPower/devices/keyboard_hidpp_battery_1"


class Runner:
    """A fake `upower`: the object listing and each device's `-i` output."""

    def __init__(
        self,
        listing: str = "",
        devices: dict[str, str] | None = None,
        failing: set[str] | None = None,
    ) -> None:
        self.listing = listing
        self.devices = devices or {}
        self.failing = failing or set()
        self.calls: list[list[str]] = []

    def __call__(self, cmd: list[str]) -> str | None:
        self.calls.append(cmd)
        if cmd == ["upower", "-e"]:
            return self.listing
        if cmd[:2] == ["upower", "-i"]:
            path = cmd[2]
            return None if path in self.failing else self.devices.get(path, "")
        raise AssertionError(cmd)


def everything(**overrides: str) -> Runner:
    """Every fixture in one listing; `overrides` replaces a path's output."""
    paths = {
        MOUSE_PATH: MOUSE,
        HEADPHONES_PATH: HEADPHONES,
        GAMEPAD_PATH: GAMEPAD,
        LAPTOP_PATH: LAPTOP,
        LINE_POWER_PATH: LINE_POWER,
        DISPLAY_DEVICE_PATH: DISPLAY_DEVICE,
        KEYBOARD_PATH: KEYBOARD,
    }
    paths.update(overrides)
    return Runner("\n".join(paths) + "\n", paths)


class ListingTests(unittest.TestCase):
    def test_the_object_paths_are_one_per_line(self) -> None:
        self.assertEqual(battery.parse_paths(f"{MOUSE_PATH}\n{LAPTOP_PATH}\n"), [MOUSE_PATH, LAPTOP_PATH])

    def test_an_empty_listing_has_no_paths(self) -> None:
        self.assertEqual(battery.parse_paths(""), [])
        self.assertEqual(battery.parse_paths("\n\n"), [])


class InfoTests(unittest.TestCase):
    def test_a_wireless_mouse_reads_every_field(self) -> None:
        info = battery.parse_info(MOUSE)
        self.assertEqual(info["native_path"], "hidpp_battery_0")
        self.assertEqual(info["model"], "Logitech G305")
        self.assertEqual(info["serial"], "46-f4-18-ad")
        self.assertEqual(info["kind"], "mouse")
        self.assertFalse(info["power_supply"])
        self.assertEqual(info["percentage"], 55)
        self.assertEqual(info["state"], "discharging")
        self.assertEqual(info["time_to_empty"], 270)

    def test_time_left_reads_in_minutes(self) -> None:
        self.assertEqual(battery.parse_info(GAMEPAD)["time_to_empty"], 720)
        self.assertIsNone(battery.parse_info(HEADPHONES)["time_to_empty"])

    def test_charging_headphones_keep_their_state(self) -> None:
        info = battery.parse_info(HEADPHONES)
        self.assertEqual((info["kind"], info["state"], info["percentage"]), ("headphones", "charging", 30))

    def test_a_fully_charged_device_is_full(self) -> None:
        text = MOUSE.replace("state:               discharging", "state:               fully-charged")
        self.assertEqual(battery.parse_info(text)["state"], "full")

    def test_a_percentage_upower_estimates_is_no_percentage(self) -> None:
        info = battery.parse_info(KEYBOARD)
        self.assertIsNone(info["percentage"])
        self.assertEqual(info["state"], "unknown")

    def test_a_device_without_a_percentage_has_none(self) -> None:
        text = MOUSE.replace("    percentage:          55%\n", "")
        self.assertIsNone(battery.parse_info(text)["percentage"])

    def test_a_percentage_never_leaves_the_scale(self) -> None:
        self.assertEqual(battery.parse_info(MOUSE.replace("55%", "140%"))["percentage"], 100)
        self.assertEqual(battery.parse_info(MOUSE.replace("55%", "84.6%"))["percentage"], 85)


class DeviceTests(unittest.TestCase):
    def device(self, path: str, text: str) -> dict | None:
        return battery.device(path, battery.parse_info(text))

    def test_a_mouse_is_a_peripheral(self) -> None:
        self.assertEqual(
            self.device(MOUSE_PATH, MOUSE),
            {
                "path": MOUSE_PATH,
                "name": "Logitech G305",
                "kind": "mouse",
                "percentage": 55,
                "state": "discharging",
                "timeToEmpty": 270,
                "model": "Logitech G305",
                "serial": "46-f4-18-ad",
            },
        )

    def test_kinds_read_like_the_ui_expects(self) -> None:
        self.assertEqual(self.device(HEADPHONES_PATH, HEADPHONES)["kind"], "headphones")
        self.assertEqual(self.device(GAMEPAD_PATH, GAMEPAD)["kind"], "gamepad")
        self.assertEqual(self.device(KEYBOARD_PATH, KEYBOARD)["kind"], "keyboard")

    def test_the_machine_battery_is_not_a_peripheral(self) -> None:
        self.assertIsNone(self.device(LAPTOP_PATH, LAPTOP))

    def test_line_power_is_not_a_peripheral(self) -> None:
        self.assertIsNone(self.device(LINE_POWER_PATH, LINE_POWER))

    def test_the_synthetic_display_device_is_not_a_peripheral(self) -> None:
        self.assertIsNone(self.device(DISPLAY_DEVICE_PATH, DISPLAY_DEVICE))

    def test_a_nameless_device_falls_back_to_its_native_path(self) -> None:
        text = HEADPHONES.replace("  model:                WH-1000XM4\n", "")
        self.assertEqual(self.device(HEADPHONES_PATH, text)["name"], "/org/bluez/hci0/dev_AC_80_0A_12_34_56")

    def test_an_unknown_kind_is_still_a_peripheral(self) -> None:
        text = MOUSE.replace("  mouse\n", "  pen\n")
        self.assertEqual(self.device(MOUSE_PATH, text)["kind"], "other")


class LowestTests(unittest.TestCase):
    def test_the_lowest_discharging_battery_wins_even_over_a_charging_one(self) -> None:
        devices = everything()
        found = battery.state(devices)["devices"]
        self.assertEqual(battery.lowest(found), {"name": "Logitech G305", "percentage": 55})

    def test_charging_ones_are_folded_when_nothing_discharges(self) -> None:
        devices = [
            battery.device(
                MOUSE_PATH,
                battery.parse_info(MOUSE.replace("state:               discharging", "state:               charging")),
            ),
            battery.device(HEADPHONES_PATH, battery.parse_info(HEADPHONES)),
        ]
        self.assertEqual(battery.lowest(devices), {"name": "WH-1000XM4", "percentage": 30})

    def test_devices_without_a_percentage_never_compete(self) -> None:
        devices = [battery.device(KEYBOARD_PATH, battery.parse_info(KEYBOARD))]
        self.assertIsNone(battery.lowest(devices))
        self.assertIsNone(battery.lowest([]))


class StateTests(unittest.TestCase):
    def test_peripherals_are_listed_and_the_machine_is_not(self) -> None:
        result = battery.state(everything())
        self.assertEqual(
            [one["name"] for one in result["devices"]],
            ["Logitech G305", "Logitech MX Keys", "WH-1000XM4", "Xbox Wireless Controller"],
        )
        self.assertEqual(result["lowest"], {"name": "Logitech G305", "percentage": 55})
        self.assertIsNone(result["error"])

    def test_each_device_has_the_agreed_shape(self) -> None:
        result = battery.state(everything())
        self.assertEqual(set(result), {"devices", "lowest", "error"})
        for one in result["devices"]:
            self.assertEqual(
                set(one), {"path", "name", "kind", "percentage", "state", "timeToEmpty", "model", "serial"}
            )
        self.assertEqual(set(result["lowest"]), {"name", "percentage"})

    def test_no_peripherals_is_an_empty_answer_not_a_failure(self) -> None:
        self.assertEqual(battery.state(Runner("")), {"devices": [], "lowest": None, "error": None})

    def test_without_upower_there_is_nothing_to_show(self) -> None:
        self.assertEqual(battery.state(lambda cmd: None), {"devices": [], "lowest": None, "error": None})

    def test_a_device_that_cannot_be_read_is_skipped(self) -> None:
        runner = everything(**{MOUSE_PATH: ""})
        runner.failing = {MOUSE_PATH}
        self.assertEqual(
            [one["name"] for one in battery.state(runner)["devices"]],
            ["Logitech MX Keys", "WH-1000XM4", "Xbox Wireless Controller"],
        )

    def test_a_duplicated_path_is_read_once(self) -> None:
        runner = everything()
        runner.listing += f"{MOUSE_PATH}\n"
        battery.state(runner)
        self.assertEqual(runner.calls.count(["upower", "-i", MOUSE_PATH]), 1)


class CommandTests(unittest.TestCase):
    def test_state_prints_one_json_document(self) -> None:
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertEqual(battery.main(["state"], everything()), 0)
        answer = json.loads(out.getvalue())
        self.assertEqual(answer["lowest"], {"name": "Logitech G305", "percentage": 55})
        self.assertEqual(len(answer["devices"]), 4)

    def test_any_other_request_is_a_usage_error(self) -> None:
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(battery.main([]), 2)
            self.assertEqual(battery.main(["list"]), 2)


if __name__ == "__main__":
    unittest.main()
