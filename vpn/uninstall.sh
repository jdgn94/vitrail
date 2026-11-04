#!/usr/bin/env bash
# uninstall.sh - Remove the domain-based split-tunnel VPN from the system.
#
# Usage:
#   sudo ./uninstall.sh
#
# What it removes:
#   - every vitrail-vpn@<id> tunnel (stopped) and its unit template
#   - /etc/vitrail/vpn/ (env, scripts) and the /usr/local/bin
#     vitrail-vpn CLI symlink
#   - the vpn-auth-watchdog service and its state
#   - the polkit rule for passwordless tunnel control
#   - the nftables split-tunnel ruleset (restores /etc/nftables.conf.orig
#     if the installer created a backup, otherwise deletes the ruleset)
#   - /etc/NetworkManager/conf.d/dns.conf (dns=dnsmasq) and the dnsmasq
#     split config
#   - the 'vpn' routing table entry in /etc/iproute2/rt_tables
#
# Your per-user connections (~/.config/vitrail-vpn) are NOT touched —
# remove them yourself with `vitrail-vpn remove <id>` for each one.
#
# NOTE: the openvpn / dnsmasq / nftables / NetworkManager packages themselves
# are left installed; only this project's configuration is removed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[[ $EUID -ne 0 ]] && {
    echo "Run as root: sudo $0" >&2
    exit 1
}

info() { printf '\033[32m[INFO]\033[0m  %s\n' "$*"; }
warn() { printf '\033[33m[WARN]\033[0m  %s\n' "$*"; }

# Stop and disable every tunnel instance
if systemctl list-unit-files | grep -q 'vitrail-vpn@'; then
    mapfile -t UNITS < <(systemctl list-unit-files 'vitrail-vpn@*' --no-legend --plain | cut -d' ' -f1)
    for unit in "${UNITS[@]}"; do
        systemctl stop "$unit" 2>/dev/null || true
        systemctl disable "$unit" 2>/dev/null || true
        info "Stopped and disabled $unit"
    done
fi

# Remove the unit template
if [[ -f /etc/systemd/system/vitrail-vpn@.service ]]; then
    rm -f /etc/systemd/system/vitrail-vpn@.service
    info "Removed unit template /etc/systemd/system/vitrail-vpn@.service"
fi

# Remove the AUTH_FAILED watchdog
if systemctl list-unit-files | grep -q 'vpn-auth-watchdog.service'; then
    systemctl disable --now vpn-auth-watchdog.service 2>/dev/null || true
    info "Stopped and disabled vpn-auth-watchdog.service"
fi
rm -f /etc/systemd/system/vpn-auth-watchdog.service
rm -f /etc/vpn-auth-watchdog.conf
rm -rf /var/lib/vpn-auth-watchdog

# Remove the project's system dir and the CLI symlink
rm -rf /etc/vitrail/vpn
rm -f /usr/local/bin/vitrail-vpn
info "Removed /etc/vitrail/vpn and the vitrail-vpn CLI symlink."

# Remove the polkit rule
rm -f /etc/polkit-1/rules.d/50-vitrail-vpn.rules
info "Removed polkit rule /etc/polkit-1/rules.d/50-vitrail-vpn.rules"

systemctl daemon-reload 2>/dev/null || true

# Restore or remove the nftables ruleset
if [[ -f /etc/nftables.conf.orig ]]; then
    mv -f /etc/nftables.conf.orig /etc/nftables.conf
    info "Restored original firewall ruleset from /etc/nftables.conf.orig"
else
    rm -f /etc/nftables.conf
    warn "No /etc/nftables.conf.orig backup found; deleted the split-tunnel ruleset."
fi
systemctl reload nftables 2>/dev/null || systemctl restart nftables 2>/dev/null || true

# Remove NetworkManager dnsmasq integration
rm -f /etc/NetworkManager/conf.d/dns.conf \
    /etc/NetworkManager/dnsmasq.d/vpn-split.conf \
    /etc/NetworkManager/dnsmasq.d/vpn-bypass.conf \
    /etc/NetworkManager/dnsmasq.d/vpn-mode.conf
systemctl restart NetworkManager 2>/dev/null || true
info "Removed NetworkManager dnsmasq configuration and restarted NetworkManager."

# Remove the 'vpn' routing table entry
if [[ -f /etc/iproute2/rt_tables ]]; then
    sed -i -E '/^[0-9]+\s+vpn$/d' /etc/iproute2/rt_tables
    info "Removed 'vpn' entry from /etc/iproute2/rt_tables"
fi

printf '\n\033[32mSplit-tunnel VPN configuration removed.\033[0m\n'
printf 'Packages (openvpn, dnsmasq, nftables) were left installed.\n'
printf 'Your connections (~/.config/vitrail-vpn) were left untouched.\n'
