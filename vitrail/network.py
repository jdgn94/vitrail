"""Network, VPN and Bluetooth for the settings window's Connection page.

The window cannot run commands, so this module does both halves:

    python3 -m vitrail.network state            prints the state as JSON
    python3 -m vitrail.network apply <request>  runs one request, then
                                                rewrites network-state.json

`bin/vitrail-settings` injects `state` at launch; `scripts/apply-settings.sh`
runs `apply` when the window asks for something (see prefs.map, area
`connection`), and the page re-reads network-state.json once it is written.

`vpn-resolve:<url>` is the one request that runs no command: it looks the URL's
addresses and subdomains up and leaves them under `resolved` in
network-state.json for the page to file into its VPN document (`vpnSettings`
in misc.ini, which only the page writes; this module only reads it, to apply
a tunnel's mode and domains when `vpn-up` raises it).

A request is `<verb>` or `<verb>:<argument>`. Only the verbs below exist, the
argument is validated and travels as one argv item: nothing goes through a
shell. Every tool is optional: a missing one leaves its section empty with
`available: false`.
"""

from __future__ import annotations

import http.client
import json
import os
import re
import shlex
import shutil
import socket
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from collections.abc import Callable
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from . import prefs

STATE_FILE = "network-state.json"
# How long `bluetoothctl scan` looks around, as the bar's launcher does.
SCAN_SECONDS = 6
# Longest a command may take: a Wi-Fi join waits for DHCP and the password.
READ_TIMEOUT = 5
ACT_TIMEOUT = 60

MAC = re.compile(r"^[0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5}$")
# A hypraether-vpn connection id: "us-free-12-protonvpn-udp".
VPN_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")

# What a host label, and a whole host name, may look like (ASCII: an internet
# domain is punycode). The last label has a letter, so an address is no host.
LABEL = r"[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?"
HOST = re.compile(rf"^({LABEL}\.)+[a-z]([a-z0-9-]{{0,61}}[a-z0-9])?$")
MAX_TARGET = 2048
# Subdomains kept per host, and how long finding and resolving them may take.
MAX_DOMAINS = 50
RESOLVE_BUDGET = 20
DIRECTORY_TIMEOUT = 10
DIRECTORY_MAX_BYTES = 8 * 1024 * 1024
# Second-level labels that sit under a two-letter country code (example.co.uk).
SECOND_LEVEL = {"co", "com", "org", "net", "gov", "ac", "edu"}

NO_ARGUMENT = {"wifi-on", "wifi-off", "wifi-disconnect", "bt-on", "bt-off", "bt-scan", "refresh"}
WITH_ARGUMENT = {"wifi-connect", "vpn-up", "vpn-down", "vpn-resolve", "bt-connect", "bt-disconnect"}

Runner = Callable[[list[str]], "str | None"]
# The network, injected so tests run offline: a host to its addresses, and a
# registrable domain to the names a certificate directory lists for it.
Resolver = Callable[[str], "list[str]"]
Directory = Callable[[str], "list[str]"]


# --- requests ----------------------------------------------------------------

def valid_ssid(text: str) -> bool:
    """1 to 32 bytes, no control characters, and not an option for nmcli."""
    return (
        0 < len(text.encode("utf-8")) <= 32
        and not text.startswith("-")
        and not any(ord(char) < 32 or ord(char) == 127 for char in text)
    )


def host_of(text: str) -> str | None:
    """The host of an http(s) URL or a bare host name, lowercased; None for
    anything else (other schemes, credentials, spaces, an option for a tool,
    an address, a name that is not a valid host)."""
    if not 0 < len(text) <= MAX_TARGET or re.search(r"[\s\x00-\x1f\x7f]", text):
        return None
    if re.match(r"(?i)^https?://", text):
        try:
            parts = urllib.parse.urlsplit(text)
            host = parts.hostname
            parts.port  # raises ValueError on a bad port
        except ValueError:
            return None
        if "@" in parts.netloc or not host:
            return None
    else:
        host = text.lower()
    host = host.lower().rstrip(".") if host else ""
    return host if len(host) <= 253 and HOST.match(host) else None


def registrable(host: str) -> str:
    """The domain a host belongs to: its last two labels, three under a
    two-letter country code with a common second level (example.co.uk).
    A heuristic: there is no public-suffix list here, so an unusual suffix
    (a *.pvt.k12.ma.us school) is taken one label too short."""
    labels = host.split(".")
    if len(labels) >= 3 and len(labels[-1]) == 2 and labels[-2] in SECOND_LEVEL:
        return ".".join(labels[-3:])
    return ".".join(labels[-2:])


def parse(request: str) -> tuple[str, str]:
    """`verb[:argument]` to (verb, argument); anything else is a ValueError."""
    verb, colon, argument = request.partition(":")
    if verb in NO_ARGUMENT and not colon:
        return verb, ""
    if verb not in WITH_ARGUMENT or not colon:
        raise ValueError(f"unknown request: {request!r}")
    ok = {
        "wifi-connect": valid_ssid,
        "vpn-up": VPN_ID.match,
        "vpn-down": VPN_ID.match,
        "vpn-resolve": host_of,
        "bt-connect": MAC.match,
        "bt-disconnect": MAC.match,
    }[verb]
    if not ok(argument):
        raise ValueError(f"bad argument for {verb}: {argument!r}")
    return verb, argument.upper() if verb.startswith("bt-") else argument


def command(verb: str, argument: str = "", wifi_device: str = "") -> list[str] | None:
    """The argv a request runs: what the bar runs for the same action.
    None for `refresh`, which only reads, and for a Wi-Fi disconnect when no
    Wi-Fi device is known."""
    match verb:
        case "wifi-on" | "wifi-off":
            return ["nmcli", "radio", "wifi", verb.removeprefix("wifi-")]
        case "wifi-connect":
            return ["nmcli", "device", "wifi", "connect", argument]
        case "wifi-disconnect":
            return ["nmcli", "device", "disconnect", wifi_device] if wifi_device else None
        case "vpn-up":
            return ["hypraether-vpn", "connect", argument]
        case "vpn-down":
            return ["hypraether-vpn", "disconnect", argument]
        case "bt-on" | "bt-off":
            return ["bluetoothctl", "power", verb.removeprefix("bt-")]
        case "bt-connect" | "bt-disconnect":
            return ["bluetoothctl", verb.removeprefix("bt-"), argument]
        case "bt-scan":
            return ["bluetoothctl", "--timeout", str(SCAN_SECONDS), "scan", "on"]
    return None


# --- parsing what the tools print --------------------------------------------

def split_terse(line: str) -> list[str]:
    """A line of `nmcli -t`: fields split on `:`, where `\\:` and `\\\\` are literal."""
    fields = [""]
    chars = iter(line)
    for char in chars:
        if char == "\\":
            fields[-1] += next(chars, "")
        elif char == ":":
            fields.append("")
        else:
            fields[-1] += char
    return fields


def parse_devices(text: str) -> list[dict]:
    """`nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device`."""
    devices = []
    for line in text.splitlines():
        fields = split_terse(line)
        if len(fields) >= 4:
            devices.append({"name": fields[0], "type": fields[1], "state": fields[2], "connection": fields[3]})
    return devices


def parse_wifi(text: str) -> list[dict]:
    """`nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list`: one entry per
    name (the one in use, else the strongest), the one in use first."""
    best: dict[str, dict] = {}
    for line in text.splitlines():
        fields = split_terse(line)
        if len(fields) < 4 or not fields[1]:
            continue
        security = "" if fields[3] == "--" else fields[3]
        network = {
            "ssid": fields[1],
            "signal": int(fields[2]) if fields[2].isdigit() else 0,
            "security": security,
            "active": fields[0] == "*",
        }
        kept = best.get(network["ssid"])
        if kept is None or (network["active"], network["signal"]) > (kept["active"], kept["signal"]):
            best[network["ssid"]] = network
    return sorted(best.values(), key=lambda one: (not one["active"], -one["signal"], one["ssid"].lower()))


def parse_ip4(text: str) -> dict:
    """`nmcli -t -f IP4.ADDRESS,IP4.GATEWAY device show <device>`."""
    found = {"address": "", "gateway": ""}
    for line in text.splitlines():
        fields = split_terse(line)
        if len(fields) < 2 or not fields[1]:
            continue
        if fields[0].startswith("IP4.ADDRESS") and not found["address"]:
            found["address"] = fields[1]
        elif fields[0] == "IP4.GATEWAY":
            found["gateway"] = fields[1]
    return found


def parse_bluetooth_show(text: str) -> dict:
    """`bluetoothctl show`: whether there is a controller, and whether it is on."""
    return {"present": "Controller " in text, "powered": "Powered: yes" in text}


def parse_bluetooth_devices(text: str) -> list[tuple[str, str]]:
    """`bluetoothctl devices`: "Device AA:BB:CC:DD:EE:FF Name" lines."""
    seen: dict[str, str] = {}
    for line in text.splitlines():
        parts = line.strip().split(" ", 2)
        if len(parts) >= 2 and parts[0] == "Device" and MAC.match(parts[1]):
            seen.setdefault(parts[1].upper(), parts[2].strip() if len(parts) == 3 else parts[1])
    return list(seen.items())


def parse_bluetooth_info(text: str) -> dict:
    """`bluetoothctl info <mac>`: paired, connected and the battery level."""
    battery = re.search(r"Battery Percentage: 0x[0-9A-Fa-f]+ \((\d+)\)", text)
    alias = re.search(r"^\s*Alias: (.+)$", text, re.M)
    return {
        "paired": "Paired: yes" in text,
        "connected": "Connected: yes" in text,
        "battery": int(battery.group(1)) if battery else None,
        "alias": alias.group(1).strip() if alias else "",
    }


def parse_vpn(text: str) -> list[dict]:
    """`hypraether-vpn list --json`, keeping only what the page shows."""
    try:
        listed = json.loads(text)
    except ValueError:
        return []
    return [
        {key: one.get(key, "") for key in ("id", "name", "provider", "region")} | {"active": bool(one.get("active"))}
        for one in listed if isinstance(one, dict) and one.get("id")
    ]


# --- reading the system ------------------------------------------------------

def run_text(argv: list[str]) -> str | None:
    """Standard output of a command; None when it is missing, fails or hangs."""
    if shutil.which(argv[0]) is None:
        return None
    try:
        done = subprocess.run(argv, capture_output=True, text=True, timeout=READ_TIMEOUT, check=False)
    except (OSError, subprocess.SubprocessError):
        return None
    return done.stdout if done.returncode == 0 else None


def device_list(run: Runner) -> list[dict] | None:
    """Every network device; None when nmcli is missing."""
    listing = run(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"])
    return None if listing is None else parse_devices(listing)


def ethernet(run: Runner, devices: list[dict]) -> dict:
    wired = []
    for device in devices:
        if device["type"] != "ethernet" or device["state"].startswith("unmanaged"):
            continue
        entry = {**device, "address": "", "gateway": ""}
        if device["state"] == "connected":
            entry |= parse_ip4(run(["nmcli", "-t", "-f", "IP4.ADDRESS,IP4.GATEWAY", "device", "show", device["name"]]) or "")
        wired.append(entry)
    return {"devices": wired}


def wifi(run: Runner, devices: list[dict]) -> dict:
    card = next((device["name"] for device in devices if device["type"] == "wifi"), "")
    enabled = (run(["nmcli", "radio", "wifi"]) or "").strip() == "enabled"
    networks = []
    if card and enabled:
        networks = parse_wifi(run(["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "no"]) or "")
    return {"available": card != "", "enabled": enabled and card != "", "device": card, "networks": networks}


def vpn(run: Runner) -> dict:
    listed = run(["hypraether-vpn", "list", "--json"])
    return {"available": listed is not None, "tunnels": parse_vpn(listed or "")}


def bluetooth(run: Runner) -> dict:
    controller = parse_bluetooth_show(run(["bluetoothctl", "show"]) or "")
    result = {"available": controller["present"], "powered": controller["powered"], "devices": []}
    if not controller["present"]:
        return result
    for mac, name in parse_bluetooth_devices(run(["bluetoothctl", "devices"]) or ""):
        info = parse_bluetooth_info(run(["bluetoothctl", "info", mac]) or "")
        name = info["alias"] or name
        # A scan also finds nameless beacons, listed under their address.
        if not info["paired"] and name.replace("-", ":").upper() == mac:
            continue
        result["devices"].append({
            "mac": mac,
            "name": name,
            "paired": info["paired"],
            "connected": info["connected"],
            "battery": info["battery"],
        })
    result["devices"].sort(key=lambda one: (not one["connected"], not one["paired"], one["name"].lower()))
    return result


def state(run: Runner = run_text) -> dict:
    """Everything the page shows. `updated` (milliseconds) tells which copy of
    the state is the newer one."""
    listed = device_list(run)
    devices = listed or []
    return {
        "updated": int(time.time() * 1000),
        "ethernet": {"available": listed is not None} | ethernet(run, devices),
        "wifi": wifi(run, devices),
        "vpn": vpn(run),
        "bluetooth": bluetooth(run),
    }


def write_state(data: dict, folder: Path | None = None) -> Path:
    """Replaces network-state.json whole, so the page never reads half of it."""
    folder = folder or prefs.config_dir()
    folder.mkdir(parents=True, exist_ok=True)
    target = folder / STATE_FILE
    partial = target.with_suffix(".tmp")
    partial.write_text(json.dumps(data, separators=(",", ":")), encoding="utf-8")
    os.replace(partial, target)
    return target


# --- the VPN rule: resolving a URL, applying a tunnel's settings -------------

def lookup(host: str) -> list[str]:
    """The IPv4 and IPv6 addresses of a host, unique and sorted; [] when it
    does not resolve (or the network is down)."""
    try:
        found = socket.getaddrinfo(host, None, type=socket.SOCK_STREAM)
    except OSError:
        return []
    return sorted({str(address[4][0]).split("%")[0] for address in found})


def parse_transparency(body: str) -> list[str]:
    """crt.sh's JSON: the `name_value` of each certificate (several names may
    share one, a name per line)."""
    try:
        listed = json.loads(body)
    except ValueError:
        return []
    return [one["name_value"] for one in listed if isinstance(one, dict) and isinstance(one.get("name_value"), str)] \
        if isinstance(listed, list) else []


def transparency(domain: str) -> list[str]:
    """The names certificate transparency (crt.sh) knows under a domain.
    OSError when the directory cannot be reached."""
    address = f"https://crt.sh/?q=%25.{domain}&output=json"
    request = urllib.request.Request(address, headers={"User-Agent": "vitrail"})
    try:
        with urllib.request.urlopen(request, timeout=DIRECTORY_TIMEOUT) as answer:
            body = answer.read(DIRECTORY_MAX_BYTES).decode("utf-8", "replace")
    except http.client.HTTPException as error:
        raise OSError(str(error)) from error
    return parse_transparency(body)


def resolve_all(names: list[str], resolver: Resolver) -> dict[str, list[str]]:
    """Every name's addresses, looked up side by side within RESOLVE_BUDGET;
    a name that is not answered in time is left out."""
    pool = ThreadPoolExecutor(max_workers=8)
    futures = {pool.submit(resolver, name): name for name in names}
    found: dict[str, list[str]] = {}
    try:
        for future in as_completed(futures, timeout=RESOLVE_BUDGET):
            found[futures[future]] = future.result()
    except TimeoutError:
        pass
    finally:
        pool.shutdown(wait=False, cancel_futures=True)
    return found


def resolve_url(url: str, resolver: Resolver = lookup, directory: Directory = transparency) -> dict:
    """What the VPN rule stores for a URL: `ips` (the host's and its
    subdomains', unique, sorted) and `domains` (the host and the subdomains of
    its registrable domain that resolve, at most MAX_DOMAINS of them besides
    the host). `retry` is set when something could not be found: the host did
    not resolve (offline) or the directory was unreachable."""
    host = host_of(url)
    if host is None:
        raise ValueError(f"not a URL or host: {url!r}")
    root = registrable(host)
    addresses = {host: resolver(host)}
    retry = not addresses[host]
    try:
        listed = directory(root)
    except (OSError, ValueError):
        listed, retry = [], True
    names = sorted({
        name
        for text in listed
        for name in (line.strip().lower() for line in text.split("\n"))
        if name != host and (name == root or name.endswith("." + root)) and HOST.match(name)
    })[:MAX_DOMAINS]
    addresses |= resolve_all(names, resolver)
    live = sorted(name for name, found in addresses.items() if found)
    found = {"ips": sorted({address for ips in addresses.values() for address in ips}), "domains": live}
    return found | {"retry": True} if retry else found


def vpn_settings(config: Path) -> dict:
    """The page's VPN document (`vpnSettings` in misc.ini); {} when it is
    missing or not a JSON object. Read-only: the page is its one writer."""
    try:
        document = json.loads(prefs.read_prefs(config).get("vpnSettings", ""))
    except ValueError:
        return {}
    return document if isinstance(document, dict) else {}


DOMAIN = re.compile(r"^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$")


def vpn_prelude(tunnel: str, settings: dict, known: set[str]) -> list[list[str]]:
    """The commands that run before `hypraether-vpn connect <tunnel>`: the
    tunnel's mode and, in split mode, the stored domains the tool's list does
    not have yet (it resolves their addresses itself). The mode and the list
    are global in the tool: the last tunnel raised sets them. [] when the
    tunnel has no assignment. Every item is checked: nothing stored reaches an
    argv unless it is a plain mode or domain name."""
    assignments = settings.get("assignments")
    chosen = next((one for one in assignments if isinstance(one, dict) and one.get("vpn") == tunnel), None) \
        if isinstance(assignments, list) else None
    if chosen is None:
        return []
    mode = "full" if chosen.get("mode") == "full" else "split"
    steps = [["hypraether-vpn", "mode", mode]]
    if mode == "split":
        seen = {name.lower() for name in known}
        for host in chosen.get("hosts") or []:
            if not isinstance(host, dict):
                continue
            names = host.get("domains") or [host_of(str(host.get("url", "")))]
            for name in names:
                name = name.lower() if isinstance(name, str) else ""
                if DOMAIN.match(name) and name not in seen:
                    seen.add(name)
                    steps.append(["hypraether-vpn", "domain", "add", name])
    return steps


def known_domains(run: Runner) -> set[str]:
    """The domains `hypraether-vpn domain list` already has."""
    try:
        listed = json.loads(run(["hypraether-vpn", "domain", "list", "--json"]) or "[]")
    except ValueError:
        return set()
    return {one["domain"] for one in listed if isinstance(one, dict) and isinstance(one.get("domain"), str)} \
        if isinstance(listed, list) else set()


# --- acting --------------------------------------------------------------------

def run_action(argv: list[str], timeout: int = ACT_TIMEOUT) -> tuple[int, str]:
    """Runs a request's command: (exit code, last line it printed)."""
    if shutil.which(argv[0]) is None:
        return 127, f"{argv[0]} not found"
    try:
        done = subprocess.run(argv, capture_output=True, text=True, timeout=timeout, check=False)
    except subprocess.TimeoutExpired:
        return 124, f"timed out after {timeout}s"
    except OSError as error:
        return 126, str(error)
    lines = (done.stderr.strip() or done.stdout.strip()).splitlines()
    return done.returncode, lines[-1] if lines else ""


def log(line: str) -> None:
    """Flushed at once: the journal shows a scan's request while it runs."""
    print(f"Connection: {line}", flush=True)


def apply(request: str, folder: Path | None = None, act: Callable[..., tuple[int, str]] = run_action,
          run: Runner = run_text, resolver: Resolver = lookup, directory: Directory = transparency) -> int:
    """Runs one request, logs it, and rewrites the state file. 0 when it ran
    (or was only a refresh or a resolution), 2 when refused, 1 when the
    command failed."""
    try:
        verb, argument = parse(request)
    except ValueError as error:
        log(f"refused ({error})")
        return 2
    code = 0
    extra: dict = {}
    if verb == "refresh":
        log("refresh")
        if wifi(run, device_list(run) or [])["device"]:
            act(["nmcli", "device", "wifi", "rescan"], READ_TIMEOUT)
    elif verb == "vpn-resolve":
        log(request)
        found = resolve_url(argument, resolver, directory)
        extra = {"resolved": {argument: found}}
        log(f"{verb} done ({len(found['ips'])} addresses, {len(found['domains'])} domains"
            + (", to retry)" if found.get("retry") else ")"))
    else:
        card = wifi(run, device_list(run) or [])["device"] if verb == "wifi-disconnect" else ""
        argv = command(verb, argument, card)
        if argv is None:
            log(f"{request} skipped (no Wi-Fi device)")
        else:
            if verb == "vpn-up":
                settings = vpn_settings(folder or prefs.config_dir())
                steps = vpn_prelude(argument, settings, set())
                if len(steps) > 1:  # the tool's list is only worth reading when domains may be added
                    steps = vpn_prelude(argument, settings, known_domains(run))
                for step in steps:
                    log(f"{request} -> {shlex.join(step)}")
                    done, last = act(step, ACT_TIMEOUT)
                    if done != 0:
                        log(f"{step[1]} failed ({done}): {last}")
                        if step[1] == "mode":
                            code = 1
                            break
            if code == 0:
                log(f"{request} -> {shlex.join(argv)}")
                code, last = act(argv, ACT_TIMEOUT + (SCAN_SECONDS if verb == "bt-scan" else 0))
                log(f"{verb} " + ("done" if code == 0 else f"failed ({code}): {last}"))
                code = 0 if code == 0 else 1
    write_state(state(run) | extra, folder)
    return code


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    if args == ["state"]:
        print(json.dumps(state(), separators=(",", ":")))
        return 0
    if len(args) == 2 and args[0] == "apply":
        return apply(args[1])
    print("usage: network state | apply <request>", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
