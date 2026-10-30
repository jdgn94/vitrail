#!/usr/bin/env bash
# Vitrail's stand-in for hyprland-dialog (installed as ~/.local/bin/hyprland-dialog,
# ahead of /usr/bin in PATH). Hyprland runs it to ask about an app that is not
# responding or about a permission; the bar shows the question in Vitrail's
# design and this script prints the chosen button back, as the real one does.
# Without the bar it hands over to the real dialog.
set -uo pipefail

REAL=/usr/bin/hyprland-dialog
BAR="$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/../bin/vitrail-bar"

title="" apptitle="" text="" buttons=""
args=("$@")
while (($#)); do
    case "$1" in
        --title) title="${2:-}"; shift 2 ;;
        --apptitle) apptitle="${2:-}"; shift 2 ;;
        --text) text="${2:-}"; shift 2 ;;
        --buttons) buttons="${2:-}"; shift 2 ;;
        *) shift ;;
    esac
done

id="$$-$(date +%s%N)"
answer="${XDG_RUNTIME_DIR:-/tmp}/vitrail-dialog/$id"

if ! "$BAR" ipc call dialog ask "$id" "${apptitle:-$title}" "$text" "$buttons" >/dev/null 2>&1; then
    exec "$REAL" "${args[@]}"
fi

# Hyprland kills the dialog when the app recovers: take the question back.
trap '"$BAR" ipc call dialog dismiss "$id" >/dev/null 2>&1; exit 0' TERM INT HUP

until [[ -f "$answer" ]]; do
    sleep 0.2
done
cat -- "$answer"
rm -f -- "$answer"
