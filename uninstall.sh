#!/usr/bin/env bash
# Removes what the installer linked into this home. It never deletes a file
# that does not point into the install, and keeps the settings unless --purge.
set -euo pipefail

HERE="$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd)"
HOME_DIR="${HOME}"
ROOT=""
PURGE=0
PACKAGES=0
DRY_RUN=0

usage() {
    cat <<'USAGE'
Usage: ./uninstall.sh [options]

Options:
  --root DIR      install root (default: the one in install.json)
  --home DIR      target HOME (default: $HOME)
  --purge         move ~/.config/vitrail* into a backup folder
  --packages      list the packages the manifest installed (does not remove)
  --dry-run, -n   show what would be removed
  -h, --help      show this help
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --root)
            ROOT="${2:?--root needs a value}"
            shift 2
            ;;
        --home)
            HOME_DIR="${2:?--home needs a value}"
            shift 2
            ;;
        --purge)
            PURGE=1
            shift
            ;;
        --packages)
            PACKAGES=1
            shift
            ;;
        --dry-run | -n)
            DRY_RUN=1
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            printf 'uninstall: unknown option: %s\n' "$1" >&2
            exit 2
            ;;
    esac
done

if [[ -z "$ROOT" ]]; then
    state="${XDG_DATA_HOME:-${HOME_DIR}/.local/share}/vitrail/install.json"
    if [[ -r "$state" ]]; then
        ROOT="$(sed -n 's/.*"root":"\([^"]*\)".*/\1/p' "$state")"
    fi
fi
[[ -n "$ROOT" ]] || {
    printf 'uninstall: no install record; pass --root\n' >&2
    exit 1
}

say() { printf '%s\n' "$*"; }
remove_link() {
    local target="$1"
    [[ -L "$target" ]] || return 0
    local resolved
    resolved="$(readlink -f -- "$target" 2>/dev/null || true)"
    [[ "$resolved" == "${ROOT}/"* ]] || return 0
    if [[ $DRY_RUN -eq 1 ]]; then
        say "would remove $target"
    else
        rm -- "$target"
        say "removed $target"
    fi
}

if [[ $PACKAGES -eq 1 ]]; then
    for manifest in "${ROOT}/packages/base.txt" "${ROOT}/packages/hyprland.txt" \
        "${ROOT}/packages/aur.txt"; do
        [[ -r "$manifest" ]] || continue
        sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$manifest"
    done | sort -u
    exit 0
fi

# Dotfiles: same walk as link_dotfiles, removing only links into the root.
if [[ -d "${ROOT}/dots" ]]; then
    while IFS= read -r -d '' source; do
        relative="${source#"${ROOT}/dots"/}"
        remove_link "${HOME_DIR}/${relative}"
    done < <(find "${ROOT}/dots" -type f -print0)
fi

bin_dir="${HOME_DIR}/.local/bin"
for name in vitrail vitrail-install vitrail-settings vitrail-preview vitrail-bar \
    vitrail-network vitrail-monitors vitrail-capture vitrail-apply-settings hyprland-dialog; do
    remove_link "${bin_dir}/${name}"
done

# Units enabled by the installer.
if command -v systemctl >/dev/null 2>&1; then
    for unit in vitrail-settings.path vitrail-settings.service vitrail-vpn-autostart.service; do
        if systemctl --user list-unit-files "$unit" >/dev/null 2>&1; then
            if [[ $DRY_RUN -eq 1 ]]; then
                say "would disable $unit"
            else
                systemctl --user disable --now "$unit" >/dev/null 2>&1 || true
                say "disabled $unit"
            fi
        fi
    done
fi

if [[ $PURGE -eq 1 ]]; then
    stamp="$(date +%Y-%m-%dT%H-%M-%S)"
    backup="${HOME_DIR}/.local/share/vitrail-backup-${stamp}"
    mkdir -p -- "$backup"
    for folder in "${HOME_DIR}/.config/vitrail" "${HOME_DIR}/.config/vitrail-vpn"; do
        [[ -d "$folder" ]] || continue
        if [[ $DRY_RUN -eq 1 ]]; then
            say "would move $folder to $backup/"
        else
            mv -- "$folder" "$backup/"
            say "moved $folder to $backup/"
        fi
    done
fi

say "Vitrail's links are gone. The checkout stays at ${ROOT}; remove it when you like."
