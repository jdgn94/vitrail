"""The Connection page's data: requests become argv lists, and what nmcli,
bluetoothctl and hypraether-vpn print becomes the page's state."""

from __future__ import annotations

import io
import json
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

from vitrail import network

DEVICES = (
    "eno1:ethernet:connected:Wired profile\n"
    "wlan0:wifi:disconnected:\n"
    "docker0:bridge:connected (externally):docker0\n"
    "veth1:ethernet:unmanaged:\n"
    "A0\\:1B\\:9E\\:B3\\:9A\\:65:bt:disconnected:\n"
    "lo:loopback:connected (externally):lo\n"
)
WIFI = (
    "*:Home\\: 5G:78:WPA2\n"
    ":Cafe:55:--\n"
    ":Home\\: 5G:40:WPA2\n"
    ":Neighbour:81:WPA2 WPA3\n"
    ":Cafe:30:--\n"
    "::20:WPA2\n"
)
IP4 = "IP4.ADDRESS[1]:192.168.1.116/24\nIP4.ADDRESS[2]:10.0.0.2/8\nIP4.GATEWAY:192.168.1.1\n"
BT_SHOW = "Controller 00:1A:7D:DA:71:10 (public)\n\tName: home-pc\n\tPowered: yes\n"
BT_DEVICES = "Device A0:1B:9E:B3:9A:65 Juan's A56\nDevice 11:22:33:44:55:66 Buds\nDevice A0:1B:9E:B3:9A:65 again\nnoise\n"
BT_INFO = {
    "A0:1B:9E:B3:9A:65": "Device A0:1B:9E:B3:9A:65 (public)\n\tAlias: Juan's A56\n\tPaired: yes\n\tConnected: yes\n"
                         "\tBattery Percentage: 0x58 (88)\n",
    "11:22:33:44:55:66": "Device 11:22:33:44:55:66 (public)\n\tAlias: Buds\n\tPaired: no\n\tConnected: no\n",
}
VPN = json.dumps([
    {"id": "us-1", "name": "us-1.proton.udp.ovpn", "provider": "proton", "region": "US",
     "credential": "secret name", "config_path": "/x/y.conf", "active": True},
    {"id": "us-2", "name": "us-2.proton.udp.ovpn", "provider": "proton", "region": "US", "active": False},
    {"name": "no id"},
])


def fake(outputs: dict[str, str | None]):
    """A runner that answers by the command's first words."""
    def run(argv: list[str]) -> str | None:
        for prefix, text in outputs.items():
            if " ".join(argv).startswith(prefix):
                return text
        return None
    return run


EVERYTHING = {
    "nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device": DEVICES,
    "nmcli radio wifi": "enabled\n",
    "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY": WIFI,
    "nmcli -t -f IP4.ADDRESS,IP4.GATEWAY device show eno1": IP4,
    "hypraether-vpn list --json": VPN,
    "bluetoothctl show": BT_SHOW,
    "bluetoothctl devices": BT_DEVICES,
    "bluetoothctl info A0:1B:9E:B3:9A:65": BT_INFO["A0:1B:9E:B3:9A:65"],
    "bluetoothctl info 11:22:33:44:55:66": BT_INFO["11:22:33:44:55:66"],
}


class RequestTests(unittest.TestCase):
    def argv(self, request: str, device: str = "wlan0") -> list[str] | None:
        verb, argument = network.parse(request)
        return network.command(verb, argument, device)

    def test_every_request_becomes_its_argv(self) -> None:
        self.assertEqual(self.argv("wifi-on"), ["nmcli", "radio", "wifi", "on"])
        self.assertEqual(self.argv("wifi-off"), ["nmcli", "radio", "wifi", "off"])
        self.assertEqual(self.argv("wifi-connect:Home: 5G"), ["nmcli", "device", "wifi", "connect", "Home: 5G"])
        self.assertEqual(self.argv("wifi-disconnect"), ["nmcli", "device", "disconnect", "wlan0"])
        self.assertEqual(self.argv("vpn-up:us-1"), ["hypraether-vpn", "connect", "us-1"])
        self.assertEqual(self.argv("vpn-down:us-1"), ["hypraether-vpn", "disconnect", "us-1"])
        self.assertEqual(self.argv("bt-on"), ["bluetoothctl", "power", "on"])
        self.assertEqual(self.argv("bt-off"), ["bluetoothctl", "power", "off"])
        self.assertEqual(self.argv("bt-connect:a0:1b:9e:b3:9a:65"), ["bluetoothctl", "connect", "A0:1B:9E:B3:9A:65"])
        self.assertEqual(self.argv("bt-disconnect:A0:1B:9E:B3:9A:65"), ["bluetoothctl", "disconnect", "A0:1B:9E:B3:9A:65"])
        self.assertEqual(self.argv("bt-scan"), ["bluetoothctl", "--timeout", "6", "scan", "on"])

    def test_refresh_runs_nothing_and_a_missing_wifi_device_skips_the_disconnect(self) -> None:
        self.assertIsNone(self.argv("refresh"))
        self.assertIsNone(self.argv("wifi-disconnect", device=""))

    def test_unknown_verbs_and_malformed_requests_are_refused(self) -> None:
        for request in ("", "reboot", "wifi-on:x", "wifi-connect", "wifi-connect:", "vpn-up", "bt-scan:now",
                        "WIFI-ON", " wifi-on", "wifi-on\n", "rm -rf /"):
            with self.subTest(request=request), self.assertRaises(ValueError):
                network.parse(request)

    def test_arguments_cannot_smuggle_options_or_shell(self) -> None:
        for request in ("wifi-connect:--help", "wifi-connect:-x", "wifi-connect:" + "a" * 33, "wifi-connect:a\nb",
                        "vpn-up:--all", "vpn-up:a b", "vpn-up:a;reboot", "vpn-up:$(id)", "vpn-down:../x",
                        "bt-connect:not-a-mac", "bt-connect:AA:BB:CC:DD:EE", "bt-connect:AA:BB:CC:DD:EE:FF;id",
                        "bt-disconnect:--help"):
            with self.subTest(request=request), self.assertRaises(ValueError):
                network.parse(request)

    def test_a_name_with_odd_but_harmless_characters_is_one_argv_item(self) -> None:
        argv = self.argv("wifi-connect:$(id); echo 'x'")
        self.assertEqual(argv[-1], "$(id); echo 'x'")
        self.assertEqual(len(argv), 5)


class ParsingTests(unittest.TestCase):
    def test_terse_fields_unescape_colons(self) -> None:
        self.assertEqual(network.split_terse("a\\:b:c\\\\d::"), ["a:b", "c\\d", "", ""])

    def test_devices(self) -> None:
        devices = network.parse_devices(DEVICES)
        self.assertEqual(devices[0], {"name": "eno1", "type": "ethernet", "state": "connected", "connection": "Wired profile"})
        self.assertEqual(devices[4]["name"], "A0:1B:9E:B3:9A:65")

    def test_wifi_keeps_one_entry_per_name_and_the_one_in_use_first(self) -> None:
        networks = network.parse_wifi(WIFI)
        self.assertEqual([one["ssid"] for one in networks], ["Home: 5G", "Neighbour", "Cafe"])
        self.assertEqual(networks[0], {"ssid": "Home: 5G", "signal": 78, "security": "WPA2", "active": True})
        self.assertEqual(networks[2], {"ssid": "Cafe", "signal": 55, "security": "", "active": False})

    def test_ip4_takes_the_first_address(self) -> None:
        self.assertEqual(network.parse_ip4(IP4), {"address": "192.168.1.116/24", "gateway": "192.168.1.1"})
        self.assertEqual(network.parse_ip4(""), {"address": "", "gateway": ""})

    def test_bluetooth(self) -> None:
        self.assertEqual(network.parse_bluetooth_show(BT_SHOW), {"present": True, "powered": True})
        self.assertEqual(network.parse_bluetooth_show("No default controller available\n"),
                         {"present": False, "powered": False})
        self.assertEqual(network.parse_bluetooth_devices(BT_DEVICES),
                         [("A0:1B:9E:B3:9A:65", "Juan's A56"), ("11:22:33:44:55:66", "Buds")])
        info = network.parse_bluetooth_info(BT_INFO["A0:1B:9E:B3:9A:65"])
        self.assertEqual(info, {"paired": True, "connected": True, "battery": 88, "alias": "Juan's A56"})
        self.assertIsNone(network.parse_bluetooth_info(BT_INFO["11:22:33:44:55:66"])["battery"])

    def test_vpn_keeps_what_the_page_shows(self) -> None:
        tunnels = network.parse_vpn(VPN)
        self.assertEqual([one["id"] for one in tunnels], ["us-1", "us-2"])
        self.assertEqual(tunnels[0], {"id": "us-1", "name": "us-1.proton.udp.ovpn", "provider": "proton",
                                      "region": "US", "active": True})
        self.assertEqual(network.parse_vpn("not json"), [])


class StateTests(unittest.TestCase):
    def test_the_state_of_a_full_system(self) -> None:
        data = network.state(fake(EVERYTHING))
        self.assertEqual(data["ethernet"]["devices"], [{
            "name": "eno1", "type": "ethernet", "state": "connected", "connection": "Wired profile",
            "address": "192.168.1.116/24", "gateway": "192.168.1.1"}])
        self.assertTrue(data["ethernet"]["available"])
        self.assertEqual((data["wifi"]["available"], data["wifi"]["enabled"], data["wifi"]["device"]),
                         (True, True, "wlan0"))
        self.assertEqual(len(data["wifi"]["networks"]), 3)
        self.assertTrue(data["vpn"]["available"])
        self.assertTrue(data["bluetooth"]["available"] and data["bluetooth"]["powered"])
        self.assertEqual([one["name"] for one in data["bluetooth"]["devices"]], ["Juan's A56", "Buds"])
        self.assertEqual(data["bluetooth"]["devices"][0]["battery"], 88)
        self.assertIsInstance(data["updated"], int)
        json.dumps(data)

    def test_the_wifi_list_is_not_asked_while_the_radio_is_off(self) -> None:
        data = network.state(fake({**EVERYTHING, "nmcli radio wifi": "disabled\n"}))
        self.assertEqual((data["wifi"]["enabled"], data["wifi"]["networks"]), (False, []))
        self.assertTrue(data["wifi"]["available"])

    def test_without_any_tool_every_section_is_empty_and_unavailable(self) -> None:
        data = network.state(fake({}))
        self.assertFalse(data["ethernet"]["available"])
        self.assertEqual(data["ethernet"]["devices"], [])
        self.assertEqual(data["wifi"], {"available": False, "enabled": False, "device": "", "networks": []})
        self.assertEqual(data["vpn"], {"available": False, "tunnels": []})
        self.assertEqual(data["bluetooth"], {"available": False, "powered": False, "devices": []})

    def test_nameless_beacons_found_by_a_scan_are_not_listed_but_paired_ones_are(self) -> None:
        listed = BT_DEVICES + "Device 00:04:EA:A4:48:90 00-04-EA-A4-48-90\n"
        data = network.state(fake({**EVERYTHING, "bluetoothctl devices": listed}))
        self.assertEqual([one["mac"] for one in data["bluetooth"]["devices"]], ["A0:1B:9E:B3:9A:65", "11:22:33:44:55:66"])

    def test_without_a_bluetooth_controller_the_devices_are_not_listed(self) -> None:
        data = network.state(fake({**EVERYTHING, "bluetoothctl show": "No default controller available\n"}))
        self.assertFalse(data["bluetooth"]["available"])
        self.assertEqual(data["bluetooth"]["devices"], [])


class ApplyTests(unittest.TestCase):
    def run_apply(self, request: str, outputs: dict | None = None, code: int = 0):
        calls: list[tuple[list[str], int]] = []

        def act(argv: list[str], timeout: int = 0) -> tuple[int, str]:
            calls.append((argv, timeout))
            return code, "boom" if code else ""

        with tempfile.TemporaryDirectory() as folder, redirect_stdout(io.StringIO()) as log:
            result = network.apply(request, Path(folder), act, fake(EVERYTHING if outputs is None else outputs))
            written = json.loads((Path(folder) / network.STATE_FILE).read_text(encoding="utf-8")) \
                if (Path(folder) / network.STATE_FILE).exists() else None
        return result, calls, log.getvalue(), written

    def test_a_request_runs_its_command_logs_it_and_writes_the_fresh_state(self) -> None:
        result, calls, log, written = self.run_apply("vpn-down:us-2")
        self.assertEqual(result, 0)
        self.assertEqual(calls, [(["hypraether-vpn", "disconnect", "us-2"], 60)])
        self.assertIn("Connection: vpn-down:us-2 -> hypraether-vpn disconnect us-2", log)
        self.assertIn("Connection: vpn-down done", log)
        self.assertEqual(written["wifi"]["device"], "wlan0")

    def test_a_scan_gets_its_window_on_top_of_the_usual_wait(self) -> None:
        _result, calls, _log, _written = self.run_apply("bt-scan")
        self.assertEqual(calls, [(["bluetoothctl", "--timeout", "6", "scan", "on"], 66)])

    def test_the_wifi_disconnect_names_the_device_it_finds(self) -> None:
        _result, calls, _log, _written = self.run_apply("wifi-disconnect")
        self.assertEqual(calls[0][0], ["nmcli", "device", "disconnect", "wlan0"])

    def test_a_wifi_disconnect_without_a_device_runs_nothing(self) -> None:
        result, calls, log, _written = self.run_apply("wifi-disconnect", {})
        self.assertEqual((result, calls), (0, []))
        self.assertIn("no Wi-Fi device", log)

    def test_a_failing_command_is_logged_and_the_state_is_still_written(self) -> None:
        result, _calls, log, written = self.run_apply("bt-connect:11:22:33:44:55:66", code=3)
        self.assertEqual(result, 1)
        self.assertIn("Connection: bt-connect failed (3): boom", log)
        self.assertIsNotNone(written)

    def test_a_refused_request_runs_nothing_and_writes_nothing(self) -> None:
        result, calls, log, written = self.run_apply("vpn-up:a;reboot")
        self.assertEqual((result, calls, written), (2, [], None))
        self.assertIn("Connection: refused", log)

    def test_a_refresh_only_rescans_and_rewrites_the_state(self) -> None:
        result, calls, _log, written = self.run_apply("refresh")
        self.assertEqual((result, [argv for argv, _timeout in calls]), (0, [["nmcli", "device", "wifi", "rescan"]]))
        self.assertIsNotNone(written)
        self.assertEqual(self.run_apply("refresh", {})[1], [])


if __name__ == "__main__":
    unittest.main()
