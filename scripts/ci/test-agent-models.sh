#!/usr/bin/env bash
# models.json is the role -> model policy for the harness agents; each agents/*.md
# must carry the model its tier names, and every agent file must have a policy row.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
policy="$root/models.json"
fail=0
listed=$(jq -r '.agents[].agent' "$policy" | sort)
present=$(cd "$root/agents" && ls *.md | sed 's/\.md$//' | sort)
if [ "$listed" != "$present" ]; then
  echo "agent files and models.json rows differ:"; diff <(echo "$listed") <(echo "$present") || true; fail=1
fi
for a in $listed; do
  want=$(jq -r --arg a "$a" '.tiers[(.agents[]|select(.agent==$a).tier)]' "$policy")
  jq -e --arg m "$want" '.available|index($m)' "$policy" >/dev/null || { echo "$a: tier model '$want' not in available"; fail=1; }
  f="$root/agents/$a.md"
  [ -f "$f" ] || continue
  got=$(awk '/^---$/{n++;next} n==1 && /^model:/{print $2}' "$f")
  name=$(awk '/^---$/{n++;next} n==1 && /^name:/{print $2}' "$f")
  [ "$got" = "$want" ] || { echo "$a: model '$got', policy wants '$want'"; fail=1; }
  want_e=$(jq -r --arg a "$a" '.agents[]|select(.agent==$a).effort // empty' "$policy")
  got_e=$(awk '/^---$/{n++;next} n==1 && /^effort:/{print $2}' "$f")
  [ -n "$want_e" ] || { echo "$a: models.json row has no effort"; fail=1; }
  [ "$got_e" = "$want_e" ] || { echo "$a: effort '$got_e', policy wants '$want_e'"; fail=1; }
  [ "$name" = "$a" ] || { echo "$a: frontmatter name '$name'"; fail=1; }
  grep -q '^maxTurns: [0-9]' "$f" || { echo "$a: missing maxTurns"; fail=1; }
  if jq -e --arg a "$a" '.readOnly|index($a)' "$policy" >/dev/null; then
    tools=$(awk '/^---$/{n++;next} n==1 && /^tools:/{sub(/^tools:[[:space:]]*/,"");print}' "$f")
    [ -n "$tools" ] || { echo "$a: read-only agent has no tools allowlist"; fail=1; }
    case ", $tools," in *", Edit,"*|*", Write,"*|*", NotebookEdit,"*) echo "$a: read-only agent allows an edit tool: $tools"; fail=1 ;; esac
  fi
done
# read-only worktree fixture: a write into it must fail (root bypasses chmod).
if [ "$(id -u)" -eq 0 ]; then
  echo "skip read-only worktree fixture: running as root"
else
  fx=$(mktemp -d)
  trap 'chmod -R u+w "$fx" 2>/dev/null; rm -rf "$fx"' EXIT
  g() { git -C "$fx/r" -c user.name=t -c user.email=t@t "$@"; }
  git init -q "$fx/r"; echo a > "$fx/r/f"; g add f; g commit -q -m f
  ro=$(cd "$fx/r" && TMPDIR="$fx" bash "$root/scripts/workflow/readonly-worktree.sh" HEAD)
  if ( echo x > "$ro/f" ) 2>/dev/null || ( : > "$ro/new" ) 2>/dev/null; then
    echo "read-only worktree is writable"; fail=1
  fi
  # A gate still runs inside it: build output and temp files go to the
  # writable siblings the verifier exports as CARGO_TARGET_DIR and TMPDIR.
  if ! ( cd "$ro" && export CARGO_TARGET_DIR="$ro/../target" TMPDIR="$ro/../tmp" &&
    t=$(mktemp) && echo ok > "$t" && : > "$CARGO_TARGET_DIR/build" && git status --porcelain >/dev/null ) 2>/dev/null; then
    echo "a gate cannot write its scratch next to the read-only worktree"; fail=1
  fi
fi
# judges: models allowed to sign a low-risk verdict (scripts/ci/risk-verdict.sh).
jq -e '.judges | length > 0' "$policy" >/dev/null || { echo "models.json: judges is empty"; fail=1; }
for m in $(jq -r '.judges[]?' "$policy"); do
  jq -e --arg m "$m" '.available|index($m)' "$policy" >/dev/null || { echo "judge model '$m' not in available"; fail=1; }
done
[ "$fail" -eq 0 ] && echo "agent models OK ($(echo "$listed" | wc -l | tr -d ' ') agents)"
exit "$fail"
