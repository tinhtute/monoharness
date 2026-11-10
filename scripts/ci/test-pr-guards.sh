#!/usr/bin/env bash
# Fixture tests for scripts/ci/pr-guards.sh (issue #216) and the consumer
# template in docs/guides/consumer-ci-guards.md. Builds throwaway repositories,
# so nothing touches this one. Run: bash scripts/ci/test-pr-guards.sh
set -u
cd "$(dirname "$0")/../.."
REPO=$PWD
# Run from inside a Git hook, the caller's GIT_DIR/GIT_INDEX_FILE/... would
# steer every fixture's git command into the calling repository.
# shellcheck disable=SC2046
unset $(git rev-parse --local-env-vars)

PRG="$REPO/scripts/ci/pr-guards.sh"
INSTALLER="$REPO/scripts/install-git-hooks.sh"
DOC="$REPO/docs/guides/consumer-ci-guards.md"

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "  ok  - $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL - $1"; }

export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# The key is assembled at run time so this file never holds a key-shaped
# literal for the repository's own secret scan to reject.
KEY="AKI""A$(printf 'A%.0s' $(seq 16))"

g() { git -C "$W" -c commit.gpgsign=false "$@"; }
# newrepo <name> [with-installer]: a repo with one conforming base commit.
newrepo() {
	W="$tmp/$1"
	git init -q -b main "$W"
	echo base > "$W/README"
	if [ "${2:-}" = with-installer ]; then
		mkdir -p "$W/scripts"
		cp "$INSTALLER" "$W/scripts/install-git-hooks.sh"
		g add -A
	else
		g add README
	fi
	g commit -q -m "chore: base"
	g checkout -q -b pr
}
commit() { # <file> <content> <message>
	printf '%s\n' "$2" > "$W/$1"
	g add "$1"
	g commit -q -m "$3"
}
run() { (cd "$W" && "$@") ; }
guard() { run bash "$PRG" main pr; }

# 1. clean range -> 0
newrepo clean with-installer
commit a.txt "hello" "feat: add a"
out=$(guard 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "clean range exits 0" || bad "clean range expected 0, got $rc: $out"

# 2. AWS-shaped key -> non-zero, names file:line and the pattern, never the value
newrepo aws with-installer
commit cfg.txt "line1
key=$KEY" "feat: add config"
out=$(guard 2>&1); rc=$?
[ "$rc" -ne 0 ] && ok "AWS-shaped key rejects (rc=$rc)" || bad "AWS-shaped key expected non-zero"
case "$out" in *"cfg.txt:2  aws-access-key"*) ok "report names file:line and pattern" ;; *) bad "report missing file:line/pattern: $out" ;; esac
case "$out" in *"$KEY"*) bad "report leaked the key value" ;; *) ok "report does not print the key value" ;; esac

# 3. secret added then removed within the PR: net diff clean, history not
newrepo roundtrip with-installer
commit cfg.txt "key=$KEY" "feat: add config"
commit cfg.txt "key=redacted" "fix: remove the key"
out=$(guard 2>&1); rc=$?
[ "$rc" -ne 0 ] && ok "secret added then removed still rejects" || bad "added-then-removed secret expected non-zero"

# 4. bad commit message on clean content -> non-zero
newrepo badmsg with-installer
commit a.txt "hello" "added a file"
out=$(guard 2>&1); rc=$?
[ "$rc" -ne 0 ] && ok "non-conventional commit message rejects (rc=$rc)" || bad "bad message expected non-zero"
case "$out" in *"Invalid commit message format"*) ok "report carries the hook's message" ;; *) bad "report missing hook message: $out" ;; esac

# 5. a secret that lands on the base after the branch point is not the PR's
newrepo stale with-installer
commit a.txt "hello" "feat: add a"
g checkout -q main
commit leaked.txt "key=$KEY" "feat: unrelated base change"
g checkout -q pr
out=$(guard 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "range starts at the merge-base, not the base tip" || bad "stale base expected 0, got $rc: $out"

# 6. a merge commit (base sync) with a non-conventional subject is skipped
g merge -q --no-ff -m "Merge branch 'main' into pr" main >/dev/null 2>&1
out=$(guard 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "merge commits are not message-checked" || bad "merge commit expected 0, got $rc: $out"

# 7. a PR that guts the installer cannot neuter the guard (core read from base)
newrepo gutted with-installer
printf '#!/bin/bash\n# ZGUARD-CORE-BEGIN\nzharness_guard_staged_secrets() { return 0; }\n# ZGUARD-CORE-END\n' > "$W/scripts/install-git-hooks.sh"
g add -A
g commit -q -m "chore: touch installer"
commit cfg.txt "key=$KEY" "feat: add config"
out=$(guard 2>&1); rc=$?
[ "$rc" -ne 0 ] && ok "head-edited installer does not neuter the guard" || bad "gutted installer expected non-zero"

# 8. consumer flow: no installer in the repo, ZHARNESS_GUARD_SRC points at a pinned copy
newrepo consumer
commit a.txt "hello" "feat: add a"
out=$(run env ZHARNESS_GUARD_SRC="$INSTALLER" bash "$PRG" main pr 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "consumer flow: clean range exits 0" || bad "consumer clean expected 0, got $rc: $out"
commit cfg.txt "key=$KEY" "feat: add config"
out=$(run env ZHARNESS_GUARD_SRC="$INSTALLER" bash "$PRG" main pr 2>&1); rc=$?
[ "$rc" -ne 0 ] && ok "consumer flow: AWS-shaped key rejects" || bad "consumer key expected non-zero"
out=$(guard 2>&1); rc=$?
if [ "$rc" -ne 0 ]; then ok "no installer and no ZHARNESS_GUARD_SRC fails closed"; else bad "missing installer expected non-zero"; fi

# 9. usage and unresolvable revisions fail closed
out=$(bash "$PRG" 2>&1); rc=$?
[ "$rc" -eq 2 ] && ok "missing arguments exit 2" || bad "usage expected 2, got $rc"
out=$(run bash "$PRG" nonexistent pr 2>&1); rc=$?
[ "$rc" -eq 1 ] && ok "unresolvable base fails closed" || bad "unresolvable base expected 1, got $rc"

# 10. the consumer template names what the script and the installer provide
yaml=$(awk '/^```yaml$/{on=1;next} /^```$/{on=0} on' "$DOC")
if [ -z "$yaml" ]; then
	bad "template: no yaml block in docs/guides/consumer-ci-guards.md"
else
	for tok in 'fetch-depth: 0' 'pull_request:' 'ZHARNESS_GUARD_SRC' 'MONOHARNESS_REF' \
		'raw.githubusercontent.com/tinhtute/monoharness/$MONOHARNESS_REF' \
		'scripts/ci/pr-guards.sh' 'scripts/install-git-hooks.sh' 'pull_request.base.sha' 'pull_request.head.sha'; do
		case "$yaml" in
		*"$tok"*) ok "template names $tok" ;;
		*) bad "template is missing $tok" ;;
		esac
	done
	# The files the template downloads exist in this repo, and the script
	# reads the variable the template sets.
	[ -f "$REPO/scripts/ci/pr-guards.sh" ] && [ -f "$INSTALLER" ] &&
		grep -q 'ZHARNESS_GUARD_SRC' "$PRG" &&
		ok "template's downloaded files and variable exist in this repo" ||
		bad "template references a file or variable this repo lacks"
	if command -v python3 >/dev/null && python3 -I -c 'import yaml' 2>/dev/null; then
		printf '%s\n' "$yaml" | python3 -I -c 'import sys,yaml; d=yaml.safe_load(sys.stdin); assert "guards" in d["jobs"]' &&
			ok "template parses as YAML with a guards job" || bad "template is not valid workflow YAML"
	fi
fi

echo
echo "pr-guards: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
