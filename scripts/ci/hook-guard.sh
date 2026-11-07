#!/usr/bin/env bash
# CI hook-guard (issue #210): enforce ZGUARD-CORE from the trusted base
# revision, not from the commit under test, so a commit cannot neuter its own
# guard. When the range edits scripts/install-git-hooks.sh, the head guard runs
# as well and both must pass.
#
# Usage: bash scripts/ci/hook-guard.sh <push|pr>
# Env:   ZHARNESS_HEAD_SHA, ZHARNESS_BEFORE_SHA (push), ZHARNESS_BASE_REF (pr),
#        ZHARNESS_DEFAULT_BRANCH (fallback base, default origin/master)
set -uo pipefail

event="${1:-}"
installer=scripts/install-git-hooks.sh
head="${ZHARNESS_HEAD_SHA:-HEAD}"
zero=0000000000000000000000000000000000000000

# The trust anchor is chosen here, not by the guard's own revspec: a head guard
# could otherwise report its own commit as the base.
case "$event" in
  pr) anchor="${ZHARNESS_BASE_REF:-}" ;;
  push) anchor="${ZHARNESS_BEFORE_SHA:-}" ;;
  *) echo "usage: hook-guard.sh <push|pr>" >&2; exit 2 ;;
esac
[ "$anchor" = "$zero" ] && anchor=""
if [ -z "$anchor" ] || ! git rev-parse --verify --quiet "${anchor}^{commit}" >/dev/null 2>&1; then
  anchor=$(git merge-base "${ZHARNESS_DEFAULT_BRANCH:-origin/master}" "$head" 2>/dev/null) || anchor=""
fi
if [ -z "$anchor" ]; then
  echo "❌ HOOK-GUARD FAILED CLOSED: no trusted base revision resolves for event '$event'." >&2
  exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

extract() { # <rev> <out-file>
  git show "$1:$installer" 2>/dev/null |
    awk '$0=="# ZGUARD-CORE-BEGIN"{on=1;next} $0=="# ZGUARD-CORE-END"{on=0} on' > "$2"
  local fn
  for fn in zharness_guard_entries_of_file zharness_guard_at_most_one_active_plan \
    zharness_guard_completed_plan_phases_done zharness_guard_revspec zharness_guard_plan_paths; do
    grep -q "^$fn()" "$2" || return 1
  done
}

run_guard() ( # <guard-file> <label>
  # shellcheck disable=SC1090
  source "$1"
  echo "== $2 guard"
  failed=0
  zharness_guard_at_most_one_active_plan "$(git rev-parse --show-toplevel)" || failed=1
  revspec=$(zharness_guard_revspec "$event") || exit 1
  gbase=$(printf '%s' "$revspec" | cut -f1)
  ghead=$(printf '%s' "$revspec" | cut -f2)
  echo "guarding range $gbase..$ghead"
  plans=$(zharness_guard_plan_paths "$gbase" "$ghead")
  if [ -z "$plans" ]; then echo "no plan changes in range"; exit $failed; fi
  printf 'plans in range:\n%s\n' "$plans"
  mkdir -p "$tmp/$2"
  zhuards_guard_plans "$plans" "$gbase" "$ghead" "$tmp/$2" || failed=1
  while IFS= read -r f; do
    case "$f" in .harness/plans/completed/*) ;; *) continue ;; esac
    git show "$ghead:$f" > "$tmp/$2/completed.md"
    zharness_guard_completed_plan_phases_done "$f" "$tmp/$2/completed.md" || failed=1
  done <<< "$plans"
  exit $failed
)

if ! extract "$anchor" "$tmp/base.sh"; then
  echo "❌ HOOK-GUARD FAILED CLOSED: $anchor carries no complete ZGUARD-CORE in $installer." >&2
  exit 1
fi
echo "guard source: $anchor (base)"
rc=0
run_guard "$tmp/base.sh" base || rc=1

if ! git diff --quiet "$anchor" "$head" -- "$installer"; then
  echo "guard source: $head (head; $installer changed in range)"
  if extract "$head" "$tmp/head.sh"; then
    run_guard "$tmp/head.sh" head || rc=1
  else
    echo "❌ HOOK-GUARD: the head $installer carries no complete ZGUARD-CORE." >&2
    rc=1
  fi
fi
exit $rc
