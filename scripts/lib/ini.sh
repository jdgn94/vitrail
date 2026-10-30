#!/usr/bin/env bash
# Reads a value from the [appearance] section of the Vitrail settings file.
#
# Accepts both "key=value" (QSettings) and "key = value" (configparser).
# Expects CONFIG to point at the settings file.

read_ini() {
    local key="$1" fallback="$2" value
    [[ -r "$CONFIG" ]] || {
        printf '%s' "$fallback"
        return
    }
    value="$(awk -F= -v key="$key" '
        /^\[/ { inside = ($0 == "[appearance]"); next }
        inside {
            name = $1
            gsub(/^[ \t]+|[ \t]+$/, "", name)
            if (name == key) {
                sub(/^[^=]*=/, "")
                gsub(/^[ \t]+|[ \t]+$/, "")
                print
                exit
            }
        }
    ' "$CONFIG")"
    printf '%s' "${value:-$fallback}"
}
