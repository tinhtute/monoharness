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
#   bash scripts/reinstall-all.sh --autostash # stash tracked edits for the run, restore them after
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
  "watzup=Recap: read branch state"
)
LOG="$(mktemp)"
# The stash this run made, passed to the pulled copy across its exec as the internal
# --autostash-ref argument (never from the environment). It is restored on exit, after
# the status table, so the table compares the committed files. A restore never touches
# a file the pull also changed: it keeps the stash and leaves the pulled tree as it is.
STASH=""
# shellcheck disable=SC2329 # invoked by the EXIT trap
restore() {
  rm -f "$LOG"
  [ -n "$STASH" ] || return 0
  local overlap
  overlap="$(comm -12 \
    <({ git diff --name-only "$STASH^1" "$STASH"; git diff --name-only "$STASH^1" "$STASH^2"; } | sort -u) \
    <(git diff --name-only "$STASH^1" HEAD | sort -u) | paste -sd ' ' -)"
  if [ -n "$overlap" ]; then
    echo "error: could not restore the autostash: the pull also changed $overlap; the tree is left at $(git rev-parse --short HEAD) and your changes are kept in stash $STASH (git stash pop --index once resolved)" >&2
    exit 1
  fi
  if [ "$(git rev-parse -q --verify refs/stash 2>/dev/null)" = "$STASH" ] && git stash pop -q --index >/dev/null 2>&1; then
    echo "  ✓ tracked changes restored from the autostash"
  else
    echo "error: could not restore the autostash cleanly; your changes are kept in stash $STASH (git stash list)" >&2
    exit 1
  fi
}
trap restore EXIT

usage() { echo "usage: $0 [--no-pull | --verify] [--autostash]" >&2; exit 2; }
pull=1 install=1 autostash=0 stash_ref=""
for arg in "$@"; do
  case "$arg" in
    --no-pull) pull=0 ;;
    --verify) pull=0 install=0 ;;
    --autostash) autostash=1 ;;
    --autostash-ref=*) stash_ref="${arg#--autostash-ref=}" ;;
    *) usage ;;
  esac
done
[ "$install" = 1 ] || [ "$autostash" = 0 ] || usage

cd "$REPO_DIR"
# Only the stash on top that this script made is restored; anything else is refused.
if [ -n "$stash_ref" ]; then
  case "$(git log -1 --format=%s refs/stash 2>/dev/null)" in
    *": reinstall-all autostash") [ "$(git rev-parse -q --verify refs/stash)" = "$stash_ref" ] || usage ;;
    *) usage ;;
  esac
  STASH="$stash_ref"
fi

# retired_dirs: paths that hold a retired harness skill, one per line: every per-skill
# symlink, and each real directory once (~/.claude/skills itself is often a symlink to
# ~/.agents/skills). Order does not matter: trashing a link leaves its target, and
# trash removes a link whose target is already gone. A link's target is listed only
# when it sits directly in one of the two skill dirs; a target elsewhere (a dev
# checkout) is never trashed.
retired_dirs() {
  local entry name marker dir real root roots=$'\n' seen=$'\n'
  for root in "$CLAUDE_DIR/skills" "$AGENTS_SKILLS_DIR"; do
    root="$(cd "$root" 2>/dev/null && pwd -P)" && roots+="$root"$'\n'
  done
  for entry in "${RETIRED_SKILLS[@]}"; do
    name="${entry%%=*}" marker="${entry#*=}"
    for dir in "$CLAUDE_DIR/skills/$name" "$AGENTS_SKILLS_DIR/$name"; do
      grep '^description:' "$dir/SKILL.md" 2>/dev/null | grep -qF -- "$marker" || continue
      real="$(cd "$dir" 2>/dev/null && pwd -P)" || real=""
      if [ -L "$dir" ]; then
        echo "$dir"
        case "$roots" in *$'\n'"$(dirname "$real")"$'\n'*) ;; *) continue ;; esac
      fi
      [ -n "$real" ] || { echo "$dir"; continue; }
      case "$seen" in *$'\n'"$real"$'\n'*) continue ;; esac
      seen+="$real"$'\n'
      if [ -L "$dir" ]; then echo "$real"; else echo "$dir"; fi
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
    if [ "$autostash" = 1 ] && [ -z "$STASH" ]; then
      step "tracked changes stashed" git stash push -q -m "reinstall-all autostash"
      STASH="$(git rev-parse refs/stash)"
    else
      echo "error: tracked changes present; commit or stash them first, or pass --autostash" >&2; exit 2
    fi
  fi
  if [ "$pull" = 1 ]; then
    step "git pull ($(git rev-parse --short HEAD) → origin)" git pull --ff-only -q
    # The pull may have changed this script (a new retired skill); run the new copy.
    exec bash "$REPO_DIR/scripts/reinstall-all.sh" --no-pull ${STASH:+"--autostash-ref=$STASH"}
  fi
  retired="$(retired_dirs)" # listed in full before any trash changes what it sees
  while IFS= read -r dir; do
    [ -z "$dir" ] || step "retired skill trashed: $dir" trash "$dir"
  done <<<"$retired"
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

while IFS= read -r dir; do
  [ -z "$dir" ] || row 1 retired "$dir" "still installed"
done <<<"$(retired_dirs)"

hook="$(git rev-parse --path-format=absolute --git-path hooks)/pre-commit"
if grep -q 'ZGUARD-CORE-BEGIN' "$hook" 2>/dev/null; then row 0 hook pre-commit
else row 1 hook pre-commit "missing or not the guard hook"; fi

if version="$(zharness --version 2>/dev/null)"; then row 0 cli "$version"
else row 1 cli zharness "not on PATH"; fi

exit "$failed"
