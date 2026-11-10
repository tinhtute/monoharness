#!/bin/bash
# baseline.sh — record the green (or pre-existing red) baseline before work starts (#219)
#
# Runs each gate command from the repository root under `bash -c`, then appends
# one `decision` entry per command to the active plan's `## Log`:
#   - <UTC> — <active_phase> — decision — baseline: <HEAD sha> <cmd> rc=<n>
# The pre-commit BASELINE guard rejects an active plan whose first `done`
# entry has no such line above it. A non-zero rc is recorded, not hidden: it
# names a failure that predates the work (work-full.md step 3).
#
# Usage:
#   scripts/workflow/baseline.sh [--plan <file>] [--list] [-- cmd...]
# Without `-- cmd...` the commands are the `## Gate Commands` bash block of
# AGENTS.md (comment and blank lines skipped). `--list` prints them and exits.
# Without `--plan` the plan is the one non-empty .harness/plans/active/*.md.
#
# Exit codes: 0 baseline recorded (whatever the commands returned); 2 usage
# error, no or several active plans, or no commands.

set -u

plan="" list=0
while [ $# -gt 0 ]; do
  case "$1" in
    --plan) [ $# -ge 2 ] || { echo "baseline: --plan needs a file" >&2; exit 2; }; plan="$2"; shift 2 ;;
    --list) list=1; shift ;;
    --) shift; break ;;
    -h|--help) grep '^#' "$0" | sed -n '2,19p' | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "usage: $0 [--plan <file>] [--list] [-- cmd...]" >&2; exit 2 ;;
  esac
done

root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "baseline: not inside a git repository" >&2; exit 2; }
cd "$root" || exit 2

cmds=()
if [ $# -gt 0 ]; then
  cmds=("$@")
else
  [ -f AGENTS.md ] || { echo "baseline: no AGENTS.md and no -- cmd given" >&2; exit 2; }
  while IFS= read -r c; do cmds+=("$c"); done < <(awk '
    /^## / { sec = ($0 ~ /^## Gate Commands[[:space:]]*$/); next }
    sec && /^```bash[[:space:]]*$/ { on = 1; next }
    on && /^```/ { exit }
    on && $0 !~ /^[[:space:]]*(#|$)/ { print }' AGENTS.md)
fi
[ "${#cmds[@]}" -gt 0 ] || { echo "baseline: no gate commands found" >&2; exit 2; }

if [ "$list" = 1 ]; then printf '%s\n' "${cmds[@]}"; exit 0; fi

if [ -z "$plan" ]; then
  found=()
  for f in .harness/plans/active/*.md; do [ -s "$f" ] && found+=("$f"); done
  [ "${#found[@]}" -eq 1 ] || { echo "baseline: expected one non-empty active plan, found ${#found[@]}; pass --plan" >&2; exit 2; }
  plan="${found[0]}"
fi
[ -f "$plan" ] || { echo "baseline: no plan at $plan" >&2; exit 2; }
grep -qx '## Log' "$plan" || { echo "baseline: $plan has no ## Log section" >&2; exit 2; }

sha=$(git rev-parse HEAD 2>/dev/null) || { echo "baseline: no HEAD commit to baseline" >&2; exit 2; }
phase=$(sed -n -E 's/^[[:space:]]*- active_phase:[[:blank:]]*`?([^`[:space:]]+)`?.*/\1/p' "$plan" | head -1)
case "$phase" in ""|none) phase=plan ;; esac

entries=""
for c in "${cmds[@]}"; do
  echo "🧪 baseline: $c" >&2
  bash -c "$c" >&2
  rc=$?
  echo "   rc=$rc" >&2
  entries="$entries- $(date -u +%Y-%m-%dT%H:%M:%SZ) — $phase — decision — baseline: $sha $c rc=$rc
"
done

# Insert at the end of ## Log, before the next heading, keeping one blank line.
tmp=$(mktemp) || exit 2
E="$entries" awk '
  function emit() { printf "%s", ENVIRON["E"] }
  $0 == "## Log" { inlog = 1; print; next }
  inlog && /^## / { emit(); print ""; inlog = 0; print; next }
  inlog && /^[[:space:]]*$/ { held = held $0 "\n"; next }
  inlog { printf "%s", held; held = ""; print; next }
  { print }
  END { if (inlog) emit() }
' "$plan" > "$tmp" && cat "$tmp" > "$plan"
rm -f "$tmp"
printf '%s' "$entries"
