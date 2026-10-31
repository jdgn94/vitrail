#!/usr/bin/env bash
# System-level settings applied by apply-settings.sh: time zone, NTP and the
# system locale. Each one acts only when its value changed, and each command
# that needs authorisation goes through polkit (the bar is the agent and asks
# in its own dialog).
#
# VITRAIL_DRY_RUN=1 prints the commands that change the system instead of
# running them (and leaves the stamps alone). Reads (timedatectl show,
# localectl list-locales) always run.
#
# A request is stamped in ~/.cache/vitrail/system/<key> whatever its outcome:
# a cancelled password prompt is not asked again on every unrelated setting,
# only when the value changes.

SYSTEM_STAMPS="${XDG_CACHE_HOME:-${HOME}/.cache}/vitrail/system"
LOCALE_HELPER="${VITRAIL_LOCALE_HELPER:-/usr/local/libexec/vitrail-locale-helper}"
ZONEINFO="/usr/share/zoneinfo"

# Runs a command that changes the system, or prints it in a dry run.
sys() {
    if [[ "${VITRAIL_DRY_RUN:-}" == "1" ]]; then
        printf 'dry-run: %s\n' "$*"
        return 0
    fi
    "$@"
}

# True when `value` is not what was last requested for `key`.
stamp_differs() {
    local file="$SYSTEM_STAMPS/$1"
    [[ ! -r "$file" || "$(<"$file")" != "$2" ]]
}

stamp_write() {
    [[ "${VITRAIL_DRY_RUN:-}" == "1" ]] && return 0
    mkdir -p -- "$SYSTEM_STAMPS"
    printf '%s' "$2" >"$SYSTEM_STAMPS/$1"
}

# A zone name that is a plain relative path to a file in the zoneinfo tree.
valid_zone() {
    local zone="$1"
    [[ "$zone" =~ ^[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)*$ ]] && [[ -f "$ZONEINFO/$zone" ]]
}

apply_timezone() {
    local wanted="$1" current
    [[ -n "$wanted" ]] || return 0
    if ! valid_zone "$wanted"; then
        printf 'Time zone: %s is not a known zone, ignored\n' "$wanted"
        return 0
    fi
    current="$(timedatectl show -p Timezone --value 2>/dev/null || true)"
    if [[ "$wanted" == "$current" ]] || ! stamp_differs timezone "$wanted"; then
        return 0
    fi
    if sys timedatectl set-timezone "$wanted"; then
        printf 'Time zone: %s\n' "$wanted"
    else
        printf 'Time zone: %s not applied (cancelled or refused)\n' "$wanted"
    fi
    stamp_write timezone "$wanted"
}

# $1 is "true" or "false"; anything else leaves the clock alone.
apply_ntp() {
    local wanted="$1" current
    case "$wanted" in
        true | false) ;;
        *) return 0 ;;
    esac
    current="$(timedatectl show -p NTP --value 2>/dev/null || true)"
    if [[ "$current" == "yes" ]]; then current=true; else current=false; fi
    if [[ "$wanted" == "$current" ]] || ! stamp_differs ntp "$wanted"; then
        return 0
    fi
    if sys timedatectl set-ntp "$wanted"; then
        printf 'NTP: %s\n' "$wanted"
    else
        printf 'NTP: %s not applied (cancelled or refused)\n' "$wanted"
    fi
    stamp_write ntp "$wanted"
}

# $1 is a locale such as es_ES.UTF-8. Generated first when the system lacks it.
apply_system_locale() {
    local wanted="$1" current
    current="$(localectl status 2>/dev/null | sed -n 's/^ *System Locale: LANG=//p' || true)"
    if [[ "$wanted" == "$current" ]] || ! stamp_differs locale "$wanted"; then
        return 0
    fi
    if ! localectl list-locales 2>/dev/null | grep -Fxq -- "$wanted"; then
        if [[ ! -x "$LOCALE_HELPER" ]]; then
            printf 'Locale: %s is not generated and %s is missing (run ./install.sh)\n' \
                "$wanted" "$LOCALE_HELPER"
            return 0
        fi
        if ! sys pkexec "$LOCALE_HELPER" "$wanted"; then
            printf 'Locale: %s not generated (cancelled or refused)\n' "$wanted"
            stamp_write locale "$wanted"
            return 0
        fi
    fi
    if sys localectl set-locale "LANG=$wanted"; then
        printf 'Locale: system language %s (after the next login)\n' "$wanted"
    else
        printf 'Locale: %s not applied (cancelled or refused)\n' "$wanted"
    fi
    stamp_write locale "$wanted"
}
