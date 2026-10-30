#!/usr/bin/env bash
# Applies the settings written by the Vitrail settings window.
#
# Hyprland 0.56 with a Lua config uses non-legacy parsers, where
# `hyprctl keyword` is refused ("keyword can't work with non-legacy parsers").
# Everything is applied through `hyprctl eval` with `hl.config`, and the
# legacy `hyprctl keyword` path is kept as a fallback.
set -euo pipefail

CONFIG="${XDG_CONFIG_HOME:-${HOME}/.config}/vitrail/settings.ini"
LANG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/environment.d"

# Resolve symlinks: the systemd unit calls ~/.local/bin/vitrail-apply-settings,
# which points here, so BASH_SOURCE alone would look for lib/ in ~/.local/bin.
SELF="$(readlink -f -- "${BASH_SOURCE[0]}")"
source "$(dirname -- "${SELF}")/lib/ini.sh"

style="$(read_ini surfaceStyle glass)"
radius="$(read_ini radius 14)"
opacity_focused="$(read_ini opacityFocused 0.97)"
opacity_unfocused="$(read_ini opacityUnfocused 0.88)"
blur_strength="$(read_ini blurStrength 6)"
focus_follows="$(read_ini focusFollowsMouse true)"
border_width="$(read_ini borderWidth 2)"
kb_raw="$(read_ini keyboardLayouts 'us:')"
kb_switch="$(read_ini keyboardSwitch grp:alt_shift_toggle)"
language="$(read_ini language en)"
tab_style="$(read_ini tabStyle capsule)"
tab_icons="$(read_ini tabIcons true)"
tab_numbers="$(read_ini tabNumbers false)"
term_scheme="$(read_ini terminalScheme system)"
font_size="$(read_ini fontSize 13)"
term_padding="$(read_ini terminalPadding 6)"
window_layout="$(read_ini windowLayout dwindle)"
visible_columns="$(read_ini visibleColumns 2)"
column_width="$(awk -v n="$visible_columns" 'BEGIN {
    if (n < 1) n = 1
    printf "%.4f", 1.0 / n
}')"
follow_focus="$(read_ini followFocus true)"
wallpaper="$(read_ini wallpaper '')"
wrap_focus="$(read_ini wrapFocus false)"

case "$language" in
    en) locale="en_US.UTF-8" ;;
    es) locale="es_ES.UTF-8" ;;
    pt) locale="pt_PT.UTF-8" ;;
    it) locale="it_IT.UTF-8" ;;
    fr) locale="fr_FR.UTF-8" ;;
    de) locale="de_DE.UTF-8" ;;
    *) locale="en_US.UTF-8" ;;
esac

mkdir -p -- "$LANG_DIR"
printf 'LANG=%s\nLANGUAGE=%s\n' "$locale" "$language" >"${LANG_DIR}/10-vitrail-locale.conf"

# Glass is the only mode that turns blur on. Solid keeps the transparency the
# user chose but draws no blur, so a translucent window shows the wallpaper.
blur_enabled=false
if [[ "$style" == "glass" ]]; then
    blur_enabled=true
fi

# "us:|es:nodeadkeys" becomes layout "us,es" and variant ",nodeadkeys".
kb_layout="$(printf '%s' "$kb_raw" | tr '|' '\n' | cut -d: -f1 | paste -sd, -)"
kb_variant="$(printf '%s' "$kb_raw" | tr '|' '\n' | cut -d: -f2 | paste -sd, -)"

follow_mouse=0
if [[ "$focus_follows" == "true" ]]; then
    follow_mouse=1
fi

if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    lua="hl.config({
        general = { border_size = ${border_width}, layout = \"${window_layout}\" },
        scrolling = {
            column_width = ${column_width},
            follow_focus = ${follow_focus},
            wrap_focus = ${wrap_focus}
        },
        decoration = {
            rounding = ${radius},
            active_opacity = ${opacity_focused},
            inactive_opacity = ${opacity_unfocused},
            blur = {
                enabled = ${blur_enabled},
                size = ${blur_strength},
                passes = 3,
                ignore_opacity = false
            }
        },
        input = {
            follow_mouse = ${follow_mouse},
            kb_layout = \"${kb_layout}\",
            kb_variant = \"${kb_variant}\",
            kb_options = \"${kb_switch}\"
        }
    })"

    # The layer rule from hyprland.lua, redefined by name: blur follows the
    # surface style, so glass/solid changes the bar, popups, notifications,
    # dialogs and session menu live.
    layer_lua="hl.layer_rule({
        name = \"vitrail-glass\",
        match = { namespace = \"^vitrail-(bar|popup|notifications|dialog|session)\$\" },
        blur = ${blur_enabled},
        ignore_alpha = 0.01
    })"
    if [[ "$(hyprctl eval "$layer_lua" 2>&1)" == "ok" ]]; then
        printf 'Hyprland layers: vitrail-glass blur=%s\n' "$blur_enabled"
    else
        printf 'Hyprland layers: vitrail-glass rule not applied (needs the Lua config)\n'
    fi

    if [[ "$(hyprctl eval "$lua" 2>&1)" == "ok" ]]; then
        printf 'Hyprland (eval): radius=%s border=%s follow_mouse=%s blur=%s size=%s opacity=%s/%s\n' \
            "$radius" "$border_width" "$follow_mouse" "$blur_enabled" "$blur_strength" \
            "$opacity_focused" "$opacity_unfocused"
    else
        # Legacy parser: same values through keywords.
        hyprctl keyword general:border_size "$border_width" >/dev/null
        hyprctl keyword decoration:rounding "$radius" >/dev/null
        hyprctl keyword decoration:active_opacity "$opacity_focused" >/dev/null
        hyprctl keyword decoration:inactive_opacity "$opacity_unfocused" >/dev/null
        hyprctl keyword decoration:blur:enabled "$blur_enabled" >/dev/null
        hyprctl keyword decoration:blur:size "$blur_strength" >/dev/null
        hyprctl keyword decoration:blur:passes 3 >/dev/null
        hyprctl keyword decoration:blur:ignore_opacity false >/dev/null
        hyprctl keyword input:follow_mouse "$follow_mouse" >/dev/null
        hyprctl keyword input:kb_layout "$kb_layout" >/dev/null
        hyprctl keyword input:kb_variant "$kb_variant" >/dev/null
        hyprctl keyword input:kb_options "$kb_switch" >/dev/null
        printf 'Hyprland (keywords): radius=%s border=%s blur=%s size=%s\n' \
            "$radius" "$border_width" "$blur_enabled" "$blur_strength"
    fi

    printf 'Keyboard: layout=%s variant=%s options=%s\n' \
        "$kb_layout" "$kb_variant" "$kb_switch"
else
    printf 'Hyprland is not running; settings were only saved.\n'
fi

# --- terminal ---------------------------------------------------------------
# header.conf is read by kitty/tab_bar.py ("key=value"); kitty-user.conf is a
# normal kitty include ("key value"). Neither lives in the repository.
# The system mode: light from 07:00 to 19:00 when auto. "system" follows it.
appearance="$(read_ini appearance auto)"
system_mode="$appearance"
if [[ "$appearance" == "auto" ]]; then
    hour="$(date +%H)"
    if (( 10#$hour >= 7 && 10#$hour < 19 )); then
        system_mode="light"
    else
        system_mode="dark"
    fi
fi
if [[ "$term_scheme" == "system" ]]; then
    term_scheme="$system_mode"
fi

flag() {
    if [[ "$1" == "true" ]]; then printf 1; else printf 0; fi
}

config_dir="$(dirname -- "$CONFIG")"
mkdir -p -- "$config_dir"
# A leftover symlink into the repo (from an older install) makes the redirect
# below fail with ENOENT; the file belongs to the user now, not to the repo.
for generated in header.conf kitty-user.conf; do
    if [[ -L "$config_dir/$generated" ]]; then
        rm -f -- "$config_dir/$generated"
    fi
done
cat >"$config_dir/header.conf" <<EOF
tabStyle=$tab_style
tabIcons=$(flag "$tab_icons")
tabNumbers=$(flag "$tab_numbers")
colorScheme=$term_scheme
EOF
cat >"$config_dir/kitty-user.conf" <<EOF
font_size $font_size
window_padding_width $term_padding
EOF
cache_dir="${XDG_CACHE_HOME:-${HOME}/.cache}/vitrail/generated"
cat >"$config_dir/kitty-colors.conf" <<EOF
include $cache_dir/terminal/kitty-$term_scheme.conf
EOF
pkill -USR1 -x kitty >/dev/null 2>&1 || true
printf 'Terminal: tabs=%s icons=%s numbers=%s scheme=%s font=%s padding=%s\n' \
    "$tab_style" "$tab_icons" "$tab_numbers" "$term_scheme" "$font_size" "$term_padding"

printf 'Language: %s (%s, next session)\n' "$language" "$locale"

# --- wallpaper and system theme ---------------------------------------------
# The bar draws the wallpaper; the palette follows it (a video lends one frame,
# an adaptive SVG its seed colour), and only a new wallpaper or seed extracts
# again. Then light or dark, with that palette, reaches GTK, Qt and Hyprland.
vitrail_cli() {
    PYTHONPATH="$(dirname -- "${SELF}")/.." python3 -m vitrail.cli "$@"
}
vitrail_cli wallpaper sync || true
vitrail_cli wallpaper apply || true
vitrail_cli theme apply --mode "$system_mode" || true
