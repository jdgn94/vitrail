#!/usr/bin/env bash
# /etc/hypraether/vpn/vpn-mode.sh
#
# Switch the VPN traffic mode:
#   split — only the domains on the list go through the tunnel
#   full  — everything goes through the tunnel except the excluded domains
#
# Installs the mode's nftables ruleset (from /etc/hypraether/vpn/config/,
# root-owned copies made by vpn/install.sh), reloads it, records VPN_MODE in /etc/hypraether/
# vpn/env plus a user-readable mirror for the settings UI, then re-applies
# the tunnel domain list through vpn-domain.sh (the dnsmasq config is
# generated from the list, so its set targets follow the mode). The domain
# list keeps its contents but changes meaning per mode — manage it in the
# settings UI or with `hypraether-vpn domain`.
#
# Installed as a real root-owned copy (NOT a symlink): it is the pkexec
# target from the settings UI, and pkexec refuses symlinks / a helper a
# non-root user could rewrite.
#
# Usage:
#   /etc/hypraether/vpn/vpn-mode.sh <split|full>
set -euo pipefail

MODE="${1:?usage: vpn-mode.sh <split|full>}"
[[ "$MODE" == split || "$MODE" == full ]] || {
    echo "vpn-mode: invalid mode \"$MODE\" (use split or full)" >&2
    exit 1
}

die() {
    printf '\033[31m[ERROR]\033[0m %s\n' "$*" >&2
    exit 1
}
info() { printf '\033[32m[INFO]\033[0m  %s\n' "$*"; }

[[ $EUID -ne 0 ]] && die "Run as root: sudo $0 $MODE"

VPN_DIR="/etc/hypraether/vpn"
CONFIG_DIR="$VPN_DIR/config"
ENV_FILE="$VPN_DIR/env"

if [[ -f "$ENV_FILE" ]]; then
    # shellcheck disable=SC1091
    source "$ENV_FILE"
fi

NFT_SRC="$CONFIG_DIR/nftables.conf"
if [[ "$MODE" == "full" ]]; then
    NFT_SRC="$CONFIG_DIR/nftables-bypass.conf"
fi

install -m 600 "$NFT_SRC" /etc/nftables.conf
systemctl reload nftables
info "Installed and reloaded nftables ruleset ($MODE)."

if [[ -f "$ENV_FILE" ]]; then
    if grep -q '^VPN_MODE=' "$ENV_FILE"; then
        sed -i "s/^VPN_MODE=.*/VPN_MODE=$MODE/" "$ENV_FILE"
    else
        printf 'VPN_MODE=%s\n' "$MODE" >>"$ENV_FILE"
    fi
    info "Updated VPN_MODE=$MODE in $ENV_FILE."

    # User-readable mirror for the settings UI: the vault dir (dirname of
    # VPN_VAULT) lives in the desktop user's config dir. Written as the user —
    # this runs passwordless through pkexec, and root writing there would
    # follow any symlink the user planted.
    if [[ -n "${VPN_VAULT:-}" && -n "${VPN_USER:-}" ]]; then
        user_vpn_dir="$(dirname "$VPN_VAULT")"
        printf '%s\n' "$MODE" | setpriv --reuid="$VPN_USER" --regid="$(id -g "$VPN_USER")" \
            --init-groups -- sh -c 'umask 077; mkdir -p "$1" && cat >"$1/mode"' sh "$user_vpn_dir"
        info "Wrote mode mirror for the settings UI ($user_vpn_dir/mode)."
    fi
fi

# Re-generate the dnsmasq config from the domain list and re-insert the
# domains' current IPs into the mode's sets (vpn_ips or bypass_ips).
"$VPN_DIR/vpn-domain.sh" apply

printf '\n\033[32mVPN mode switched to %s.\033[0m\n' "$MODE"
printf 'Manage the domain list in the settings UI or with:\n'
printf '  hypraether-vpn domain add|remove <domain>\n'
