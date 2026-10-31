#!/usr/bin/env bash
# Reads a Vitrail preference by key.
#
# Preferences live in one INI file per area; vitrail/prefs.map says which file
# holds each key (a key it does not list is in misc.ini). Accepts both
# "key=value" (QSettings) and "key = value" (configparser) and ignores the
# section headers. Expects CONFIG_DIR to point at ~/.config/vitrail.

PREFS_MAP="${PREFS_MAP:-$(dirname -- "${BASH_SOURCE[0]}")/../../vitrail/prefs.map}"
declare -A PREF_FILE=()

load_pref_map() {
    local file key
    while read -r file key _; do
        [[ -z "$file" || "$file" == \#* ]] && continue
        PREF_FILE[$key]="$file"
    done <"$PREFS_MAP"
}
# Once, here: read_ini runs in command substitutions, which cannot cache.
load_pref_map

read_ini() {
    local key="$1" fallback="$2" file value
    file="$CONFIG_DIR/${PREF_FILE[$key]:-misc}.ini"
    [[ -r "$file" ]] || {
        printf '%s' "$fallback"
        return
    }
    value="$(awk -F= -v key="$key" '
        /^[ \t]*[\[#;]/ { next }
        {
            name = $1
            gsub(/^[ \t]+|[ \t]+$/, "", name)
            if (name == key) {
                sub(/^[^=]*=/, "")
                gsub(/^[ \t]+|[ \t]+$/, "")
                print
                exit
            }
        }
    ' "$file")"
    printf '%s' "${value:-$fallback}"
}
