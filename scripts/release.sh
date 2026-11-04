#!/usr/bin/env bash
# Builds the release tarball from tracked files only.
#
#   scripts/release.sh [--dry-run]
#
# The archive never carries the wallpapers (assets/*wallpapers are ignored and
# large) and is reproducible from a clean tag.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DRY=0
[[ "${1:-}" == "--dry-run" ]] && DRY=1

version="$(awk -F'"' '/^version[[:space:]]*=/{print $2; exit}' "$ROOT/pyproject.toml")"
[[ -n "$version" ]] || {
    printf 'release: no version in pyproject.toml\n' >&2
    exit 1
}
name="vitrail-${version}"
out="${ROOT}/dist"

# Untracked files (the plans, the screenshots) do not block a release; a
# modified or staged file does.
if [[ -n "$(git -C "$ROOT" status --porcelain --untracked-files=no)" ]]; then
    printf 'release: the tracked tree has changes; commit or stash them first\n' >&2
    exit 1
fi

if ! git -C "$ROOT" rev-parse --verify --quiet "v${version}" >/dev/null; then
    printf 'release: tag v%s does not exist yet\n' "$version" >&2
fi

if [[ $DRY -eq 1 ]]; then
    printf 'would write %s/%s.tar.gz (version %s)\n' "$out" "$name" "$version"
    exit 0
fi

mkdir -p -- "$out"
git -C "$ROOT" archive --format=tar.gz --prefix="${name}/" \
    -o "${out}/${name}.tar.gz" HEAD
(cd "$out" && sha256sum "${name}.tar.gz" >"${name}.tar.gz.sha256")
printf '%s/%s.tar.gz\n' "$out" "$name"
printf '%s\n' "$(cat "${out}/${name}.tar.gz.sha256")"
