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
mapfile -t got < <(GPU_VENDOR=none collect_packages "$tmp/repo" hyprland niri)
expect_eq "collect_packages merges and dedupes" "git qt6-wayland hyprland niri mesa" "${got[*]}"

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

# read_ini finds a key's file through vitrail/prefs.map, and must accept both
# "key=value" and "key = value" (configparser writes the latter, QSettings the
# former).
mkdir -p "$tmp/cfg/vitrail"
printf '[windows]\nvisibleColumns = 3\n' >"$tmp/cfg/vitrail/windows.ini"
printf '[appearance]\nradius=9\n; radius=1\n' >"$tmp/cfg/vitrail/appearance.ini"
printf '[misc]\nfuture=7\n' >"$tmp/cfg/vitrail/misc.ini"
CONFIG_DIR="$tmp/cfg/vitrail"
expect_eq "read_ini reads spaced values" "3" "$(read_ini visibleColumns 2)"
expect_eq "read_ini reads compact values" "9" "$(read_ini radius 14)"
expect_eq "read_ini reads unmapped keys from misc.ini" "7" "$(read_ini future 0)"
expect_eq "read_ini falls back on a missing key" "6" "$(read_ini blurStrength 6)"
expect_eq "read_ini ignores a key in the wrong file" "14" "$(read_ini spacing 14)"
printf '[appearance]\nvisibleColumns=5\n' >>"$tmp/cfg/vitrail/appearance.ini"
expect_eq "read_ini only looks in the key's own file" "3" "$(read_ini visibleColumns 2)"

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
printf '[windows]\nopacityFocused=0.9\nopacityUnfocused=0.7\n' >"$tmp/home/vitrail/windows.ini"
if env -u HYPRLAND_INSTANCE_SIGNATURE XDG_CONFIG_HOME="$tmp/home" HOME="$tmp" \
    bash "$tmp/vitrail-apply-settings" >/dev/null 2>&1; then
    ok "apply-settings works through a symlink"
else
    not_ok "apply-settings works through a symlink"
fi

# The terminal files are generated from terminal.ini, outside the repository.
mkdir -p "$tmp/term/vitrail"
printf '[terminal]\ntabStyle=tonal\ntabIcons=false\ntabNumbers=true\nterminalScheme=light\nfontSize=16\nterminalPadding=8\n' \
    >"$tmp/term/vitrail/terminal.ini"
env -u HYPRLAND_INSTANCE_SIGNATURE XDG_CONFIG_HOME="$tmp/term" \
    bash "$REPO/scripts/apply-settings.sh" >/dev/null 2>&1
if grep -qx 'tabStyle=tonal' "$tmp/term/vitrail/header.conf" \
    && grep -qx 'tabIcons=0' "$tmp/term/vitrail/header.conf" \
    && grep -qx 'font_size 16' "$tmp/term/vitrail/kitty-user.conf"; then
    ok "terminal config is generated from settings"
else
    not_ok "terminal config is generated from settings"
fi

# A settings.ini from before the split is divided into one file per area
# before anything is read, and the terminal files still follow its values.
mkdir -p "$tmp/legacy/vitrail"
printf '[appearance]\ntabStyle=tonal\nradius=9\nfuture=1\n' >"$tmp/legacy/vitrail/settings.ini"
env -u HYPRLAND_INSTANCE_SIGNATURE XDG_CONFIG_HOME="$tmp/legacy" \
    bash "$REPO/scripts/apply-settings.sh" >/dev/null 2>&1
if grep -qx 'tabStyle=tonal' "$tmp/legacy/vitrail/terminal.ini" \
    && grep -qx 'radius=9' "$tmp/legacy/vitrail/appearance.ini" \
    && grep -qx 'future=1' "$tmp/legacy/vitrail/misc.ini" \
    && [[ ! -e "$tmp/legacy/vitrail/settings.ini" ]] \
    && [[ -f "$tmp/legacy/vitrail/settings.ini.before-split" ]] \
    && grep -qx 'tabStyle=tonal' "$tmp/legacy/vitrail/header.conf"; then
    ok "apply-settings splits a legacy settings.ini"
else
    not_ok "apply-settings splits a legacy settings.ini"
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
printf '[terminal]\ntabStyle=tonal\n' >"$tmp/term2/vitrail/terminal.ini"
ln -sfn "$tmp/does-not-exist.conf" "$tmp/term2/vitrail/header.conf"
if env -u HYPRLAND_INSTANCE_SIGNATURE XDG_CONFIG_HOME="$tmp/term2" \
    bash "$REPO/scripts/apply-settings.sh" >/dev/null 2>&1 \
    && [[ -f "$tmp/term2/vitrail/header.conf" && ! -L "$tmp/term2/vitrail/header.conf" ]]; then
    ok "dangling header.conf symlink is replaced"
else
    not_ok "dangling header.conf symlink is replaced"
fi

# ------------------------------------------------------------ optional assets

# The repository carries optional assets and the user chooses which groups to
# install. Wallpapers go through `vitrail wallpaper import`; a cursor or icon
# pack is validated and copied into ~/.local/share/icons, with a backup when a
# theme of the same name is already there.
tmp="$(sandbox)"
mkdir -p "$tmp/bin" "$tmp/home" \
    "$tmp/repo/assets/wallpapers" \
    "$tmp/repo/assets/adaptive-wallpapers" \
    "$tmp/repo/assets/animation-wallpapers" \
    "$tmp/repo/assets/cursors/TestCursors/cursors" \
    "$tmp/repo/assets/cursors/EmptyCursor" \
    "$tmp/repo/assets/cursors/MaterialDesign-Light/cursors" \
    "$tmp/repo/assets/cursors/MaterialDesign-Dark/cursors" \
    "$tmp/repo/assets/cursors/material-design/source" \
    "$tmp/repo/assets/icons/TestIcons/48x48/apps" \
    "$tmp/repo/assets/icons/NoIndex" \
    "$tmp/repo/assets/icons/Empty"
printf '[Icon Theme]\nName=Vitrail test cursor\n' \
    >"$tmp/repo/assets/cursors/TestCursors/index.theme"
printf 'Xcur' >"$tmp/repo/assets/cursors/TestCursors/cursors/left_ptr"
for theme in MaterialDesign-Light MaterialDesign-Dark; do
    printf '[Icon Theme]\nName=%s\n' "$theme" >"$tmp/repo/assets/cursors/$theme/index.theme"
    printf 'Xcur' >"$tmp/repo/assets/cursors/$theme/cursors/left_ptr"
done
touch "$tmp/repo/assets/cursors/material-design/.vitrail-source"
printf '[Icon Theme]\nName=No cursors\n' >"$tmp/repo/assets/cursors/EmptyCursor/index.theme"
printf '[Icon Theme]\nName=Vitrail test icons\nDirectories=48x48/apps\n' \
    >"$tmp/repo/assets/icons/TestIcons/index.theme"
printf '<svg/>' >"$tmp/repo/assets/icons/TestIcons/48x48/apps/app.svg"
printf '[Icon Theme]\nName=No icons\n' >"$tmp/repo/assets/icons/Empty/index.theme"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$XDG_CONFIG_HOME|$*" >>"%s/calls"\n' "$tmp" >"$tmp/bin/python3"
chmod +x "$tmp/bin/python3"
ROOT_DIR="$tmp/repo"
HOME_DIR="$tmp/home"

ASSET_SELECTION=""
parse_assets "$ASSET_SELECTION"
expect_eq "no --assets keeps the wallpaper folders" "images animated adaptive" "${SELECTED_ASSETS[*]}"

parse_assets "images,animated,adaptive,cursors,icons"
expect_eq "--assets selects every group in order" "images animated adaptive cursors icons" \
    "${SELECTED_ASSETS[*]}"
parse_assets "cursors,icons,images,cursors"
expect_eq "--assets deduplicates groups" "cursors icons images" "${SELECTED_ASSETS[*]}"
parse_assets "none"
expect_eq "--assets=none selects nothing" "0" "${#SELECTED_ASSETS[@]}"
if (parse_assets "fonts" 2>"$tmp/unknown.err") >/dev/null; then
    not_ok "an unknown asset group is rejected"
else
    grep -q "unknown asset group: fonts" "$tmp/unknown.err" \
        && ok "an unknown asset group is rejected" \
        || not_ok "an unknown asset group is rejected" "output: $(cat "$tmp/unknown.err")"
fi

parse_assets "images"
PATH="$tmp/bin:$PATH" import_assets >/dev/null
expect_eq "selected wallpapers go through the CLI" \
    "$tmp/home/.config|-m vitrail.cli wallpaper import $tmp/repo/assets/wallpapers" \
    "$(cat "$tmp/calls")"
rm -f "$tmp/calls"
parse_assets "adaptive,animated"
PATH="$tmp/bin:$PATH" import_assets >/dev/null
expect_eq "only the selected wallpaper groups are imported" \
    "$tmp/home/.config|-m vitrail.cli wallpaper import $tmp/repo/assets/adaptive-wallpapers $tmp/repo/assets/animation-wallpapers" \
    "$(cat "$tmp/calls")"
rm -f "$tmp/calls"

parse_assets "cursors"
PATH="$tmp/bin:$PATH" import_assets >/dev/null 2>"$tmp/cursors.err"
[[ -f "$tmp/home/.local/share/icons/TestCursors/index.theme" &&
    -f "$tmp/home/.local/share/icons/TestCursors/cursors/left_ptr" ]] \
    && ok "a cursor pack is copied with its tree" \
    || not_ok "a cursor pack is copied with its tree" "output: $(cat "$tmp/cursors.err")"
for theme in MaterialDesign-Light MaterialDesign-Dark; do
    [[ -f "$tmp/home/.local/share/icons/$theme/index.theme" &&
        -f "$tmp/home/.local/share/icons/$theme/cursors/left_ptr" ]] \
        && ok "the $theme cursor theme is installed" \
        || not_ok "the $theme cursor theme is installed" "output: $(cat "$tmp/cursors.err")"
done
[[ ! -e "$tmp/home/.local/share/icons/material-design" ]] \
    && ok "a .vitrail-source folder is not installed as a theme" \
    || not_ok "a .vitrail-source folder is not installed as a theme"
grep -q "material-design" "$tmp/cursors.err" \
    && not_ok "a .vitrail-source folder is not reported as a bad pack" "output: $(cat "$tmp/cursors.err")" \
    || ok "a .vitrail-source folder is not reported as a bad pack"
grep -q "cursor pack EmptyCursor: no cursors/ folder" "$tmp/cursors.err" \
    && ok "a cursor pack without cursors/ is reported" \
    || not_ok "a cursor pack without cursors/ is reported" "output: $(cat "$tmp/cursors.err")"
[[ ! -e "$tmp/home/.local/share/icons/EmptyCursor" ]] \
    && ok "an invalid cursor pack is not installed" \
    || not_ok "an invalid cursor pack is not installed"
[[ ! -e "$tmp/home/.local/share/icons/TestIcons" && ! -e "$tmp/calls" ]] \
    && ok "unselected cursor imports leave the icons and wallpapers alone" \
    || not_ok "unselected cursor imports leave the icons and wallpapers alone"

parse_assets "icons"
PATH="$tmp/bin:$PATH" import_assets >/dev/null 2>"$tmp/icons.err"
[[ -f "$tmp/home/.local/share/icons/TestIcons/48x48/apps/app.svg" ]] \
    && ok "an icon pack is copied with its tree" \
    || not_ok "an icon pack is copied with its tree" "output: $(cat "$tmp/icons.err")"
grep -q "icon pack NoIndex: no index.theme" "$tmp/icons.err" \
    && ok "a pack without index.theme is reported" \
    || not_ok "a pack without index.theme is reported" "output: $(cat "$tmp/icons.err")"
grep -q "icon pack Empty: no icon files" "$tmp/icons.err" \
    && ok "a pack without icons is reported" \
    || not_ok "a pack without icons is reported" "output: $(cat "$tmp/icons.err")"
[[ ! -e "$tmp/home/.local/share/icons/NoIndex" && ! -e "$tmp/home/.local/share/icons/Empty" ]] \
    && ok "invalid packs are not installed" \
    || not_ok "invalid packs are not installed"

printf 'user copy\n' >"$tmp/home/.local/share/icons/TestCursors/local-note"
parse_assets "cursors"
PATH="$tmp/bin:$PATH" import_assets >/dev/null 2>&1
backup="$(find "$tmp/home/.local/share/icons/.vitrail-backups" -type f -name local-note 2>/dev/null | head -1)"
if [[ -n "$backup" ]] && grep -q "user copy" "$backup" \
    && [[ -f "$tmp/home/.local/share/icons/TestCursors/index.theme" ]]; then
    ok "an existing theme is backed up instead of being overwritten"
else
    not_ok "an existing theme is backed up instead of being overwritten"
fi

rm -rf "$tmp/home/.local/share/icons"
rm -f "$tmp/calls"
parse_assets "images,cursors"
plan="$(DRY_RUN=1 import_assets)"
DRY_RUN=0
if [[ ! -e "$tmp/home/.local/share/icons" && ! -e "$tmp/calls" ]] \
    && [[ "$plan" == *"vitrail wallpaper import"* && "$plan" == *"cp -a"* ]]; then
    ok "--dry-run prints the asset plan and copies nothing"
else
    not_ok "--dry-run prints the asset plan and copies nothing" "output: $plan"
fi

rm -rf "$tmp/home/.local/share/icons"
rm -f "$tmp/calls"
parse_assets "none"
PATH="$tmp/bin:$PATH" import_assets >/dev/null 2>&1
[[ ! -e "$tmp/home/.local/share/icons" && ! -e "$tmp/calls" ]] \
    && ok "--assets=none copies no assets" \
    || not_ok "--assets=none copies no assets"

ROOT_DIR="$REPO"
HOME_DIR="$tmp/home"
rm -rf "$tmp"

# ------------------------------------------------------------ locale helper

# The helper runs as root through pkexec: it is copied root-owned, never linked.
ROOT_DIR="$REPO"
DRY_RUN=1
expect_eq "install_locale_helper installs a root-owned copy" \
    "sudo install -D -m 0755 -o root -g root $REPO/scripts/vitrail-locale-helper.sh /usr/local/libexec/vitrail-locale-helper" \
    "$(install_locale_helper | sed -e 's/\x1b\[[0-9;]*m//g' -e 's/^ *\$ //')"
DRY_RUN=0

# ---------------------------------------------------------- file search index

# The launcher's file mode reads plocate's database; its timer keeps it fresh.
tmp="$(sandbox)"
mkdir -p "$tmp/bin"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >>"%s/calls"\n' "$tmp" >"$tmp/bin/sudo"
chmod +x "$tmp/bin/sudo"
PATH="$tmp/bin:$PATH" enable_file_index >/dev/null
expect_eq "enable_file_index turns the plocate timer on" \
    "systemctl enable --now plocate-updatedb.timer" "$(cat "$tmp/calls")"
rm -f "$tmp/calls"
SKIP_PACKAGES=1 PATH="$tmp/bin:$PATH" enable_file_index >/dev/null
[[ ! -e "$tmp/calls" ]] && ok "enable_file_index is skipped with --skip-packages" \
    || not_ok "enable_file_index is skipped with --skip-packages"
SKIP_PACKAGES=0
rm -rf "$tmp"

# ------------------------------------------------------- display control

# External monitors are dimmed over i2c: module at boot, udev rule, i2c group.
tmp="$(sandbox)"
mkdir -p "$tmp/bin"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >>"%s/calls"\n' "$tmp" >"$tmp/bin/sudo"
chmod +x "$tmp/bin/sudo"
ROOT_DIR="$REPO"
ETC_DIR="$tmp/etc" SUDO_USER="nobody-vitrail" PATH="$tmp/bin:$PATH" setup_display_control >/dev/null
calls="$(cat "$tmp/calls")"
expect_eq "setup_display_control loads i2c-dev at boot" "1" \
    "$(grep -c "^install -D -m 0644 $REPO/scripts/system/i2c-dev.conf $tmp/etc/modules-load.d/i2c-dev.conf\$" <<<"$calls")"
expect_eq "setup_display_control installs the udev rule" "1" \
    "$(grep -c "^install -D -m 0644 $REPO/scripts/system/60-ddcutil-i2c.rules $tmp/etc/udev/rules.d/60-ddcutil-i2c.rules\$" <<<"$calls")"
expect_eq "setup_display_control adds the user to the i2c group" "1" \
    "$(grep -c '^usermod -aG i2c nobody-vitrail$' <<<"$calls")"
expect_eq "setup_display_control reloads udev" "1" "$(grep -c '^udevadm control --reload$' <<<"$calls")"
rm -f "$tmp/calls"
ETC_DIR="$tmp/etc" SKIP_PACKAGES=1 PATH="$tmp/bin:$PATH" setup_display_control >/dev/null
[[ ! -e "$tmp/calls" ]] && ok "setup_display_control is skipped with --skip-packages" \
    || not_ok "setup_display_control is skipped with --skip-packages"
SKIP_PACKAGES=0
rm -rf "$tmp"

# ------------------------------------------------------- VPN login rule unit

tmp="$(sandbox)"
mkdir -p "$tmp/bin"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >>"%s/calls"\n' "$tmp" >"$tmp/bin/systemctl"
chmod +x "$tmp/bin/systemctl"
VPN_MODE=split PATH="$tmp/bin:$PATH" enable_vpn_autostart >/dev/null
expect_eq "enable_vpn_autostart enables the user unit" "1" \
    "$(grep -c '^--user enable vitrail-vpn-autostart.service$' "$tmp/calls" 2>/dev/null)"
rm -f "$tmp/calls"
VPN_MODE=none PATH="$tmp/bin:$PATH" enable_vpn_autostart >/dev/null
[[ ! -e "$tmp/calls" ]] && ok "enable_vpn_autostart is off with --vpn none" \
    || not_ok "enable_vpn_autostart is off with --vpn none"
rm -rf "$tmp"

# ------------------------------------------------------------- validation

if (
    SELECTED_COMPOSITORS=(sway)
    validate_selection
) >/dev/null 2>&1; then
    not_ok "validate_selection rejects unknown compositors"
else
    ok "validate_selection rejects unknown compositors"
fi

if (
    SELECTED_HELPERS=(yay)
    validate_selection
) >/dev/null 2>&1; then
    ok "validate_selection accepts known helpers"
else
    not_ok "validate_selection accepts known helpers"
fi

# --------------------------------------------------------- install record

# `vitrail update` replays this file; it is written before the optional system
# steps, so a late failure must never leave the install without a record.
tmp="$(sandbox)"
mkdir -p "$tmp/home"
ROOT_DIR="$REPO"
HOME_DIR="$tmp/home"
SELECTED_COMPOSITORS=(hyprland)
SELECTED_HELPERS=(yay)
VPN_MODE=split
XDG_DATA_HOME="$tmp/data" HOME="$tmp/home" write_install_state
record="$tmp/data/vitrail/install.json"
[[ -f "$record" ]] && ok "write_install_state writes install.json in XDG_DATA_HOME" \
    || not_ok "write_install_state writes install.json in XDG_DATA_HOME"

if python3 - "$record" "$REPO" <<'PY'
import json
import os
import subprocess
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
want = {"root", "version", "method", "commit", "branch", "vpn", "compositors"}
if not want <= data.keys():
    sys.exit("missing keys: %s" % (want - data.keys()))
if data["root"] != sys.argv[2]:
    sys.exit("root: %r" % data["root"])
if not data["version"]:
    sys.exit("empty version")
if data["method"] not in ("git", "copy", "package"):
    sys.exit("method: %r" % data["method"])
if os.path.isdir(os.path.join(sys.argv[2], ".git")):
    head = subprocess.run(
        ["git", "-C", sys.argv[2], "rev-parse", "HEAD"],
        capture_output=True, text=True, check=True).stdout.strip()
    if data["commit"] != head:
        sys.exit("commit: %r != %r" % (data["commit"], head))
if data["vpn"] != "split" or data["compositors"] != "hyprland":
    sys.exit("choices not recorded")
PY
then
    ok "write_install_state records root, version, method, commit and the choices"
else
    not_ok "write_install_state records root, version, method, commit and the choices"
fi

version="$(awk -F'"' '/^version[[:space:]]*=/{print $2; exit}' "$REPO/pyproject.toml")"
expect_eq "the record carries the project version" "$version" \
    "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$record")"

XDG_DATA_HOME="$tmp/data" HOME="$tmp/home" write_install_state
expect_eq "writing the record twice is idempotent" "1" \
    "$(find "$tmp/data/vitrail" -name install.json | wc -l)"

# ------------------------------------------- optional steps must not abort

# A failing optional step warns and returns 0: `set -e` in the installer must
# not turn it into a lost installation.
tmp="$(sandbox)"
mkdir -p "$tmp/bin" "$tmp/home"
cat >"$tmp/bin/sudo" <<'STUB'
#!/usr/bin/env bash
exit 1
STUB
chmod +x "$tmp/bin/sudo"
ROOT_DIR="$REPO"
HOME_DIR="$tmp/home"

if (
    set -euo pipefail
    PATH="$tmp/bin:$PATH" VPN_MODE=split setup_vpn
) \
    2>"$tmp/vpn.err" >/dev/null; then
    ok "a failing vpn/install.sh does not abort the installer"
else
    not_ok "a failing vpn/install.sh does not abort the installer"
fi
grep -q "the VPN infrastructure did not finish" "$tmp/vpn.err" \
    && ok "setup_vpn warns when the VPN step fails" \
    || not_ok "setup_vpn warns when the VPN step fails" "output: $(cat "$tmp/vpn.err")"

# plocate-updatedb.timer is a static unit: `systemctl enable` refuses it.
if (
    set -euo pipefail
    PATH="$tmp/bin:$PATH" enable_file_index
) \
    2>"$tmp/plocate.err" >/dev/null; then
    ok "a static unit that refuses to enable does not abort the installer"
else
    not_ok "a static unit that refuses to enable does not abort the installer"
fi
grep -q "file search falls back to fd" "$tmp/plocate.err" \
    && ok "enable_file_index warns on a static unit" \
    || not_ok "enable_file_index warns on a static unit" "output: $(cat "$tmp/plocate.err")"

printf '#!/usr/bin/env bash\nexit 1\n' >"$tmp/bin/systemctl"
chmod +x "$tmp/bin/systemctl"
if (
    set -euo pipefail
    PATH="$tmp/bin:$PATH" VPN_MODE=split enable_vpn_autostart
) \
    2>"$tmp/autostart.err" >/dev/null; then
    ok "a failing VPN autostart unit does not abort the installer"
else
    not_ok "a failing VPN autostart unit does not abort the installer"
fi
grep -q "connect from the bar after login" "$tmp/autostart.err" \
    && ok "enable_vpn_autostart warns when the unit fails" \
    || not_ok "enable_vpn_autostart warns when the unit fails" "output: $(cat "$tmp/autostart.err")"

# A VPN folder that cannot be created is reported, not fatal.
printf 'not a directory\n' >"$tmp/blocked"
if (
    set -euo pipefail
    HOME_DIR="$tmp/blocked" prepare_vpn_storage
) \
    2>"$tmp/storage.err" >/dev/null; then
    ok "an unwritable VPN folder does not abort the installer"
else
    not_ok "an unwritable VPN folder does not abort the installer"
fi
grep -q "could not create the VPN folders" "$tmp/storage.err" \
    && ok "prepare_vpn_storage warns when the folders fail" \
    || not_ok "prepare_vpn_storage warns when the folders fail" "output: $(cat "$tmp/storage.err")"

ROOT_DIR="$REPO"
rm -rf "$tmp"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]

# ------------------------------------------------------------ graphics stack

tmp="$(sandbox)"
mkdir -p "$tmp/bin"
printf '#!/bin/sh\nprintf "01:00.0 VGA compatible controller: NVIDIA Corporation GA104\n"\n' \
    >"$tmp/bin/lspci"
chmod +x "$tmp/bin/lspci"
expect_eq "gpu_vendor detects NVIDIA" "nvidia" "$(PATH="$tmp/bin:$PATH" gpu_vendor)"
printf '#!/bin/sh\nprintf "00:02.0 VGA compatible controller: Intel Corporation UHD\n"\n' \
    >"$tmp/bin/lspci"
expect_eq "gpu_vendor detects Intel" "intel" "$(PATH="$tmp/bin:$PATH" gpu_vendor)"
expect_eq "gpu_packages for amd" "mesa vulkan-radeon libva-mesa-driver" \
    "$(gpu_packages amd | tr '\n' ' ' | sed 's/ $//')"
expect_eq "an unknown vendor falls back to mesa" "mesa" "$(gpu_packages none)"
