#!/usr/bin/env bash
# /etc/vitrail/vpn/vpn-auth-clean.sh
#
# ExecStopPost of vitrail-vpn@<id>.service: remove the transient
# credential file written by vpn-auth-prep.sh. systemd also wipes the
# RuntimeDirectory on stop; this is belt-and-suspenders for the file itself.
set -euo pipefail

ID="${1:?usage: vpn-auth-clean.sh <id>}"
[[ "$ID" =~ ^[A-Za-z0-9-]+$ ]] || exit 0

rm -rf "/run/vitrail-vpn/$ID"
