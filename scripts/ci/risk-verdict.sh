#!/usr/bin/env bash
# CI risk-verdict gate (issue #213): a PR merges only on a low-risk verdict
# bound to its head commit and signed by an allowlisted independent judge, or
# after the owner applied the `owner-reviewed` label.
#
# Usage: bash scripts/ci/risk-verdict.sh <base> <head> <body-file>
# Env:   OWNER_REVIEWED=true when the PR carries the `owner-reviewed` label.
#
# The PR body's `## Risk` section (check-risk.md § Risk Section) must carry
#   **Verdict:** low risk, judged on <head SHA> (judge: independent, judge_model: <model>, judge_session: <id>)
# with <model> listed in `judges` of the base revision's models.json and <id>
# the judge sub-agent's session id ([A-Za-z0-9-]+; shape only, not proof). The
# verdict is the judge's claim; the base revision's risk-facts.sh re-derives
# the mechanical facts here, and any hit fails the gate.
set -uo pipefail

[ "$#" -eq 3 ] || { echo "usage: risk-verdict.sh <base> <head> <body-file>" >&2; exit 2; }
base=$1
head=$2
body=$3
facts_script=skills/stages/check/scripts/risk-facts.sh
command -v jq >/dev/null || { echo "jq is required" >&2; exit 2; }
[ -r "$body" ] || { echo "risk-verdict: cannot read $body" >&2; exit 2; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
problems=()

head_sha=$(git rev-parse --verify --quiet "${head}^{commit}") || {
  echo "❌ RISK-VERDICT: unknown head $head" >&2
  exit 2
}

# The id is shape-checked in the C locale so [A-Za-z0-9-] means ASCII only.
session_shape_ok() { local LC_ALL=C; [[ $1 =~ ^[A-Za-z0-9-]+$ ]]; }

# The judge's claim, from the PR body.
risk=$(tr -d '\r' <"$body" | awk '/^## Risk[[:space:]]*$/{on=1;next} on && /^## /{exit} on')
verdict=$(printf '%s\n' "$risk" | grep -m1 '^\*\*Verdict:\*\*' || true)
re='^\*\*Verdict:\*\* (low risk|needs review), judged on ([0-9a-f]+) \(judge: (independent|same-session), judge_model: ([A-Za-z0-9._-]+)(, judge_session: (.*))?\)[[:space:]]*$'
if [ -z "$risk" ]; then
  problems+=("no ## Risk section in the PR body")
elif [[ ! $verdict =~ $re ]]; then
  problems+=("no parseable **Verdict:** line (check-risk.md § Risk Section)")
else
  v_level=${BASH_REMATCH[1]} v_sha=${BASH_REMATCH[2]} v_judge=${BASH_REMATCH[3]} v_model=${BASH_REMATCH[4]}
  v_has_session=${BASH_REMATCH[5]} v_session=${BASH_REMATCH[6]}
  [ "$v_level" = "low risk" ] || problems+=("verdict is '$v_level'")
  if [ -z "$v_has_session" ]; then
    problems+=("no judge_session after judge_model (check-risk.md § Risk Section)")
  elif ! session_shape_ok "$v_session"; then
    # Never echo the value: this log runs under pull_request_target.
    problems+=("judge_session is not [A-Za-z0-9-]+ (check-risk.md § Risk Section)")
  elif [ "$v_judge" = independent ] && [ "$v_session" = none ]; then
    problems+=("judge_session none means no judge sub-agent, but judge is independent (check-risk.md § Judge)")
  fi
  [ "$v_sha" = "$head_sha" ] || problems+=("verdict judged on $v_sha, head is $head_sha")
  [ "$v_judge" = "independent" ] || problems+=("judge is '$v_judge', not independent")
  judges=$(git show "$base:models.json" 2>/dev/null | jq -r '.judges[]?' 2>/dev/null)
  if [ -z "$judges" ]; then
    problems+=("$base:models.json lists no judges (failed closed)")
  elif ! grep -qxF -- "$v_model" <<<"$judges"; then
    problems+=("judge_model '$v_model' is not in the base judges: $(paste -sd' ' - <<<"$judges")")
  fi
fi

# The mechanical facts, from the base revision's script.
if git show "$base:$facts_script" >"$tmp/facts.sh" 2>/dev/null &&
  facts=$(bash "$tmp/facts.sh" "$base" "$head_sha"); then
  while IFS= read -r hit; do
    [ -n "$hit" ] && problems+=("risk-facts: $hit")
  done < <(jq -r '
    (if .counted_lines > 400 then ["size: \(.counted_lines) counted lines"] else [] end) +
    (.always_review_hits | map("always-review path: " + .)) +
    (if .ci_config_touched then ["CI config touched"] else [] end) +
    (if .manifest_or_lockfile_touched then ["manifest or lockfile touched"] else [] end) +
    (.test_changes.removed_files // [] | map("removed test file: " + .)) +
    (.test_changes.skip_markers_added // [] | map("skip marker: " + .)) +
    (.test_changes.assertions_removed // [] | map("assertions removed: " + .)) +
    (.test_changes.assertions_changed // [] | map("assertions changed: " + .))
    | .[]' <<<"$facts")
else
  problems+=("risk-facts: $base:$facts_script missing or failed (failed closed)")
fi

if [ "${#problems[@]}" -eq 0 ]; then
  echo "✅ low risk, judged on $head_sha by an independent $v_model judge; risk-facts clean"
  exit 0
fi
printf '%s\n' "${problems[@]}"
if [ "${OWNER_REVIEWED:-}" = "true" ]; then
  echo "⚠️  merge allowed by the owner's \`owner-reviewed\` label"
  exit 0
fi
echo "❌ RISK-VERDICT GATE REJECTED: no valid low-risk verdict for $head_sha (above)."
echo "   Re-judge per check-risk.md, or the owner applies the \`owner-reviewed\` label after review."
echo "   Agents never apply that label (AGENTS.md § Unattended Shipping)."
exit 1
