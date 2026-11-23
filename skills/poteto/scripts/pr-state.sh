#!/usr/bin/env bash
# pr-state.sh - one row per pull request: state, head SHA and check rollup.
#
# Usage: bash pr-state.sh PR [PR...]
#
# Runs one `gh pr view PR --json number,state,headRefOid,statusCheckRollup,updatedAt`
# per argument, all in parallel, in the current directory's repository, and
# prints one tab-separated row per argument, in argument order:
#   NUMBER  STATE  HEAD_SHA  PASS  FAIL  PENDING  UPDATED_AT
# A PR whose gh call (or its JSON) fails prints instead:
#   ARG  ERROR  MESSAGE      (gh's stderr on one line)
# and the other rows still print.
#
# Rollup counts: each check counts once, by its latest run (greatest startedAt):
# a CheckRun is keyed by workflow name plus check name, so a rerun replaces the
# earlier run while same-named jobs in different workflows stay apart; a
# StatusContext is keyed by its context. pass = conclusion SUCCESS, NEUTRAL or
# SKIPPED, or state SUCCESS; fail = conclusion FAILURE, CANCELLED, TIMED_OUT,
# ACTION_REQUIRED or STARTUP_FAILURE, or state FAILURE or ERROR; pending =
# anything else (no conclusion yet, PENDING, EXPECTED).
#
# Exit 0 when every row printed; exit 1 when any row is an ERROR row; exit 2 on
# bad usage (no argument). Needs gh and jq.

set -euo pipefail

[ $# -gt 0 ] || { echo "usage: pr-state.sh PR [PR...]" >&2; exit 2; }

tmp=$(mktemp -d)
trap 'rm -rf "${tmp:?}"' EXIT

i=0
for pr in "$@"; do
	i=$((i + 1))
	(
		rc=0
		gh pr view "$pr" --json number,state,headRefOid,statusCheckRollup,updatedAt \
			>"$tmp/$i.json" 2>"$tmp/$i.err" || rc=$?
		echo "$rc" >"$tmp/$i.rc"
	) &
done
wait

# shellcheck disable=SC2016 # jq program, not shell
row='
	def verdict:
		if .__typename == "StatusContext" then
			(if .state == "SUCCESS" then "pass"
			elif (.state == "FAILURE" or .state == "ERROR") then "fail"
			else "pending" end)
		else
			(.conclusion // "") as $c
			| if ($c | IN("SUCCESS", "NEUTRAL", "SKIPPED")) then "pass"
			elif ($c | IN("FAILURE", "CANCELLED", "TIMED_OUT", "ACTION_REQUIRED", "STARTUP_FAILURE")) then "fail"
			else "pending" end
		end;
	[(.statusCheckRollup // [])
		| group_by(if .__typename == "StatusContext" then ["ctx", .context] else ["run", (.workflowName // ""), .name] end)[]
		| max_by(.startedAt // "") | verdict] as $v
	| [.number, .state, .headRefOid,
		($v | map(select(. == "pass")) | length),
		($v | map(select(. == "fail")) | length),
		($v | map(select(. == "pending")) | length),
		.updatedAt] | @tsv'

status=0
i=0
for pr in "$@"; do
	i=$((i + 1))
	line=""
	if [ "$(cat "$tmp/$i.rc")" = 0 ]; then
		line=$(jq -r "$row" "$tmp/$i.json" 2>"$tmp/$i.err") || line=""
	fi
	if [ -n "$line" ]; then
		printf '%s\n' "$line"
	else
		msg=$(tr '\t\n' '  ' <"$tmp/$i.err" | sed 's/  */ /g; s/^ //; s/ $//')
		printf '%s\tERROR\t%s\n' "$pr" "${msg:-gh exited $(cat "$tmp/$i.rc")}"
		status=1
	fi
done
exit "$status"
