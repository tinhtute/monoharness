#!/usr/bin/env bash
# CI test-weakening gate (issue #212): fail a PR whose diff deletes a test file,
# adds a skip marker or trivial assertion, or removes more assertion/test-case
# lines than it adds, unless the owner applied the `allow-test-weakening` label.
#
# Usage: bash scripts/ci/test-weakening.sh <base> <head>
# Env:   ALLOW_TEST_WEAKENING=true when the PR carries the override label.
#
# The facts come from the base revision's risk-facts.sh, so a PR cannot neuter
# its own gate. The head copy never runs: the workflow is pull_request_target,
# and PR code must not execute in the base context.
set -uo pipefail

[ "$#" -eq 2 ] || { echo "usage: test-weakening.sh <base> <head>" >&2; exit 2; }
base=$1
head=$2
script=skills/stages/check/scripts/risk-facts.sh
command -v jq >/dev/null || { echo "jq is required" >&2; exit 2; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

findings() { # <risk-facts-copy> <label>
  local out
  out=$(bash "$1" "$base" "$head") || { echo "❌ TEST-WEAKENING: $2 risk-facts.sh failed" >&2; return 2; }
  jq -r '.test_changes
    | (.removed_files // [] | map("removed test file: " + .)) +
      (.skip_markers_added // [] | map("skip marker or trivial assertion: " + .)) +
      (.assertions_removed // [] | map("assertions removed: " + .))
    | .[]' <<<"$out"
}

git show "$base:$script" > "$tmp/base.sh" 2>/dev/null || {
  echo "❌ TEST-WEAKENING FAILED CLOSED: $base carries no $script." >&2
  exit 1
}
found=$(findings "$tmp/base.sh" base) || exit 1

if [ -z "$found" ]; then
  echo "✅ no test weakening in $base...$head"
  exit 0
fi
printf '%s\n' "$found"
if [ "${ALLOW_TEST_WEAKENING:-}" = "true" ]; then
  echo "⚠️  test weakening allowed by the owner's \`allow-test-weakening\` label"
  exit 0
fi
echo "❌ TEST-WEAKENING GATE REJECTED: the PR weakens tests (above)."
echo "   Restore the tests, or the owner applies the \`allow-test-weakening\` label after review."
echo "   Agents never apply that label (AGENTS.md § Unattended Shipping)."
exit 1
