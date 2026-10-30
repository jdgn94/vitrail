#!/usr/bin/env bash
# /etc/hypraether/vpn/vpn-auth-prep.sh
#
# ExecStartPre of hypraether-vpn@<id>.service: read the credentials for the
# instance from the sqlite vault and write them to a transient auth file
# under /run (tmpfs) that OpenVPN reads via `auth-user-pass`. Nothing on
# disk persists the password; the file is regenerated on every start and
# removed on stop (see vpn-auth-clean.sh). Also builds the client config
# OpenVPN runs from the user's connection file (vpn-client-conf.py).
#
# Runs as root. The vault path comes from /etc/hypraether/vpn/env so the
# unit never hardcodes a user's home (see vpn_manager.py).
set -euo pipefail

ID="${1:?usage: vpn-auth-prep.sh <id>}"
[[ "$ID" =~ ^[A-Za-z0-9-]+$ ]] || {
    echo "vpn-auth-prep: invalid connection id" >&2
    exit 1
}

ENV_FILE="/etc/hypraether/vpn/env"
if [[ -f "$ENV_FILE" ]]; then
    # shellcheck disable=SC1091
    source "$ENV_FILE"
fi

[[ -n "${VPN_VAULT:-}" ]] || {
    echo "vpn-auth-prep: VPN_VAULT not set (is /etc/hypraether/vpn/env installed?)" >&2
    exit 1
}
[[ -n "${VPN_USER:-}" && -n "${VPN_CONF_DIR:-}" ]] || {
    echo "vpn-auth-prep: VPN_USER/VPN_CONF_DIR not set (re-run vpn/install.sh)" >&2
    exit 1
}
[[ -f "$VPN_VAULT" ]] || {
    echo "vpn-auth-prep: vault not found: $VPN_VAULT" >&2
    exit 1
}

AUTH_DIR="/run/hypraether-vpn/$ID"
AUTH_FILE="$AUTH_DIR/auth.txt"

install -d -m 700 "$AUTH_DIR"

python3 -I /etc/hypraether/vpn/vpn-client-conf.py "$VPN_USER" \
    "$VPN_CONF_DIR/$ID.conf" "$AUTH_DIR/client.conf" "$AUTH_FILE"

python3 -I - "$VPN_VAULT" "$ID" "$AUTH_FILE" "$VPN_USER" <<'PY'
import os
import pwd
import sqlite3
import sys

vault, conn_id, out, user = sys.argv[1:5]
# Root reads this path from the user's home: only a vault the user owns.
if os.stat(vault).st_uid != pwd.getpwnam(user).pw_uid:
    sys.exit("vpn-auth-prep: the vault is not owned by VPN_USER")
db = sqlite3.connect(f"file:{vault}?mode=ro", uri=True)
row = db.execute(
    """SELECT cr.username, cr.password FROM connections c
       JOIN credentials cr ON cr.id = c.credential_id
       WHERE c.id = ?""",
    (conn_id,),
).fetchone()
if row is None:
    sys.exit(f'vpn-auth-prep: no credential for "{conn_id}" in vault')
fd = os.open(out, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
with os.fdopen(fd, "w", encoding="utf-8") as fh:
    fh.write(f"{row[0]}\n{row[1]}\n")
PY

chmod 600 "$AUTH_FILE"
chown root:root "$AUTH_FILE"
