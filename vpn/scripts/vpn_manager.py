#!/usr/bin/env python3
"""vitrail-vpn — manage the project's split-tunnel OpenVPN connections.

Every connection is a generated split-tunnel client config (see
ovpn2split.py) plus a row in a private sqlite vault
(~/.config/vitrail-vpn/vault.db, mode 600). Credentials live in their
own reusable table: one named username/password pair can be shared by any
number of connections (e.g. one ProtonVPN credential across several .ovpn
files). The runtime tunnel is a vitrail-vpn@<id>.service instance; a
root wrapper (vpn-auth-prep.sh) reads the vault on start and hands the
credentials to OpenVPN via a transient 0600 file under /run (tmpfs).

All vault/config work runs as the invoking user; only start/stop touch
systemd, which the installer's polkit rule allows for vitrail-vpn@*
units. Only one tunnel is active at a time (shared 'vpn' routing table).
"""

from __future__ import annotations

import argparse
import getpass
import json
import os
import re
import sqlite3
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

from ovpn2split import convert  # noqa: E402

CONFIG_HOME = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
VPN_DIR = CONFIG_HOME / "vitrail-vpn"
VAULT_PATH = VPN_DIR / "vault.db"
CONF_DIR = VPN_DIR / "connections"
# User-readable mirror of the global traffic mode, written by vpn-mode.sh /
# install.sh (which run as root) so the desktop shell can display it.
MODE_FILE = VPN_DIR / "mode"
# The tunnel's domain list (source of truth for the settings UI and the
# root vpn-domain.sh helper). User-owned, like the vault.
DOMAINS_FILE = VPN_DIR / "domains"
# Marker the desktop shell reads at login to decide whether the VPN should
# come back up (auto-connecting the best connection). Kept in sync by the
# commands below that change unit state: it exists while any tunnel is
# active, regardless of whether the shell or a terminal drove the change.
ENABLED_FILE = VPN_DIR / "enabled"

AUTH_FILE = "/run/vitrail-vpn/{id}/auth.txt"
UNIT_TEMPLATE = "vitrail-vpn@{id}.service"

# Substrings (lowercased) used to guess the provider from a filename or the
# `remote` host lines of a .ovpn. Order matters: first match wins.
PROVIDER_KEYWORDS: dict[str, list[str]] = {
    "proton": ["proton"],
    "mullvad": ["mullvad"],
    "nordvpn": ["nordvpn", "nord"],
    "expressvpn": ["expressvpn", "express"],
    "surfshark": ["surfshark"],
    "windscribe": ["windscribe"],
    "ipvanish": ["ipvanish"],
    "cyberghost": ["cyberghost"],
    "pia": ["privateinternetaccess", "private internet access", "pia"],
    "hide.me": ["hideme", "hide.me"],
    "purevpn": ["purevpn"],
    "vyprvpn": ["vyprvpn", "vypr"],
    "tunnelbear": ["tunnelbear"],
    "ivpn": ["ivpn"],
}

ISO3166_ALPHA2 = {
    "AD",
    "AE",
    "AF",
    "AG",
    "AI",
    "AL",
    "AM",
    "AO",
    "AQ",
    "AR",
    "AS",
    "AT",
    "AU",
    "AW",
    "AX",
    "AZ",
    "BA",
    "BB",
    "BD",
    "BE",
    "BF",
    "BG",
    "BH",
    "BI",
    "BJ",
    "BL",
    "BM",
    "BN",
    "BO",
    "BQ",
    "BR",
    "BS",
    "BT",
    "BV",
    "BW",
    "BY",
    "BZ",
    "CA",
    "CC",
    "CD",
    "CF",
    "CG",
    "CH",
    "CI",
    "CK",
    "CL",
    "CM",
    "CN",
    "CO",
    "CR",
    "CU",
    "CV",
    "CW",
    "CX",
    "CY",
    "CZ",
    "DE",
    "DJ",
    "DK",
    "DM",
    "DO",
    "DZ",
    "EC",
    "EE",
    "EG",
    "EH",
    "ER",
    "ES",
    "ET",
    "FI",
    "FJ",
    "FK",
    "FM",
    "FO",
    "FR",
    "GA",
    "GB",
    "GD",
    "GE",
    "GF",
    "GG",
    "GH",
    "GI",
    "GL",
    "GM",
    "GN",
    "GP",
    "GQ",
    "GR",
    "GS",
    "GT",
    "GU",
    "GW",
    "GY",
    "HK",
    "HM",
    "HN",
    "HR",
    "HT",
    "HU",
    "ID",
    "IE",
    "IL",
    "IM",
    "IN",
    "IO",
    "IQ",
    "IR",
    "IS",
    "IT",
    "JE",
    "JM",
    "JO",
    "JP",
    "KE",
    "KG",
    "KH",
    "KI",
    "KM",
    "KN",
    "KP",
    "KR",
    "KW",
    "KY",
    "KZ",
    "LA",
    "LB",
    "LC",
    "LI",
    "LK",
    "LR",
    "LS",
    "LT",
    "LU",
    "LV",
    "LY",
    "MA",
    "MC",
    "MD",
    "ME",
    "MF",
    "MG",
    "MH",
    "MK",
    "ML",
    "MM",
    "MN",
    "MO",
    "MP",
    "MQ",
    "MR",
    "MS",
    "MT",
    "MU",
    "MV",
    "MW",
    "MX",
    "MY",
    "MZ",
    "NA",
    "NC",
    "NE",
    "NF",
    "NG",
    "NI",
    "NL",
    "NO",
    "NP",
    "NR",
    "NU",
    "NZ",
    "OM",
    "PA",
    "PE",
    "PF",
    "PG",
    "PH",
    "PK",
    "PL",
    "PM",
    "PN",
    "PR",
    "PS",
    "PT",
    "PW",
    "PY",
    "QA",
    "RE",
    "RO",
    "RS",
    "RU",
    "RW",
    "SA",
    "SB",
    "SC",
    "SD",
    "SE",
    "SG",
    "SH",
    "SI",
    "SJ",
    "SK",
    "SL",
    "SM",
    "SN",
    "SO",
    "SR",
    "SS",
    "ST",
    "SV",
    "SX",
    "SY",
    "SZ",
    "TC",
    "TD",
    "TF",
    "TG",
    "TH",
    "TJ",
    "TK",
    "TL",
    "TM",
    "TN",
    "TO",
    "TR",
    "TT",
    "TV",
    "TW",
    "TZ",
    "UA",
    "UG",
    "UM",
    "US",
    "UY",
    "UZ",
    "VA",
    "VC",
    "VE",
    "VG",
    "VI",
    "VN",
    "VU",
    "WF",
    "WS",
    "YE",
    "YT",
    "ZA",
    "ZM",
    "ZW",
}


def die(message: str, code: int = 1) -> None:
    print(f"vitrail-vpn: {message}", file=sys.stderr)
    sys.exit(code)


# ---------------------------------------------------------------------------
# Vault
# ---------------------------------------------------------------------------


def _connect(readonly: bool = False) -> sqlite3.Connection:
    if readonly:
        return sqlite3.connect(f"file:{VAULT_PATH}?mode=ro", uri=True)
    db = sqlite3.connect(VAULT_PATH)
    # Read commands must not touch the file: every write bumps the mtime and
    # the auth watchdog would restart the tunnel (a polling feedback loop).
    if db.execute("PRAGMA user_version").fetchone()[0] == 2:
        return db
    # Schema v1 (inline username/password on connections) is discarded
    # wholesale rather than migrated: v2 splits credentials into their own
    # reusable table, and per project decision an old vault is dropped.
    cols = {r[1] for r in db.execute("PRAGMA table_info(connections)")}
    if cols and "username" in cols:
        db.execute("DROP TABLE connections")
    db.execute("PRAGMA user_version = 2")
    db.execute(
        """CREATE TABLE IF NOT EXISTS credentials (
               id         INTEGER PRIMARY KEY AUTOINCREMENT,
               name       TEXT NOT NULL UNIQUE,
               username   TEXT NOT NULL,
               password   TEXT NOT NULL,
               created_at TEXT NOT NULL,
               updated_at TEXT NOT NULL
           )"""
    )
    db.execute(
        """CREATE TABLE IF NOT EXISTS connections (
               id            TEXT PRIMARY KEY,
               name          TEXT NOT NULL,
               provider      TEXT,
               region        TEXT,
               credential_id INTEGER REFERENCES credentials(id),
               config_path   TEXT NOT NULL,
               created_at    TEXT NOT NULL,
               updated_at    TEXT NOT NULL
           )"""
    )
    return db


def _ensure_vault() -> None:
    VPN_DIR.mkdir(mode=0o700, parents=True, exist_ok=True)
    CONF_DIR.mkdir(mode=0o700, parents=True, exist_ok=True)
    if not VAULT_PATH.exists():
        _connect().close()
    try:
        os.chmod(VAULT_PATH, 0o600)
    except FileNotFoundError:
        pass


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


# --- credentials ---


def list_credentials() -> list[dict[str, str | int]]:
    db = _connect()
    rows = db.execute(
        """SELECT c.id, c.name, c.username,
                  (SELECT COUNT(*) FROM connections x
                   WHERE x.credential_id = c.id) AS used_by
           FROM credentials c ORDER BY c.name"""
    ).fetchall()
    db.close()
    return [{"id": r[0], "name": r[1], "username": r[2], "used_by": r[3]} for r in rows]


def get_credential(name: str) -> dict[str, str | int] | None:
    db = _connect()
    row = db.execute(
        "SELECT id, name, username, password FROM credentials WHERE name = ?",
        (name,),
    ).fetchone()
    db.close()
    if row is None:
        return None
    return {"id": row[0], "name": row[1], "username": row[2], "password": row[3]}


def add_credential(name: str, username: str, password: str) -> int:
    now = _now()
    db = _connect()
    cur = db.execute(
        "INSERT INTO credentials (name, username, password, created_at, updated_at) VALUES (?, ?, ?, ?, ?)",
        (name, username, password, now, now),
    )
    db.commit()
    new_id = cur.lastrowid
    db.close()
    return new_id


def update_credential(
    name: str,
    *,
    rename: str | None = None,
    username: str | None = None,
    password: str | None = None,
) -> None:
    db = _connect()
    fields: list[str] = []
    values: list[object] = []
    if rename is not None:
        fields.append("name")
        values.append(rename)
    if username is not None:
        fields.append("username")
        values.append(username)
    if password is not None:
        fields.append("password")
        values.append(password)
    fields.append("updated_at")
    values.append(_now())
    values.append(name)
    db.execute(
        f"UPDATE credentials SET {', '.join(f'{f} = ?' for f in fields)} WHERE name = ?",
        values,
    )
    db.commit()
    db.close()


def remove_credential(name: str) -> list[str]:
    """Delete a credential and return the connection ids that referenced it
    (their `credential_id` is nulled — a tunnel has no auth until another
    credential is assigned)."""
    db = _connect()
    cred = db.execute("SELECT id FROM credentials WHERE name = ?", (name,)).fetchone()
    if cred is None:
        db.close()
        return []
    affected = [r[0] for r in db.execute("SELECT id FROM connections WHERE credential_id = ?", (cred[0],)).fetchall()]
    db.execute(
        "UPDATE connections SET credential_id = NULL, updated_at = ? WHERE credential_id = ?",
        (_now(), cred[0]),
    )
    db.execute("DELETE FROM credentials WHERE id = ?", (cred[0],))
    db.commit()
    db.close()
    return affected


def connection_ids_for_credential(name: str) -> list[str]:
    db = _connect()
    rows = db.execute(
        """SELECT c.id FROM connections c
           JOIN credentials cr ON cr.id = c.credential_id
           WHERE cr.name = ?""",
        (name,),
    ).fetchall()
    db.close()
    return [r[0] for r in rows]


# --- connections ---


def get_connection(conn_id: str) -> dict[str, str | None] | None:
    db = _connect()
    row = db.execute(
        """SELECT c.id, c.name, c.provider, c.region, c.config_path, cr.name
           FROM connections c LEFT JOIN credentials cr ON cr.id = c.credential_id
           WHERE c.id = ?""",
        (conn_id,),
    ).fetchone()
    db.close()
    if row is None:
        return None
    return {
        "id": row[0],
        "name": row[1],
        "provider": row[2],
        "region": row[3],
        "config_path": row[4],
        "credential": row[5],
    }


def list_connections() -> list[dict[str, str | None]]:
    db = _connect()
    rows = db.execute(
        """SELECT c.id, c.name, c.provider, c.region, c.config_path, cr.name
           FROM connections c LEFT JOIN credentials cr ON cr.id = c.credential_id
           ORDER BY c.provider, c.region, c.name"""
    ).fetchall()
    db.close()
    return [
        {
            "id": r[0],
            "name": r[1],
            "provider": r[2],
            "region": r[3],
            "config_path": r[4],
            "credential": r[5],
        }
        for r in rows
    ]


def upsert_connection(
    conn_id: str,
    name: str,
    provider: str | None,
    region: str | None,
    credential_id: int | None,
    config_path: str,
) -> None:
    now = _now()
    db = _connect()
    db.execute(
        """INSERT INTO connections
               (id, name, provider, region, credential_id, config_path,
                created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)
           ON CONFLICT(id) DO UPDATE SET
               name = excluded.name,
               provider = excluded.provider,
               region = excluded.region,
               credential_id = excluded.credential_id,
               config_path = excluded.config_path,
               updated_at = excluded.updated_at""",
        (conn_id, name, provider, region, credential_id, config_path, now, now),
    )
    db.commit()
    db.close()


def set_connection_credential(conn_id: str, credential_name: str) -> None:
    db = _connect()
    cred = db.execute("SELECT id FROM credentials WHERE name = ?", (credential_name,)).fetchone()
    if cred is None:
        db.close()
        die(f'no credential "{credential_name}"')
    db.execute(
        "UPDATE connections SET credential_id = ?, updated_at = ? WHERE id = ?",
        (cred[0], _now(), conn_id),
    )
    db.commit()
    db.close()


def set_connection_credentials(conn_id: str, username: str, password: str) -> None:
    """Update the credential a connection uses — or create one (named after
    the connection) and assign it, for flows that mint fresh credentials
    (proton-anon-refresh.py) without a pre-existing credential to reuse."""
    db = _connect()
    row = db.execute(
        """SELECT cr.id, cr.name FROM connections c
           JOIN credentials cr ON cr.id = c.credential_id
           WHERE c.id = ?""",
        (conn_id,),
    ).fetchone()
    if row is not None:
        now = _now()
        db.execute(
            "UPDATE credentials SET username = ?, password = ?, updated_at = ? WHERE id = ?",
            (username, password, now, row[0]),
        )
        db.commit()
        db.close()
        return
    db.close()
    add_credential(conn_id, username, password)
    set_connection_credential(conn_id, conn_id)


def delete_connection(conn_id: str) -> None:
    db = _connect()
    db.execute("DELETE FROM connections WHERE id = ?", (conn_id,))
    db.commit()
    db.close()


# ---------------------------------------------------------------------------
# systemd
# ---------------------------------------------------------------------------


def _systemctl(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["systemctl", *args], capture_output=True, text=True, check=False)


def unit_name(conn_id: str) -> str:
    return UNIT_TEMPLATE.format(id=conn_id)


def is_active(conn_id: str) -> bool:
    try:
        result = _systemctl("is-active", unit_name(conn_id))
    except OSError:
        return False
    return result.returncode == 0 and result.stdout.strip() == "active"


def active_ids() -> list[str]:
    return [conn["id"] for conn in list_connections() if is_active(conn["id"])]


def start_unit(conn_id: str) -> None:
    result = _systemctl("start", unit_name(conn_id))
    if result.returncode != 0:
        die(f"failed to start {unit_name(conn_id)}: {result.stderr.strip()}")


def stop_unit(conn_id: str) -> None:
    result = _systemctl("stop", unit_name(conn_id))
    if result.returncode != 0:
        die(f"failed to stop {unit_name(conn_id)}: {result.stderr.strip()}")


def restart_unit(conn_id: str) -> None:
    result = _systemctl("restart", unit_name(conn_id))
    if result.returncode != 0:
        die(f"failed to restart {unit_name(conn_id)}: {result.stderr.strip()}")


def sync_enabled_marker() -> None:
    """Mirror "is any tunnel active" into the shell's auto-connect marker."""
    if active_ids():
        ENABLED_FILE.touch()
    else:
        ENABLED_FILE.unlink(missing_ok=True)


def restart_credential_tunnels(name: str) -> None:
    """Restart every active tunnel whose connection uses `name`'s
    credentials — a credential change must reach the running tunnels
    immediately, not only on their next reconnect."""
    for conn_id in connection_ids_for_credential(name):
        if is_active(conn_id):
            print(f"Restarting {unit_name(conn_id)} to pick up the change...")
            restart_unit(conn_id)


# ---------------------------------------------------------------------------
# Metadata detection
# ---------------------------------------------------------------------------


def sanitize_id(raw: str) -> str:
    clean = re.sub(r"[^a-z0-9]+", "-", raw.lower()).strip("-")
    return clean or "vpn"


def parse_remotes(text: str) -> list[str]:
    """The host parts of `remote <host> <port>` lines (skips bare IPs)."""
    hosts = re.findall(r"(?im)^\s*remote\s+([^\s]+)\s+\d+", text)
    return [h for h in hosts if not re.match(r"^\d+\.\d+\.\d+\.\d+$", h)]


def detect_provider(filename: str, remote_hosts: list[str]) -> str | None:
    haystack = " ".join([filename, *remote_hosts]).lower()
    for provider, keywords in PROVIDER_KEYWORDS.items():
        if any(k in haystack for k in keywords):
            return provider
    return None


def detect_region(filename: str, remote_hosts: list[str]) -> str | None:
    for token in re.split(r"[._\-+\s]+", filename.lower()):
        if len(token) == 2 and token.upper() in ISO3166_ALPHA2:
            return token.upper()
    for host in remote_hosts:
        label = host.split(".")[0].lower()
        if len(label) == 2 and label.upper() in ISO3166_ALPHA2:
            return label.upper()
    return None


# ---------------------------------------------------------------------------
# Credentials (input helpers)
# ---------------------------------------------------------------------------


def collect_credentials(user: str | None, password: str | None, pass_file: str | None) -> tuple[str, str]:
    if pass_file:
        password = Path(pass_file).read_text(encoding="utf-8").strip()
        if not password:
            die(f"password file is empty: {pass_file}")
    if not user:
        user = input("OpenVPN username: ").strip()
    if password is None:
        password = getpass.getpass("OpenVPN password: ")
    if not user:
        die("empty username")
    if not password:
        die("empty password")
    return user, password


def resolve_credential(
    reuse: str | None,
    create_name: str | None,
    user: str | None,
    password: str | None,
    pass_file: str | None,
    fallback_name: str,
) -> str:
    """Turn the `import`/`credential add` flags into a credential name:
    `--credential` reuses an existing one; `--credential-name` creates it
    (prompting for username/password); with neither, prompt for a name and
    reuse if it exists, else create it."""
    if reuse:
        if get_credential(reuse) is None:
            die(f'no credential "{reuse}" (add one with `vitrail-vpn credential add`)')
        return reuse
    if create_name:
        if get_credential(create_name) is not None:
            die(f'credential "{create_name}" already exists')
        username, pwd = collect_credentials(user, password, pass_file)
        add_credential(create_name, username, pwd)
        return create_name
    prompt = input(f"Credential name (create or reuse) [{fallback_name}]: ").strip()
    name = prompt or fallback_name
    if get_credential(name) is not None:
        return name
    username, pwd = collect_credentials(user, password, pass_file)
    add_credential(name, username, pwd)
    return name


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------


def cmd_import(args: argparse.Namespace) -> None:
    _ensure_vault()
    ovpn = Path(args.ovpn).expanduser()
    if not ovpn.is_file():
        die(f".ovpn file not found: {ovpn}")

    conn_id = args.id or sanitize_id(ovpn.stem)
    if not re.fullmatch(r"[a-z0-9-]+", conn_id):
        die(f"invalid connection id (a-z0-9- only): {conn_id}")
    if get_connection(conn_id) is not None and not args.force:
        die(f'connection "{conn_id}" already exists (use --force to overwrite)')

    text = ovpn.read_text(encoding="utf-8")
    remote_hosts = parse_remotes(text)
    provider = args.provider or detect_provider(ovpn.stem, remote_hosts)
    region = args.region or detect_region(ovpn.stem, remote_hosts)
    name = args.name or ovpn.name

    credential_name = resolve_credential(
        args.credential,
        args.credential_name,
        args.user,
        args.password,
        args.pass_file,
        conn_id,
    )
    cred = get_credential(credential_name)
    assert cred is not None

    config_path = CONF_DIR / f"{conn_id}.conf"
    convert(
        str(ovpn),
        str(config_path),
        auth_file=AUTH_FILE.format(id=conn_id),
    )
    os.chmod(config_path, 0o600)

    upsert_connection(conn_id, name, provider, region, cred["id"], str(config_path))
    print(f'Imported "{conn_id}" -> {config_path}')
    print(f"  name:       {name}")
    print(f"  provider:   {provider or '(unknown)'}")
    print(f"  region:     {region or '(unknown)'}")
    print(f"  credential: {credential_name}")
    print(f"  connect:    vitrail-vpn connect {conn_id}")


def cmd_list(args: argparse.Namespace) -> None:
    _ensure_vault()
    entries = [
        {
            "id": c["id"],
            "name": c["name"],
            "provider": c["provider"],
            "region": c["region"],
            "credential": c["credential"],
            "config_path": c["config_path"],
            "active": is_active(c["id"]),
        }
        for c in list_connections()
    ]
    if args.json:
        print(json.dumps(entries, indent=2))
        return
    if not entries:
        print("No connections. Import one with: vitrail-vpn import <file.ovpn>")
        return
    width = max(len(c["id"]) for c in entries)
    for entry in entries:
        marker = "*" if entry["active"] else " "
        region = entry["region"] or "-"
        provider = entry["provider"] or "-"
        credential = entry["credential"] or "-"
        print(f"{marker} {entry['id'].ljust(width)}  {region:<3}  {provider:<10}  {credential:<16}  {entry['name']}")
    print("\n* = active")


def cmd_connect(args: argparse.Namespace) -> None:
    _ensure_vault()
    conn = get_connection(args.id)
    if conn is None:
        die(f'no connection "{args.id}" in the vault')
    if not conn["credential"]:
        die(f'connection "{args.id}" has no credential assigned (use `vitrail-vpn credential assign <name> {args.id}`)')
    for other in active_ids():
        if other != args.id:
            print(f"Stopping {other} (single active tunnel)...")
            stop_unit(other)
    start_unit(args.id)
    sync_enabled_marker()
    print(f"Started {unit_name(args.id)}")


def cmd_disconnect(args: argparse.Namespace) -> None:
    _ensure_vault()
    if args.id:
        if is_active(args.id):
            stop_unit(args.id)
            print(f"Stopped {unit_name(args.id)}")
        else:
            print(f"{unit_name(args.id)} is not active")
    else:
        targets = active_ids()
        if not targets:
            print("No active tunnels")
        for conn_id in targets:
            stop_unit(conn_id)
            print(f"Stopped {unit_name(conn_id)}")
    sync_enabled_marker()


def cmd_creds(args: argparse.Namespace) -> None:
    _ensure_vault()
    conn = get_connection(args.id)
    if conn is None:
        die(f'no connection "{args.id}" in the vault')
    cred_name = conn["credential"]
    if not cred_name:
        die(f'connection "{args.id}" has no credential assigned (use `vitrail-vpn credential assign <name> {args.id}`)')
    cred = get_credential(cred_name)
    assert cred is not None

    username: str | None = None
    password: str | None = None
    if args.pass_file:
        password = Path(args.pass_file).read_text(encoding="utf-8").strip()
        if not password:
            die(f"password file is empty: {args.pass_file}")
    elif args.password is not None:
        password = args.password
    elif args.user is not None:
        password = getpass.getpass("OpenVPN password: ")
    else:
        # No credential flags at all: full rotation, prompt for both.
        username = input(f"OpenVPN username [{cred['username']}]: ").strip()
        password = getpass.getpass("OpenVPN password: ")
    if args.user is not None:
        username = args.user
    username = username or str(cred["username"])
    if not password:
        die("empty password")

    update_credential(cred_name, username=username, password=password)
    print(f'Updated credential "{cred_name}" (used by "{args.id}")')
    if is_active(args.id):
        print("Restarting tunnel to pick them up...")
        restart_unit(args.id)


def cmd_remove(args: argparse.Namespace) -> None:
    _ensure_vault()
    conn = get_connection(args.id)
    if conn is None:
        die(f'no connection "{args.id}" in the vault')
    if is_active(args.id):
        stop_unit(args.id)
    Path(conn["config_path"]).unlink(missing_ok=True)
    delete_connection(args.id)
    sync_enabled_marker()
    print(f'Removed "{args.id}"')


def cmd_status(args: argparse.Namespace) -> None:
    _ensure_vault()
    active = active_ids()
    if not active:
        print("No active tunnels")
        return
    for conn_id in active:
        conn = get_connection(conn_id)
        if conn is None:
            continue
        print(f"Active: {conn_id} ({unit_name(conn_id)})")
        print(f"  name:       {conn['name']}")
        print(f"  provider:   {conn['provider'] or '(unknown)'}")
        print(f"  region:     {conn['region'] or '(unknown)'}")
        print(f"  credential: {conn['credential'] or '(none)'}")


def read_mode() -> str:
    """The current global traffic mode from the user-readable mirror
    (written by the root vpn-mode.sh / install.sh); falls back to split."""
    try:
        value = MODE_FILE.read_text(encoding="utf-8").strip()
        if value in ("split", "full"):
            return value
    except OSError:
        pass
    return "split"


def cmd_mode(args: argparse.Namespace) -> None:
    _ensure_vault()
    if args.mode is None:
        print(read_mode())
        return
    # Switching is root's job (nftables + NetworkManager): delegate to the
    # real root-owned helper via pkexec, allowed passwordless by the
    # installer's polkit rule.
    result = subprocess.run(
        ["pkexec", "/etc/vitrail/vpn/vpn-mode.sh", args.mode],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        die(f"failed to switch mode: {result.stderr.strip()}")
    print(read_mode())


# --- domain subcommands ---

DOMAIN_RE = re.compile(r"^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$")


def read_domains() -> list[str]:
    """The tunnel's domain list, deduplicated in order."""
    if not DOMAINS_FILE.exists():
        return []
    try:
        seen: list[str] = []
        for line in DOMAINS_FILE.read_text(encoding="utf-8").splitlines():
            domain = line.strip().lower()
            if domain and not domain.startswith("#") and domain not in seen:
                seen.append(domain)
        return seen
    except OSError:
        return []


def write_domains(domains: list[str]) -> None:
    VPN_DIR.mkdir(mode=0o700, parents=True, exist_ok=True)
    DOMAINS_FILE.write_text("\n".join(domains) + ("\n" if domains else ""), encoding="utf-8")


def resolve_domain_ips(domain: str) -> list[str]:
    """Current A/AAAA records for a domain via getent (the system resolver,
    which is dnsmasq — the same addresses it would feed the nftables sets)."""
    ips: list[str] = []
    for family in ("ahostsv4", "ahostsv6"):
        try:
            result = subprocess.run(
                ["getent", family, domain],
                capture_output=True,
                text=True,
                check=False,
                timeout=10,
            )
        except (OSError, subprocess.TimeoutExpired):
            continue
        for line in result.stdout.splitlines():
            fields = line.split()
            if fields and fields[0] not in ips and not fields[0].startswith("::ffff:"):
                ips.append(fields[0])
    return ips


def apply_domains() -> None:
    """Apply the domain list as root (regenerate dnsmasq config + insert the
    domains' current IPs into the active mode's nftables sets)."""
    result = subprocess.run(
        ["pkexec", "/etc/vitrail/vpn/vpn-domain.sh", "apply"],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        die(f"failed to apply domains: {result.stderr.strip()}")


def cmd_domain_add(args: argparse.Namespace) -> None:
    _ensure_vault()
    domain = args.domain.strip().lower().rstrip(".")
    if not DOMAIN_RE.fullmatch(domain):
        die(f'invalid domain: "{args.domain}"')
    domains = read_domains()
    if domain in domains:
        print(f'Domain "{domain}" is already in the list.')
    else:
        domains.append(domain)
        write_domains(domains)
        print(f'Added "{domain}" to the domain list.')
    apply_domains()
    ips = resolve_domain_ips(domain)
    print(f"  IPs: {', '.join(ips) if ips else '(none resolved)'}")


def cmd_domain_remove(args: argparse.Namespace) -> None:
    _ensure_vault()
    domain = args.domain.strip().lower().rstrip(".")
    domains = read_domains()
    if domain not in domains:
        die(f'domain "{domain}" is not in the list')
    write_domains([d for d in domains if d != domain])
    print(f'Removed "{domain}" from the domain list.')
    apply_domains()


def cmd_domain_list(args: argparse.Namespace) -> None:
    _ensure_vault()
    entries = [{"domain": domain, "ips": resolve_domain_ips(domain)} for domain in read_domains()]
    if args.json:
        print(json.dumps(entries, indent=2))
        return
    if not entries:
        print("No domains in the list. Add one with: vitrail-vpn domain add <domain>")
        return
    width = max(len(entry["domain"]) for entry in entries)
    for entry in entries:
        ips = ", ".join(entry["ips"]) if entry["ips"] else "(none)"
        print(f"{entry['domain'].ljust(width)}  {ips}")


def cmd_domain_refresh(args: argparse.Namespace) -> None:
    _ensure_vault()
    apply_domains()
    print("Re-applied all domain IPs.")


# --- credential subcommands ---


def cmd_credential_add(args: argparse.Namespace) -> None:
    _ensure_vault()
    name = args.name.strip()
    if not name:
        die("empty credential name")
    if get_credential(name) is not None:
        die(f'credential "{name}" already exists')
    username, password = collect_credentials(args.user, args.password, args.pass_file)
    add_credential(name, username, password)
    print(f'Added credential "{name}"')


def cmd_credential_list(args: argparse.Namespace) -> None:
    _ensure_vault()
    creds = list_credentials()
    if args.json:
        print(json.dumps(creds, indent=2))
        return
    if not creds:
        print("No credentials. Add one with: vitrail-vpn credential add <name>")
        return
    width = max(len(c["name"]) for c in creds)
    for c in creds:
        print(f"{c['name'].ljust(width)}  {c['username']:<24}  used by {c['used_by']}")


def cmd_credential_update(args: argparse.Namespace) -> None:
    _ensure_vault()
    existing = get_credential(args.name)
    if existing is None:
        die(f'no credential "{args.name}"')
    if args.rename is not None and get_credential(args.rename) is not None:
        die(f'credential "{args.rename}" already exists')

    # Update only what was given; a bare `update <name>` prompts for a full
    # rotation (username + password). The shell always passes explicit
    # flags, so it never hits the interactive path.
    username: str | None = args.user
    password: str | None = None
    if args.pass_file:
        password = Path(args.pass_file).read_text(encoding="utf-8").strip()
        if not password:
            die(f"password file is empty: {args.pass_file}")
    elif args.password is not None:
        password = args.password
    elif args.rename is None and args.user is None:
        username = input(f"OpenVPN username [{existing['username']}]: ").strip()
        password = getpass.getpass("OpenVPN password: ")
    if username == "":
        die("empty username")
    if password == "":
        die("empty password")

    update_credential(args.name, rename=args.rename, username=username, password=password)
    print(f'Updated credential "{args.name}"')
    restart_credential_tunnels(args.name)


def cmd_credential_assign(args: argparse.Namespace) -> None:
    _ensure_vault()
    if get_credential(args.name) is None:
        die(f'no credential "{args.name}"')
    for conn_id in args.ids:
        if get_connection(conn_id) is None:
            die(f'no connection "{conn_id}" in the vault')
        set_connection_credential(conn_id, args.name)
    print(f'Assigned credential "{args.name}" to: {", ".join(args.ids)}')


def cmd_credential_remove(args: argparse.Namespace) -> None:
    _ensure_vault()
    if get_credential(args.name) is None:
        die(f'no credential "{args.name}"')
    affected = remove_credential(args.name)
    for conn_id in affected:
        if is_active(conn_id):
            stop_unit(conn_id)
    sync_enabled_marker()
    print(f'Removed credential "{args.name}"')
    if affected:
        print("  connections left without a credential (reassign with `vitrail-vpn credential assign <name> <id>`):")
        for conn_id in affected:
            print(f"    {conn_id}")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    p_import = sub.add_parser("import", help="import a .ovpn and generate a split-tunnel config")
    p_import.add_argument("ovpn")
    p_import.add_argument("--id", help="connection id (default: from filename)")
    p_import.add_argument("--name", help="display name (default: filename)")
    p_import.add_argument("--provider", help="e.g. proton, mullvad (default: auto-detect)")
    p_import.add_argument("--region", help="e.g. US, JP, DE (default: auto-detect)")
    p_import.add_argument("--credential", help="reuse an existing credential by name")
    p_import.add_argument("--credential-name", help="create a new credential with this name")
    p_import.add_argument("--user", help="OpenVPN username (for a new credential)")
    p_import.add_argument("--pass", dest="password", help="OpenVPN password (leaks to history; prefer --pass-file)")
    p_import.add_argument("--pass-file", help="read the password from a file (recommended)")
    p_import.add_argument("--force", action="store_true", help="overwrite an existing connection id")
    p_import.set_defaults(func=cmd_import)

    p_list = sub.add_parser("list", help="list connections with active state")
    p_list.add_argument("--json", action="store_true", help="machine-readable output")
    p_list.set_defaults(func=cmd_list)

    p_connect = sub.add_parser("connect", help="start a tunnel (stops any other active)")
    p_connect.add_argument("id")
    p_connect.set_defaults(func=cmd_connect)

    p_disconnect = sub.add_parser("disconnect", help="stop a tunnel, or all active ones")
    p_disconnect.add_argument("id", nargs="?")
    p_disconnect.set_defaults(func=cmd_disconnect)

    p_creds = sub.add_parser("creds", help="rotate the credentials of a connection's linked credential")
    p_creds.add_argument("id")
    p_creds.add_argument("--user")
    p_creds.add_argument("--pass", dest="password")
    p_creds.add_argument("--pass-file")
    p_creds.set_defaults(func=cmd_creds)

    p_remove = sub.add_parser("remove", help="delete a connection (config + vault row)")
    p_remove.add_argument("id")
    p_remove.set_defaults(func=cmd_remove)

    p_status = sub.add_parser("status", help="show the active tunnel")
    p_status.set_defaults(func=cmd_status)

    p_mode = sub.add_parser("mode", help="show or switch the global traffic mode (split/full)")
    p_mode.add_argument("mode", nargs="?", choices=["split", "full"])
    p_mode.set_defaults(func=cmd_mode)

    p_domain = sub.add_parser("domain", help="manage the tunnel's domain list")
    domain_sub = p_domain.add_subparsers(dest="domain_command", required=True)

    p_dadd = domain_sub.add_parser("add", help="add a domain (resolves its IPs and applies)")
    p_dadd.add_argument("domain")
    p_dadd.set_defaults(func=cmd_domain_add)

    p_drem = domain_sub.add_parser("remove", help="remove a domain")
    p_drem.add_argument("domain")
    p_drem.set_defaults(func=cmd_domain_remove)

    p_dlist = domain_sub.add_parser("list", help="list domains with their resolved IPs")
    p_dlist.add_argument("--json", action="store_true", help="machine-readable output")
    p_dlist.set_defaults(func=cmd_domain_list)

    p_dref = domain_sub.add_parser("refresh", help="re-resolve and re-apply all domain IPs")
    p_dref.set_defaults(func=cmd_domain_refresh)

    p_cred = sub.add_parser("credential", help="manage reusable credentials")
    cred_sub = p_cred.add_subparsers(dest="credential_command", required=True)

    p_add = cred_sub.add_parser("add", help="add a new credential")
    p_add.add_argument("name")
    p_add.add_argument("--user")
    p_add.add_argument("--pass", dest="password")
    p_add.add_argument("--pass-file")
    p_add.set_defaults(func=cmd_credential_add)

    p_clist = cred_sub.add_parser("list", help="list saved credentials")
    p_clist.add_argument("--json", action="store_true", help="machine-readable output")
    p_clist.set_defaults(func=cmd_credential_list)

    p_cupd = cred_sub.add_parser("update", help="rename / change user / change password")
    p_cupd.add_argument("name")
    p_cupd.add_argument("--rename", help="new credential name")
    p_cupd.add_argument("--user")
    p_cupd.add_argument("--pass", dest="password")
    p_cupd.add_argument("--pass-file")
    p_cupd.set_defaults(func=cmd_credential_update)

    p_cass = cred_sub.add_parser("assign", help="assign a credential to one or more connections")
    p_cass.add_argument("name")
    p_cass.add_argument("ids", nargs="+", help="connection id(s)")
    p_cass.set_defaults(func=cmd_credential_assign)

    p_crem = cred_sub.add_parser("remove", help="delete a credential (connections keep existing, unassigned)")
    p_crem.add_argument("name")
    p_crem.set_defaults(func=cmd_credential_remove)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
