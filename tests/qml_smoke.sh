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

# Qt 6's qmllint lives with qt6-declarative; a Qt5 one in PATH would not do.
if [[ -x /usr/lib/qt6/bin/qmllint ]]; then
    QMLLINT=/usr/lib/qt6/bin/qmllint
else
    QMLLINT="$(command -v qmllint || true)"
fi
[[ -n "$QMLLINT" ]] || {
    printf 'qmllint is missing\n' >&2
    exit 1
}

for file in "$REPO"/kit/*.qml "$REPO"/kit/base/*.qml "$REPO"/kit/composed/*.qml \
    "$REPO"/shell/*.qml "$REPO"/shell/pages/*.qml "$REPO"/login/*.qml "$REPO"/lock/*.qml \
    "$REPO"/gallery/*.qml; do
    name="qmllint $(basename "$file")"
    if output="$("$QMLLINT" "$file" 2>&1)"; then
        ok "$name"
    else
        not_ok "$name" "$output"
    fi
done

# The launcher uses Quickshell types, so only a Quickshell process can load it.
# Its fixture sits beside a symlink to bar/ because Quickshell refuses imports
# from outside the config folder. A QML error in the launcher makes
# createObject() return null and the process exit non-zero.
if ! command -v quickshell >/dev/null 2>&1; then
    not_ok "launcher loads in the shell" "quickshell is missing"
else
    mkdir -p "$tmp/launcher" "$tmp/launcher-runtime"
    ln -s "$REPO/bar" "$tmp/launcher/bar"
    cp "$REPO/tests/fixtures/launcher_smoke.qml" "$tmp/launcher/shell.qml"
    if XDG_CONFIG_HOME="$tmp/launcher-config" XDG_CACHE_HOME="$tmp/launcher-cache" \
        XDG_RUNTIME_DIR="$tmp/launcher-runtime" \
        QT_QPA_PLATFORM=offscreen timeout 20 quickshell --path "$tmp/launcher/shell.qml" \
        >"$tmp/launcher.log" 2>&1 && grep -q "launcher smoke: loaded" "$tmp/launcher.log"; then
        ok "launcher loads in the shell"
    else
        not_ok "launcher loads in the shell" \
            "$(grep -E 'ERROR|Failed|did not load|timed out' "$tmp/launcher.log" | head -5)"
    fi
fi

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

# Pages are built when their category is first shown, so the run above covers
# only the first one: open each category on its own and require it to render.
# A page that fails to build makes the selftest exit non-zero (LazyPage.qml).
categories="$(grep -oP '^\s+\{ key: "\K\w+(?=", group:)' "$REPO/shell/main.qml")"
pages="$(grep -c '^ *LazyPage {' "$REPO/shell/main.qml")"
if [[ "$(wc -w <<<"$categories")" -ne "$pages" ]]; then
    not_ok "every category has a page" "$(wc -w <<<"$categories") categories, $pages pages"
fi
for category in $categories; do
    (
        XDG_CONFIG_HOME="$tmp/config-$category" XDG_CACHE_HOME="$tmp/cache-$category" \
            QT_QPA_PLATFORM=offscreen timeout 25 "$REPO/bin/vitrail-settings" \
            --selftest --category "$category" >/dev/null 2>&1
    ) &
done
wait
for category in $categories; do
    if [[ -s "$tmp/config-$category/vitrail/selftest.png" ]]; then
        ok "category $category renders"
    else
        not_ok "category $category renders" "selftest.png missing: the page did not load"
    fi
done

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
