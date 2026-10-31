#!/usr/bin/env bash
# Smoke test for the Qt/QML settings window.
#
# Runtime QML errors are silent in this environment, so the window renders
# itself offscreen and only writes the marker after every component loaded.
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
    shift
    printf '  %s\n' "$@"
    fail=$((fail + 1))
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

for file in "$REPO"/kit/*.qml "$REPO"/kit/base/*.qml "$REPO"/kit/composed/*.qml \
    "$REPO"/shell/*.qml "$REPO"/shell/pages/*.qml "$REPO"/login/*.qml "$REPO"/lock/*.qml \
    "$REPO"/gallery/*.qml; do
    name="qmllint $(basename "$file")"
    if output="$(qmllint "$file" 2>&1)"; then
        ok "$name"
    else
        not_ok "$name" "$output"
    fi
done

if XDG_CONFIG_HOME="$tmp/config" XDG_CACHE_HOME="$tmp/cache" \
    QT_QPA_PLATFORM=offscreen timeout 25 "$REPO/bin/vitrail-settings" --selftest >/dev/null 2>&1; then
    ok "window loads and exits"
else
    not_ok "window loads and exits" "exit code $?"
fi

settings="$tmp/config/vitrail/misc.ini"
if grep -q '^selftest=' "$settings" 2>/dev/null; then
    ok "settings are persisted"
else
    not_ok "settings are persisted" "no selftest key in $settings"
fi

if [[ -s "$tmp/config/vitrail/selftest.png" ]]; then
    ok "settings window renders"
else
    not_ok "settings window renders" "selftest.png missing or empty"
fi

for screen in login lock; do
    target="$tmp/${screen}.png"
    if QT_QPA_PLATFORM=offscreen timeout 25 "$REPO/bin/vitrail-preview" "$screen" --grab "$target" >/dev/null 2>&1 \
        && [[ -s "$target" ]]; then
        ok "${screen} screen renders"
    else
        not_ok "${screen} screen renders" "render or grab failed"
    fi
done

if QT_QPA_PLATFORM=offscreen timeout 25 /usr/lib/qt6/bin/qmltestrunner -input "$REPO/tests/qml" >"$tmp/qmltest.log" 2>&1; then
    ok "qml unit tests"
else
    not_ok "qml unit tests" "$(grep -E 'FAIL|Totals' "$tmp/qmltest.log")"
fi

for theme in dark light; do
    target="$tmp/gallery-${theme}.png"
    if QT_QPA_PLATFORM=offscreen timeout 25 "$REPO/bin/vitrail-gallery" --theme "$theme" --grab "$target" >/dev/null 2>&1 \
        && [[ -s "$target" ]]; then
        ok "gallery renders (${theme})"
    else
        not_ok "gallery renders (${theme})" "render or grab failed"
    fi
done

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
