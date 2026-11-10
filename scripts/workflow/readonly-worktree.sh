#!/usr/bin/env bash
# Create a detached worktree at <sha> and make it read-only; print its path.
# Usage: readonly-worktree.sh <sha>   (remove later: chmod -R u+w <path>; git worktree remove --force <path>)
# Enforcement: filesystem permissions. A non-root process cannot write inside; root can.
set -euo pipefail
[ $# -eq 1 ] || { echo "usage: $0 <sha>" >&2; exit 2; }
sha=$(git rev-parse --verify --quiet "$1^{commit}") || { echo "unknown commit: $1" >&2; exit 1; }
dir=$(mktemp -d "${TMPDIR:-/tmp}/verify-ro.XXXXXX")
git worktree add --detach -q "$dir/tree" "$sha" >&2
chmod -R a-w "$dir/tree"
echo "$dir/tree"
