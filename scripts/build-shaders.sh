#!/usr/bin/env bash
# Rebuilds every QML shader from its GLSL source. The .qsb files are committed,
# so running the shell needs no shader tools; only changing a shader does.
#
#   scripts/build-shaders.sh
#
# `qsb` comes with qt6-shadertools.
set -euo pipefail

HERE="$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd)"
QSB="${QSB:-}"
if [[ -z "$QSB" ]]; then
    for candidate in qsb /usr/lib/qt6/bin/qsb; do
        if command -v "$candidate" >/dev/null 2>&1; then
            QSB="$candidate"
            break
        fi
    done
fi
if [[ -z "$QSB" ]]; then
    printf 'qsb is missing: install qt6-shadertools\n' >&2
    exit 1
fi

sources=("${HERE}/../kit/shaders"/*.frag)
if [[ ! -e "${sources[0]}" ]]; then
    printf 'no shaders in kit/shaders\n' >&2
    exit 1
fi

for source in "${sources[@]}"; do
    "$QSB" --qt6 -o "${source}.qsb" "$source"
    printf 'baked %s.qsb\n' "$(basename "${source}")"
done
