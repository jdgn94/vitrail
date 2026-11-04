#!/usr/bin/env bash
# Keep Vitrail's knowledge graph fresh (graphify) without blocking anything.
#
# The post-commit hook and the agents call it detached, so a commit or an
# answer never waits for the build. One build runs at a time; a second caller
# leaves quietly. `graphify-out/` is a derived artifact and is git-ignored: the
# graph is never committed.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/.." && pwd)"
GIT_DIR="$(git -C "$ROOT" rev-parse --git-dir 2>/dev/null || true)"
[[ -n "$GIT_DIR" ]] || exit 0
[[ "$GIT_DIR" = /* ]] || GIT_DIR="$ROOT/$GIT_DIR"
LOG="${GRAPHIFY_LOG:-$GIT_DIR/graphify-hook.log}"
LOCK="$GIT_DIR/graphify.lock"

cd -- "$ROOT"
mkdir -p -- "$(dirname -- "$LOG")"

# One build at a time: a detached second caller is not an error.
exec 9>"$LOCK"
flock -n 9 || exit 0

# Never touch the agent skills from a background build.
export GRAPHIFY_NO_AUTO_REFRESH=1

{
    printf '\n=== %s graphify update ===\n' "$(date -Is)"
    if command -v graphify >/dev/null 2>&1; then
        graphify update "$ROOT"
    elif command -v uv >/dev/null 2>&1; then
        uv run --quiet --frozen --group dev graphify update "$ROOT"
    else
        echo "graphify is not installed: uv tool install graphifyy"
        exit 0
    fi
} >>"$LOG" 2>&1
