#!/usr/bin/env bash
# Fixture tests for scripts/reinstall-all.sh: a throwaway repo, stub npx/trash/zharness
# on PATH, and stub install-*.sh scripts. No network, no real ~/.claude.
set -euo pipefail

SCRIPT_UNDER_TEST="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/reinstall-all.sh"
# Run from inside a Git hook, the caller's GIT_* would steer the fixture repos.
# shellcheck disable=SC2046
unset $(git rev-parse --local-env-vars)
ROOT="$(mktemp -d)"
# Fixture git never reads the caller's config (a global core.hooksPath would leak).
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 HOME="$ROOT/home"
cleanup() { if command -v trash >/dev/null 2>&1; then trash "$ROOT" 2>/dev/null || true; else rm -rf "${ROOT:?}"; fi; }
trap cleanup EXIT
PASSED=0
FAILED=0

check() { # check <name> <expected rc> <actual rc> <output> [pattern that must appear]...
  local name="$1" want="$2" got="$3" out="$4"; shift 4
  local ok=1 pat
  [ "$want" = "$got" ] || ok=0
  for pat in "$@"; do grep -qF -- "$pat" <<<"$out" || ok=0; done
  if [ "$ok" = 1 ]; then PASSED=$((PASSED + 1)); echo "ok   $name"
  else FAILED=$((FAILED + 1)); echo "FAIL $name (rc want $want got $got)"; printf '     %s\n' "$out"; fi
}

# Stubs on PATH: npx copies the fixture skills (or a stale copy), trash moves aside.
mkdir -p "$ROOT/bin"
cat >"$ROOT/bin/npx" <<'EOF'
#!/usr/bin/env bash
echo "npx $*" >>"$STUB_LOG"
mkdir -p "$CLAUDE_DIR/skills"
cp -R "$STUB_REPO/skills/stages/foo" "$CLAUDE_DIR/skills/"
[ -z "${STUB_STALE:-}" ] || echo stale >"$CLAUDE_DIR/skills/foo/references/a.md"
EOF
cat >"$ROOT/bin/trash" <<'EOF'
#!/usr/bin/env bash
mkdir -p "$STUB_TRASH" && mv "$1" "$STUB_TRASH/$(basename "$1").$RANDOM"
EOF
cat >"$ROOT/bin/zharness" <<'EOF'
#!/usr/bin/env bash
echo "zharness version 9.9.9"
EOF
chmod +x "$ROOT/bin/"*

new_repo() { # fresh fixture repo + empty install dirs; sets REPO and exports stub env
  REPO="$ROOT/repo.$RANDOM"
  mkdir -p "$REPO/scripts" "$REPO/skills/stages/foo/references" "$REPO/agents"
  cp "$SCRIPT_UNDER_TEST" "$REPO/scripts/reinstall-all.sh"
  printf -- '---\nname: foo\n---\n' >"$REPO/skills/stages/foo/SKILL.md"
  echo ref >"$REPO/skills/stages/foo/references/a.md"
  echo agent >"$REPO/agents/bar.md"
  cat >"$REPO/scripts/install-agents.sh" <<'EOF'
mkdir -p "$CLAUDE_DIR/agents" && cp agents/*.md "$CLAUDE_DIR/agents/"
EOF
  cat >"$REPO/scripts/install-git-hooks.sh" <<'EOF'
h="$(git rev-parse --path-format=absolute --git-path hooks)" && mkdir -p "$h" && echo '# ZGUARD-CORE-BEGIN' >"$h/pre-commit"
EOF
  echo 'true' >"$REPO/scripts/install-zharness.sh"
  git -C "$REPO" init -q -b master
  git -C "$REPO" add -A
  git -C "$REPO" -c user.name=t -c user.email=t@t commit -qm init
  export CLAUDE_DIR="$REPO.claude" AGENTS_SKILLS_DIR="$REPO.agents" STUB_REPO="$REPO"
  export STUB_LOG="$REPO.npx.log" STUB_TRASH="$REPO.trash" STUB_STALE=""
  mkdir -p "$CLAUDE_DIR/skills" "$AGENTS_SKILLS_DIR"
  : >"$STUB_LOG"
}

run() { set +e; OUT="$(PATH="$ROOT/bin:$PATH" bash "$REPO/scripts/reinstall-all.sh" "$@" 2>&1)"; RC=$?; set -e; }

retired_skill() { # retired_skill <dir> <description>
  mkdir -p "$1" && printf -- '---\nname: %s\ndescription: "%s"\n---\n' "$(basename "$1")" "$2" >"$1/SKILL.md"
}

# 1. Fresh install retires mono-write from both dirs and verifies every row.
new_repo
retired_skill "$CLAUDE_DIR/skills/mono-write" "Polish a research or learn draft (EN/VI)"
retired_skill "$AGENTS_SKILLS_DIR/mono-write" "Polish a research or learn draft (EN/VI)"
retired_skill "$CLAUDE_DIR/skills/mono" "The user's own skill that happens to be called mono"
run --no-pull
check "install: all rows ok" 0 "$RC" "$OUT" "✓ skill   foo" "✓ agent   bar" "✓ hook    pre-commit" "✓ cli     zharness version 9.9.9"
trashed=1
if [ ! -e "$CLAUDE_DIR/skills/mono-write" ] && [ ! -e "$AGENTS_SKILLS_DIR/mono-write" ] \
  && [ "$(compgen -G "$STUB_TRASH/mono-write.*" | wc -l | tr -d " ")" = 2 ]; then trashed=0; fi
check "install: retired skill trashed from both dirs" 0 "$trashed" ""
kept=1; [ -f "$CLAUDE_DIR/skills/mono/SKILL.md" ] && kept=0
check "install: a same-name skill without the harness description is kept" 0 "$kept" ""

# 2. A pull that adds a retired skill runs the pulled script, so the new entry applies.
new_repo
git clone -q --bare "$REPO" "$REPO.git"
git -C "$REPO" remote add origin "$REPO.git"
git -C "$REPO" fetch -q origin && git -C "$REPO" branch -q -u origin/master
git clone -q "$REPO.git" "$REPO.work"
perl -pi -e 's/^  "mono-write=/  "old-x=Old harness skill"\n  "mono-write=/' "$REPO.work/scripts/reinstall-all.sh"
git -C "$REPO.work" -c user.name=t -c user.email=t@t commit -qam "retire old-x"
git -C "$REPO.work" push -q origin master
retired_skill "$CLAUDE_DIR/skills/old-x" "Old harness skill, now retired"
run
check "pull: retired entry from the pulled script applies" 0 "$RC" "$OUT" "✓ git pull" "retired skill trashed: $CLAUDE_DIR/skills/old-x"

# 3. A stale installed file fails its skill row and names the file.
new_repo
STUB_STALE=1 run --no-pull
check "stale skill file: row fails" 1 "$RC" "$OUT" "✗ skill   foo  differs or missing: references/a.md"

# 4. --verify never installs: nothing installed → rows fail, npx not called.
new_repo
run --verify
check "verify only: missing install fails" 1 "$RC" "$OUT" "✗ skill   foo" "✗ agent   bar"
check "verify only: npx not called" 0 "$(wc -c <"$STUB_LOG" | tr -d ' ')" ""

# 5. Preconditions: tracked change, other branch, bad flag → exit 2 before installing.
new_repo
echo dirty >>"$REPO/agents/bar.md"
run --no-pull
check "dirty tree: refused" 2 "$RC" "$OUT" "tracked changes present"
new_repo
git -C "$REPO" switch -q -c feat/x
run --no-pull
check "not on master: refused" 2 "$RC" "$OUT" "reinstall from master"
run --bogus
check "unknown flag: usage" 2 "$RC" "$OUT" "usage:"

# 6. ~/.claude/skills symlinked to ~/.agents/skills: one retired dir, trashed once.
new_repo
rmdir "$CLAUDE_DIR/skills" && ln -s "$AGENTS_SKILLS_DIR" "$CLAUDE_DIR/skills"
retired_skill "$AGENTS_SKILLS_DIR/mono-write" "Polish a research or learn draft (EN/VI)"
run --no-pull
check "symlinked skills dir: retired skill trashed once" 0 "$RC" "$OUT" "✓ skill   foo"
gone=1; [ ! -e "$AGENTS_SKILLS_DIR/mono-write" ] && [ "$(compgen -G "$STUB_TRASH/mono-write.*" | wc -l | tr -d " ")" = 1 ] && gone=0
check "symlinked skills dir: retired skill gone" 0 "$gone" ""

# 7. Per-skill symlink: ~/.claude/skills/<name> links to ~/.agents/skills/<name>;
#    both the link and the real directory go, so verify reports nothing left.
new_repo
retired_skill "$AGENTS_SKILLS_DIR/mono-write" "Polish a research or learn draft (EN/VI)"
ln -s "$AGENTS_SKILLS_DIR/mono-write" "$CLAUDE_DIR/skills/mono-write"
run --no-pull
check "per-skill symlink: install ok" 0 "$RC" "$OUT" "✓ skill   foo"
gone=1; [ ! -e "$AGENTS_SKILLS_DIR/mono-write" ] && [ ! -L "$CLAUDE_DIR/skills/mono-write" ] && gone=0
check "per-skill symlink: link and real dir gone" 0 "$gone" ""

echo "passed=$PASSED failed=$FAILED"
[ "$FAILED" = 0 ]
