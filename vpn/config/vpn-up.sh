#!/usr/bin/env bash
# /etc/hypraether/vpn/vpn-up.sh
#
# Called by OpenVPN after the tunnel interface comes up.
# Sets up the split-tunnel policy routing so that only fwmark 0x4555 traffic
# (i.e. the target domains populated by dnsmasq) goes through the tunnel,
# while everything else keeps using the normal default route.
#
# OpenVPN passes the tunnel parameters as environment variables:
#   dev            -> tunnel device name (e.g. tun0)
#   ifconfig_local -> our IP inside the tunnel (e.g. 10.96.0.22)
#   route_vpn_gateway / ifconfig_remote -> peer/gateway inside the tunnel
set -e

MARK=0x4555
TABLE=vpn
DEV="${dev:-tun0}"
GW="${route_vpn_gateway:-${ifconfig_remote:-}}"
SRC="${ifconfig_local:-}"

# fwmark rule -> vpn table (idempotent, safe to re-run on reconnect)
if ! ip rule show | grep -q "from all fwmark $MARK lookup $TABLE"; then
    ip rule add fwmark $MARK priority 3000 lookup $TABLE
fi

# Default route via the tunnel gateway in the vpn table.
# Prefer an explicit gateway; fall back to a device-only route otherwise.
if [ -n "$GW" ]; then
    ip route replace default via "$GW" dev "$DEV" src "$SRC" table $TABLE 2>/dev/null || true
else
    ip route replace default dev "$DEV" src "$SRC" table $TABLE 2>/dev/null || true
fi

# SNAT so the tunnel exit sees our tunnel-IP as the source address.
# Without this, packets would egress the tunnel with the LAN source IP and
# Proton (and most VPN gateways) would drop them.
if [ -n "$SRC" ]; then
    nft add table ip vpn_nat 2>/dev/null || true
    nft add chain ip vpn_nat postrouting { type nat hook postrouting priority srcnat\; } 2>/dev/null || true
    nft flush chain ip vpn_nat postrouting
    nft add rule ip vpn_nat postrouting oifname "$DEV" snat to "$SRC"
fi

exit 0
