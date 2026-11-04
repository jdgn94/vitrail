#!/usr/bin/env bash
# Vitrail installer: packages, AUR helpers and dotfiles for Arch Linux.
#
# Pure bash on purpose: a freshly installed Arch system has no Python,
# so the bootstrap must not depend on anything beyond bash + coreutils.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

COMPOSITORS=(hyprland)
COMPOSITOR_LABELS=("Hyprland")
AUR_HELPERS=(yay paru pikaur)
ARCH_LIKE=(arch manjaro endeavouros cachyos garuda artix)

DRY_RUN=0
ASSUME_YES=0
SKIP_PACKAGES=0
HOME_DIR="${HOME}"
SELECTED_COMPOSITORS=()
SELECTED_HELPERS=()
VPN_MODE=""
SELECTED=()

if [[ -t 1 ]]; then
    BOLD=$'\e[1m' DIM=$'\e[2m' RESET=$'\e[0m' ACCENT=$'\e[38;5;110m' RED=$'\e[31m'
else
    BOLD='' DIM='' RESET='' ACCENT='' RED=''
fi

info() { printf '%s\n' "$*"; }
warn() { printf '%s\n' "${RED}!${RESET} $*" >&2; }
die() {
    warn "$*"
    exit 1
}

usage() {
    cat <<'EOF'
Usage: ./install.sh [options]

Runs an interactive installer. Use the arrow keys to move, space to
toggle an option and enter to accept.

Options:
  --compositor NAME   Wayland desktop (repeatable or comma separated)
  --aur NAME          AUR helper to install (repeatable or comma separated)
  --yes, -y           do not prompt; use the flags above
  --dry-run, -n       show the plan without changing anything
  --skip-packages     only link dotfiles
  --vpn MODE          vpn traffic mode: split, full or none (default: ask)
  --root DIR          repository root (default: this script's directory)
  --home DIR          target HOME (default: $HOME)
  -h, --help          show this help
EOF
}

# What this install is: where it came from, which commit, and the choices the
# updater must replay. `vitrail update` reads it.
write_install_state() {
    local folder="${XDG_DATA_HOME:-${HOME}/.local/share}/vitrail"
    local commit="" branch="main" method="copy" version="unknown"
    if git -C "$ROOT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
        commit="$(git -C "$ROOT_DIR" rev-parse HEAD 2>/dev/null || true)"
        branch="$(git -C "$ROOT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
        [[ -n "$branch" ]] || branch="main"
        method="git"
    fi
    # A tree under /usr comes from the package, even if it carries no .git.
    case "$ROOT_DIR" in /usr/*) [[ "$method" == "git" ]] || method="package" ;; esac
    if [[ -f "$ROOT_DIR/pyproject.toml" ]]; then
        version="$(awk -F'"' '/^version[[:space:]]*=/{print $2; exit}' "$ROOT_DIR/pyproject.toml")"
        [[ -n "$version" ]] || version="unknown"
    fi
    mkdir -p -- "$folder"
    printf '{"root":"%s","version":"%s","method":"%s","commit":"%s","branch":"%s","remote":"origin","compositors":"%s","aur":"%s","vpn":"%s","installed":"%s"}\n' \
        "$ROOT_DIR" "$version" "$method" "$commit" "$branch" "${SELECTED_COMPOSITORS[*]}" \
        "${SELECTED_HELPERS[*]}" "$VPN_MODE" "$(date +%Y-%m-%dT%H-%M-%S)" \
        >"$folder/install.json"
}

# ---------------------------------------------------------------- detection

read_package_list() {
    local file="$1" line
    [[ -f "$file" ]] || return 0
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line="${line//[[:space:]]/}"
        if [[ -n "$line" ]]; then
            printf '%s\n' "$line"
        fi
    done <"$file"
}

collect_packages() {
    local root="$1"
    shift
    local compositor
    {
        read_package_list "$root/packages/base.txt"
        for compositor in "$@"; do
            read_package_list "$root/packages/$compositor.txt"
        done
    } | awk '!seen[$0]++'
}

aur_packages() {
    read_package_list "$1/packages/aur.txt"
}

is_arch_like() {
    local id=""
    if [[ -r /etc/os-release ]]; then
        id="$(awk -F= '/^ID=/{gsub(/"/, "", $2); print tolower($2)}' /etc/os-release)"
    fi
    local wanted
    for wanted in "${ARCH_LIKE[@]}"; do
        [[ "$id" == "$wanted" ]] && return 0
    done
    return 1
}

detect_compositor() {
    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || command -v Hyprland >/dev/null 2>&1; then
        printf 'hyprland'
    fi
}

# ---------------------------------------------------------------------- TUI

multiselect() {
    local title="$1"
    shift
    local -a items=("$@")
    local -a state=()
    local cursor=0 index key rest mark eof=0
    for index in "${!items[@]}"; do
        state[index]=0
    done

    printf '\e[?25l' >/dev/tty
    while true; do
        {
            printf '\e[H\e[2J'
            printf '%s%s%s\n\n' "$BOLD" "$title" "$RESET"
            for index in "${!items[@]}"; do
                mark='[ ]'
                if [[ ${state[index]} -eq 1 ]]; then
                    mark='[x]'
                fi
                if [[ $index -eq $cursor ]]; then
                    printf '%s>  %s %s%s\n' "$ACCENT" "$mark" "${items[index]}" "$RESET"
                else
                    printf '   %s %s\n' "$mark" "${items[index]}"
                fi
            done
            printf '\n%s  up/down move · space toggle · enter accept%s\n' "$DIM" "$RESET"
        } >/dev/tty

        if ! IFS= read -rsn1 key </dev/tty; then
            eof=1
            break
        fi
        case "$key" in
            $'\e')
                rest=''
                IFS= read -rsn2 -t 0.05 rest </dev/tty || true
                case "$rest" in
                    '[A') cursor=$(((cursor - 1 + ${#items[@]}) % ${#items[@]})) ;;
                    '[B') cursor=$(((cursor + 1) % ${#items[@]})) ;;
                esac
                ;;
            ' ')
                state[cursor]=$((1 - state[cursor]))
                ;;
            k) cursor=$(((cursor - 1 + ${#items[@]}) % ${#items[@]})) ;;
            j) cursor=$(((cursor + 1) % ${#items[@]})) ;;
            '') break ;;
        esac
    done
    printf '\e[?25h' >/dev/tty

    if [[ $eof -eq 1 ]]; then
        return 1
    fi

    VPN_MODE=""
    SELECTED=()
    for index in "${!items[@]}"; do
        if [[ ${state[index]} -eq 1 ]]; then
            SELECTED+=("${items[index]}")
        fi
    done
}

singleselect() {
    local title="$1"
    shift
    local -a items=("$@")
    local cursor=0 index key rest
    printf '\e[?25l' >/dev/tty
    while true; do
        {
            printf '\e[H\e[2J'
            printf '%s%s%s\n\n' "$BOLD" "$title" "$RESET"
            for index in "${!items[@]}"; do
                if [[ $index -eq $cursor ]]; then
                    printf '%s>  (*) %s%s\n' "$ACCENT" "${items[index]}" "$RESET"
                else
                    printf '   ( ) %s\n' "${items[index]}"
                fi
            done
            printf '\n%s  up/down move · enter accept%s\n' "$DIM" "$RESET"
        } >/dev/tty
        if ! IFS= read -rsn1 key </dev/tty; then
            printf '\e[?25h' >/dev/tty
            return 1
        fi
        case "$key" in
            $'\e')
                rest=''
                IFS= read -rsn2 -t 0.05 rest </dev/tty || true
                case "$rest" in
                    '[A') cursor=$(((cursor - 1 + ${#items[@]}) % ${#items[@]})) ;;
                    '[B') cursor=$(((cursor + 1) % ${#items[@]})) ;;
                esac
                ;;
            k) cursor=$(((cursor - 1 + ${#items[@]}) % ${#items[@]})) ;;
            j) cursor=$(((cursor + 1) % ${#items[@]})) ;;
            '') break ;;
        esac
    done
    printf '\e[?25h' >/dev/tty
    SELECTED=("${items[cursor]}")
}

choose_vpn() {
    [[ -n "$VPN_MODE" ]] && return 0
    if ! singleselect "VPN traffic" \
        "No VPN" \
        "Split tunnel (only the listed domains)" \
        "Full tunnel (everything except the excluded)"; then
        die "no terminal input; use --vpn none"
    fi
    case "${SELECTED[0]}" in
        Split*) VPN_MODE=split ;;
        Full*) VPN_MODE=full ;;
        *) VPN_MODE=none ;;
    esac
}

setup_vpn() {
    [[ "$VPN_MODE" == "none" || -z "$VPN_MODE" ]] && return 0
    [[ -x "$ROOT_DIR/vpn/install.sh" ]] || {
        warn "vpn/install.sh not found; skipping"
        return 0
    }
    run sudo "$ROOT_DIR/vpn/install.sh" --mode "$VPN_MODE"
}

# The VPN's own folders belong to the user: ~/.config/vitrail-vpn holds the
# document (which connections the automatic choice may use) and
# ~/.local/share/vitrail-vpn the OpenVPN files Vitrail copied there. Both 0700,
# files 0600; the migration moves the old misc.ini key out once.
prepare_vpn_storage() {
    local config="${HOME_DIR}/.config/vitrail-vpn" data="${HOME_DIR}/.local/share/vitrail-vpn"
    if [[ $DRY_RUN -eq 1 ]]; then
        printf '  %s$ install -d -m 0700 %s %s%s\n' "$DIM" "$config" "$data" "$RESET"
        return 0
    fi
    install -d -m 0700 "$config" "$data"
    PYTHONPATH="$ROOT_DIR" HOME="$HOME_DIR" XDG_CONFIG_HOME="${HOME_DIR}/.config" \
        env -u XDG_DATA_HOME python3 -m vitrail.cli migrate >/dev/null 2>&1 \
        || warn "could not migrate the VPN settings; the settings window will"
}

confirm() {
    local answer
    printf '%s [y/N] ' "$1"
    if ! IFS= read -r answer </dev/tty; then
        return 1
    fi
    [[ "${answer,,}" == "y" || "${answer,,}" == "yes" ]]
}

lowercase() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

# -------------------------------------------------------------- package set

# Filters a list down to the packages no installed package satisfies.
# `pacman -T` understands "provides", so matugen-bin satisfies matugen and
# the transaction never hits a conflict prompt.
unmet_packages() {
    (($#)) || return 0
    pacman -T "$@" 2>/dev/null || true
}

# ------------------------------------------------------------------- actions

run() {
    if [[ $DRY_RUN -eq 1 ]]; then
        printf '  %s$ %s%s\n' "$DIM" "$*" "$RESET"
        return 0
    fi
    printf '  %s$ %s%s\n' "$DIM" "$*" "$RESET"
    "$@"
}

install_repo_packages() {
    [[ $SKIP_PACKAGES -eq 1 ]] && return 0
    local -a wanted=() missing=()
    mapfile -t wanted < <(collect_packages "$ROOT_DIR" "${SELECTED_COMPOSITORS[@]}")
    [[ ${#wanted[@]} -eq 0 ]] && return 0
    mapfile -t missing < <(unmet_packages "${wanted[@]}")
    if [[ ${#missing[@]} -eq 0 ]]; then
        info "  every package is already satisfied"
        return 0
    fi
    run sudo pacman -S --needed --noconfirm "${missing[@]}"
}

install_helper() {
    local name="$1" tmp
    if pacman -T "$name" >/dev/null 2>&1; then
        info "  ${name} is already satisfied"
        return 0
    fi
    tmp="$(mktemp -d)"
    if ! run git clone --depth=1 "https://aur.archlinux.org/${name}.git" "${tmp}/${name}"; then
        rm -rf -- "$tmp"
        return 1
    fi
    if [[ $DRY_RUN -eq 0 ]]; then
        if ! (cd "${tmp}/${name}" && makepkg -si --noconfirm); then
            rm -rf -- "$tmp"
            return 1
        fi
    fi
    rm -rf -- "$tmp"
}

install_helpers() {
    [[ $SKIP_PACKAGES -eq 1 ]] && return 0
    local helper
    for helper in "${SELECTED_HELPERS[@]}"; do
        install_helper "$helper"
    done
}

first_available_helper() {
    local helper
    for helper in "${SELECTED_HELPERS[@]}"; do
        if command -v "$helper" >/dev/null 2>&1; then
            printf '%s' "$helper"
            return 0
        fi
    done
    return 1
}

install_aur_packages() {
    [[ $SKIP_PACKAGES -eq 1 ]] && return 0
    local -a packages=()
    mapfile -t packages < <(aur_packages "$ROOT_DIR")
    [[ ${#packages[@]} -eq 0 ]] && return 0

    local helper
    if ! helper="$(first_available_helper)"; then
        warn "no AUR helper available for: ${packages[*]}"
        return 1
    fi
    run "$helper" -S --needed --noconfirm "${packages[@]}"
}

# Returns the first symlinked parent directory of a target, if any.
# Linking through a symlinked directory would move files out of whatever repo
# that symlink points at, so the installer refuses instead.
symlink_parent() {
    local path
    path="$(dirname -- "$1")"
    while [[ "$path" != "$HOME_DIR" && "$path" != "/" && "$path" != "." ]]; do
        if [[ -L "$path" ]]; then
            printf '%s' "$path"
            return 0
        fi
        path="$(dirname -- "$path")"
    done
    return 1
}

link_dotfiles() {
    local mode="$1"
    local stamp="$2"
    local dots="${ROOT_DIR}/dots"
    local source relative target backup linked
    local conflicts=0
    local -A announced=()

    [[ -d "$dots" ]] || return 0

    while IFS= read -r -d '' source; do
        relative="${source#"${dots}"/}"
        linked=''
        announced_symlink=''
        case "$relative" in
            */__pycache__/* | *.pyc) continue ;;
        esac
        target="${HOME_DIR}/${relative}"

        if linked="$(symlink_parent "$target")"; then
            # A symlinked ~/.config/<dir> would make the linker write inside
            # whatever repo it points at. Replace the link with a real
            # directory: the target repository keeps every file.
            announced_symlink=1
            if [[ -z "${announced[$linked]:-}" ]]; then
                announced[$linked]=1
                if [[ "$mode" == "plan" ]]; then
                    printf '  %snote: %s is a symlink; it becomes a real directory%s\n' \
                        "$DIM" "$linked" "$RESET"
                else
                    rm -- "$linked"
                    printf '  replaced symlink %s with a real directory\n' "$linked"
                fi
            fi
        fi
        if [[ -L "$target" && "$(readlink -f -- "$target")" == "$(readlink -f -- "$source")" ]]; then
            continue
        fi
        if [[ -d "$target" && ! -L "$target" ]]; then
            warn "conflict: ${target} is a directory; move it away and retry"
            conflicts=1
            continue
        fi
        backup=''
        # After replacing a symlinked parent the old file is gone, so there is
        # nothing to back up.
        if [[ -z "${linked:-}" ]] && [[ -e "$target" || -L "$target" ]]; then
            backup="${ROOT_DIR}/.backup/${stamp}/${relative}"
        fi

        if [[ "$mode" == "plan" ]]; then
            if [[ -n "$backup" ]]; then
                printf '  %s -> %s  %s(backup: %s)%s\n' \
                    "$target" "$relative" "$DIM" "${backup#"${ROOT_DIR}"/}" "$RESET"
            else
                printf '  %s -> %s\n' "$target" "$relative"
            fi
        else
            if [[ -n "$backup" ]]; then
                mkdir -p -- "$(dirname -- "$backup")"
                mv -- "$target" "$backup"
            fi
            mkdir -p -- "$(dirname -- "$target")"
            ln -s -- "$source" "$target"
        fi
    done < <(find "$dots" -type f -print0 | sort -z)

    [[ $conflicts -eq 0 ]]
}

link_binaries() {
    local bin_dir="${HOME_DIR}/.local/bin"
    local name source target
    mkdir -p -- "$bin_dir"
    for name in vitrail-settings vitrail-preview vitrail-bar vitrail-network vitrail-monitors vitrail-capture vitrail-apply-settings hyprland-dialog; do
        case "$name" in
            vitrail-apply-settings) source="$ROOT_DIR/scripts/apply-settings.sh" ;;
            # Ahead of /usr/bin in PATH: Hyprland's dialogs open in the bar.
            hyprland-dialog) source="$ROOT_DIR/scripts/hyprland-dialog.sh" ;;
            *) source="$ROOT_DIR/bin/$name" ;;
        esac
        [[ -f "$source" ]] || continue
        target="$bin_dir/$name"
        if [[ -e "$target" && ! -L "$target" ]]; then
            local backup="$ROOT_DIR/.backup/$(date +%Y-%m-%dT%H-%M-%S)/bin/$name"
            mkdir -p -- "$(dirname -- "$backup")"
            mv -- "$target" "$backup"
        fi
        ln -sfn -- "$source" "$target"
    done
}

# The root helper behind "apply the language to the system". pkexec runs it as
# root, so it is installed root-owned: a file the user can edit must not be one.
install_locale_helper() {
    local source="$ROOT_DIR/scripts/vitrail-locale-helper.sh"
    [[ -f "$source" ]] || return 0
    run sudo install -D -m 0755 -o root -g root "$source" /usr/local/libexec/vitrail-locale-helper \
        || warn "could not install the locale helper; the system language will not be generated"
}

# The brightness slider of the OSD dims external monitors with ddcutil, over
# the i2c buses: it needs the i2c-dev module loaded at boot, a udev rule that
# lets the user open /dev/i2c-*, and membership of the i2c group. A new
# session picks the group up, so the user must log out and back in.
setup_display_control() {
    [[ $SKIP_PACKAGES -eq 1 ]] && return 0
    local system="$ROOT_DIR/scripts/system" user="${SUDO_USER:-${USER:-$(id -un)}}" etc="${ETC_DIR:-/etc}" changed=0
    local -a files=("i2c-dev.conf:$etc/modules-load.d/i2c-dev.conf" "60-ddcutil-i2c.rules:$etc/udev/rules.d/60-ddcutil-i2c.rules")
    local pair
    for pair in "${files[@]}"; do
        if ! cmp -s "$system/${pair%%:*}" "${pair#*:}"; then
            run sudo install -D -m 0644 "$system/${pair%%:*}" "${pair#*:}" \
                || {
                    warn "could not install ${pair#*:}; brightness of external monitors may not work"
                    return 0
                }
            changed=1
        fi
    done
    getent group i2c >/dev/null 2>&1 || run sudo groupadd --system i2c || true
    if ! id -nG "$user" 2>/dev/null | grep -qw i2c; then
        run sudo usermod -aG i2c "$user" || warn "could not add $user to the i2c group"
        changed=1
    fi
    [[ $changed -eq 1 ]] || return 0
    run sudo modprobe i2c-dev || true
    run sudo udevadm control --reload || true
    run sudo udevadm trigger --subsystem-match=i2c-dev || true
    info "  Brightness of external monitors: log out and back in so the i2c access applies."
}

# Copies the bundled wallpapers into the user's library. `vitrail wallpaper
# import` verifies and optimizes them, converts SVGs, never overwrites and skips
# what is already there, so running the installer again adds nothing.
import_wallpapers() {
    local assets="${ROOT_DIR}/assets" kind
    local -a paths=()
    for kind in wallpapers adaptive-wallpapers animation-wallpapers; do
        [[ -d "${assets}/${kind}" ]] && paths+=("${assets}/${kind}")
    done
    [[ ${#paths[@]} -gt 0 ]] || return 0
    if [[ $DRY_RUN -eq 1 ]]; then
        printf '  %s$ vitrail wallpaper import %s%s\n' "$DIM" "${paths[*]}" "$RESET"
        return 0
    fi
    info "Importing wallpapers (videos are re-encoded, this can take a while)..."
    PYTHONPATH="$ROOT_DIR" XDG_CONFIG_HOME="${HOME_DIR}/.config" \
        python3 -m vitrail.cli wallpaper import "${paths[@]}" \
        || warn "could not import the bundled wallpapers; add them from the settings window"
}

# The launcher's file mode (`/`) reads plocate's database; its timer keeps it
# fresh. Without it the launcher falls back to fd.
enable_file_index() {
    [[ $SKIP_PACKAGES -eq 1 ]] && return 0
    run sudo systemctl enable --now plocate-updatedb.timer \
        || warn "could not enable plocate-updatedb.timer; file search falls back to fd"
}

enable_settings_watch() {
    if [[ $EUID -eq 0 ]]; then
        warn "run the installer as your user to enable the settings watcher"
        return 0
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
        printf '  %s$ systemctl --user enable --now vitrail-settings.path%s\n' "$DIM" "$RESET"
        return 0
    fi
    systemctl --user daemon-reload >/dev/null 2>&1 || true
    if ! systemctl --user enable --now vitrail-settings.path >/dev/null 2>&1; then
        warn "could not enable vitrail-settings.path; settings will apply on demand"
    fi
    # A running watcher keeps the files it was started with.
    systemctl --user try-restart vitrail-settings.path >/dev/null 2>&1 || true
}

# The VPN's login rule is a user unit, not the bar: after a login the tunnel
# comes up even if Quickshell never starts, and a shell restart never repeats
# it. The tunnel itself is vitrail-vpn's system unit; this only enables the
# rule. `--vpn none` leaves it off.
enable_vpn_autostart() {
    [[ "$VPN_MODE" == "none" || -z "$VPN_MODE" ]] && return 0
    if [[ $EUID -eq 0 ]]; then
        warn "run the installer as your user to enable the VPN login rule"
        return 0
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
        printf '  %s$ systemctl --user enable vitrail-vpn-autostart.service%s\n' "$DIM" "$RESET"
        return 0
    fi
    systemctl --user daemon-reload >/dev/null 2>&1 || true
    if ! systemctl --user enable vitrail-vpn-autostart.service >/dev/null 2>&1; then
        warn "could not enable vitrail-vpn-autostart.service; connect from the bar after login"
    fi
}

# --------------------------------------------------------------------- flow

choose_compositors() {
    [[ ${#SELECTED_COMPOSITORS[@]} -gt 0 ]] && return 0
    # Only one desktop is supported, so there is nothing to ask.
    if [[ ${#COMPOSITORS[@]} -eq 1 ]]; then
        SELECTED_COMPOSITORS=("${COMPOSITORS[0]}")
        return 0
    fi
    while true; do
        if ! multiselect "Which Wayland desktop(s) will you use?" "${COMPOSITOR_LABELS[@]}"; then
            die "no terminal input; use --yes with --compositor"
        fi
        SELECTED_COMPOSITORS=()
        local label
        for label in "${SELECTED[@]}"; do
            SELECTED_COMPOSITORS+=("$(lowercase "$label")")
        done
        [[ ${#SELECTED_COMPOSITORS[@]} -gt 0 ]] && return 0
        printf '%s  Select at least one option.%s\n' "$RED" "$RESET" >/dev/tty
        sleep 1
    done
}

choose_helpers() {
    [[ ${#SELECTED_HELPERS[@]} -gt 0 ]] && return 0
    if ! multiselect "Which AUR helper(s) do you want?" "${AUR_HELPERS[@]}"; then
        die "no terminal input; use --yes with --aur"
    fi
    SELECTED_HELPERS=()
    local helper
    for helper in "${SELECTED[@]}"; do
        SELECTED_HELPERS+=("$helper")
    done
}

validate_selection() {
    local name
    for name in "${SELECTED_COMPOSITORS[@]}"; do
        local found=0 candidate
        for candidate in "${COMPOSITORS[@]}"; do
            [[ "$name" == "$candidate" ]] && found=1
        done
        [[ $found -eq 1 ]] || die "unknown compositor: ${name}"
    done
    for name in "${SELECTED_HELPERS[@]}"; do
        local found=0 candidate
        for candidate in "${AUR_HELPERS[@]}"; do
            [[ "$name" == "$candidate" ]] && found=1
        done
        [[ $found -eq 1 ]] || die "unknown AUR helper: ${name}"
    done
}

show_summary() {
    local -a packages=() missing=() aur=()
    mapfile -t packages < <(collect_packages "$ROOT_DIR" "${SELECTED_COMPOSITORS[@]}")
    mapfile -t missing < <(unmet_packages "${packages[@]}")
    mapfile -t aur < <(aur_packages "$ROOT_DIR")

    local labels=''
    local name
    for name in "${SELECTED_COMPOSITORS[@]}"; do
        labels+="${labels:+, }${name}"
    done

    info ""
    info "${BOLD}Summary${RESET} · ${labels}"
    info ""
    if [[ $SKIP_PACKAGES -eq 1 ]]; then
        info "Official packages: skipped"
    else
        info "Official packages: ${#packages[@]} (missing here: ${#missing[@]})"
        info "${DIM}  the manifest is the same on a clean system; pacman skips what is present${RESET}"
    fi
    info "AUR helpers: ${SELECTED_HELPERS[*]:-none}"
    info "VPN: ${VPN_MODE}"
    if [[ ${#aur[@]} -gt 0 ]]; then
        info "AUR packages: ${aur[*]}"
    fi
    info ""
    info "Dotfiles in ${HOME_DIR}:"
    if ! link_dotfiles plan "$(date +%Y-%m-%dT%H-%M-%S)"; then
        die "resolve the conflicts above and run again"
    fi
}

main() {
    while (($#)); do
        case "$1" in
            --compositor)
                IFS=',' read -r -a parts <<<"${2:?--compositor needs a value}"
                SELECTED_COMPOSITORS+=("${parts[@]}")
                shift 2
                ;;
            --aur)
                IFS=',' read -r -a parts <<<"${2:?--aur needs a value}"
                SELECTED_HELPERS+=("${parts[@]}")
                shift 2
                ;;
            --yes | -y)
                ASSUME_YES=1
                shift
                ;;
            --dry-run | -n)
                DRY_RUN=1
                shift
                ;;
            --skip-packages)
                SKIP_PACKAGES=1
                shift
                ;;
            --vpn)
                VPN_MODE="${2:?--vpn needs a value}"
                case "$VPN_MODE" in
                    split | full | none) ;;
                    *) die "invalid --vpn mode: $VPN_MODE (split, full, none)" ;;
                esac
                shift 2
                ;;
            --root)
                ROOT_DIR="${2:?--root needs a value}"
                shift 2
                ;;
            --home)
                HOME_DIR="${2:?--home needs a value}"
                shift 2
                ;;
            -h | --help)
                usage
                exit 0
                ;;
            *)
                usage >&2
                die "unknown option: $1"
                ;;
        esac
    done

    is_arch_like || die "Vitrail needs Arch Linux or a derivative."

    if [[ $ASSUME_YES -eq 0 ]]; then
        [[ -r /dev/tty ]] || die "no terminal available; use --yes with --compositor"
        choose_compositors
        choose_helpers
        choose_vpn
    elif [[ ${#SELECTED_COMPOSITORS[@]} -eq 0 ]]; then
        SELECTED_COMPOSITORS=("$(detect_compositor)")
        [[ -n "${SELECTED_COMPOSITORS[0]}" ]] || SELECTED_COMPOSITORS=(hyprland)
    fi

    [[ -z "$VPN_MODE" ]] && VPN_MODE="none"

    validate_selection

    show_summary

    if [[ $DRY_RUN -eq 1 ]]; then
        info ""
        info "Dry run: nothing was changed."
        exit 0
    fi

    if [[ $ASSUME_YES -eq 0 ]] && ! confirm "Apply this installation?"; then
        info "Cancelled: nothing was changed."
        exit 0
    fi

    info ""
    install_repo_packages
    install_helpers
    install_aur_packages
    if ! link_dotfiles apply "$(date +%Y-%m-%dT%H-%M-%S)"; then
        die "some dotfiles could not be linked"
    fi
    link_binaries
    install_locale_helper
    import_wallpapers
    enable_file_index
    setup_display_control
    enable_settings_watch
    prepare_vpn_storage
    setup_vpn
    enable_vpn_autostart
    write_install_state

    info ""
    info "Done."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
