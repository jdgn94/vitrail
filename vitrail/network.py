"""Network, VPN and Bluetooth for the settings window's Connection page.

The window cannot run commands, so this module does both halves:

    python3 -m vitrail.network state            prints the state as JSON
    python3 -m vitrail.network apply <request>  runs one request, then
                                                rewrites network-state.json
    python3 -m vitrail.network autostart        hypraether's login rule for
                                                the VPN, once per session

`bin/vitrail-settings` injects `state` at launch; `scripts/apply-settings.sh`
runs `apply` when the window asks for something (see prefs.map, area
`connection`), and the page re-reads network-state.json once it is written.
The bar runs `autostart` once when it starts.

A request is `<verb>`, `<verb>:<argument>` or `<verb>:<json>`. Only the verbs
below exist, every argument is validated and travels as one argv item:
nothing goes through a shell. Every tool is optional: a missing one leaves its
section empty with `available: false`.

The VPN is hypraether's (`hypraether-vpn`): connections, credentials (name,
user name, password), the global traffic mode and domain list, and the
`enabled` marker (autostart) are all its own. Vitrail keeps one thing of its
own, the document in `~/.config/vitrail-vpn` (`vitrail/vpndoc.py`): which
connections the automatic choice may use, and the .ovpn files it copied into
`~/.local/share/vitrail-vpn` before handing them to the tool. Both folders
belong to the system user (0700, files 0600), so no account, file or rule is
shared with another one. A password never rides in a request, a preference or
the state: the window writes it to `$XDG_RUNTIME_DIR/vitrail-secret-<nonce>.ini`
(the request carries the nonce), this module hands it to the tool as a
`--pass-file` and deletes both files whatever happens. Logs name the verb and
the credential only.
"""

from __future__ import annotations

import http.client
import json
import os
import re
import itertools
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
from . import vpndoc

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
# A domain of the tool's list, as it prints it.
DOMAIN = re.compile(r"^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$")
MAX_TARGET = 2048
# Subdomains kept per host, and how long finding and resolving them may take.
MAX_DOMAINS = 50
RESOLVE_BUDGET = 20
DIRECTORY_TIMEOUT = 10
DIRECTORY_MAX_BYTES = 8 * 1024 * 1024
# Second-level labels that sit under a two-letter country code (example.co.uk).
SECOND_LEVEL = {"co", "com", "org", "net", "gov", "ac", "edu"}

# Reading the tool's domain list resolves every domain: it may take a while.
LONG_READ = 20

# The VPN requests. The argument of a JSON verb is an object with exactly the
# keys of its shape (required, optional), each one validated.
NONCE = re.compile(r"^[0-9a-f]{32}$")
SHAPES = {
    "vpn-import": ({"file"}, {"name", "credential", "move"}),
    "vpn-cred-add": ({"name", "user", "nonce"}, set()),
    "vpn-cred-update": ({"name"}, {"rename", "user", "nonce"}),
    "vpn-cred-assign": ({"name", "ids"}, set()),
}
MAX_IDS = 64
# Requests that name a credential or a file in the log instead of their argv.
LABELLED = set(SHAPES) | {"vpn-cred-remove"}
# The password file the window writes, and the plain one the tool is given.
SECRET_PREFIX = "vitrail-secret-"
PASS_PREFIX = "vitrail-pass-"
SECRET_MAX_AGE = 300
SECRET_WAIT = 3

# What `ping` is asked, how many hosts of a connection, how long one takes.
PING_HOSTS = 3
PING_TIMEOUT = 10
REMOTE = re.compile(r"^remote\s+(\S+)\s+\d+", re.M)
PING_HOST = re.compile(r"^[A-Za-z0-9][A-Za-z0-9.:-]{0,252}$")
RTT = re.compile(r"rtt min/avg/max/mdev = [\d.]+/([\d.]+)")
LOSS = re.compile(r"(\d+)% packet loss")
# Waiting for the network at login when nothing could be measured.
NETWORK_WAIT = 30
NETWORK_POLL = 2

NO_ARGUMENT = {"wifi-on", "wifi-off", "wifi-disconnect", "bt-on", "bt-off", "bt-scan", "refresh",
               "vpn-best", "vpn-probe", "vpn-off", "vpn-domain-refresh"}
WITH_ARGUMENT = {"wifi-connect", "vpn-up", "vpn-down", "vpn-mode", "vpn-domain-add", "vpn-domain-remove",
                 "vpn-remove", "vpn-cred-remove", "bt-connect", "bt-disconnect"} | set(SHAPES)

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


def valid_label(text: object, limit: int = 64) -> bool:
    """A name (credential, user) the tool takes as one argument: 1 to `limit`
    characters, no control characters, no surrounding space, not an option."""
    return (
        isinstance(text, str)
        and 0 < len(text) <= limit
        and text == text.strip()
        and not text.startswith("-")
        and not any(ord(char) < 32 or ord(char) == 127 for char in text)
    )


def valid_user(text: object) -> bool:
    return valid_label(text, 256)


def valid_domain(text: object) -> bool:
    return isinstance(text, str) and len(text) <= 253 and DOMAIN.match(text) is not None


def valid_file(text: object) -> bool:
    """An absolute path to a .ovpn or .conf file; whether it exists is the tool's to say."""
    return (
        isinstance(text, str)
        and 0 < len(text) <= 4096
        and text.startswith("/")
        and text.lower().endswith((".ovpn", ".conf"))
        and not any(ord(char) < 32 or ord(char) == 127 for char in text)
    )


def valid_ids(value: object) -> bool:
    return isinstance(value, list) and 0 < len(value) <= MAX_IDS \
        and all(isinstance(one, str) and VPN_ID.match(one) for one in value)


FIELDS: dict[str, Callable[[object], bool]] = {
    "file": valid_file, "name": valid_label, "credential": valid_label, "rename": valid_label,
    "user": valid_user, "ids": valid_ids, "nonce": lambda text: isinstance(text, str) and NONCE.match(text) is not None,
    "move": lambda value: isinstance(value, bool),
}


def payload(verb: str, argument: str) -> dict:
    """The object of a JSON verb; a ValueError unless it has exactly the keys
    of the verb's shape, each valid."""
    try:
        data = json.loads(argument)
    except ValueError as error:
        raise ValueError(f"bad argument for {verb}: not JSON") from error
    required, optional = SHAPES[verb]
    if not isinstance(data, dict) or not required <= set(data) <= required | optional:
        raise ValueError(f"bad argument for {verb}: wrong keys")
    for key, value in data.items():
        if not FIELDS[key](value):
            raise ValueError(f"bad argument for {verb}: {key}")
    if verb == "vpn-cred-update" and not set(data) - {"name"}:
        raise ValueError(f"bad argument for {verb}: nothing to change")
    return data


def parse(request: str) -> tuple[str, str]:
    """`verb[:argument]` to (verb, argument); anything else is a ValueError."""
    verb, colon, argument = request.partition(":")
    if verb in NO_ARGUMENT and not colon:
        return verb, ""
    if verb not in WITH_ARGUMENT or not colon:
        raise ValueError(f"unknown request: {request!r}")
    if verb in SHAPES:
        payload(verb, argument)
        return verb, argument
    ok = {
        "wifi-connect": valid_ssid,
        "vpn-up": VPN_ID.match,
        "vpn-down": VPN_ID.match,
        "vpn-mode": lambda text: text in ("split", "full"),
        "vpn-domain-add": host_of,
        "vpn-domain-remove": valid_domain,
        "vpn-remove": VPN_ID.match,
        "vpn-cred-remove": valid_label,
        "bt-connect": MAC.match,
        "bt-disconnect": MAC.match,
    }[verb]
    if not ok(argument):
        raise ValueError(f"bad argument for {verb}: {argument!r}")
    return verb, argument.upper() if verb.startswith("bt-") else argument


def label(verb: str, argument: str) -> str:
    """What the log says of a request that carries a name or a file: the verb and
    the credential (or the file's name), never a user name or a password."""
    if verb == "vpn-cred-remove":
        return f"{verb} {argument}"
    data = payload(verb, argument)
    return f"{verb} {os.path.basename(data['file']) if verb == 'vpn-import' else data['name']}"


def command(verb: str, argument: str = "", wifi_device: str = "", secret: str = "") -> list[str] | None:
    """The argv a request runs: what the bar runs for the same action. `secret`
    is the password file of a credential request. None for `refresh`, which only
    reads, for the requests that run several commands (or none), and for a
    Wi-Fi disconnect when no Wi-Fi device is known."""
    tool = ["hypraether-vpn"]
    match verb:
        case "wifi-on" | "wifi-off":
            return ["nmcli", "radio", "wifi", verb.removeprefix("wifi-")]
        case "wifi-connect":
            return ["nmcli", "device", "wifi", "connect", argument]
        case "wifi-disconnect":
            return ["nmcli", "device", "disconnect", wifi_device] if wifi_device else None
        case "vpn-up":
            return [*tool, "connect", argument]
        case "vpn-down":
            return [*tool, "disconnect", argument]
        case "vpn-off":
            return [*tool, "disconnect"]
        case "vpn-mode":
            return [*tool, "mode", argument]
        case "vpn-domain-remove":
            return [*tool, "domain", "remove", argument]
        case "vpn-domain-refresh":
            return [*tool, "domain", "refresh"]
        case "vpn-remove":
            return [*tool, "remove", argument]
        case "vpn-cred-remove":
            return [*tool, "credential", "remove", argument]
        case "vpn-import":
            data = payload(verb, argument)
            return [*tool, "import", data["file"],
                    *(["--name", data["name"]] if "name" in data else []),
                    *(["--credential", data["credential"]] if "credential" in data else [])]
        case "vpn-cred-add":
            data = payload(verb, argument)
            return [*tool, "credential", "add", data["name"], "--user", data["user"], "--pass-file", secret]
        case "vpn-cred-update":
            data = payload(verb, argument)
            return [*tool, "credential", "update", data["name"],
                    *(["--rename", data["rename"]] if "rename" in data else []),
                    *(["--user", data["user"]] if "user" in data else []),
                    *(["--pass-file", secret] if "nonce" in data else [])]
        case "vpn-cred-assign":
            data = payload(verb, argument)
            return [*tool, "credential", "assign", data["name"], *data["ids"]]
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


def json_list(text: str) -> list:
    try:
        listed = json.loads(text)
    except ValueError:
        return []
    return listed if isinstance(listed, list) else []


def parse_vpn(text: str) -> list[dict]:
    """`hypraether-vpn list --json`, keeping what the page and the rules use."""
    return [
        {key: one.get(key) or "" for key in ("id", "name", "provider", "region", "credential", "config_path")}
        | {"active": bool(one.get("active"))}
        for one in json_list(text) if isinstance(one, dict) and one.get("id")
    ]


def parse_credentials(text: str) -> list[dict]:
    """`hypraether-vpn credential list --json`: name, user name and how many
    connections use it. The tool never prints a password; none is kept."""
    return [
        {"name": one["name"], "username": str(one.get("username") or ""),
         "usedBy": one["used_by"] if isinstance(one.get("used_by"), int) else 0}
        for one in json_list(text) if isinstance(one, dict) and isinstance(one.get("name"), str) and one["name"]
    ]


def parse_domains(text: str) -> list[dict]:
    """`hypraether-vpn domain list --json`: each domain with how many addresses it has now."""
    return [
        {"domain": one["domain"], "ips": len(one["ips"]) if isinstance(one.get("ips"), list) else 0}
        for one in json_list(text) if isinstance(one, dict) and isinstance(one.get("domain"), str) and one["domain"]
    ]


def parse_mode(text: str) -> str:
    """`hypraether-vpn mode`: split or full (split when it says anything else)."""
    return "full" if text.strip() == "full" else "split"


# --- reading the system ------------------------------------------------------

def run_text(argv: list[str]) -> str | None:
    """Standard output of a command; None when it is missing, fails or hangs."""
    if shutil.which(argv[0]) is None:
        return None
    try:
        done = subprocess.run(argv, capture_output=True, text=True, check=False,
                              timeout=LONG_READ if argv[:3] == ["hypraether-vpn", "domain", "list"] else READ_TIMEOUT)
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


def marker_path() -> Path:
    """hypraether's `enabled` marker: it exists while a tunnel is up (the tool
    keeps it for every connect, disconnect and removal, from any frontend)."""
    config = os.environ.get("XDG_CONFIG_HOME") or str(Path.home() / ".config")
    return Path(config) / "hypraether" / "vpn" / "enabled"


def vpn(run: Runner, quality: dict | None = None, marker: Path | None = None) -> dict:
    """The VPN as hypraether has it. `quality` is the last probe's (see
    `probe`): state() itself never pings."""
    listed = run(["hypraether-vpn", "list", "--json"])
    tunnels = parse_vpn(listed or "")
    ids = {one["id"] for one in tunnels}
    return {
        "available": listed is not None,
        "tunnels": tunnels,
        "credentials": parse_credentials(run(["hypraether-vpn", "credential", "list", "--json"]) or ""),
        "mode": parse_mode(run(["hypraether-vpn", "mode"]) or ""),
        "domains": parse_domains(run(["hypraether-vpn", "domain", "list", "--json"]) or ""),
        "enabled": listed is not None and (marker or marker_path()).exists(),
        "quality": {key: value for key, value in (quality or {}).items() if key in ids},
    }


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


def state(run: Runner = run_text, quality: dict | None = None, marker: Path | None = None) -> dict:
    """Everything the page shows. `updated` (milliseconds) tells which copy of
    the state is the newer one."""
    listed = device_list(run)
    devices = listed or []
    return {
        "updated": int(time.time() * 1000),
        "ethernet": {"available": listed is not None} | ethernet(run, devices),
        "wifi": wifi(run, devices),
        "vpn": vpn(run, quality, marker),
        "bluetooth": bluetooth(run),
    }


def write_state(data: dict, folder: Path | None = None) -> Path:
    """Replaces network-state.json whole, so the page never reads half of it.
    It names the user's own files: readable by its owner only."""
    folder = folder or prefs.config_dir()
    folder.mkdir(parents=True, exist_ok=True)
    target = folder / STATE_FILE
    partial = target.with_suffix(".tmp")
    handle = os.open(partial, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(handle, "w", encoding="utf-8") as out:
        out.write(json.dumps(data, separators=(",", ":")))
    os.replace(partial, target)
    os.chmod(target, 0o600)
    return target


# --- the VPN rules: resolving a URL, the quality of a connection, the best one

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


def excluded(document: dict) -> set[str]:
    """The connections the user kept out of the automatic choice: the document
    of `vitrail/vpndoc.py` is `{"connections": {"<id>": {"auto": false}}}`."""
    connections = document.get("connections") if isinstance(document, dict) else None
    if not isinstance(connections, dict):
        return set()
    return {key for key, value in connections.items() if isinstance(value, dict) and value.get("auto") is False}


def domain_list(run: Runner) -> list[dict]:
    return parse_domains(run(["hypraether-vpn", "domain", "list", "--json"]) or "")


def read_config(path: str) -> str:
    try:
        return Path(path).read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def remote_hosts(text: str) -> list[str]:
    """The first PING_HOSTS `remote <host> <port>` hosts of an OpenVPN config
    (a name or an address; anything that could be read as an option is skipped)."""
    return [host for host in REMOTE.findall(text) if PING_HOST.match(host)][:PING_HOSTS]


def parse_ping(output: str) -> tuple[float | None, int | None]:
    """(mean round trip in ms, packet loss in percent) of iputils' `ping`; None for what it did not say."""
    rtt, loss = RTT.search(output), LOSS.search(output)
    return (float(rtt.group(1)) if rtt else None), (int(loss.group(1)) if loss else None)


def ping_host(host: str) -> tuple[float | None, int | None]:
    """Three pings with a second to answer each; LANG=C keeps the output in English."""
    try:
        done = subprocess.run(["env", "LANG=C", "ping", "-c", "3", "-W", "1", host], capture_output=True,
                              text=True, timeout=PING_TIMEOUT, check=False)
    except (OSError, subprocess.SubprocessError):
        return None, 100
    return parse_ping(done.stdout)


Pinger = Callable[[str], "tuple[float | None, int | None]"]


def probe(tunnels: list[dict], pinger: Pinger = ping_host, read: Callable[[str], str] = read_config) -> dict[str, dict]:
    """hypraether's measure: ping up to three of each connection's remote hosts
    side by side. Latency is the mean of the hosts' average round trips, loss
    the worst of their losses; None when no host said."""
    hosts = {one["id"]: remote_hosts(read(one["config_path"])) for one in tunnels}
    unique = sorted({host for listed in hosts.values() for host in listed})
    with ThreadPoolExecutor(max_workers=max(1, min(16, len(unique)))) as pool:
        results = dict(zip(unique, pool.map(pinger, unique)))
    found = {}
    for key, listed in hosts.items():
        latencies = [results[host][0] for host in listed if results[host][0] is not None]
        losses = [results[host][1] for host in listed if results[host][1] is not None]
        found[key] = {"latency": sum(latencies) / len(latencies) if latencies else None,
                      "loss": max(losses) if losses else None}
    return found


def best(tunnels: list[dict], quality: dict, left_out: set[str]) -> str | None:
    """hypraether's rule: of the connections that have a credential (all, when
    none has), the measured one with the lowest latency, loss breaking a tie;
    nothing measured, the first. Vitrail's one addition: a connection the user
    left out of the automatic choice does not compete, unless that empties the
    pool."""
    pool = [one for one in tunnels if one["credential"]] or tunnels
    pool = [one for one in pool if one["id"] not in left_out] or pool
    if not pool:
        return None

    def measured(one: dict) -> float | None:
        return (quality.get(one["id"]) or {}).get("latency")

    candidates = [one for one in pool if measured(one) is not None] or pool
    return min(candidates, key=lambda one: (
        measured(one) if measured(one) is not None else float("inf"),
        (quality.get(one["id"]) or {}).get("loss") or 0,
    ))["id"]


def load_quality(folder: Path) -> dict:
    """The quality the last probe left in network-state.json."""
    try:
        found = json.loads((folder / STATE_FILE).read_text(encoding="utf-8"))["vpn"]["quality"]
    except (OSError, ValueError, KeyError, TypeError):
        return {}
    return {key: {"latency": one.get("latency"), "loss": one.get("loss")}
            for key, one in found.items() if isinstance(one, dict)} if isinstance(found, dict) else {}


def startup_action(enabled: bool, tunnels: list[dict]) -> str:
    """hypraether's login rule. A tunnel up without the marker records it
    ("mark-enabled"); the marker with nothing up and a connection with a
    credential connects the best one ("connect"); everything else is "none"
    (off stays off)."""
    if any(one["active"] for one in tunnels):
        return "none" if enabled else "mark-enabled"
    if not enabled or not any(one["credential"] for one in tunnels):
        return "none"
    return "connect"


# --- the password -----------------------------------------------------------

QT_ESCAPES = {"n": "\n", "t": "\t", "r": "\r", "a": "\a", "b": "\b", "f": "\f", "v": "\v"}
QT_ESCAPE = re.compile(r"\\(x[0-9A-Fa-f]{1,4}|.)", re.S)


def qt_value(raw: str) -> str:
    """A value as QSettings stored it: quoted when it has a comma, a semicolon
    or edge spaces, a backslash or quote escaped, a leading `@` doubled. A
    ValueError for `@Variant(...)` and the like, which are not strings."""
    raw = raw.strip()
    if len(raw) >= 2 and raw[0] == raw[-1] == '"':
        raw = raw[1:-1]
    if raw.startswith("@") and not raw.startswith("@@"):
        raise ValueError("not a string")

    def one(found: re.Match) -> str:
        code = found.group(1)
        return chr(int(code[1:], 16)) if code[0] == "x" and len(code) > 1 else QT_ESCAPES.get(code, code)

    return QT_ESCAPE.sub(one, raw.removeprefix("@"))


def read_secret_text(text: str) -> str:
    """The password in what Qt.labs.settings wrote (`password=` in `[secret]`).
    A ValueError when there is none, or it is empty or has control characters."""
    line = next((one for one in text.splitlines() if one.startswith("password=")), None)
    try:
        password = qt_value(line.removeprefix("password=")) if line is not None else ""
    except ValueError:
        password = ""
    if not password or any(ord(char) < 32 or ord(char) == 127 for char in password):
        raise ValueError("no password")
    return password


def read_secret(path: Path, wait: float = SECRET_WAIT) -> str:
    """The password in the window's file, waiting up to `wait` seconds for the file to appear."""
    deadline = time.monotonic() + wait
    while True:
        try:
            return read_secret_text(path.read_text(encoding="utf-8"))
        except OSError:
            if time.monotonic() >= deadline:
                raise ValueError("no password") from None
            time.sleep(0.1)


def sweep_secrets(runtime: Path, now: float | None = None) -> None:
    """Deletes the password files a request left behind (older than SECRET_MAX_AGE)."""
    now = time.time() if now is None else now
    for path in itertools.chain(runtime.glob(SECRET_PREFIX + "*"), runtime.glob(PASS_PREFIX + "*")):
        try:
            if now - path.stat().st_mtime > SECRET_MAX_AGE:
                path.unlink()
        except OSError:
            pass


def write_private(path: Path, text: str) -> None:
    """A new file only its owner can read."""
    path.unlink(missing_ok=True)
    handle = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(handle, "w", encoding="utf-8") as out:
        out.write(text)


def runtime_dir() -> Path | None:
    """`$XDG_RUNTIME_DIR` (a private tmpfs); None without it: nothing secret may touch another place."""
    found = os.environ.get("XDG_RUNTIME_DIR")
    return Path(found) if found and Path(found).is_dir() else None


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


Act = Callable[..., "tuple[int, str]"]
# Copies a picked .ovpn into the private folder: (source, move) -> the copy.
Store = Callable[[Path, bool], Path]


def run_logged(verb: str, argv: list[str], act: Act) -> int:
    """Runs a command and logs how it ended; 0 or 1."""
    code, last = act(argv, ACT_TIMEOUT + (SCAN_SECONDS if verb == "bt-scan" else 0))
    log(f"{verb} " + ("done" if code == 0 else f"failed ({code}): {last}"))
    return 0 if code == 0 else 1


def run_with_password(verb: str, argument: str, act: Act, runtime: Path | None, wait: float) -> int:
    """A credential request: the password is read from the window's file, handed
    to the tool as a plain private file, and both are deleted whatever happens."""
    nonce = payload(verb, argument).get("nonce")
    if nonce is None:
        return run_logged(verb, command(verb, argument) or [], act)
    if runtime is None:
        log(f"{verb} failed: no runtime directory for the password")
        return 1
    source, target = runtime / f"{SECRET_PREFIX}{nonce}.ini", runtime / f"{PASS_PREFIX}{nonce}"
    try:
        try:
            password = read_secret(source, wait)
        except ValueError:
            log(f"{verb} failed: no password in the request")
            return 1
        write_private(target, password)
        return run_logged(verb, command(verb, argument, secret=str(target)) or [], act)
    finally:
        source.unlink(missing_ok=True)
        target.unlink(missing_ok=True)


def add_domains(url: str, act: Act, run: Runner, resolver: Resolver, directory: Directory) -> int:
    """`vpn-domain-add`: the host, then the live subdomains of its domain that
    certificate transparency lists (at most MAX_DOMAINS), each one `domain add`
    unless the tool has it. The host is added even when nothing resolved."""
    host = host_of(url) or ""
    found = resolve_url(url, resolver, directory)
    known = {one["domain"] for one in domain_list(run)}
    names = [host, *(name for name in found["domains"] if name != host)]
    code = 0
    added = 0
    for name in names:
        if name in known:
            continue
        done, last = act(["hypraether-vpn", "domain", "add", name], ACT_TIMEOUT)
        added += done == 0
        if done != 0:
            log(f"domain add failed ({done}): {last}")
            code = 1
    log(f"vpn-domain-add done ({added} added" + (", incomplete: offline or no directory)" if found.get("retry") else ")"))
    return code


def import_file(argument: str, act: Act, store: Store) -> int:
    """`vpn-import`: the picked file is copied into Vitrail's private folder
    first and the tool imports that copy, so the connection never depends on a
    file the user may move or delete afterwards. The original goes only when
    the request asks to move it."""
    data = payload("vpn-import", argument)
    try:
        stored = store(Path(data["file"]), bool(data.get("move", False)))
    except (OSError, ValueError) as error:
        log(f"vpn-import failed: {error}")
        return 1
    log(label("vpn-import", argument))
    argv = ["hypraether-vpn", "import", str(stored),
            *(["--name", data["name"]] if "name" in data else []),
            *(["--credential", data["credential"]] if "credential" in data else [])]
    return run_logged("vpn-import", argv, act)


def connect_best(verb: str, tunnels: list[dict], quality: dict, document: dict, act: Act) -> int:
    chosen = best(tunnels, quality, excluded(document))
    if chosen is None:
        log(f"{verb} skipped (no connection)")
        return 0
    log(f"{verb} -> hypraether-vpn connect {chosen}")
    return run_logged(verb, ["hypraether-vpn", "connect", chosen], act)


def apply(request: str, folder: Path | None = None, act: Act = run_action, run: Runner = run_text, *,
          resolver: Resolver = lookup, directory: Directory = transparency, pinger: Pinger = ping_host,
          read: Callable[[str], str] = read_config, runtime: Path | None = None, marker: Path | None = None,
          secret_wait: float = SECRET_WAIT, doc_folder: Path | None = None,
          store: Store = vpndoc.store_file) -> int:
    """Runs one request, logs it, and rewrites the state file. 0 when it ran
    (or was only a refresh, a probe or a skipped request), 2 when refused, 1
    when the command failed."""
    try:
        verb, argument = parse(request)
    except ValueError as error:
        log(f"refused ({error})")
        return 2
    folder = folder or prefs.config_dir()
    if runtime is not None:
        sweep_secrets(runtime)
    quality = load_quality(folder)
    code = 0
    if verb == "refresh":
        log("refresh")
        if wifi(run, device_list(run) or [])["device"]:
            act(["nmcli", "device", "wifi", "rescan"], READ_TIMEOUT)
    elif verb == "vpn-probe":
        log(verb)
        quality = probe(parse_vpn(run(["hypraether-vpn", "list", "--json"]) or ""), pinger, read)
    elif verb == "vpn-best":
        tunnels = parse_vpn(run(["hypraether-vpn", "list", "--json"]) or "")
        quality = probe(tunnels, pinger, read)
        code = connect_best(verb, tunnels, quality, vpndoc.read_doc(doc_folder), act)
    elif verb == "vpn-import":
        code = import_file(argument, act, store)
    elif verb == "vpn-domain-add":
        log(request)
        code = add_domains(argument, act, run, resolver, directory)
    elif verb in LABELLED:
        log(label(verb, argument))
        code = run_with_password(verb, argument, act, runtime, secret_wait) if verb in SHAPES \
            else run_logged(verb, command(verb, argument) or [], act)
    else:
        card = wifi(run, device_list(run) or [])["device"] if verb == "wifi-disconnect" else ""
        argv = command(verb, argument, card)
        if argv is None:
            log(f"{request} skipped (no Wi-Fi device)")
        else:
            log(f"{request} -> {shlex.join(argv)}")
            code = run_logged(verb, argv, act)
    # Which request this state answers, and how it went (the verb only).
    write_state(state(run, quality, marker) | {"result": {"verb": verb, "code": code}}, folder)
    return code


def claim_session(runtime: Path, session: str | None) -> bool:
    """True the first time it is called in a graphical session, False after: a
    stamp under the runtime directory, keyed by the compositor instance, so a
    restart of the bar never repeats what a login did."""
    name = re.sub(r"[^A-Za-z0-9._-]", "_", session or os.environ.get("HYPRLAND_INSTANCE_SIGNATURE") or "no-session")
    try:
        os.close(os.open(runtime / f"vitrail-vpn-autostart-{name}", os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600))
    except FileExistsError:
        return False
    return True


def network_up(run: Runner) -> bool:
    """NetworkManager reports full connectivity (True too when it cannot be asked: waiting would be blind)."""
    answer = run(["nmcli", "networking", "connectivity"])
    return answer is None or answer.strip() == "full"


def autostart(folder: Path | None = None, act: Act = run_action, run: Runner = run_text, *,
              pinger: Pinger = ping_host, read: Callable[[str], str] = read_config, runtime: Path | None = None,
              marker: Path | None = None, session: str | None = None, doc_folder: Path | None = None,
              sleep: Callable[[float], None] = time.sleep) -> int:
    """hypraether's login rule for the VPN, once per session (see
    `startup_action`). When it connects and nothing could be measured, it waits
    up to NETWORK_WAIT seconds for NetworkManager to report full connectivity,
    measures again, and connects the best anyway."""
    if runtime is None:
        log("autostart skipped (no runtime directory)")
        return 0
    if not claim_session(runtime, session):
        return 0
    folder = folder or prefs.config_dir()
    marker = marker or marker_path()
    listed = run(["hypraether-vpn", "list", "--json"])
    if listed is None:
        log("autostart skipped (hypraether-vpn is not available)")
        return 0
    tunnels = parse_vpn(listed)
    action = startup_action(marker.exists(), tunnels)
    log(f"autostart: {action}")
    quality = load_quality(folder)
    code = 0
    if action == "mark-enabled" and marker.parent.is_dir():
        marker.touch()
    elif action == "connect":
        quality = probe(tunnels, pinger, read)
        if not any(one["latency"] is not None for one in quality.values()):
            waited = 0
            while waited < NETWORK_WAIT and not network_up(run):
                sleep(NETWORK_POLL)
                waited += NETWORK_POLL
            if waited:
                quality = probe(tunnels, pinger, read)
        code = connect_best("autostart", tunnels, quality, vpndoc.read_doc(doc_folder), act)
    write_state(state(run, quality, marker), folder)
    return code


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    if args == ["state"]:
        print(json.dumps(state(quality=load_quality(prefs.config_dir())), separators=(",", ":")))
        return 0
    if len(args) == 2 and args[0] == "apply":
        # The request comes from connection.ini, where QSettings escaped it.
        try:
            request = qt_value(args[1])
        except ValueError as error:
            log(f"refused ({error})")
            return 2
        return apply(request, runtime=runtime_dir())
    if args == ["autostart"]:
        return autostart(runtime=runtime_dir())
    print("usage: network state | apply <request> | autostart", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
