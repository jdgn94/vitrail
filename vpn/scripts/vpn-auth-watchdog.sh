#!/usr/bin/env bash
# /etc/vitrail/vpn/vpn-auth-watchdog.sh
#
# Watches the OpenVPN services and notifies the desktop user when a tunnel
# has connection problems:
#   - AUTH_FAILED: the provider rejected the credentials. Notifies and opens
#     the Proton dashboard where the OpenVPN password is reset.
#   - Other failure signals from the journal (config errors, TLS handshake
#     failures, unresolved hosts, refused connections, unit start failures):
#     notifies with the connection name.
#   - A unit stuck in systemd's `failed` state: notifies.
#
# Credentials live in the sqlite vault (~/.config/vitrail-vpn/vault.db,
# see vpn_manager.py); the vault mtime is watched so that `vitrail-vpn
# creds <id>` restarts the affected tunnels automatically.
#
# A cooldown (default 900s) between notifications avoids spam while a
# tunnel flaps.
#
# Runs as root (reads the journal of system services, sends desktop
# notifications to the graphical session and restarts systemd units).
set -euo pipefail

ENV_FILE="/etc/vitrail/vpn/env"
CONF="/etc/vpn-auth-watchdog.conf"
STATE_DIR="/var/lib/vpn-auth-watchdog"
STATE_FILE="$STATE_DIR/last-notify"
COOLDOWN_SECONDS="${COOLDOWN_SECONDS:-900}"
PROTON_DASHBOARD="https://account.protonvpn.com/account#openvpn"

log() { echo "vpn-auth-watchdog: $*" >&2; }

now() { date +%s; }

# Load the vault path and the desktop user to notify.
if [[ -f "$ENV_FILE" ]]; then
    # shellcheck disable=SC1091
    source "$ENV_FILE"
fi
if [[ -f "$CONF" ]]; then
    # shellcheck disable=SC1091
    source "$CONF"
fi
NOTIFY_UID="${NOTIFY_UID:-$(id -u "$NOTIFY_USER" 2>/dev/null || echo 1000)}"
VAULT="${VPN_VAULT:-}"

# send_desktop_notify <urgency> <summary> <body>
send_desktop_notify() {
    local urgency="$1" summary="$2" body="$3"
    if [[ -n "${NOTIFY_USER:-}" ]]; then
        runuser -u "$NOTIFY_USER" -- \
            env XDG_RUNTIME_DIR="/run/user/$NOTIFY_UID" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$NOTIFY_UID/bus" \
            notify-send -u "$urgency" -a "Vitrail VPN" "$summary" "$body" \
            >/dev/null 2>&1 || true
    fi
}

within_cooldown() {
    [[ -f "$STATE_FILE" ]] || return 1
    local last now_diff
    last="$(cat "$STATE_FILE" 2>/dev/null || echo 0)"
    now_diff=$(($(now) - last))
    ((now_diff < COOLDOWN_SECONDS))
}

record_trigger() {
    mkdir -p "$STATE_DIR"
    echo "$(now)" >"$STATE_FILE"
}

# extract_id <journal-line> -> connection id, from the `vitrail-vpn@<id>[...]`
# process prefix, the `vitrail-vpn@<id>.service:` unit message, or
# systemd's "split-tunnel VPN (<id>)" start message.
extract_id() {
    local line="$1" id
    id="$(printf '%s' "$line" | sed -n 's/.*\(vitrail-vpn@[a-zA-Z0-9-]*\)\[.*/\1/p' | sed 's/^vitrail-vpn@//')"
    if [[ -n "$id" ]]; then
        echo "$id"
        return
    fi
    id="$(printf '%s' "$line" | sed -n 's/.*\(vitrail-vpn@[a-zA-Z0-9-]*\)\.service:.*/\1/p' | sed 's/^vitrail-vpn@//')"
    if [[ -n "$id" ]]; then
        echo "$id"
        return
    fi
    printf '%s' "$line" | sed -n 's/.*Vitrail split-tunnel VPN (\([a-zA-Z0-9-]*\)).*/\1/p'
}

handle_auth_failed() {
    local id="$1"
    if within_cooldown; then
        log "AUTH_FAILED detected but inside cooldown; skipping notification."
        return 0
    fi
    record_trigger
    log "AUTH_FAILED detected ($id). Notifying user and opening dashboard."
    send_desktop_notify critical "VPN AUTH_FAILED" \
        "The provider rejected the OpenVPN credentials for $id.\nUpdate them with:\n  vitrail-vpn creds $id\n\nThe tunnel restarts automatically once the vault changes."
    if [[ -n "${NOTIFY_USER:-}" ]]; then
        runuser -u "$NOTIFY_USER" -- xdg-open "$PROTON_DASHBOARD" >/dev/null 2>&1 || true
    fi
}

handle_connection_problem() {
    local id="$1" detail="$2"
    if within_cooldown; then
        log "connection problem detected but inside cooldown; skipping notification."
        return 0
    fi
    record_trigger
    log "connection problem ($id): $detail. Notifying user."
    send_desktop_notify normal "VPN connection problem" \
        "$id: $detail.\nCheck the tunnel with: vitrail-vpn status"
}

restart_tunnels() {
    log "vault changed; restarting active tunnels."
    while IFS= read -r unit; do
        [[ -n "$unit" ]] || continue
        systemctl restart "$unit" || log "restart of $unit failed"
    done < <(systemctl list-units 'vitrail-vpn@*.service' --no-legend --plain | awk '$3 == "active" { print $1 }')
}

# ---------------------------------------------------------------------------
# Loops
# ---------------------------------------------------------------------------
log "Starting watchdogs for vitrail-vpn@* (cooldown=${COOLDOWN_SECONDS}s, notify=${NOTIFY_USER:-root})."

# Tail the journal and react to failure signals.
# shellcheck disable=SC2016
journalctl -f -u 'vitrail-vpn@*' -o short | while IFS= read -r line; do
    id="$(extract_id "$line")"
    id="${id:-unknown}"
    case "$line" in
        *AUTH_FAILED*)
            handle_auth_failed "$id"
            ;;
        *"Options error"*)
            handle_connection_problem "$id" "configuration error prevents starting"
            ;;
        *"Exiting due to fatal error"*)
            handle_connection_problem "$id" "fatal error, the tunnel is down"
            ;;
        *"TLS key negotiation failed"* | *"tls-crypt unwrap error"*)
            handle_connection_problem "$id" "TLS handshake failed"
            ;;
        *"RESOLVE: Cannot resolve host address"*)
            handle_connection_problem "$id" "cannot resolve the server address"
            ;;
        *"Connection refused"*)
            handle_connection_problem "$id" "the server refused the connection"
            ;;
        *"Failed to start Vitrail split-tunnel VPN"* | *"Failed with result"*)
            handle_connection_problem "$id" "the service failed to start"
            ;;
    esac
done &

JOURNAL_PID=$!

# Watch the vault mtime and restart active tunnels when credentials change.
(
    LAST_MTIME=$(stat -c %Y "$VAULT" 2>/dev/null || echo 0)
    while true; do
        sleep 5
        MTIME=$(stat -c %Y "$VAULT" 2>/dev/null || echo 0)
        if [[ "$MTIME" != "$LAST_MTIME" ]]; then
            LAST_MTIME="$MTIME"
            restart_tunnels
        fi
    done
) &

VAULT_PID=$!

# Periodically surface units stuck in a failed state (start failures,
# repeated crashes) — the journal patterns cover the cause, this catches
# whatever slips through while the unit stays down.
while true; do
    sleep 15
    failed="$(systemctl list-units 'vitrail-vpn@*.service' --no-legend --plain | awk '$3 == "failed" { print $1 }' | sed 's/^vitrail-vpn@//' | tr '\n' ' ')"
    if [[ -n "$failed" ]]; then
        handle_connection_problem "${failed% }" "the service is in a failed state"
    fi
done &

STATE_PID=$!

wait "$JOURNAL_PID" "$VAULT_PID" "$STATE_PID"
