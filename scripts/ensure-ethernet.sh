#!/usr/bin/env bash
# Keeps the wired connection always on.
#
# Makes the NetworkManager profile autoconnect with infinite retries and the
# highest priority, so a wired link always wins over Wi-Fi.
set -euo pipefail

if ! command -v nmcli >/dev/null 2>&1; then
    printf 'NetworkManager (nmcli) not found.\n' >&2
    exit 1
fi

connection="${1:-}"
if [[ -z "$connection" ]]; then
    connection="$(nmcli -t -f NAME,TYPE connection show \
        | awk -F: '$2 == "802-3-ethernet" { print $1; exit }')"
fi

if [[ -z "$connection" ]]; then
    printf 'No wired NetworkManager profile found.\n' >&2
    exit 1
fi

nmcli connection modify "$connection" connection.autoconnect yes
nmcli connection modify "$connection" connection.autoconnect-priority 100
nmcli connection modify "$connection" connection.autoconnect-retries 0
nmcli connection up "$connection" >/dev/null 2>&1 || true

printf "Wired profile '%s' will always autoconnect.\n" "$connection"
