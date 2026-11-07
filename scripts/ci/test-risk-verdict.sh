#!/usr/bin/env bash
# Fixture tests for scripts/ci/risk-verdict.sh (issue #213): each case builds a
# throwaway repository with a base and a change commit, writes a PR body, and
# asserts on the gate's exit code.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$HERE/risk-verdict.sh"
FACTS="$HERE/../../skills/stages/check/scripts/risk-facts.sh"
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT
command -v jq >/dev/null || { echo "jq is required" >&2; exit 2; }

PASSED=0
FAILED=0
REPO=""

g() {
  git -C "$REPO" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false \
    -c core.hooksPath=/dev/null "$@"
}

# new_repo NAME [JUDGES_JSON]: base commit on main with the gate's inputs, then
# a small source change on `change`.
new_repo() {
  REPO="$ROOT/$1"
  mkdir -p "$REPO/src" "$REPO/skills/stages/check/scripts"
  g init -q -b main
  printf '# Agents\n\n## Unattended Shipping\n\n- Always-review paths: .github/**\n' >"$REPO/AGENTS.md"
  printf '{"judges": %s}\n' "${2:-[\"fable\", \"opus\"]}" >"$REPO/models.json"
  cp "$FACTS" "$REPO/skills/stages/check/scripts/risk-facts.sh"
  printf 'fn main() {}\n' >"$REPO/src/main.rs"
  g add -A
  g commit -q -m base
  g checkout -q -b change
  printf 'fn main() {\n    println!("hi");\n}\n' >"$REPO/src/main.rs"
  g add -A
  g commit -q -m change
}

# body LEVEL SHA JUDGE MODEL: a PR body with a filled Risk section.
body() {
  printf '## Summary\n\nA change.\n\n## Risk\n\n**Verdict:** %s, judged on %s (judge: %s, judge_model: %s)\n\n- Size: 3 counted lines → ok\n\n## Exercised\n\nok\n' \
    "$1" "$2" "$3" "$4" >"$ROOT/body.md"
}

head_sha() { g rev-parse change; }

check_rc() { # <name> <want-rc> [ENV=VAL...]
  local name=$1 want=$2 rc=0 out
  shift 2
  out=$(cd "$REPO" && env "$@" bash "$GATE" main change "$ROOT/body.md" 2>&1) || rc=$?
  if [ "$rc" -eq "$want" ]; then
    PASSED=$((PASSED + 1))
    echo "ok   $name"
  else
    FAILED=$((FAILED + 1))
    echo "FAIL $name (rc=$rc, want $want)"
    printf '%s\n' "$out" | sed 's/^/     /'
  fi
}

new_repo pass
body "low risk" "$(head_sha)" independent fable
check_rc "frontier model, head SHA, low risk passes" 0

new_repo missing
printf '## Summary\n\nNo risk section.\n' >"$ROOT/body.md"
check_rc "missing Risk section fails" 1

new_repo stale
body "low risk" "$(g rev-parse main)" independent fable
check_rc "verdict on a stale SHA fails" 1

new_repo haiku
body "low risk" "$(head_sha)" independent haiku
check_rc "judge_model haiku fails" 1

new_repo review
body "needs review" "$(head_sha)" independent opus
check_rc "needs-review verdict fails" 1

new_repo same
body "low risk" "$(head_sha)" same-session fable
check_rc "same-session judge fails" 1

new_repo short
body "low risk" "$(g rev-parse --short change)" independent fable
check_rc "abbreviated SHA fails" 1

new_repo facts
mkdir -p "$REPO/.github/workflows"
printf 'name: x\n' >"$REPO/.github/workflows/x.yml"
g add -A
g commit -q -m ci
body "low risk" "$(head_sha)" independent fable
check_rc "low-risk claim on a diff with a risk-facts hit fails" 1

new_repo selfallow
printf '{"judges": ["haiku"]}\n' >"$REPO/models.json"
g add -A
g commit -q -m judges
body "low risk" "$(head_sha)" independent haiku
check_rc "judges come from the base, so a PR cannot allowlist its own judge" 1

new_repo nojudges '[]'
body "low risk" "$(head_sha)" independent fable
check_rc "a base without judges fails closed" 1

new_repo crlf
body "low risk" "$(head_sha)" independent opus
sed 's/$/\r/' "$ROOT/body.md" >"$ROOT/crlf.md" && mv "$ROOT/crlf.md" "$ROOT/body.md"
check_rc "a CRLF body from the web editor parses" 0

new_repo label
printf '## Summary\n\nNo risk section.\n' >"$ROOT/body.md"
check_rc "the owner's label passes a PR without a verdict" 0 OWNER_REVIEWED=true

echo
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
