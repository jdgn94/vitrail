#!/usr/bin/env bash
# /etc/vitrail/vpn/vpn-down.sh
#
# Called by OpenVPN when the tunnel goes down. Cleans up the split-tunnel
# routing and SNAT rules created by vpn-up.sh.
set -e

TABLE=vpn
DEV="${dev:-tun0}"

# Remove the default route from the vpn table (if any)
if ip route show table $TABLE 2>/dev/null | grep -q default; then
    ip route del default table $TABLE 2>/dev/null || true
fi

# Drop the SNAT rule for this tunnel (empty the whole chain: only one tunnel at a time)
nft flush chain ip vpn_nat postrouting 2>/dev/null || true

exit 0
