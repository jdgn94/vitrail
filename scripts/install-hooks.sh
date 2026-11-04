#!/usr/bin/env bash
# Point git at the tracked hooks: pre-commit formats the staged code,
# post-commit refreshes the graph in the background. One call per clone.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/.." && pwd)"

chmod +x -- "$ROOT/.githooks/pre-commit" "$ROOT/.githooks/post-commit" \
    "$ROOT/scripts/graphify-refresh.sh"
git -C "$ROOT" config core.hooksPath .githooks
printf 'git hooks: %s\n' "$(git -C "$ROOT" config --get core.hooksPath)"
