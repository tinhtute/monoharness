#!/usr/bin/env bash
# CI parity for the local secret guard and commit-msg hook (issue #216): run
# both over a PR range, so a local-hook bypass cannot land a secret or a
# malformed commit message.
#
# Usage: bash scripts/ci/pr-guards.sh <base> <head>
# Env:   ZHARNESS_GUARD_SRC  path to an install-git-hooks.sh to take the guards
#                            from. Unset: the installer at the merge-base
#                            revision, so a PR cannot neuter its own guard.
#                            A consumer repo has no installer of its own and
#                            sets this to a pinned copy (see
#                            docs/guides/consumer-ci-guards.md).
#
# Reads the guards out of the installer at runtime (ZGUARD-CORE for the secret
# scan, the commit-msg heredoc for the message check); no guard logic is copied
# here. Exit 0 = clean, 1 = a guard rejected or failed closed, 2 = usage.
set -uo pipefail

if [ "$#" -ne 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
  echo "usage: pr-guards.sh <base> <head>" >&2
  exit 2
fi
# Run from inside a Git hook, the caller's GIT_DIR/GIT_INDEX_FILE/... would
# steer every git command below into the calling repository.
# shellcheck disable=SC2046
unset $(git rev-parse --local-env-vars 2>/dev/null)

installer=scripts/install-git-hooks.sh
die() { echo "❌ PR-GUARDS FAILED CLOSED: $*" >&2; exit 1; }

root=$(git rev-parse --show-toplevel 2>/dev/null) || die "not inside a git repository."
base=$(git rev-parse --verify --quiet "$1^{commit}") || die "base '$1' does not resolve to a commit (shallow checkout? use fetch-depth: 0)."
head=$(git rev-parse --verify --quiet "$2^{commit}") || die "head '$2' does not resolve to a commit (shallow checkout? use fetch-depth: 0)."
# The range is what the PR adds: merge-base..head, as zharness_guard_revspec
# computes it. A stale base tip must not make the PR own master's newer lines.
mb=$(git merge-base "$base" "$head" 2>/dev/null) || die "no merge-base between '$1' and '$2' (need full history)."

tmp=$(mktemp -d) || die "cannot create a temp dir."
trap 'rm -rf "$tmp"' EXIT

if [ -n "${ZHARNESS_GUARD_SRC:-}" ]; then
  [ -f "$ZHARNESS_GUARD_SRC" ] || die "ZHARNESS_GUARD_SRC='$ZHARNESS_GUARD_SRC' is not a file."
  cp "$ZHARNESS_GUARD_SRC" "$tmp/src.sh"
  src_label="$ZHARNESS_GUARD_SRC"
else
  git show "$mb:$installer" > "$tmp/src.sh" 2>/dev/null ||
    die "$installer is absent at the merge-base; set ZHARNESS_GUARD_SRC to a pinned copy."
  src_label="$mb:$installer"
fi

# Same extraction the pre-commit hook and hook-guard.sh use.
awk '$0=="# ZGUARD-CORE-BEGIN"{on=1;next} $0=="# ZGUARD-CORE-END"{on=0} on' "$tmp/src.sh" > "$tmp/guard.sh"
grep -q '^zharness_guard_staged_secrets()' "$tmp/guard.sh" || die "secret guard missing from $src_label."
# The commit-msg hook body is the heredoc of create_commit_msg_hook.
awk '/^function create_commit_msg_hook/{f=1} f&&/<< .HOOK_EOF.$/{on=1;next} on&&$0=="HOOK_EOF"{exit} on' "$tmp/src.sh" > "$tmp/commit-msg.sh"
grep -q 'grep -qE' "$tmp/commit-msg.sh" || die "commit-msg hook body missing from $src_label."
# shellcheck disable=SC1090
source "$tmp/guard.sh"

# The secret guard reads `git diff --cached`. Give it a scratch clone whose HEAD
# and index we set per revision pair, so "staged" means exactly that diff. The
# clone shares objects and never checks out a file or touches this repository.
scan="$tmp/scan"
git clone -q -s -n "$root" "$scan" 2>/dev/null || die "cannot create the scan clone."

failed=0
scan_diff() { # <parent> <tree-ish> <label>
  git -C "$scan" update-ref --no-deref HEAD "$1" &&
    git -C "$scan" read-tree "$2" || { echo "❌ cannot stage $3 for scanning" >&2; failed=1; return; }
  if ! zharness_guard_staged_secrets "$scan"; then
    echo "   ($3)" >&2
    failed=1
  fi
}

echo "== PR guards: $(git rev-parse --short "$mb")..$(git rev-parse --short "$head") (guards from $src_label)"

# The net diff, then every non-merge commit: a secret added and removed within
# the PR is still in history, and merge commits (a base sync) carry the base's
# lines, not the PR's.
scan_diff "$mb" "$head" "net diff of the range"
commits=$(git rev-list --reverse --no-merges "$mb..$head")
n=0
for c in $commits; do
  n=$((n + 1))
  short=$(git rev-parse --short "$c")
  parent=$(git rev-parse --verify --quiet "$c^") || { echo "❌ $short has no parent; cannot scan" >&2; failed=1; continue; }
  scan_diff "$parent" "$c" "commit $short"
  git log -1 --format=%B "$c" > "$tmp/msg"
  if ! out=$(bash "$tmp/commit-msg.sh" "$tmp/msg" 2>&1); then
    printf '%s\n' "$out" | sed "s/^/   /" >&2
    echo "   (commit $short: $(git log -1 --format=%s "$c"))" >&2
    failed=1
  fi
done

if [ "$failed" -ne 0 ]; then
  echo "❌ PR guards rejected this range." >&2
  exit 1
fi
echo "✅ PR guards passed ($n commit(s) checked)"
