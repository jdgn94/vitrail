#!/usr/bin/env bash
# install.sh - Installer for the Hypraether Domain-Based Split-Tunnel VPN
#
# Installs the SYSTEM infrastructure only: packages, the dnsmasq/nftables/
# routing config, the hypraether-vpn@.service template, the root credential
# wrappers, the polkit rule and the `hypraether-vpn` CLI symlink.
#
# Two traffic modes are supported (global, stored in /etc/hypraether/vpn/env
# as VPN_MODE):
#   split — only the domains on the list go through the tunnel (default)
#   full  — everything goes through the tunnel except the excluded domains
#
# Connections are imported per-user afterwards (NOT as root) so that each
# .ovpn keeps its own credentials in the user's sqlite vault:
#   hypraether-vpn import /path/to/downloaded.ovpn [--provider] [--region]
#                        [--user NAME] [--pass-file FILE]
#
# Usage:
#   sudo ./install.sh [--mode split|full]
#
# Options:
#   --mode <split|full>  VPN traffic mode (default: split)
#   --user <name>        Desktop user to grant polkit control + env paths
#                        (default: the SUDO_USER that ran the installer)
#   --no-watchdog        Install config but do NOT enable/start the watchdog
#   -h, --help           Show this help
#
# Requirements:
#   - Arch Linux or an Arch-based distro (Manjaro, EndeavourOS, ...)
#   - An active NetworkManager-managed connection
#   - An OpenVPN provider that hands you .ovpn files

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

VPN_DIR="/etc/hypraether/vpn"
ENV_FILE="$VPN_DIR/env"
NM_DNS_CONF="/etc/NetworkManager/conf.d/dns.conf"
# The dnsmasq domain config (/etc/NetworkManager/dnsmasq.d/vpn-mode.conf) is
# generated from the user's domain list by vpn-domain.sh — no static file here.
NFT_CONF="/etc/nftables.conf"
RT_TABLES="/etc/iproute2/rt_tables"
UNIT_TEMPLATE="/etc/systemd/system/hypraether-vpn@.service"
WATCHDOG_UNIT="/etc/systemd/system/vpn-auth-watchdog.service"
WATCHDOG_CONF="/etc/vpn-auth-watchdog.conf"
POLKIT_RULE="/etc/polkit-1/rules.d/50-hypraether-vpn.rules"
CLI_LINK="/usr/local/bin/hypraether-vpn"

VPN_USER=""
DO_WATCHDOG=1
VPN_MODE="split"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
die() {
    printf '\033[31m[ERROR]\033[0m %s\n' "$*" >&2
    exit 1
}
info() { printf '\033[32m[INFO]\033[0m  %s\n' "$*"; }
warn() { printf '\033[33m[WARN]\033[0m  %s\n' "$*"; }

as_user() {
    setpriv --reuid="$VPN_USER" --regid="$(id -g "$VPN_USER")" --init-groups -- "$@"
}

need_root() {
    if [[ $EUID -ne 0 ]]; then
        die "Run as root: sudo $0 $*"
    fi
}

is_arch_based() {
    grep -qiE 'arch|manjaro|endeavour' /etc/os-release 2>/dev/null
}

install_packages() {
    local pkgs=(openvpn dnsmasq nftables networkmanager iproute2)
    local missing=()
    for p in "${pkgs[@]}"; do
        pacman -Qi "$p" >/dev/null 2>&1 || missing+=("$p")
    done
    if ((${#missing[@]} > 0)); then
        info "Installing missing packages: ${missing[*]}"
        pacman -Sy --noconfirm --needed "${missing[@]}"
    else
        info "All required packages are already installed."
    fi
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
usage() {
    sed -n '1,38p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

parse_args() {
    while (($# > 0)); do
        case "$1" in
            --mode)
                VPN_MODE="$2"
                shift 2
                ;;
            --user)
                VPN_USER="$2"
                shift 2
                ;;
            --no-watchdog)
                DO_WATCHDOG=0
                shift
                ;;
            -h | --help)
                usage
                exit 0
                ;;
            *) die "Unknown option: $1" ;;
        esac
    done
    [[ "$VPN_MODE" == split || "$VPN_MODE" == full ]] || die "Invalid --mode: $VPN_MODE (use split or full)"
}

# ---------------------------------------------------------------------------
# Install steps
# ---------------------------------------------------------------------------
install_project_dir() {
    info "Installing project scripts to $VPN_DIR (root-owned copies)..."
    install -d -m 755 "$VPN_DIR"
    # Real root-owned copies, never symlinks into the clone: systemd and
    # OpenVPN run these as root, and the user starts the service without a
    # password — a user-writable target would be a root shell. Repo edits
    # reach them by re-running this installer.
    local script
    for script in config/vpn-up.sh config/vpn-down.sh scripts/vpn-auth-prep.sh \
        scripts/vpn-auth-clean.sh scripts/vpn-auth-watchdog.sh \
        scripts/vpn-client-conf.py scripts/vpn-mode.sh scripts/vpn-domain.sh; do
        rm -f "$VPN_DIR/$(basename "$script")"
        install -m 755 -o root -g root "$REPO_ROOT/vpn/$script" "$VPN_DIR/$(basename "$script")"
    done

    # The mode rulesets vpn-mode.sh installs.
    install -d -m 755 "$VPN_DIR/config"
    rm -f "$VPN_DIR/config/nftables.conf" "$VPN_DIR/config/nftables-bypass.conf"
    install -m 644 -o root -g root "$REPO_ROOT/vpn/config/nftables.conf" "$VPN_DIR/config/nftables.conf"
    install -m 644 -o root -g root "$REPO_ROOT/vpn/config/nftables-bypass.conf" "$VPN_DIR/config/nftables-bypass.conf"

    # Env pointing root-owned services at the user's vault/configs.
    local user_home
    user_home="$(getent passwd "$VPN_USER" | cut -d: -f6)"
    [[ -n "$user_home" ]] || die "Cannot resolve home for user $VPN_USER"
    {
        printf 'VPN_USER=%s\n' "$VPN_USER"
        printf 'VPN_VAULT=%s/.config/hypraether/vpn/vault.db\n' "$user_home"
        printf 'VPN_CONF_DIR=%s/.config/hypraether/vpn/connections\n' "$user_home"
        printf 'VPN_MODE=%s\n' "$VPN_MODE"
    } >"$ENV_FILE"
    chmod 600 "$ENV_FILE"

    # User-readable mirror of the mode for the settings UI. Written as the
    # user: root writing into the user's tree would follow their symlinks.
    as_user mkdir -p -m 700 "$user_home/.config/hypraether/vpn"
    printf '%s\n' "$VPN_MODE" | as_user sh -c 'umask 077; cat >"$1"' sh "$user_home/.config/hypraether/vpn/mode"

    # Seed the tunnel domain list on first install with the mode's defaults
    # (split = the services the project targets; full = nothing excluded).
    local domains_file="$user_home/.config/hypraether/vpn/domains"
    if [[ ! -f "$domains_file" ]]; then
        local default_domains=()
        if [[ "$VPN_MODE" == "split" ]]; then
            default_domains=(anthropic.com openai.com chatgpt.com claude.ai
                oaistatic.com oaiusercontent.com auth0.com)
        fi
        {
            printf '# Domains for the tunnel — one per line.\n'
            printf '# split mode: tunneled · full mode: excluded.\n'
            for domain in "${default_domains[@]}"; do
                printf '%s\n' "$domain"
            done
        } | as_user sh -c 'umask 077; cat >"$1"' sh "$domains_file"
        info "Seeded the tunnel domain list ($VPN_MODE defaults)."
    fi

    info "Wrote $ENV_FILE (vault + conf dir for user $VPN_USER, mode $VPN_MODE)."
}

install_configs() {
    info "Writing system config files (mode: $VPN_MODE)..."

    local nft_src="$REPO_ROOT/vpn/config/nftables.conf"
    if [[ "$VPN_MODE" == "full" ]]; then
        nft_src="$REPO_ROOT/vpn/config/nftables-bypass.conf"
    fi

    # NetworkManager runs dnsmasq as the resolver (the nftset mechanism);
    # the dnsmasq domain config itself is generated from the user's domain
    # list by vpn-domain.sh apply (run after the services are enabled).
    install -d -m 755 /etc/NetworkManager/conf.d /etc/NetworkManager/dnsmasq.d
    install -m 644 "$REPO_ROOT/vpn/config/dns.conf" "$NM_DNS_CONF"
    rm -f /etc/NetworkManager/dnsmasq.d/vpn-split.conf \
        /etc/NetworkManager/dnsmasq.d/vpn-bypass.conf

    # nftables ruleset (backup any existing ruleset first)
    if [[ -f "$NFT_CONF" && ! -f "$NFT_CONF.orig" ]]; then
        cp "$NFT_CONF" "$NFT_CONF.orig"
        info "Backed up existing firewall ruleset to $NFT_CONF.orig"
    fi
    install -m 600 "$nft_src" "$NFT_CONF"

    # Routing table id for the tunnel
    install -d -m 755 /etc/iproute2
    if [[ -f "$RT_TABLES" ]] && grep -qE '^[0-9]+\s+vpn$' "$RT_TABLES"; then
        info "Routing table 'vpn' already present in $RT_TABLES."
    else
        printf '100\tvpn\n' >>"$RT_TABLES"
        info "Added '100 vpn' to $RT_TABLES."
    fi
}

install_units() {
    install -m 644 "$REPO_ROOT/vpn/config/hypraether-vpn@.service" "$UNIT_TEMPLATE"
    install -m 644 "$REPO_ROOT/vpn/config/vpn-auth-watchdog.service" "$WATCHDOG_UNIT"

    # Desktop user to notify (the watchdog daemon runs as root).
    local notify_uid
    notify_uid="$(id -u "$VPN_USER" 2>/dev/null || echo 1000)"
    {
        printf 'NOTIFY_USER=%s\n' "$VPN_USER"
        printf 'NOTIFY_UID=%s\n' "$notify_uid"
    } >"$WATCHDOG_CONF"
    chmod 600 "$WATCHDOG_CONF"

    systemctl daemon-reload
    info "Installed $UNIT_TEMPLATE and $WATCHDOG_UNIT."
}

install_polkit() {
    install -d -m 755 /etc/polkit-1/rules.d
    sed "s/@VPN_USER@/$VPN_USER/g" \
        "$REPO_ROOT/vpn/config/50-hypraether-vpn.rules" >"$POLKIT_RULE"
    chmod 644 "$POLKIT_RULE"
    info "Installed $POLKIT_RULE (passwordless control of hypraether-vpn@* for $VPN_USER)."
}

install_cli() {
    ln -sfn "$REPO_ROOT/vpn/scripts/vpn_manager.py" "$CLI_LINK"
    # The symlink is invoked directly (shebang), so the target must be
    # executable — a fresh clone may have it as 644.
    chmod +x "$REPO_ROOT/vpn/scripts/vpn_manager.py"
    info "Linked $CLI_LINK -> $REPO_ROOT/vpn/scripts/vpn_manager.py"
}

enable_services() {
    systemctl enable --now nftables
    systemctl restart NetworkManager

    if ((DO_WATCHDOG)); then
        systemctl enable --now vpn-auth-watchdog.service
        info "vpn-auth-watchdog.service enabled and started (notifications -> $VPN_USER)."
    else
        warn "--no-watchdog set: watchdog NOT enabled/started."
        info "Enable later with: systemctl enable --now vpn-auth-watchdog"
    fi
}

apply_domains() {
    info "Applying the tunnel domain list (regenerating dnsmasq + inserting IPs)..."
    "$VPN_DIR/vpn-domain.sh" apply
}

print_summary() {
    printf '\n\033[32m============================================================\033[0m\n'
    printf '\033[32m  Split-tunnel VPN infrastructure installed!\033[0m\n'
    printf '\033[32m============================================================\033[0m\n\n'
    printf 'Traffic mode:        %s\n' "$VPN_MODE"
    if [[ "$VPN_MODE" == "full" ]]; then
        printf '                     everything through the tunnel except exclusions\n'
        printf '                     (list starts EMPTY — manage it in the settings UI)\n'
    else
        printf '                     only listed domains through the tunnel\n'
    fi
    printf 'Tunnel units:        hypraether-vpn@<id>.service (one per connection)\n'
    printf 'CLI:                 hypraether-vpn\n'
    printf 'Watchdog:            vpn-auth-watchdog.service (problem notifications)\n'
    printf '\nNext step — import a connection as your user (NOT root):\n'
    printf '  hypraether-vpn import /path/to/downloaded.ovpn --user MyUser \\\n'
    printf '                     --pass-file ./password.txt\n'
    printf '  hypraether-vpn connect <id>\n'
    printf '\nDomains:             manage in the settings UI, or:\n'
    printf '                     hypraether-vpn domain add|remove <domain>\n'
    printf '                     hypraether-vpn domain list\n'
    printf '\nRoute check:         ip route get 160.79.104.10 mark 0x4555\n'
    printf 'DNS resolver:        cat /etc/resolv.conf  (must contain 127.0.0.1)\n'
    printf '\nSwitch mode later:   sudo /etc/hypraether/vpn/vpn-mode.sh split|full\n'
    printf '\nIMPORTANT: disable DNS-over-HTTPS in your browser so that the local\n'
    printf 'dnsmasq keeps populating the nftables sets (Firefox: Settings > DNS\n'
    printf 'over HTTPS > OFF). Chrome uses the system resolver by default.\n'
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    parse_args "$@"
    need_root
    is_arch_based || die "This installer targets Arch Linux / Arch-based distros only."
    VPN_USER="${VPN_USER:-${SUDO_USER:-}}"
    [[ -n "$VPN_USER" ]] || die "Cannot determine the desktop user (pass --user <name>)."

    install_packages
    install_configs
    install_project_dir
    install_units
    install_polkit
    install_cli
    enable_services
    apply_domains
    print_summary
}

main "$@"
