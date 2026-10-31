#!/bin/bash
# Root helper for the system language, run through pkexec by apply-settings.sh.
# Installed root-owned as /usr/local/libexec/vitrail-locale-helper by install.sh
# (a file the user can edit must not run as root).
#
# One argument: a locale listed in /usr/share/i18n/SUPPORTED. It enables that
# locale in /etc/locale.gen and runs locale-gen. Nothing else.
set -euo pipefail

SUPPORTED=/usr/share/i18n/SUPPORTED
LOCALE_GEN=/etc/locale.gen
LOCALE_GEN_BIN=/usr/bin/locale-gen

[[ $# -eq 1 ]] || { echo "usage: vitrail-locale-helper LOCALE" >&2; exit 2; }
locale="$1"

# Strict shape first, then it must be a whole line of SUPPORTED ("es_ES.UTF-8 UTF-8").
[[ "$locale" =~ ^[a-z]{2,3}_[A-Z]{2}(@[a-z]+)?\.UTF-8$ ]] || { echo "invalid locale" >&2; exit 2; }
grep -Fxq -- "$locale UTF-8" "$SUPPORTED" || { echo "unsupported locale" >&2; exit 2; }

if grep -Fxq -- "$locale UTF-8" "$LOCALE_GEN"; then
    :
elif grep -Eq -- "^#[[:space:]]*$locale UTF-8\$" "$LOCALE_GEN"; then
    sed -i -E -- "s/^#[[:space:]]*($locale UTF-8)\$/\\1/" "$LOCALE_GEN"
else
    printf '%s UTF-8\n' "$locale" >>"$LOCALE_GEN"
fi

exec "$LOCALE_GEN_BIN"
