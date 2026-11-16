#!/usr/bin/env bash
# reinstall-all.sh — Pull this repository and reinstall everything it ships on this
# machine (skills, harness agents, git hooks, the zharness CLI), then prove it: every
# tracked file of every skill and agent is compared byte for byte with the installed
# copy, and one status table answers "is everything installed?".
#
# Retired skills (renamed or dropped here; `npx skills add` never removes them) are
# trashed from both skill directories first, but only when their SKILL.md still
# carries the harness description, so a user's own skill of the same name is kept.
# Add an entry to RETIRED_SKILLS whenever a CHANGELOG entry renames or drops a skill.
#
# Usage:
#   bash scripts/reinstall-all.sh             # pull, retire, install, verify
#   bash scripts/reinstall-all.sh --no-pull   # skip `git pull`
#   bash scripts/reinstall-all.sh --verify    # only print the status table
# Env: CLAUDE_DIR (default ~/.claude), AGENTS_SKILLS_DIR (default ~/.agents/skills),
#      SKILLS_SOURCE (default git@github.com:tinhtute/monoharness.git)
# Exit: 0 every row ok; 1 a row failed; 2 usage error or unmet precondition.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
AGENTS_SKILLS_DIR="${AGENTS_SKILLS_DIR:-$HOME/.agents/skills}"
SKILLS_SOURCE="${SKILLS_SOURCE:-git@github.com:tinhtute/monoharness.git}"
RETIRED_SKILLS=( # "<name>=<start of its last description>"
  "mono=Entry router: match a task to one of"
  "mono-write=Polish a research or learn draft"
)
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

pull=1 install=1
case "${1:-}" in
  "") ;;
  --no-pull) pull=0 ;;
  --verify) pull=0 install=0 ;;
  *) echo "usage: $0 [--no-pull | --verify]" >&2; exit 2 ;;
esac

cd "$REPO_DIR"

# retired_dirs: installed directories that hold a retired harness skill.
retired_dirs() {
  local entry name marker dir
  for entry in "${RETIRED_SKILLS[@]}"; do
    name="${entry%%=*}" marker="${entry#*=}"
    for dir in "$CLAUDE_DIR/skills/$name" "$AGENTS_SKILLS_DIR/$name"; do
      if grep '^description:' "$dir/SKILL.md" 2>/dev/null | grep -qF -- "$marker"; then
        echo "$dir"
      fi
    done
  done
}

# step <label> <command...>: run quietly; on failure print the log tail and stop.
step() {
  local label="$1"; shift
  if "$@" >"$LOG" 2>&1; then
    echo "  ✓ $label"
  else
    echo "  ✗ $label failed:" >&2
    tail -20 "$LOG" >&2
    exit 1
  fi
}

if [ "$install" = 1 ]; then
  branch="$(git symbolic-ref --short HEAD 2>/dev/null || echo DETACHED)"
  if [ "$branch" != master ]; then
    echo "error: on '$branch'; reinstall from master" >&2; exit 2
  fi
  if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
    echo "error: tracked changes present; commit or stash them first" >&2; exit 2
  fi
  if [ "$pull" = 1 ]; then
    step "git pull ($(git rev-parse --short HEAD) → origin)" git pull --ff-only -q
    # The pull may have changed this script (a new retired skill); run the new copy.
    exec bash "$REPO_DIR/scripts/reinstall-all.sh" --no-pull
  fi
  for dir in $(retired_dirs); do
    step "retired skill trashed: $dir" trash "$dir"
  done
  step "skills ($SKILLS_SOURCE)" npx -y skills add "$SKILLS_SOURCE" -a claude-code -g -y
  step "agents" env CLAUDE_DIR="$CLAUDE_DIR" bash scripts/install-agents.sh
  step "git hooks" bash scripts/install-git-hooks.sh --force
  step "zharness" bash scripts/install-zharness.sh
fi

failed=0
row() { # row <ok:0|1> <kind> <name> [detail]
  if [ "$1" = 0 ]; then printf '  ✓ %-7s %s\n' "$2" "$3"
  else printf '  ✗ %-7s %s  %s\n' "$2" "$3" "${4:-}"; failed=1; fi
}

echo "Installed state ($(git symbolic-ref --short HEAD 2>/dev/null || echo DETACHED) $(git rev-parse --short HEAD)):"
while IFS= read -r skill_md; do
  src="$(dirname "$skill_md")"
  name="$(basename "$src")"
  dest="$CLAUDE_DIR/skills/$name"
  bad=""
  while IFS= read -r f; do
    cmp -s "$f" "$dest/${f#"$src"/}" || { bad="${f#"$src"/}"; break; }
  done < <(git ls-files "$src")
  if [ -z "$bad" ]; then row 0 skill "$name"; else row 1 skill "$name" "differs or missing: $bad"; fi
done < <(git ls-files 'skills/*SKILL.md')

for src in agents/*.md; do
  name="$(basename "$src" .md)"
  if cmp -s "$src" "$CLAUDE_DIR/agents/$name.md"; then row 0 agent "$name"
  else row 1 agent "$name" "differs or missing"; fi
done

for dir in $(retired_dirs); do row 1 retired "$dir" "still installed"; done

hook="$(git rev-parse --path-format=absolute --git-path hooks)/pre-commit"
if grep -q 'ZGUARD-CORE-BEGIN' "$hook" 2>/dev/null; then row 0 hook pre-commit
else row 1 hook pre-commit "missing or not the guard hook"; fi

if version="$(zharness --version 2>/dev/null)"; then row 0 cli "$version"
else row 1 cli zharness "not on PATH"; fi

exit "$failed"
