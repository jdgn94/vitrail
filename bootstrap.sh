#!/usr/bin/env bash
# Installs Vitrail without cloning by hand.
#
#   curl -fsSL https://raw.githubusercontent.com/jdgn94/vitrail/master/bootstrap.sh | bash
#
# It clones the repository into ~/.local/share/vitrail (shallow) or updates that
# clone, then runs the interactive installer. VITRAIL_REPO overrides the remote
# and VITRAIL_HOME the checkout's place.
set -euo pipefail

REPO="${VITRAIL_REPO:-https://github.com/jdgn94/vitrail.git}"
TARGET="${VITRAIL_HOME:-${XDG_DATA_HOME:-${HOME}/.local/share}/vitrail}"

command -v git >/dev/null 2>&1 || {
    printf 'vitrail: git is required; install it first (pacman -S git)\n' >&2
    exit 1
}

if [[ -d "$TARGET/.git" ]]; then
    printf 'Updating %s\n' "$TARGET"
    git -C "$TARGET" fetch --depth 1 origin
    git -C "$TARGET" reset --hard origin/HEAD
else
    printf 'Cloning %s into %s\n' "$REPO" "$TARGET"
    mkdir -p -- "$(dirname -- "$TARGET")"
    git clone --depth 1 "$REPO" "$TARGET"
fi

exec "$TARGET/install.sh" "$@"
