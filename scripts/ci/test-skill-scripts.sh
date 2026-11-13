#!/usr/bin/env bash
# Fixture tests for skill scripts: one hit and one miss case per script.
# Run: bash scripts/ci/test-skill-scripts.sh
# SKILL_SCRIPTS_ROOT points at an alternate tree holding skills/ (mutation checks).
set -euo pipefail
here=$(cd "$(dirname "$0")/../.." && pwd)
root=${SKILL_SCRIPTS_ROOT:-$here}
fx="$here/scripts/ci/fixtures/skill-scripts"
# Run from inside a Git hook, the caller's GIT_* would steer fixture repos.
# shellcheck disable=SC2046
unset $(git rev-parse --local-env-vars)

tmp=$(mktemp -d)
cleanup() { if command -v trash >/dev/null 2>&1; then trash "$tmp" 2>/dev/null || true; else rm -rf "${tmp:?}"; fi; }
trap cleanup EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "  ok  - $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL - $1"; }

out=""
rc=0
run() { rc=0; out=$("$@" 2>&1) || rc=$?; }
expect() { # <name> <want-rc>
	if [ "$rc" -eq "$2" ]; then ok "$1 (rc=$rc)"; else bad "$1: want rc=$2, got rc=$rc: $out"; fi
}

newrepo() { rm -rf "${tmp:?}/r"; mkdir "$tmp/r"; git -C "$tmp/r" init -q; }

scan="$root/skills/tools/git/scripts/scan-staged.sh"
group="$root/skills/tools/git/scripts/group-staged.sh"
lint="$root/skills/reason/ambition/scripts/lint-prompt.sh"
ghs="$root/skills/tools/librarian/scripts/gh-search.sh"
fetch="$root/skills/tools/read/scripts/fetch.sh"
digest="$root/skills/stages/retro/scripts/session-digest.py"

# scan-staged.sh
secret="AKIA$(printf 'A%.0s' $(seq 16))"
newrepo
printf 'key = %s\n' "$secret" > "$tmp/r/cfg.txt"
git -C "$tmp/r" add cfg.txt
run bash -c "cd '$tmp/r' && bash '$scan'"
expect "scan-staged hit: staged AKIA key" 1
case "$out" in *cfg.txt:1*) ok "scan-staged hit prints file:line" ;; *) bad "scan-staged hit missing file:line: $out" ;; esac
case "$out" in *"$secret"*) bad "scan-staged leaked the key value" ;; *) ok "scan-staged hides the key value" ;; esac
newrepo
echo "hello world" > "$tmp/r/a.txt"
git -C "$tmp/r" add a.txt
run bash -c "cd '$tmp/r' && bash '$scan'"
expect "scan-staged miss: clean stage" 0
run bash -c "cd '$tmp' && GIT_CEILING_DIRECTORIES='$tmp' bash '$scan'"
expect "scan-staged usage: outside a repo" 2

# group-staged.sh
newrepo
mkdir "$tmp/r/src"
echo '{}' > "$tmp/r/package.json"
echo '# d' > "$tmp/r/README.md"
echo 'x' > "$tmp/r/src/app.js"
git -C "$tmp/r" add -A
run bash -c "cd '$tmp/r' && bash '$group'"
expect "group-staged hit: mixed stage" 0
want=$'code: src/app.js\ndeps: package.json\ndocs: README.md'
if [ "$(printf '%s\n' "$out" | sort)" = "$(printf '%s\n' "$want" | sort)" ]; then
	ok "group-staged classifies deps/docs/code"
else
	bad "group-staged output: $out"
fi
newrepo
run bash -c "cd '$tmp/r' && bash '$group'"
expect "group-staged miss: empty stage" 0
if [ -z "$out" ]; then ok "group-staged empty stage prints nothing"; else bad "group-staged empty output: $out"; fi
run bash -c "cd '$tmp' && GIT_CEILING_DIRECTORIES='$tmp' bash '$group'"
expect "group-staged usage: outside a repo" 2

# lint-prompt.sh
run bash "$lint" "$fx/bad-prompt.txt"
expect "lint-prompt hit: missing slots" 1
case "$out" in *"Instruments: missing"*) ok "lint-prompt names the missing slot" ;; *) bad "lint-prompt output: $out" ;; esac
run bash "$lint" "$fx/good-prompt.txt"
expect "lint-prompt miss: complete prompt" 0
run bash "$lint" --lens bogus "$fx/good-prompt.txt"
expect "lint-prompt usage: bad lens" 2

# gh-search.sh, offline usage only
run bash "$ghs"
expect "gh-search usage: no command" 2
run bash "$ghs" bogus
expect "gh-search usage: unknown command" 2

# fetch.sh, offline usage only
run bash "$fetch"
if [ "$rc" -ne 0 ]; then ok "fetch usage: no URL (rc=$rc)"; else bad "fetch accepted no URL"; fi
case "$out" in *Usage*) ok "fetch usage message printed" ;; *) bad "fetch usage message missing: $out" ;; esac

# session-digest.py
run python3 -I "$digest" "$fx/session.jsonl"
expect "session-digest hit: fixture log" 0
case "$out" in *"Bash: boom"*) ok "session-digest reports the errored result" ;; *) bad "session-digest output: $out" ;; esac
: > "$tmp/empty.jsonl"
run python3 -I "$digest" "$tmp/empty.jsonl"
expect "session-digest miss: empty log" 0
case "$out" in *"tool calls: 0"*) ok "session-digest empty log counts zero" ;; *) bad "session-digest empty output: $out" ;; esac
run python3 -I "$digest" no-such-session-id
expect "session-digest usage: unknown session" 1
# session-digest.py --signals: one line per errored result, repeated call (x3+), and gh pr merge
tu() { printf '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"%s","name":"Bash","input":{"command":"%s"}}]}}\n' "$1" "$2"; }
tres() { printf '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"%s","content":"%s","is_error":%s}]}}\n' "$1" "$2" "$3"; }
{
	tu e1 "make"; tres e1 "boom" true
	for i in 1 2 3; do tu "r$i" "cargo test"; tres "r$i" "ok" false; done
	tu m1 "gh pr merge 281 --merge"; tres m1 "merged" false
} > "$tmp/signals.jsonl"
run python3 -I "$digest" --signals "$tmp/signals.jsonl"
expect "session-digest --signals hit: exits 0" 0
case "$out" in *"signal: error tool=Bash result=boom"*) ok "session-digest --signals reports the errored result" ;; *) bad "session-digest --signals error line: $out" ;; esac
case "$out" in *"signal: repeat tool=Bash count=3 input="*"cargo test"*) ok "session-digest --signals reports the repeated call" ;; *) bad "session-digest --signals repeat line: $out" ;; esac
case "$out" in *"signal: merge pr=281 command=gh pr merge 281 --merge"*) ok "session-digest --signals reports the merge with its PR" ;; *) bad "session-digest --signals merge line: $out" ;; esac
if [ "$(printf '%s\n' "$out" | grep -vc '^signal: ')" -eq 0 ]; then ok "session-digest --signals prints only signal lines"; else bad "session-digest --signals extra lines: $out"; fi
{
	tu c1 "make"; tres c1 "ok" false
	tu c2 "cargo test"; tres c2 "ok" false
	tu c3 "cargo test"; tres c3 "ok" false
} > "$tmp/clean.jsonl"
run python3 -I "$digest" --signals "$tmp/clean.jsonl"
expect "session-digest --signals miss: clean log exits 0" 0
if [ -z "$out" ]; then ok "session-digest --signals clean log prints nothing"; else bad "session-digest --signals clean output: $out"; fi
run python3 -I "$digest" "$tmp/signals.jsonl"
if printf '%s\n' "$out" | grep -q '^signal: '; then bad "session-digest default mode printed a signal line: $out"; else ok "session-digest default mode prints no signal lines"; fi
# --since: only records at or after the timestamp count toward any signal
tut() { printf '{"type":"assistant","timestamp":"%s","message":{"content":[{"type":"tool_use","id":"%s","name":"Bash","input":{"command":"%s"}}]}}\n' "$1" "$2" "$3"; }
trest() { printf '{"type":"user","timestamp":"%s","message":{"content":[{"type":"tool_result","tool_use_id":"%s","content":"%s","is_error":%s}]}}\n' "$1" "$2" "$3" "$4"; }
old=2026-11-13T01:00:00.000Z
{
	tut $old o1 "make"; trest $old o1 "boom" true
	for i in 1 2 3; do tut $old "or$i" "cargo test"; trest $old "or$i" "ok" false; done
	tut $old om "gh pr merge 7"; trest $old om "merged" false
} > "$tmp/since.jsonl"
run python3 -I "$digest" --signals --since 2026-11-13T02:00:00Z "$tmp/since.jsonl"
expect "session-digest --since miss: old signals only exits 0" 0
if [ -z "$out" ]; then ok "session-digest --since drops error, repeat and merge before it"; else bad "session-digest --since old output: $out"; fi
cp "$tmp/since.jsonl" "$tmp/since2.jsonl"
{ tut 2026-11-13T02:00:00.000Z n1 "make"; trest 2026-11-13T02:00:00.000Z n1 "fresh" true; } >> "$tmp/since2.jsonl"
run python3 -I "$digest" --signals --since=2026-11-13T02:00:00Z "$tmp/since2.jsonl"
expect "session-digest --since hit: exits 0" 0
if [ "$out" = "signal: error tool=Bash result=fresh" ]; then ok "session-digest --since keeps a record at the timestamp"; else bad "session-digest --since new output: $out"; fi
for v in yesterday 2026-11-13T02:00:00 2026-13-40T99:00:00Z; do
	run python3 -I "$digest" --signals --since "$v" "$tmp/since.jsonl"
	expect "session-digest --since usage: rejects $v" 2
done
run python3 -I "$digest" --since 2026-11-13T02:00:00Z "$tmp/since.jsonl"
expect "session-digest usage: --since without --signals" 2
run python3 -I "$digest" --json --signals "$tmp/signals.jsonl"
expect "session-digest usage: --json with --signals" 2
# exit 1 from a read-only command (no match, files differ) is not a signal; anything else is
{
	tu g1 "grep -n foo a.txt"; tres g1 "Exit code 1" true
	tu g2 "git diff --quiet; rg -n 'a|b' src | head -3"; tres g2 "Exit code 1\\n" true
	tu g3 "make lint"; tres g3 "Exit code 1\\nlint failed" true
	tu g4 "grep -n foo a.txt && make"; tres g4 "Exit code 1\\nmake failed" true
	tu g5 "grep foo missing.txt"; tres g5 "Exit code 2\\nno such file" true
} > "$tmp/readonly.jsonl"
run python3 -I "$digest" --signals "$tmp/readonly.jsonl"
want=$'signal: error tool=Bash result=Exit code 1 lint failed\nsignal: error tool=Bash result=Exit code 1 make failed\nsignal: error tool=Bash result=Exit code 2 no such file'
if [ "$out" = "$want" ]; then ok "session-digest --signals drops read-only exit 1 only"; else bad "session-digest --signals read-only output: $out"; fi
# repeats key on the exact input: two inputs sharing their first 250 chars, twice each, are no loop
long=$(printf 'x%.0s' $(seq 250))
{ for i in 1 2; do tu "la$i" "echo $long A"; tres "la$i" ok false; tu "lb$i" "echo $long B"; tres "lb$i" ok false; done; } > "$tmp/long.jsonl"
run python3 -I "$digest" --signals "$tmp/long.jsonl"
if [ -z "$out" ]; then ok "session-digest --signals keys repeats on the untruncated input"; else bad "session-digest --signals long-input output: $out"; fi
# the merged PR: stop at a separator (attached or not), see gh after cd &&, unwrap a subshell
{
	tu p1 "gh pr merge --merge && gh pr view 280"; tres p1 ok false
	tu p2 "gh pr merge --merge; gh pr view 281"; tres p2 ok false
	tu p3 "(gh pr merge 11)"; tres p3 ok false
	tu p4 "cd x && gh pr merge 5"; tres p4 ok false
} > "$tmp/merge.jsonl"
run python3 -I "$digest" --signals "$tmp/merge.jsonl"
for want in "pr=? command=gh pr merge --merge && gh pr view 280" "pr=? command=gh pr merge --merge; gh pr view 281" "pr=11 command=(gh pr merge 11)" "pr=5 command=cd x && gh pr merge 5"; do
	case "$out" in *"signal: merge $want"*) ok "session-digest --signals merge $want" ;; *) bad "session-digest --signals merge $want: $out" ;; esac
done

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
