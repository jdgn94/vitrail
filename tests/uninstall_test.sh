#!/usr/bin/env bash
# The uninstaller removes only what the installer linked.
set -uo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
pass=0
fail=0
ok() {
    printf 'ok - %s\n' "$1"
    pass=$((pass + 1))
}
not_ok() {
    printf 'not ok - %s\n' "$1"
    fail=$((fail + 1))
}

tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
root="$tmp/root"
home="$tmp/home"
mkdir -p "$root/dots/.config" "$root/bin" "$root/packages" "$home/.config/vitrail" "$home/.local/bin"
printf 'x\n' >"$root/dots/.config/vitrail.conf"
printf 'foreign\n' >"$home/.config/foreign.conf"
printf 'b\n' >"$root/bin/vitrail-settings"
chmod +x "$root/bin/vitrail-settings"
printf 'settings\n' >"$home/.config/vitrail/bar.ini"
ln -s "$root/dots/.config/vitrail.conf" "$home/.config/vitrail.conf"
ln -s "$root/bin/vitrail-settings" "$home/.local/bin/vitrail-settings"

bash "$REPO/uninstall.sh" --root "$root" --home "$home" >/dev/null 2>&1
[[ ! -e "$home/.config/vitrail.conf" ]] && ok "a linked dotfile is removed" \
    || not_ok "a linked dotfile is removed"
[[ -f "$home/.config/foreign.conf" ]] && ok "a foreign file is kept" \
    || not_ok "a foreign file is kept"
[[ ! -e "$home/.local/bin/vitrail-settings" ]] && ok "a linked binary is removed" \
    || not_ok "a linked binary is removed"
[[ -f "$home/.config/vitrail/bar.ini" ]] && ok "the settings are kept without --purge" \
    || not_ok "the settings are kept without --purge"

ln -s "$root/dots/.config/vitrail.conf" "$home/.config/vitrail.conf"
bash "$REPO/uninstall.sh" --root "$root" --home "$home" --dry-run >/dev/null 2>&1
[[ -L "$home/.config/vitrail.conf" ]] && ok "--dry-run changes nothing" \
    || not_ok "--dry-run changes nothing"

bash "$REPO/uninstall.sh" --root "$root" --home "$home" --purge >/dev/null 2>&1
[[ ! -d "$home/.config/vitrail" ]] && ok "--purge moves the settings away" \
    || not_ok "--purge moves the settings away"
ls -d "$home"/.local/share/vitrail-backup-* >/dev/null 2>&1 && ok "--purge keeps a backup" \
    || not_ok "--purge keeps a backup"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
