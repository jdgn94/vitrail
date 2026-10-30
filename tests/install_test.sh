#!/usr/bin/env bash
# Tests for the bash installer. Run with: bash tests/install_test.sh

set -uo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../install.sh
source "$REPO/install.sh"
# shellcheck source=../scripts/lib/ini.sh
source "$REPO/scripts/lib/ini.sh"

pass=0
fail=0

ok() {
    printf 'ok - %s\n' "$1"
    pass=$((pass + 1))
}

not_ok() {
    printf 'not ok - %s\n' "$1"
    shift
    printf '  %s\n' "$@"
    fail=$((fail + 1))
}

expect_eq() {
    local name="$1" want="$2" got="$3"
    if [[ "$want" == "$got" ]]; then
        ok "$name"
    else
        not_ok "$name" "want: $want" "got:  $got"
    fi
}

sandbox() {
    mktemp -d
}

# ------------------------------------------------------------ package lists

tmp="$(sandbox)"
printf '# comment\ngit\n\nzsh   \nfoo # inline\n' >"$tmp/list.txt"
mapfile -t got < <(read_package_list "$tmp/list.txt")
expect_eq "read_package_list strips comments and blanks" "git zsh foo" "${got[*]}"

mapfile -t got < <(read_package_list "$tmp/missing.txt")
expect_eq "missing list yields nothing" "0" "${#got[@]}"

mkdir -p "$tmp/repo/packages"
printf 'git\nqt6-wayland\n' >"$tmp/repo/packages/base.txt"
printf 'hyprland\nqt6-wayland\n' >"$tmp/repo/packages/hyprland.txt"
printf 'niri\n' >"$tmp/repo/packages/niri.txt"
mapfile -t got < <(collect_packages "$tmp/repo" hyprland niri)
expect_eq "collect_packages merges and dedupes" "git qt6-wayland hyprland niri" "${got[*]}"

fakebin="$tmp/fakebin"
mkdir -p "$fakebin"
cat >"$fakebin/pacman" <<'STUB'
#!/usr/bin/env bash
# Stub of `pacman -T`: "matugen" is satisfied by an installed provider.
shift
for name in "$@"; do
    [[ "$name" == "matugen" ]] || printf '%s\n' "$name"
done
STUB
chmod +x "$fakebin/pacman"

saved_path="$PATH"
PATH="$fakebin:$PATH"
expect_eq "unmet_packages skips providers" "git zsh" "$(unmet_packages matugen git zsh | paste -sd' ' -)"
expect_eq "unmet_packages accepts no packages" "" "$(unmet_packages)"
PATH="$saved_path"

expect_eq "aur_packages reads aur.txt" "0" "$(aur_packages "$tmp/repo" | wc -l)"

# ------------------------------------------------------------ shell helpers

expect_eq "lowercase handles mixed case" "hyprland" "$(lowercase "HyprLand")"

# read_ini must accept both "key=value" and "key = value" (configparser writes
# the latter, QSettings the former).
mkdir -p "$tmp/cfg/vitrail"
printf '[appearance]\nvisibleColumns = 3\nradius=9\n' >"$tmp/cfg/vitrail/settings.ini"
CONFIG="$tmp/cfg/vitrail/settings.ini"
expect_eq "read_ini reads spaced values" "3" "$(read_ini visibleColumns 2)"
expect_eq "read_ini reads compact values" "9" "$(read_ini radius 14)"

# --------------------------------------------------------------- dotfiles

home="$tmp/home"
repo="$tmp/dotrepo"
mkdir -p "$home" "$repo/dots/.config/vitrail"
printf 'export EDITOR=nvim\n' >"$repo/dots/.zshrc"
printf 'theme=tonal\n' >"$repo/dots/.config/vitrail/config"
printf 'previous\n' >"$home/.zshrc"

ROOT_DIR="$repo"
HOME_DIR="$home"

plan="$(link_dotfiles plan 2026-01-01T00-00-00)"
if [[ -L "$home/.zshrc" ]]; then
    not_ok "plan does not create links"
else
    ok "plan does not create links"
fi
case "$plan" in
    *"/.zshrc -> .zshrc"*"(backup:"*) ok "plan reports the pending backup" ;;
    *) not_ok "plan reports the pending backup" "output: $plan" ;;
esac

link_dotfiles apply 2026-01-01T00-00-00 >/dev/null
if [[ -L "$home/.zshrc" && "$(readlink -f "$home/.zshrc")" == "$(readlink -f "$repo/dots/.zshrc")" ]]; then
    ok "apply creates the symlink"
else
    not_ok "apply creates the symlink"
fi
if [[ "$(cat "$repo/.backup/2026-01-01T00-00-00/.zshrc" 2>/dev/null)" == "previous" ]]; then
    ok "apply preserves the previous file"
else
    not_ok "apply preserves the previous file"
fi

link_dotfiles apply 2026-01-02T00-00-00 >/dev/null
count="$(find "$repo/.backup" -mindepth 1 -maxdepth 1 -type d | wc -l)"
expect_eq "applying twice is idempotent" "1" "$count"

mkdir -p "$home/.config/vitrail"
printf 'user dir\n' >"$home/.config/vitrail/config"
printf 'blocked\n' >"$repo/dots/.config/blocked.conf"
mkdir -p "$home/.config/blocked.conf"
if link_dotfiles apply 2026-01-03T00-00-00 >/dev/null 2>&1; then
    not_ok "directory conflict fails"
else
    ok "directory conflict fails"
fi

# A symlinked config directory is replaced by a real one, not linked through.
target_dir="$tmp/elsewhere"
mkdir -p "$target_dir" "$tmp/home2/.config"
printf 'keep me\n' >"$target_dir/file.conf"
ln -sfn "$target_dir" "$tmp/home2/.config/confdir"
mkdir -p "$tmp/repo2/dots/.config/confdir"
printf 'new\n' >"$tmp/repo2/dots/.config/confdir/file.conf"
ROOT_DIR="$tmp/repo2"
HOME_DIR="$tmp/home2"
link_dotfiles apply 2026-02-02T00-00-00 >/dev/null 2>&1
if [[ -d "$tmp/home2/.config/confdir" && ! -L "$tmp/home2/.config/confdir" ]] \
    && [[ -L "$tmp/home2/.config/confdir/file.conf" ]] \
    && [[ -f "$target_dir/file.conf" ]]; then
    ok "symlinked directory becomes a real one"
else
    not_ok "symlinked directory becomes a real one"
fi
ROOT_DIR="$REPO"
HOME_DIR="$tmp/home"

# The systemd unit runs the script through a symlink; it must still find its lib.
ln -sfn "$REPO/scripts/apply-settings.sh" "$tmp/vitrail-apply-settings"
mkdir -p "$tmp/home/vitrail"
printf '[appearance]\nopacityFocused=0.9\nopacityUnfocused=0.7\n' >"$tmp/home/vitrail/settings.ini"
if env -u HYPRLAND_INSTANCE_SIGNATURE XDG_CONFIG_HOME="$tmp/home" HOME="$tmp" \
    bash "$tmp/vitrail-apply-settings" >/dev/null 2>&1; then
    ok "apply-settings works through a symlink"
else
    not_ok "apply-settings works through a symlink"
fi

# The terminal files are generated from settings.ini, outside the repository.
mkdir -p "$tmp/term/vitrail"
printf '[appearance]\ntabStyle=tonal\ntabIcons=false\ntabNumbers=true\nterminalScheme=light\nfontSize=16\nterminalPadding=8\n' \
    >"$tmp/term/vitrail/settings.ini"
env -u HYPRLAND_INSTANCE_SIGNATURE XDG_CONFIG_HOME="$tmp/term" \
    bash "$REPO/scripts/apply-settings.sh" >/dev/null 2>&1
if grep -qx 'tabStyle=tonal' "$tmp/term/vitrail/header.conf" \
    && grep -qx 'tabIcons=0' "$tmp/term/vitrail/header.conf" \
    && grep -qx 'font_size 16' "$tmp/term/vitrail/kitty-user.conf"; then
    ok "terminal config is generated from settings"
else
    not_ok "terminal config is generated from settings"
fi

# Launchers are executed through ~/.local/bin symlinks; they must find the repo.
fakebin="$tmp/fakebin2"
mkdir -p "$fakebin"
printf '#!/bin/sh\nexit 0\n' >"$fakebin/qml6"
chmod +x "$fakebin/qml6"
for launcher in vitrail-settings vitrail-preview; do
    ln -sfn "$REPO/bin/$launcher" "$tmp/$launcher-link"
    if PATH="$fakebin:$PATH" XDG_CONFIG_HOME="$tmp/cfg2" \
        "$tmp/$launcher-link" >/dev/null 2>&1; then
        ok "$launcher works through a symlink"
    else
        not_ok "$launcher works through a symlink"
    fi
done

# A leftover symlink from an old install must not break the generated files.
mkdir -p "$tmp/term2/vitrail"
printf '[appearance]\ntabStyle=tonal\n' >"$tmp/term2/vitrail/settings.ini"
ln -sfn "$tmp/does-not-exist.conf" "$tmp/term2/vitrail/header.conf"
if env -u HYPRLAND_INSTANCE_SIGNATURE XDG_CONFIG_HOME="$tmp/term2" \
    bash "$REPO/scripts/apply-settings.sh" >/dev/null 2>&1 \
    && [[ -f "$tmp/term2/vitrail/header.conf" && ! -L "$tmp/term2/vitrail/header.conf" ]]; then
    ok "dangling header.conf symlink is replaced"
else
    not_ok "dangling header.conf symlink is replaced"
fi

# ------------------------------------------------------------- validation

if (SELECTED_COMPOSITORS=(sway); validate_selection) >/dev/null 2>&1; then
    not_ok "validate_selection rejects unknown compositors"
else
    ok "validate_selection rejects unknown compositors"
fi

if (SELECTED_HELPERS=(yay); validate_selection) >/dev/null 2>&1; then
    ok "validate_selection accepts known helpers"
else
    not_ok "validate_selection accepts known helpers"
fi

rm -rf "$tmp"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
