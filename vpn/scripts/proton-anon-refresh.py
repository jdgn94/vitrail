#!/usr/bin/env python3
"""Mint fresh anonymous ProtonVPN credentials and regenerate the split-tunnel config.

When OpenVPN reports AUTH_FAILED, Proton has rejected the current OpenVPN
credentials (free-tier credentials get rotated/expired server-side). This script
recovers without any user interaction by using Proton's /credentialless API,
which is the same flow the official Android app uses for anonymous signup:

  1. POST /auth/v4/sessions          -> anonymous session (UID + AccessToken)
  2. POST /auth/v4/credentialless    -> upgrade to an anonymous (credentialless) token
  3. GET  /vpn/v2                    -> fresh VPN.Name + VPN.Password
  4. GET  /vpn/v1/logicals           -> pick a free (Tier==0) US exit server
  5. Reuse the <ca>/<tls-crypt> blocks from the existing client config (they are
     shared Proton infrastructure and stay valid for anonymous credentials).
  6. Store the fresh credentials in the sqlite vault and regenerate the
     split-tunnel config, then restart the tunnel.

NOTE: this does NOT touch the user's Proton account and does not store any
Proton account password. Each run creates a throwaway anonymous account.
Runs as the desktop user (the vault/configs are yours); the tunnel restart
goes through the installer's polkit rule.

Usage:
  proton-anon-refresh.py                     # full refresh + restart
  proton-anon-refresh.py --check             # only validate API reachability
  proton-anon-refresh.py --dry-run           # mint creds but do not write/restart
"""

from __future__ import annotations

import argparse
import json
import os
import random
import re
import ssl
import subprocess
import sys
import urllib.request
import urllib.error

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
from vpn_manager import get_connection, set_connection_credentials  # noqa: E402

API_BASE = "https://vpn-api.proton.me"
APP_VERSION = "5.11.70.0"
USER_AGENT = f"ProtonVPN/{APP_VERSION} (Android 15; google sdk_gphone64_x86_64)"
ACCEPT = "application/vnd.protonmail.v1+json"

DEFAULT_ID = "proton-us"
AUTH_PATH = "/run/vitrail-vpn/{id}/auth.txt"

# Split-tunnel option block, mirroring what ovpn2split.py injects.
SPLIT_BLOCK = """pull-filter ignore "redirect-gateway"
pull-filter ignore "dhcp-option DNS"
route-nopull

ping 10
ping-restart 60
connect-retry 5 60
connect-timeout 30
explicit-exit-notify
resolv-retry infinite

script-security 2
up /etc/vitrail/vpn/vpn-up.sh
down /etc/vitrail/vpn/vpn-down.sh

"""


def http_json(
    url: str, headers: dict[str, str], data: dict | None = None, method: str | None = None
) -> tuple[int, dict, dict]:
    """Perform an HTTPS request and return (status, parsed JSON body, response headers)."""
    body = json.dumps(data).encode() if data is not None else None
    req = urllib.request.Request(url, data=body, method=method or ("POST" if data is not None else "GET"))
    req.add_header("User-Agent", USER_AGENT)
    req.add_header("Accept", ACCEPT)
    req.add_header("Content-Type", "application/json; charset=utf-8")
    req.add_header("X-Pm-Appversion", f"android-vpn@{APP_VERSION}+play")
    req.add_header("X-Pm-Locale", "en")
    req.add_header("Connection", "keep-alive")
    for k, v in headers.items():
        req.add_header(k, v)
    ctx = ssl.create_default_context()
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=45) as resp:
            body_dict = json.loads(resp.read().decode())
            cookies = resp.headers.get_all("Set-Cookie") or []
            return resp.status, body_dict, cookies
    except urllib.error.HTTPError as exc:
        try:
            payload = json.loads(exc.read().decode())
        except Exception:
            payload = {}
        return exc.code, payload, exc.headers.get_all("Set-Cookie") if exc.headers else []


def new_session() -> tuple[str, str, str]:
    """Create an anonymous session. Returns (UID, AccessToken, Session-Id)."""
    device_name = random.randint(111111111111, 999999999999)
    payload = {
        "Payload": {
            "vpn-android-v4-challenge-0": {
                "v": "2.0.7",
                "appLang": "en",
                "timezone": "Europe/Monaco",
                "deviceName": str(device_name),
                "regionCode": "US",
                "timezoneOffset": -120,
                "isJailbreak": False,
                "preferredContentSize": "1.0",
                "storageCapacity": 16.0,
                "isDarkmodeOn": False,
                "keyboards": [
                    "com.google.android.inputmethod.latin",
                    "com.google.android.tts",
                ],
            }
        }
    }
    status, body, resp_headers = http_json(f"{API_BASE}/auth/v4/sessions", {}, payload)
    if status != 200 or body.get("Code") != 1000:
        raise RuntimeError(f"session creation failed: HTTP {status} {body}")

    # The Session-Id is delivered in a Set-Cookie header, not in the JSON body.
    session_id = ""
    for cookie in resp_headers:
        if "Session-Id=" in cookie:
            session_id = cookie.split("Session-Id=", 1)[1].split(";", 1)[0]
            break
    if not session_id:
        raise RuntimeError("session created but no Session-Id cookie returned")

    return body["UID"], body["AccessToken"], session_id


def get_credentialless_token(uid: str, token: str, session_id: str) -> str:
    """Upgrade the anonymous session to a credentialless token."""
    device_name = random.randint(111111111111, 999999999999)
    payload = {
        "Payload": {
            "vpn-android-v4-challenge-0": {
                "type": "me.proton.core.challenge.data.frame.ChallengeFrame.Device",
                "v": "2.0.7",
                "appLang": "en",
                "timezone": "Europe/Monaco",
                "deviceName": str(device_name),
                "regionCode": "US",
                "timezoneOffset": -120,
                "isJailbreak": False,
                "preferredContentSize": "1.0",
                "storageCapacity": 16.0,
                "isDarkmodeOn": True,
                "keyboards": ["com.google.android.inputmethod.latin", "com.google.android.tts"],
            }
        }
    }
    headers = {
        "X-Pm-Uid": uid,
        "Authorization": f"Bearer {token}",
        "Cookie": f"Session-Id={session_id}; Tag=vpn-b",
    }
    status, body, _ = http_json(f"{API_BASE}/auth/v4/credentialless", headers, payload)
    if status != 200 or body.get("Code") != 1000:
        raise RuntimeError(f"credentialless upgrade failed: HTTP {status} {body}")
    return body["AccessToken"]


def get_vpn_credentials(uid: str, token: str, session_id: str) -> tuple[str, str]:
    """Fetch the fresh VPN username/password."""
    headers = {
        "X-Pm-Uid": uid,
        "Authorization": f"Bearer {token}",
        "Cookie": f"Session-Id={session_id}; Tag=vpn-b",
    }
    status, body, _ = http_json(f"{API_BASE}/vpn/v2", headers)
    if status != 200 or body.get("Code") != 1000:
        raise RuntimeError(f"vpn credentials fetch failed: HTTP {status} {body}")
    vpn = body["VPN"]
    return vpn["Name"], vpn["Password"]


def pick_us_free_server(uid: str, token: str, session_id: str) -> tuple[str, int]:
    """Pick the least-loaded free US server. Returns (EntryIP, port)."""
    headers = {
        "X-Pm-Country": "US",
        "If-Modified-Since": "Thu, 01 Jan 1970 00:00:00 GMT",
        "X-Pm-Uid": uid,
        "Authorization": f"Bearer {token}",
        "Cookie": f"Session-Id={session_id}; Tag=vpn-b",
    }
    url = (
        f"{API_BASE}/vpn/v1/logicals?WithTranslations=en"
        "&WithEntriesForProtocols=WireGuardUDP%2CWireGuardTCP%2COpenVPNUDP%2COpenVPNTCP%2CWireGuardTLS"
        "&WithState=true"
    )
    status, body, _ = http_json(url, headers)
    if status != 200 or body.get("Code") != 1000:
        raise RuntimeError(f"logicals fetch failed: HTTP {status} {body}")

    servers = [s for s in body.get("LogicalServers", []) if s.get("Tier") == 0]
    us = [s for s in servers if s.get("ExitCountry") == "US" and s.get("Servers")]
    if not us:
        raise RuntimeError("no free US servers found")

    best = min(us, key=lambda s: s.get("Load", 100))
    entry_ip = best["Servers"][0]["EntryIP"]
    port = 1194
    # Prefer a server whose entries expose an OpenVPN UDP port.
    for srv in best["Servers"]:
        for proto in srv.get("Protocols", []) or []:
            if proto.get("Protocol") == "OpenVPNUDP":
                port = proto.get("Ports", [1194])[0]
                break
        else:
            continue
        break
    return entry_ip, port


def extract_block(conf: str, tag: str) -> str:
    """Extract a <tag>...</tag> block from the config, or raise."""
    match = re.search(rf"<{tag}>.*?</{tag}>", conf, re.S)
    if not match:
        raise RuntimeError(f"<{tag}> block not found in the client config")
    return match.group(0)


def read_cert_blocks(conf_path: str) -> tuple[str, str]:
    """Read the <ca> and <tls-crypt> blocks from the existing client config."""
    with open(conf_path, encoding="utf-8") as fh:
        conf = fh.read()
    return extract_block(conf, "ca"), extract_block(conf, "tls-crypt")


def build_config(entry_ip: str, port: int, ca_block: str, tls_crypt_block: str, auth_path: str) -> str:
    """Compose the full split-tunnel client config for the anonymous server."""
    return f"""# Regenerated automatically by proton-anon-refresh.py
client
dev tun
proto udp

remote {entry_ip} {port}

remote-random
resolv-retry infinite
nobind

cipher AES-256-GCM

setenv CLIENT_CERT 0
tun-mtu 1500
mssfix 0
persist-key
persist-tun

reneg-sec 0

remote-cert-tls server
auth-user-pass {auth_path}

{SPLIT_BLOCK}
{ca_block}

{tls_crypt_block}
"""


def store_credentials(conn_id: str, auth_user: str, auth_pass: str) -> None:
    """Update (or create) the vault credential the connection uses — never
    a plaintext file."""
    conn = get_connection(conn_id)
    if conn is None:
        raise RuntimeError(f'no connection "{conn_id}" in the vault; import one first')
    set_connection_credentials(conn_id, auth_user, auth_pass)


def restart_tunnel(conn_id: str) -> None:
    """Restart the tunnel (runs as the user via the installer's polkit rule)."""
    subprocess.run(["systemctl", "restart", f"vitrail-vpn@{conn_id}.service"], check=True)


def check_api() -> None:
    """Reachability probe: create a session, nothing else."""
    uid, token, sid = new_session()
    print(f"API reachable. Anonymous session created (UID={uid[:8]}...)")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--id", default=DEFAULT_ID, help="connection id to update (default: proton-us)")
    parser.add_argument("--check", action="store_true", help="only validate API reachability")
    parser.add_argument("--dry-run", action="store_true", help="mint creds but do not write files or restart")
    args = parser.parse_args()

    conn = get_connection(args.id)
    if conn is None:
        print(f'ERROR: no connection "{args.id}" in the vault; import one first', file=sys.stderr)
        return 1

    try:
        if args.check:
            check_api()
            return 0

        print("Creating anonymous Proton session...")
        uid, token, session_id = new_session()
        print("Upgrading to credentialless session...")
        token = get_credentialless_token(uid, token, session_id)
        print("Fetching fresh VPN credentials...")
        vpn_user, vpn_pass = get_vpn_credentials(uid, token, session_id)
        print("Picking least-loaded free US server...")
        entry_ip, port = pick_us_free_server(uid, token, session_id)
        print(f"Selected {entry_ip}:{port}")

        if args.dry_run:
            print(f"DRY RUN: would set user={vpn_user} pass=*** server={entry_ip}:{port}")
            return 0

        print("Reading certificate blocks from existing config...")
        ca_block, tls_crypt_block = read_cert_blocks(conn["config_path"])
        conf_text = build_config(
            entry_ip,
            port,
            ca_block,
            tls_crypt_block,
            AUTH_PATH.format(id=args.id),
        )
        print(f"Storing credentials in the vault and writing {conn['config_path']}...")
        store_credentials(args.id, vpn_user, vpn_pass)
        with open(conn["config_path"], "w", encoding="utf-8") as fh:
            fh.write(conf_text)
        os.chmod(conn["config_path"], 0o600)
        print(f"Restarting vitrail-vpn@{args.id}...")
        restart_tunnel(args.id)
        print("Done. Tunnel restarted with fresh anonymous credentials.")
        return 0
    except Exception as exc:  # noqa: BLE001 - report any failure cleanly to the watchdog
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
