"""The Connection page's data: requests become argv lists, and what nmcli,
bluetoothctl and hypraether-vpn print becomes the page's state."""

from __future__ import annotations

import io
import json
import os
import stat
import subprocess
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock

from vitrail import network, vpndoc

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
     "credential": "secret name", "config_path": "/x/us-1.conf", "active": True},
    {"id": "us-2", "name": "us-2.proton.udp.ovpn", "provider": "proton", "region": "US",
     "credential": "secret name", "config_path": "/x/us-2.conf", "active": False},
    {"id": "us-3", "name": "us-3.proton.udp.ovpn", "provider": "proton", "region": "US",
     "config_path": "/x/us-3.conf", "active": False},
    {"name": "no id"},
])
CREDENTIALS = json.dumps([
    {"id": 1, "name": "secret name", "username": "someone", "used_by": 2, "password": "must-not-pass"},
    {"id": 2, "name": "spare", "username": "other", "used_by": 0},
    {"name": 3},
])
DOMAIN_LIST = json.dumps([
    {"domain": "example.com", "ips": ["93.184.216.34", "2606:2800::1"]},
    {"domain": "www.example.com", "ips": []},
    {"domain": 5},
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
    "hypraether-vpn credential list --json": CREDENTIALS,
    "hypraether-vpn domain list --json": DOMAIN_LIST,
    "hypraether-vpn mode": "full\n",
    "bluetoothctl show": BT_SHOW,
    "bluetoothctl devices": BT_DEVICES,
    "bluetoothctl info A0:1B:9E:B3:9A:65": BT_INFO["A0:1B:9E:B3:9A:65"],
    "bluetoothctl info 11:22:33:44:55:66": BT_INFO["11:22:33:44:55:66"],
}


def controller(present: bool):
    return lambda: present


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
        self.assertEqual([one["id"] for one in tunnels], ["us-1", "us-2", "us-3"])
        self.assertEqual(tunnels[0], {"id": "us-1", "name": "us-1.proton.udp.ovpn", "provider": "proton",
                                      "region": "US", "credential": "secret name", "config_path": "/x/us-1.conf",
                                      "active": True})
        self.assertEqual(tunnels[2]["credential"], "")
        self.assertEqual(network.parse_vpn("not json"), [])

    def test_credentials_never_carry_a_password(self) -> None:
        self.assertEqual(network.parse_credentials(CREDENTIALS), [
            {"name": "secret name", "username": "someone", "usedBy": 2},
            {"name": "spare", "username": "other", "usedBy": 0},
        ])
        self.assertEqual(network.parse_credentials("not json"), [])

    def test_the_domain_list_keeps_a_count_of_addresses(self) -> None:
        self.assertEqual(network.parse_domains(DOMAIN_LIST), [
            {"domain": "example.com", "ips": 2}, {"domain": "www.example.com", "ips": 0}])
        self.assertEqual(network.parse_domains("{}"), [])


class StateTests(unittest.TestCase):
    def test_the_state_of_a_full_system(self) -> None:
        data = network.state(fake(EVERYTHING), bluetooth_present=controller(True))
        self.assertEqual(data["ethernet"]["devices"], [{
            "name": "eno1", "type": "ethernet", "state": "connected", "connection": "Wired profile",
            "address": "192.168.1.116/24", "gateway": "192.168.1.1"}])
        self.assertTrue(data["ethernet"]["available"])
        self.assertEqual((data["wifi"]["available"], data["wifi"]["enabled"], data["wifi"]["device"]),
                         (True, True, "wlan0"))
        self.assertEqual(len(data["wifi"]["networks"]), 3)
        self.assertTrue(data["vpn"]["available"])
        self.assertEqual(data["vpn"]["mode"], "full")
        self.assertEqual([one["name"] for one in data["vpn"]["credentials"]], ["secret name", "spare"])
        self.assertEqual([one["domain"] for one in data["vpn"]["domains"]], ["example.com", "www.example.com"])
        self.assertTrue(data["bluetooth"]["available"] and data["bluetooth"]["powered"])
        self.assertEqual([one["name"] for one in data["bluetooth"]["devices"]], ["Juan's A56", "Buds"])
        self.assertEqual(data["bluetooth"]["devices"][0]["battery"], 88)
        self.assertIsInstance(data["updated"], int)
        json.dumps(data)

    def test_the_wifi_list_is_not_asked_while_the_radio_is_off(self) -> None:
        data = network.state(fake({**EVERYTHING, "nmcli radio wifi": "disabled\n"}), bluetooth_present=controller(True))
        self.assertEqual((data["wifi"]["enabled"], data["wifi"]["networks"]), (False, []))
        self.assertTrue(data["wifi"]["available"])

    def test_without_any_tool_every_section_is_empty_and_unavailable(self) -> None:
        data = network.state(fake({}))
        self.assertFalse(data["ethernet"]["available"])
        self.assertEqual(data["ethernet"]["devices"], [])
        self.assertEqual(data["wifi"], {"available": False, "enabled": False, "device": "", "networks": []})
        self.assertEqual(data["vpn"], {"available": False, "tunnels": [], "credentials": [], "mode": "split",
                                       "domains": [], "enabled": False, "quality": {}})
        self.assertEqual(data["bluetooth"], {"available": False, "powered": False, "devices": []})

    def test_nameless_beacons_found_by_a_scan_are_not_listed_but_paired_ones_are(self) -> None:
        listed = BT_DEVICES + "Device 00:04:EA:A4:48:90 00-04-EA-A4-48-90\n"
        data = network.state(fake({**EVERYTHING, "bluetoothctl devices": listed}), bluetooth_present=controller(True))
        self.assertEqual([one["mac"] for one in data["bluetooth"]["devices"]], ["A0:1B:9E:B3:9A:65", "11:22:33:44:55:66"])

    def test_without_a_bluetooth_controller_the_devices_are_not_listed(self) -> None:
        data = network.state(fake({**EVERYTHING, "bluetoothctl show": "No default controller available\n"}),
                              bluetooth_present=controller(True))
        self.assertFalse(data["bluetooth"]["available"])
        self.assertEqual(data["bluetooth"]["devices"], [])

    def test_without_an_adapter_bluetoothctl_is_never_run(self) -> None:
        asked: list[list[str]] = []

        def run(argv: list[str]) -> str | None:
            asked.append(argv)
            return fake(EVERYTHING)(argv)

        data = network.state(run, bluetooth_present=controller(False))
        self.assertEqual(data["bluetooth"], {"available": False, "powered": False, "devices": []})
        self.assertFalse([argv for argv in asked if argv[0] == "bluetoothctl"])

    def test_the_adapter_check_looks_for_an_entry_in_sys_class_bluetooth(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            self.assertFalse(network.has_bluetooth_controller(Path(folder)))
            self.assertFalse(network.has_bluetooth_controller(Path(folder) / "missing"))
            (Path(folder) / "hci0").mkdir()
            self.assertTrue(network.has_bluetooth_controller(Path(folder)))

    def test_bluetoothctl_reads_wait_less_than_other_reads(self) -> None:
        waited: list[float] = []

        def fake_run(argv, **kwargs):
            waited.append(kwargs["timeout"])
            raise subprocess.TimeoutExpired(argv, kwargs["timeout"])

        with mock.patch.object(network.shutil, "which", return_value="/usr/bin/x"), \
                mock.patch.object(network.subprocess, "run", fake_run):
            self.assertIsNone(network.run_text(["bluetoothctl", "show"]))
            self.assertIsNone(network.run_text(["nmcli", "radio", "wifi"]))
        self.assertEqual(waited, [network.BLUETOOTH_READ, network.READ_TIMEOUT])
        self.assertLess(network.BLUETOOTH_READ, network.READ_TIMEOUT)


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

DOMAIN_ADDRESSES = {
    "example.com": ["93.184.216.34", "2606:2800::1"],
    "www.example.com": ["93.184.216.34"],
    "mail.example.com": ["93.184.216.35"],
}


def lookup(host: str) -> list[str]:
    return list(DOMAIN_ADDRESSES.get(host, []))


def transparency(domain: str) -> list[str]:
    return ["example.com\n*.example.com", "WWW.example.com", "mail.example.com", "gone.example.com",
            "example.org", "evil-example.com", "a.b.example.com"] if domain == "example.com" else []


def offline(_name: str) -> list[str]:
    raise OSError("network is unreachable")


class TargetTests(unittest.TestCase):
    def test_a_url_or_a_bare_host_gives_its_host(self) -> None:
        self.assertEqual(network.host_of("https://Example.com/a/b?q=1"), "example.com")
        self.assertEqual(network.host_of("http://example.com:8080"), "example.com")
        self.assertEqual(network.host_of("sub.example.co.uk"), "sub.example.co.uk")

    def test_anything_else_is_not_a_host(self) -> None:
        for text in ("", "-example.com", "--help", "ftp://example.com", "https://", "example", "a b.com",
                     "exa;mple.com", "https://user@example.com", "https://exa mple.com", "$(id).com",
                     "a" * 64 + ".com", ("a." * 130) + "com", "https://example.com/" + "x" * 2100,
                     "example.com\n", "-.com", "a..com", "https://127.0.0.1"):
            with self.subTest(text=text):
                self.assertIsNone(network.host_of(text))

    def test_the_registrable_domain_is_a_heuristic(self) -> None:
        self.assertEqual(network.registrable("www.example.com"), "example.com")
        self.assertEqual(network.registrable("example.com"), "example.com")
        self.assertEqual(network.registrable("a.b.example.co.uk"), "example.co.uk")
        self.assertEqual(network.registrable("www.example.com.br"), "example.com.br")
        self.assertEqual(network.registrable("www.example.org"), "example.org")


class ResolveTests(unittest.TestCase):
    def test_addresses_and_subdomains_are_merged_and_sorted(self) -> None:
        found = network.resolve_url("https://www.example.com/x", lookup, transparency)
        self.assertEqual(found["domains"], ["example.com", "mail.example.com", "www.example.com"])
        self.assertEqual(found["ips"], ["2606:2800::1", "93.184.216.34", "93.184.216.35"])
        self.assertNotIn("retry", found)

    def test_names_outside_the_domain_and_wildcards_and_dead_names_are_dropped(self) -> None:
        found = network.resolve_url("example.com", lookup, transparency)
        for name in ("example.org", "evil-example.com", "gone.example.com", "*.example.com", "a.b.example.com"):
            self.assertNotIn(name, found["domains"])

    def test_the_list_is_capped(self) -> None:
        many = {f"h{n}.example.com": [f"10.0.0.{n % 250}"] for n in range(200)}
        found = network.resolve_url(
            "example.com", lambda host: many.get(host, ["1.1.1.1"] if host == "example.com" else []),
            lambda _domain: list(many))
        self.assertEqual(len(found["domains"]), network.MAX_DOMAINS + 1)
        self.assertIn("example.com", found["domains"])

    def test_offline_keeps_empty_lists_and_asks_for_a_retry(self) -> None:
        found = network.resolve_url("https://example.com", lambda _host: [], offline)
        self.assertEqual(found, {"ips": [], "domains": [], "retry": True})

    def test_a_failing_directory_keeps_what_the_host_gave_and_asks_for_a_retry(self) -> None:
        found = network.resolve_url("https://example.com", lookup, offline)
        self.assertEqual(found["domains"], ["example.com"])
        self.assertEqual(found["ips"], ["2606:2800::1", "93.184.216.34"])
        self.assertTrue(found["retry"])

    def test_the_directory_answer_is_read_from_crt_sh_json(self) -> None:
        body = json.dumps([{"name_value": "a.example.com\nb.example.com"}, {"name_value": "c.example.com"}, {}])
        self.assertEqual(network.parse_transparency(body), ["a.example.com\nb.example.com", "c.example.com"])
        self.assertEqual(network.parse_transparency("not json"), [])


# --- the requests of the VPN tab ------------------------------------------------

NONCE = "0123456789abcdef0123456789abcdef"
OTHER_NONCE = "fedcba9876543210fedcba9876543210"


def req(verb: str, payload: dict) -> str:
    return f"{verb}:{json.dumps(payload)}"


class VpnRequestTests(unittest.TestCase):
    def argv(self, request: str, secret: str = "/run/s") -> list[str] | None:
        verb, argument = network.parse(request)
        return network.command(verb, argument, secret=secret)

    def test_the_simple_verbs_become_the_tools_argv(self) -> None:
        self.assertEqual(self.argv("vpn-off"), ["hypraether-vpn", "disconnect"])
        self.assertEqual(self.argv("vpn-mode:full"), ["hypraether-vpn", "mode", "full"])
        self.assertEqual(self.argv("vpn-mode:split"), ["hypraether-vpn", "mode", "split"])
        self.assertEqual(self.argv("vpn-domain-remove:www.example.com"),
                         ["hypraether-vpn", "domain", "remove", "www.example.com"])
        self.assertEqual(self.argv("vpn-domain-refresh"), ["hypraether-vpn", "domain", "refresh"])
        self.assertEqual(self.argv("vpn-remove:us-1"), ["hypraether-vpn", "remove", "us-1"])
        self.assertEqual(self.argv("vpn-cred-remove:jdgn protonvpn"),
                         ["hypraether-vpn", "credential", "remove", "jdgn protonvpn"])

    def test_verbs_that_run_several_commands_or_none_have_no_single_argv(self) -> None:
        for request in ("vpn-best", "vpn-probe", "vpn-domain-add:https://example.com"):
            with self.subTest(request=request):
                self.assertIsNone(self.argv(request))

    def test_an_import_names_the_file_and_only_what_was_given(self) -> None:
        self.assertEqual(self.argv(req("vpn-import", {"file": "/home/a b/x.ovpn"})),
                         ["hypraether-vpn", "import", "/home/a b/x.ovpn"])
        self.assertEqual(
            self.argv(req("vpn-import", {"file": "/x/y.ovpn", "name": "My server", "credential": "spare"})),
            ["hypraether-vpn", "import", "/x/y.ovpn", "--name", "My server", "--credential", "spare"])
        # Moving the original is Vitrail's step, not an argument of the tool.
        self.assertEqual(self.argv(req("vpn-import", {"file": "/x/y.ovpn", "move": True})),
                         ["hypraether-vpn", "import", "/x/y.ovpn"])

    def test_a_credential_add_hands_the_password_over_by_file_only(self) -> None:
        argv = self.argv(req("vpn-cred-add", {"name": "work", "user": "me", "nonce": NONCE}), "/run/p")
        self.assertEqual(argv, ["hypraether-vpn", "credential", "add", "work", "--user", "me", "--pass-file", "/run/p"])
        self.assertNotIn(NONCE, " ".join(argv))

    def test_a_credential_update_changes_only_what_was_asked(self) -> None:
        self.assertEqual(self.argv(req("vpn-cred-update", {"name": "work", "rename": "job"})),
                         ["hypraether-vpn", "credential", "update", "work", "--rename", "job"])
        self.assertEqual(self.argv(req("vpn-cred-update", {"name": "work", "user": "me", "nonce": NONCE}), "/run/p"),
                         ["hypraether-vpn", "credential", "update", "work", "--user", "me", "--pass-file", "/run/p"])

    def test_a_credential_assign_lists_the_connections(self) -> None:
        self.assertEqual(self.argv(req("vpn-cred-assign", {"name": "work", "ids": ["us-1", "us-2"]})),
                         ["hypraether-vpn", "credential", "assign", "work", "us-1", "us-2"])

    def test_malformed_vpn_requests_are_refused(self) -> None:
        bad = [
            "vpn-best:x", "vpn-off:x", "vpn-probe:", "vpn-mode", "vpn-mode:", "vpn-mode:both", "vpn-mode:SPLIT",
            "vpn-domain-add", "vpn-domain-add:--help", "vpn-domain-add:a b.com", "vpn-domain-add:ftp://x.com",
            "vpn-domain-remove:--all", "vpn-domain-remove:a b.com", "vpn-domain-remove:x;reboot.com",
            "vpn-domain-remove:single", "vpn-remove:--all", "vpn-remove:../x", "vpn-remove:a b",
            "vpn-cred-remove:", "vpn-cred-remove:-x", "vpn-cred-remove:a\nb", "vpn-cred-remove:" + "a" * 65,
            "vpn-cred-remove: padded ",
            "vpn-import:not json", "vpn-import:[]", "vpn-import:{}",
            req("vpn-import", {"file": "relative/x.ovpn"}),
            req("vpn-import", {"file": "/x/y.txt"}),
            req("vpn-import", {"file": "/x/y.ovpn\n"}),
            req("vpn-import", {"file": "/x/y.ovpn", "name": "-x"}),
            req("vpn-import", {"file": "/x/y.ovpn", "credential": "--pass"}),
            req("vpn-import", {"file": "/x/y.ovpn", "extra": 1}),
            req("vpn-import", {"file": "/x/y.ovpn", "move": "yes"}),
            req("vpn-import", {"file": 5}),
            req("vpn-cred-add", {"name": "work", "user": "me"}),
            req("vpn-cred-add", {"name": "work", "user": "me", "nonce": "short"}),
            req("vpn-cred-add", {"name": "work", "user": "me", "nonce": "../" + NONCE[3:]}),
            req("vpn-cred-add", {"name": "work", "user": "", "nonce": NONCE}),
            req("vpn-cred-add", {"name": "work", "user": "-me", "nonce": NONCE}),
            req("vpn-cred-add", {"name": "work", "user": "me", "nonce": NONCE, "password": "leak"}),
            req("vpn-cred-update", {"name": "work"}),
            req("vpn-cred-update", {"name": "work", "rename": "-x"}),
            req("vpn-cred-update", {"name": "work", "nonce": "x"}),
            req("vpn-cred-assign", {"name": "work", "ids": []}),
            req("vpn-cred-assign", {"name": "work", "ids": ["--all"]}),
            req("vpn-cred-assign", {"name": "work", "ids": "us-1"}),
            req("vpn-cred-assign", {"name": "work", "ids": ["us-1"] * 65}),
        ]
        for request in bad:
            with self.subTest(request=request), self.assertRaises(ValueError):
                network.parse(request)

    def test_a_removed_verb_is_unknown(self) -> None:
        with self.assertRaises(ValueError):
            network.parse("vpn-resolve:https://example.com")


class SecretTests(unittest.TestCase):
    """The password travels in a file the window writes through Qt.labs.settings
    (an ini under $XDG_RUNTIME_DIR, named by a nonce); the lines below are what
    Qt 6.11 really wrote for each password."""
    WRITTEN = [
        ("plain", "password=plain"),
        ("@start", "password=@@start"),
        (" lead and trail ", 'password=" lead and trail "'),
        ("semi;colon", 'password="semi;colon"'),
        ("back\\slash", "password=back\\\\slash"),
        ('q"uote', 'password=q\\"uote'),
        ("comma,one,two", 'password="comma,one,two"'),
        ("é漢😀", "password=é漢😀"),
        ("@a;b", 'password="@@a;b"'),
        ('a"b;c', 'password="a\\"b;c"'),
        ("p\\", "password=p\\\\"),
        ("\\x41", "password=\\\\x41"),
        ("a\\nb", "password=a\\\\nb"),
        ("[bracket]#hash%41", "password=[bracket]#hash%41"),
    ]

    def test_what_qt_wrote_reads_back_exactly(self) -> None:
        for password, line in self.WRITTEN:
            with self.subTest(password=password):
                self.assertEqual(network.read_secret_text(f"[secret]\n{line}\n"), password)

    def test_a_file_without_a_usable_password_is_refused(self) -> None:
        for text in ("", "[secret]\n", "[secret]\npassword=\n", '[secret]\npassword=""\n', "[secret]\nother=x\n",
                     "[secret]\npassword=@Variant(abc)\n", "[secret]\npassword=a\\x1b\n"):
            with self.subTest(text=text), self.assertRaises(ValueError):
                network.read_secret_text(text)

    def test_stale_secret_files_are_swept_and_fresh_ones_kept(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            runtime = Path(folder)
            names = {"vitrail-secret-" + NONCE + ".ini": 10_000, "vitrail-pass-" + NONCE: 10_000,
                     "vitrail-secret-" + OTHER_NONCE + ".ini": 5, "unrelated.txt": 10_000}
            for name, age in names.items():
                (runtime / name).write_text("x", encoding="utf-8")
                os.utime(runtime / name, (1_000_000 - age, 1_000_000 - age))
            network.sweep_secrets(runtime, now=1_000_000)
            self.assertEqual(sorted(path.name for path in runtime.iterdir()),
                             ["unrelated.txt", "vitrail-secret-" + OTHER_NONCE + ".ini"])


class VpnHarness(unittest.TestCase):
    """`apply` with everything injected: the tool, the network, the pings, the
    config files and the runtime directory (where a password file may sit)."""

    OUTPUTS = {**EVERYTHING}
    CONFIGS = {
        "/x/us-1.conf": "client\nremote a.example.net 1194\nremote b.example.net 443\n",
        "/x/us-2.conf": "remote c.example.net 1194\n",
        "/x/us-3.conf": "remote d.example.net 1194\n",
    }
    PINGS = {"a.example.net": (40.0, 0), "b.example.net": (60.0, 0), "c.example.net": (30.0, 10),
             "d.example.net": (5.0, 0)}

    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.folder = Path(self.tmp.name) / "config"
        self.runtime = Path(self.tmp.name) / "run"
        self.vpn = Path(self.tmp.name) / "vpn"
        self.share = Path(self.tmp.name) / "share"
        self.folder.mkdir()
        self.runtime.mkdir()
        self.calls: list[list[str]] = []
        self.seen_files: list[dict[str, str]] = []
        self.pinged: list[str] = []
        self.codes: dict[str, int] = {}
        self.marker = Path(self.tmp.name) / "enabled"

    def store(self, source: Path, move: bool = False) -> Path:
        return vpndoc.store_file(source, move, self.share)

    def act(self, argv: list[str], timeout: int = 0) -> tuple[int, str]:
        self.calls.append(argv)
        # What sits in the runtime directory while the tool runs.
        self.seen_files.append({path.name: path.read_text(encoding="utf-8") for path in self.runtime.iterdir()})
        return self.codes.get(" ".join(argv[1:3]), 0), "boom"

    def pinger(self, host: str) -> tuple[float | None, int | None]:
        self.pinged.append(host)
        return self.PINGS.get(host, (None, 100))

    def apply(self, request: str, outputs: dict | None = None, **extra):
        outputs = self.OUTPUTS if outputs is None else outputs
        with redirect_stdout(io.StringIO()) as log:
            result = network.apply(request, self.folder, self.act, fake(outputs), resolver=lookup,
                                   directory=transparency, pinger=self.pinger,
                                   read=lambda path: self.CONFIGS.get(path, ""),
                                   runtime=self.runtime, marker=self.marker,
                                   doc_folder=self.vpn, store=self.store, **extra)
        path = self.folder / network.STATE_FILE
        written = json.loads(path.read_text(encoding="utf-8")) if path.exists() else None
        return result, log.getvalue(), written

    def write_secret(self, nonce: str, line: str) -> Path:
        path = self.runtime / f"vitrail-secret-{nonce}.ini"
        path.write_text(f"[secret]\n{line}\n", encoding="utf-8")
        return path


class SimpleVpnApplyTests(VpnHarness):
    def test_a_simple_verb_runs_its_argv_logs_it_and_rewrites_the_state(self) -> None:
        for request, argv in (("vpn-mode:full", ["hypraether-vpn", "mode", "full"]),
                              ("vpn-off", ["hypraether-vpn", "disconnect"]),
                              ("vpn-domain-refresh", ["hypraether-vpn", "domain", "refresh"]),
                              ("vpn-remove:us-3", ["hypraether-vpn", "remove", "us-3"])):
            with self.subTest(request=request):
                self.calls.clear()
                result, log, written = self.apply(request)
                self.assertEqual((result, self.calls), (0, [argv]))
                self.assertIn(f"Connection: {request} -> {' '.join(argv)}", log)
                self.assertTrue(written["vpn"]["available"])

    def test_a_refused_vpn_request_runs_nothing(self) -> None:
        result, log, written = self.apply("vpn-mode:both")
        self.assertEqual((result, self.calls, written), (2, [], None))
        self.assertIn("Connection: refused", log)

    def test_a_failing_tool_is_logged_and_gives_one(self) -> None:
        self.codes["mode full"] = 3
        result, log, written = self.apply("vpn-mode:full")
        self.assertEqual(result, 1)
        self.assertIn("vpn-mode failed (3): boom", log)
        self.assertIsNotNone(written)

    def test_the_state_says_which_request_it_answers_and_how_it_went(self) -> None:
        self.assertEqual(self.apply("vpn-mode:full")[2]["result"], {"verb": "vpn-mode", "code": 0})
        self.codes["mode split"] = 2
        self.assertEqual(self.apply("vpn-mode:split")[2]["result"], {"verb": "vpn-mode", "code": 1})

    def test_the_marker_is_the_enabled_flag_of_the_state(self) -> None:
        self.assertFalse(self.apply("refresh")[2]["vpn"]["enabled"])
        self.marker.write_text("", encoding="utf-8")
        self.assertTrue(self.apply("refresh")[2]["vpn"]["enabled"])
        self.assertFalse(self.apply("refresh", {})[2]["vpn"]["enabled"])


class DomainApplyTests(VpnHarness):
    OUTPUTS = {**EVERYTHING, "hypraether-vpn domain list --json": json.dumps(
        [{"domain": "example.com", "ips": ["1.2.3.4"]}])}

    def test_adding_a_url_adds_the_host_and_the_live_subdomains_it_found(self) -> None:
        result, log, _written = self.apply("vpn-domain-add:https://www.example.com/x")
        self.assertEqual(result, 0)
        self.assertEqual(self.calls, [
            ["hypraether-vpn", "domain", "add", "www.example.com"],
            ["hypraether-vpn", "domain", "add", "mail.example.com"],
        ])
        self.assertIn("vpn-domain-add done (2 added)", log)

    def test_names_the_tool_already_lists_are_not_added_again(self) -> None:
        self.apply("vpn-domain-add:example.com")
        self.assertEqual([call[-1] for call in self.calls], ["mail.example.com", "www.example.com"])

    def test_offline_the_host_alone_is_still_added(self) -> None:
        with redirect_stdout(io.StringIO()):
            network.apply("vpn-domain-add:https://nothing.test", self.folder, self.act, fake(self.OUTPUTS),
                          resolver=lambda _host: [], directory=offline, runtime=self.runtime, marker=self.marker)
        self.assertEqual(self.calls, [["hypraether-vpn", "domain", "add", "nothing.test"]])

    def test_a_failed_add_of_the_host_gives_one_and_the_rest_still_runs(self) -> None:
        self.codes["domain add"] = 1
        result, log, _written = self.apply("vpn-domain-add:www.example.com")
        self.assertEqual(result, 1)
        self.assertEqual(len(self.calls), 2)
        self.assertIn("domain add failed", log)

    def test_the_subdomains_are_capped(self) -> None:
        many = {f"h{n}.example.com": ["10.0.0.1"] for n in range(200)}
        with redirect_stdout(io.StringIO()):
            network.apply("vpn-domain-add:example.com", self.folder, self.act, fake(self.OUTPUTS),
                          resolver=lambda host: many.get(host, ["1.1.1.1"]), directory=lambda _d: list(many),
                          runtime=self.runtime, marker=self.marker)
        self.assertLessEqual(len(self.calls), network.MAX_DOMAINS + 1)


class CredentialApplyTests(VpnHarness):
    def add_request(self, nonce: str = NONCE, user: str = "me-user") -> str:
        return req("vpn-cred-add", {"name": "work", "user": user, "nonce": nonce})

    def test_the_password_reaches_the_tool_by_file_and_the_files_are_gone_afterwards(self) -> None:
        self.write_secret(NONCE, 'password="s3cr;et,pw"')
        result, log, written = self.apply(self.add_request())
        self.assertEqual(result, 0)
        argv = self.calls[0]
        self.assertEqual(argv[:6], ["hypraether-vpn", "credential", "add", "work", "--user", "me-user"])
        self.assertEqual(argv[6], "--pass-file")
        # While the tool ran the file held exactly the password, with no newline.
        self.assertEqual(list(self.seen_files[0].values()).count("s3cr;et,pw"), 1)
        self.assertEqual(sorted(path.name for path in self.runtime.iterdir()), [])
        self.assertNotIn("s3cr", log + json.dumps(written))

    def test_the_password_file_is_private(self) -> None:
        self.write_secret(NONCE, "password=pw")
        modes: list[int] = []

        def act(argv: list[str], timeout: int = 0) -> tuple[int, str]:
            modes.append(os.stat(argv[-1]).st_mode & 0o777)
            return 0, ""

        with redirect_stdout(io.StringIO()):
            network.apply(self.add_request(), self.folder, act, fake(EVERYTHING), runtime=self.runtime,
                          marker=self.marker)
        self.assertEqual(modes, [0o600])

    def test_files_are_deleted_when_the_tool_fails(self) -> None:
        self.write_secret(NONCE, "password=pw")
        self.codes["credential add"] = 4
        result, log, _written = self.apply(self.add_request())
        self.assertEqual(result, 1)
        self.assertEqual(list(self.runtime.iterdir()), [])
        self.assertIn("vpn-cred-add failed (4)", log)

    def test_files_are_deleted_when_the_run_blows_up(self) -> None:
        self.write_secret(NONCE, "password=pw")

        def act(argv: list[str], timeout: int = 0) -> tuple[int, str]:
            raise RuntimeError("tool exploded")

        with redirect_stdout(io.StringIO()), self.assertRaises(RuntimeError):
            network.apply(self.add_request(), self.folder, act, fake(EVERYTHING), runtime=self.runtime,
                          marker=self.marker)
        self.assertEqual(list(self.runtime.iterdir()), [])

    def test_neither_the_password_nor_the_username_is_ever_logged_or_stored(self) -> None:
        self.write_secret(NONCE, 'password="hunter2;hunter2"')
        _result, log, written = self.apply(self.add_request(user="very-secret-user"))
        for text in (log, json.dumps(written)):
            self.assertNotIn("hunter2", text)
            self.assertNotIn("very-secret-user", text)
        self.assertIn("Connection: vpn-cred-add work", log)

    def test_a_missing_or_broken_secret_runs_nothing(self) -> None:
        self.write_secret(OTHER_NONCE, "password=\n")
        for nonce in (NONCE, OTHER_NONCE):
            with self.subTest(nonce=nonce):
                result, log, _written = self.apply(self.add_request(nonce), secret_wait=0)
                self.assertEqual((result, self.calls), (1, []))
                self.assertIn("no password", log)
        self.assertEqual(list(self.runtime.iterdir()), [])

    def test_without_a_runtime_directory_a_password_request_is_refused(self) -> None:
        with redirect_stdout(io.StringIO()) as log:
            result = network.apply(self.add_request(), self.folder, self.act, fake(EVERYTHING), runtime=None,
                                   marker=self.marker)
        self.assertEqual((result, self.calls), (1, []))
        self.assertIn("no runtime directory", log.getvalue())

    def test_an_update_without_a_new_password_needs_no_file(self) -> None:
        result, log, _written = self.apply(req("vpn-cred-update", {"name": "work", "rename": "job"}))
        self.assertEqual((result, self.calls),
                         (0, [["hypraether-vpn", "credential", "update", "work", "--rename", "job"]]))
        self.assertIn("Connection: vpn-cred-update work", log)

    def test_an_update_with_a_new_password_passes_the_file(self) -> None:
        self.write_secret(NONCE, "password=new")
        self.apply(req("vpn-cred-update", {"name": "work", "user": "me", "nonce": NONCE}))
        self.assertEqual(self.calls[0][:7],
                         ["hypraether-vpn", "credential", "update", "work", "--user", "me", "--pass-file"])
        self.assertEqual(list(self.runtime.iterdir()), [])

    def test_stale_files_of_other_requests_are_swept_first(self) -> None:
        stale = self.write_secret(OTHER_NONCE, "password=old")
        os.utime(stale, (1, 1))
        self.apply("refresh")
        self.assertFalse(stale.exists())

    def test_the_other_credential_verbs_log_the_name_only(self) -> None:
        _r, log, _w = self.apply(req("vpn-cred-assign", {"name": "work", "ids": ["us-1", "us-2"]}))
        self.assertIn("Connection: vpn-cred-assign work", log)
        self.assertEqual(self.calls, [["hypraether-vpn", "credential", "assign", "work", "us-1", "us-2"]])
        _r, log, _w = self.apply("vpn-cred-remove:work")
        self.assertIn("Connection: vpn-cred-remove work", log)

    def picked(self, name: str = "x.ovpn", text: str = "client\n") -> Path:
        folder = Path(self.tmp.name) / "picked"
        folder.mkdir(exist_ok=True)
        path = folder / name
        path.write_text(text, encoding="utf-8")
        return path

    def test_an_import_copies_the_file_privately_and_gives_the_copy_to_the_tool(self) -> None:
        source = self.picked()
        _r, log, _w = self.apply(req("vpn-import", {"file": str(source), "credential": "spare"}))
        stored = self.share / "x.ovpn"
        self.assertEqual(self.calls, [["hypraether-vpn", "import", str(stored), "--credential", "spare"]])
        self.assertEqual(stored.read_text(encoding="utf-8"), "client\n")
        self.assertEqual(stat.S_IMODE(stored.stat().st_mode), 0o600)
        self.assertTrue(source.exists())
        self.assertIn("Connection: vpn-import x.ovpn", log)

    def test_a_move_removes_the_original_after_the_copy(self) -> None:
        source = self.picked()
        self.apply(req("vpn-import", {"file": str(source), "move": True}))
        self.assertFalse(source.exists())
        self.assertEqual(self.calls[0][2], str(self.share / "x.ovpn"))

    def test_an_import_of_a_file_that_is_not_there_runs_nothing(self) -> None:
        result, log, _w = self.apply(req("vpn-import", {"file": str(Path(self.tmp.name) / "gone.ovpn")}))
        self.assertEqual((result, self.calls), (1, []))
        self.assertIn("vpn-import failed", log)


class ProbeTests(unittest.TestCase):
    PING = ("PING a (1.2.3.4) 56(84) bytes of data.\n\n--- a ping statistics ---\n"
            "3 packets transmitted, 3 received, 0% packet loss, time 2003ms\n"
            "rtt min/avg/max/mdev = 10.100/12.500/15.000/1.000 ms\n")
    LOST = "3 packets transmitted, 0 received, 100% packet loss, time 2048ms\n"

    def test_ping_output_gives_the_mean_rtt_and_the_loss(self) -> None:
        self.assertEqual(network.parse_ping(self.PING), (12.5, 0))
        self.assertEqual(network.parse_ping(self.LOST), (None, 100))
        self.assertEqual(network.parse_ping("garbage"), (None, None))

    def test_the_remote_hosts_come_from_the_config_three_at_most(self) -> None:
        text = "client\nremote a.example.net 1194\nremote b.example.net 443\nremote 10.0.0.1 1\nremote d.example.net 2\n"
        self.assertEqual(network.remote_hosts(text), ["a.example.net", "b.example.net", "10.0.0.1"])
        self.assertEqual(network.remote_hosts("remote -x 1\nremote a;b 2\nremote a.b\nnothing"), [])

    def test_latency_is_the_mean_of_the_hosts_and_loss_the_worst(self) -> None:
        tunnels = [{"id": "a", "config_path": "/a"}, {"id": "b", "config_path": "/b"},
                   {"id": "c", "config_path": "/c"}]
        configs = {"/a": "remote h1.example.net 1\nremote h2.example.net 1\n", "/b": "remote h3.example.net 1\n",
                   "/c": "# no remote\n"}
        pings = {"h1.example.net": (10.0, 0), "h2.example.net": (30.0, 33), "h3.example.net": (None, 100)}
        got = network.probe(tunnels, lambda host: pings[host], lambda path: configs[path])
        self.assertEqual(got, {"a": {"latency": 20.0, "loss": 33}, "b": {"latency": None, "loss": 100},
                               "c": {"latency": None, "loss": None}})

    def test_a_host_shared_by_two_connections_is_pinged_once(self) -> None:
        seen: list[str] = []
        network.probe([{"id": "a", "config_path": "/a"}, {"id": "b", "config_path": "/a"}],
                      lambda host: seen.append(host) or (1.0, 0), lambda _p: "remote h.example.net 1\n")
        self.assertEqual(seen, ["h.example.net"])

    def test_the_ping_argv_is_the_one_hypraether_uses(self) -> None:
        done = mock.Mock(stdout=self.PING)
        with mock.patch.object(network.subprocess, "run", return_value=done) as run:
            self.assertEqual(network.ping_host("a.example.net"), (12.5, 0))
        self.assertEqual(run.call_args.args[0], ["env", "LANG=C", "ping", "-c", "3", "-W", "1", "a.example.net"])

    def test_a_ping_that_cannot_run_counts_as_lost(self) -> None:
        with mock.patch.object(network.subprocess, "run", side_effect=OSError("no ping")):
            self.assertEqual(network.ping_host("a.example.net"), (None, 100))


def conn(id: str, credential: str = "cred") -> dict:
    return {"id": id, "credential": credential}


class BestTests(unittest.TestCase):
    def quality(self, **kwargs: tuple[float | None, int | None]) -> dict:
        return {key: {"latency": latency, "loss": loss} for key, (latency, loss) in kwargs.items()}

    def test_the_lowest_latency_wins(self) -> None:
        tunnels = [conn("a"), conn("b"), conn("c")]
        self.assertEqual(network.best(tunnels, self.quality(a=(50, 0), b=(20, 0), c=(30, 0)), set()), "b")

    def test_loss_breaks_a_tie(self) -> None:
        tunnels = [conn("a"), conn("b")]
        self.assertEqual(network.best(tunnels, self.quality(a=(20, 10), b=(20, 0)), set()), "b")

    def test_only_connections_with_a_credential_compete_unless_none_has_one(self) -> None:
        tunnels = [conn("a", ""), conn("b")]
        self.assertEqual(network.best(tunnels, self.quality(a=(1, 0), b=(90, 0)), set()), "b")
        self.assertEqual(network.best([conn("a", ""), conn("b", "")], self.quality(a=(9, 0), b=(5, 0)), set()), "b")

    def test_measured_connections_beat_unmeasured_ones(self) -> None:
        tunnels = [conn("a"), conn("b")]
        self.assertEqual(network.best(tunnels, self.quality(a=(None, 100), b=(300, 0)), set()), "b")

    def test_nothing_measured_gives_the_first_of_the_pool(self) -> None:
        self.assertEqual(network.best([conn("a", ""), conn("b"), conn("c")], {}, set()), "b")
        self.assertEqual(network.best([conn("a"), conn("b")], self.quality(a=(None, None), b=(None, None)), set()), "a")

    def test_an_excluded_connection_is_left_out_unless_that_empties_the_pool(self) -> None:
        tunnels = [conn("a"), conn("b")]
        quality = self.quality(a=(10, 0), b=(50, 0))
        self.assertEqual(network.best(tunnels, quality, {"a"}), "b")
        self.assertEqual(network.best(tunnels, quality, {"a", "b"}), "a")

    def test_the_credential_filter_comes_before_the_exclusion(self) -> None:
        # a has no credential and b is excluded: the pool is {b}, and excluding it would empty it.
        self.assertEqual(network.best([conn("a", ""), conn("b")], {}, {"b"}), "b")

    def test_no_connections_gives_none(self) -> None:
        self.assertIsNone(network.best([], {}, set()))


class ExcludedTests(unittest.TestCase):
    def test_the_auto_flag_is_read_from_the_vpn_document(self) -> None:
        self.assertEqual(network.excluded({}), set())
        self.assertEqual(network.excluded({"connections": "no"}), set())
        document = {"connections": {"us-1": {"auto": False}, "us-2": {"auto": True}, "us-3": {}, "us-4": 5},
                    "users": [{"id": "old"}], "assignments": []}
        self.assertEqual(network.excluded(document), {"us-1"})

    def test_the_document_is_read_from_the_private_folder(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            self.assertEqual(network.excluded(vpndoc.read_doc(Path(folder))), set())
            vpndoc.write_doc({"connections": {"us-1": {"auto": False}}}, Path(folder))
            self.assertEqual(network.excluded(vpndoc.read_doc(Path(folder))), {"us-1"})


class BestApplyTests(VpnHarness):
    def test_the_best_one_is_connected_after_a_fresh_probe_and_the_quality_is_kept(self) -> None:
        result, log, written = self.apply("vpn-best")
        self.assertEqual(result, 0)
        # us-3 has no credential; us-1 averages 50 ms and us-2 answers in 30 ms.
        self.assertEqual(self.calls, [["hypraether-vpn", "connect", "us-2"]])
        # Every connection is measured, the one without a credential too.
        self.assertEqual(sorted(self.pinged), ["a.example.net", "b.example.net", "c.example.net", "d.example.net"])
        self.assertEqual(written["vpn"]["quality"]["us-1"], {"latency": 50.0, "loss": 0})
        self.assertEqual(written["vpn"]["quality"]["us-2"], {"latency": 30.0, "loss": 10})
        self.assertIn("vpn-best -> hypraether-vpn connect us-2", log)

    def test_the_exclusion_of_the_page_is_honoured(self) -> None:
        document = {"connections": {"us-2": {"auto": False}}}
        vpndoc.write_doc(document, self.vpn)
        self.apply("vpn-best")
        self.assertEqual(self.calls, [["hypraether-vpn", "connect", "us-1"]])

    def test_without_connections_nothing_runs(self) -> None:
        result, log, _written = self.apply("vpn-best", {"hypraether-vpn list --json": "[]"})
        self.assertEqual((result, self.calls), (0, []))
        self.assertIn("no connection", log)

    def test_a_probe_pings_every_connection_and_connects_nothing(self) -> None:
        result, _log, written = self.apply("vpn-probe")
        self.assertEqual((result, self.calls), (0, []))
        self.assertEqual(sorted(written["vpn"]["quality"]), ["us-1", "us-2", "us-3"])
        self.assertEqual(written["vpn"]["quality"]["us-3"], {"latency": 5.0, "loss": 0})

    def test_any_other_request_keeps_the_last_quality_and_pings_nothing(self) -> None:
        self.apply("vpn-probe")
        self.pinged.clear()
        _r, _l, written = self.apply("refresh")
        self.assertEqual(self.pinged, [])
        self.assertEqual(written["vpn"]["quality"]["us-1"], {"latency": 50.0, "loss": 0})

    def test_the_state_alone_never_pings_and_drops_connections_that_are_gone(self) -> None:
        (self.folder / network.STATE_FILE).write_text(json.dumps(
            {"vpn": {"quality": {"us-1": {"latency": 1.0, "loss": 0}, "gone": {"latency": 2.0, "loss": 0}}}}),
            encoding="utf-8")
        data = network.state(fake(EVERYTHING), network.load_quality(self.folder), marker=self.marker,
                             bluetooth_present=controller(True))
        self.assertEqual(data["vpn"]["quality"], {"us-1": {"latency": 1.0, "loss": 0}})
        self.assertEqual(self.pinged, [])

    def test_a_broken_state_file_gives_no_quality(self) -> None:
        (self.folder / network.STATE_FILE).write_text("{not json", encoding="utf-8")
        self.assertEqual(network.load_quality(self.folder), {})
        self.assertEqual(network.load_quality(self.folder / "nowhere"), {})


class StartupTests(unittest.TestCase):
    def test_the_login_rule_of_hypraether(self) -> None:
        active = [{"id": "a", "credential": "c", "active": True}]
        idle = [{"id": "a", "credential": "c", "active": False}]
        bare = [{"id": "a", "credential": "", "active": False}]
        self.assertEqual(network.startup_action(False, idle), "none")
        self.assertEqual(network.startup_action(False, []), "none")
        self.assertEqual(network.startup_action(True, active), "none")
        self.assertEqual(network.startup_action(False, active), "mark-enabled")
        self.assertEqual(network.startup_action(True, idle), "connect")
        self.assertEqual(network.startup_action(True, []), "none")
        self.assertEqual(network.startup_action(True, bare), "none")


class AutostartTests(VpnHarness):
    def setUp(self) -> None:
        super().setUp()
        self.sleeps: list[float] = []
        self.connectivity = "full\n"

    def outputs(self, listed: list[dict] | None = None) -> dict:
        return {**EVERYTHING, "nmcli networking connectivity": self.connectivity,
                **({} if listed is None else {"hypraether-vpn list --json": json.dumps(listed)})}

    def start(self, outputs: dict | None = None, session: str | None = "sig-1", run=None, pinger=None):
        outputs = self.outputs() if outputs is None else outputs
        with redirect_stdout(io.StringIO()) as log:
            result = network.autostart(
                self.folder, self.act, run or fake(outputs), pinger=pinger or self.pinger,
                read=lambda path: self.CONFIGS.get(path, ""), runtime=self.runtime, marker=self.marker,
                session=session, sleep=self.sleeps.append, doc_folder=self.vpn)
        return result, log.getvalue()

    def listing(self, active: bool) -> list[dict]:
        return [{"id": "us-1", "name": "n", "credential": "c", "config_path": "/x/us-1.conf", "active": active},
                {"id": "us-2", "name": "n", "credential": "c", "config_path": "/x/us-2.conf", "active": False}]

    def test_without_the_marker_and_without_a_tunnel_nothing_happens(self) -> None:
        self.assertEqual(self.start(self.outputs(self.listing(False)))[0], 0)
        self.assertEqual((self.calls, self.pinged, self.marker.exists()), ([], [], False))

    def test_a_tunnel_that_is_up_without_the_marker_gets_the_marker(self) -> None:
        self.start(self.outputs(self.listing(True)))
        self.assertTrue(self.marker.exists())
        self.assertEqual(self.calls, [])

    def test_a_tunnel_that_is_up_with_the_marker_is_left_alone(self) -> None:
        self.marker.write_text("", encoding="utf-8")
        self.start(self.outputs(self.listing(True)))
        self.assertEqual((self.calls, self.pinged), ([], []))

    def test_the_marker_with_nothing_up_connects_the_best(self) -> None:
        self.marker.write_text("", encoding="utf-8")
        result, log = self.start(self.outputs(self.listing(False)))
        self.assertEqual((result, self.calls), (0, [["hypraether-vpn", "connect", "us-2"]]))
        self.assertEqual(self.sleeps, [])
        self.assertIn("autostart", log)

    def test_the_marker_but_no_credential_connects_nothing(self) -> None:
        self.marker.write_text("", encoding="utf-8")
        listed = [{"id": "us-1", "credential": "", "config_path": "/x/us-1.conf", "active": False}]
        self.start(self.outputs(listed))
        self.assertEqual(self.calls, [])

    def test_the_rule_runs_once_per_session(self) -> None:
        self.marker.write_text("", encoding="utf-8")
        self.start(self.outputs(self.listing(False)))
        self.calls.clear()
        self.assertEqual(self.start(self.outputs(self.listing(False)))[0], 0)
        self.assertEqual(self.calls, [])
        self.start(self.outputs(self.listing(False)), session="sig-2")
        self.assertEqual(len(self.calls), 1)

    def test_a_disconnect_in_between_is_not_undone_by_a_restart(self) -> None:
        self.marker.write_text("", encoding="utf-8")
        self.start(self.outputs(self.listing(False)))
        self.marker.unlink()
        self.calls.clear()
        self.start(self.outputs(self.listing(False)))
        self.assertEqual(self.calls, [])

    def test_without_a_runtime_directory_nothing_runs(self) -> None:
        self.marker.write_text("", encoding="utf-8")
        with redirect_stdout(io.StringIO()):
            result = network.autostart(self.folder, self.act, fake(self.outputs(self.listing(False))),
                                       pinger=self.pinger, runtime=None, marker=self.marker, session="s",
                                       sleep=self.sleeps.append)
        self.assertEqual((result, self.calls), (0, []))

    def test_nothing_measured_waits_for_the_network_then_measures_again(self) -> None:
        self.marker.write_text("", encoding="utf-8")
        answers = iter(["none\n", "none\n", "full\n"])
        listed = fake(self.outputs(self.listing(False)))

        def run(argv: list[str]) -> str | None:
            return next(answers) if argv[:2] == ["nmcli", "networking"] else listed(argv)

        def pinger(host: str) -> tuple[float | None, int | None]:
            self.pinged.append(host)
            # The three hosts of the first round fail: the network is not up yet.
            return (None, 100) if len(self.pinged) <= 3 else self.PINGS.get(host, (None, 100))

        self.start(run=run, pinger=pinger)
        self.assertEqual(len(self.sleeps), 2)
        self.assertEqual(self.calls, [["hypraether-vpn", "connect", "us-2"]])

    def test_the_wait_is_bounded_and_the_connection_happens_anyway(self) -> None:
        self.marker.write_text("", encoding="utf-8")
        self.connectivity = "none\n"
        self.PINGS = {}
        self.start(self.outputs(self.listing(False)))
        self.assertEqual(sum(self.sleeps), network.NETWORK_WAIT)
        self.assertEqual(self.calls, [["hypraether-vpn", "connect", "us-1"]])

    def test_the_state_is_rewritten_so_the_page_sees_it(self) -> None:
        self.marker.write_text("", encoding="utf-8")
        self.start(self.outputs(self.listing(False)))
        written = json.loads((self.folder / network.STATE_FILE).read_text(encoding="utf-8"))
        self.assertTrue(written["vpn"]["enabled"])

    def test_the_tool_missing_does_nothing(self) -> None:
        self.marker.write_text("", encoding="utf-8")
        self.assertEqual(self.start({})[0], 0)
        self.assertEqual(self.calls, [])


class MainTests(unittest.TestCase):
    def test_a_request_is_read_as_qsettings_stored_it(self) -> None:
        stored = ['vpn-import:{\\"file\\":\\"/x/y.ovpn\\"}',
                  '"vpn-cred-update:{\\"name\\":\\"a\\",\\"user\\":\\"b\\"}"', "vpn-up:us-1"]
        decoded = [network.qt_value(text) for text in stored]
        self.assertEqual(decoded, ['vpn-import:{"file":"/x/y.ovpn"}',
                                   'vpn-cred-update:{"name":"a","user":"b"}', "vpn-up:us-1"])
        for request in decoded:
            network.parse(request)

    def test_main_applies_the_decoded_request(self) -> None:
        with mock.patch.object(network, "apply", return_value=0) as apply, \
                mock.patch.object(network, "runtime_dir", return_value=None):
            self.assertEqual(network.main(["apply", 'vpn-import:{\\"file\\":\\"/x/y.ovpn\\"}']), 0)
        self.assertEqual(apply.call_args.args[0], 'vpn-import:{"file":"/x/y.ovpn"}')

    def test_an_unknown_subcommand_prints_the_usage(self) -> None:
        with redirect_stderr(io.StringIO()) as usage:
            self.assertEqual(network.main(["nonsense"]), 2)
        self.assertIn("autostart", usage.getvalue())


if __name__ == "__main__":
    unittest.main()
