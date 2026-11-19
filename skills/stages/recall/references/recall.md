# Playbook: recall

Read-only. Rebuilds working context from live state (Git and the plan at `.monows/plans/active/{slug}.md`) and, in full mode, from recent chat transcripts and connected sources.

| Mode | Trigger | Steps |
|---|---|---|
| `state` | `recall state`, or a playbook step that names it | 1–4 |
| full | `recall` or `recall <topic>` | 1–8 |

## Preconditions

1. Select the active plan by name: exactly one non-empty file may exist under `.monows/plans/active/*.md`; IF more → name every candidate and stop.
2. Remain read-only: no writes, commits, gates, or code changes.
3. Transcripts and connected sources yield leads, not evidence: label each `lead (unverified)` until step 8 confirms it against Git or GitHub, and never write one to the plan, its Log or its Validation.

## Steps

1. **Branch state** — resolve the base (do not assume `main`):

   ```sh
   base=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
   [ -z "$base" ] || git show-ref --verify --quiet "refs/heads/$base" || base=""
   [ -n "$base" ] || for c in main master; do
     git show-ref --verify --quiet "refs/heads/$c" && base=$c && break
   done
   [ -n "$base" ] || base=$(git branch --show-current)
   ```

   Then `git status -sb`, `git log --oneline "$base..HEAD"`, `git rev-list --left-right --count "$base...HEAD"`. IF base is the current branch → report status only.
2. **Plan by section** — never the whole file (slice as in `work-full.md` step 1): `## Goal` head, Current State, the `## Log` and `## Validation` tails; a plan with `## Map` → also its frontier (`open` lines whose `blocked_by` lines are all `decided`) and the `fog:` count. Read task execution status only from append-only `## Log`, the sole task execution-status source.
3. **WIP** — the working-tree diff, top five files; flag incomplete work or missing proof.
4. **Risks** — blockers verbatim, missing tests, large uncommitted diffs, contract breaks, secrets. No invented reassurance.
5. **Scope** (full only) — pin the window (default the last 7 days), the topic if named, and the workspace: this repository's transcripts in `~/.claude/projects/<slug>/`, where `<slug>` is the absolute working directory with every character outside `A-Za-z0-9` replaced by `-`. State the scope back. Never shrink "all" to "recent N"; read another project's transcripts only when asked.
6. **Transcripts** — order sessions by modification time (`command ls -t`, never by UUID name), skip the current session and subagent, eval and test sessions, grep the topic first, then read only the matching regions. More than two matching sessions → split them across parallel read-only subagents on a fast model. Each returns per session: topic, the user's goal, decisions, open threads, corrections, artifacts (PRs, branches, issues), each cited by session ID. Raw transcript text stays in the subagents.
7. **Connected sources** — when the topic names a feature, file, subsystem or bug; skip only for activity recall with no named target ("what did I do this week"). Run in parallel with step 6: GitHub through `gh` (issues, PRs, reverted PRs), and each MCP source already connected in this session (issue tracker, chat, docs, error tracking) through one subagent that has MCP tools, briefed to read only (no posts, comments or edits). Ask each: current state, what was tried and did not hold, what users still report. Send only the topic terms, never transcript text. Skip a source that needs authentication and name it; a null result is a finding.
8. **Verify** — check every PR, branch and issue from steps 6–7 with `git` and `gh`. A lead Git or GitHub confirms loses its `lead (unverified)` label; one they contradict is dropped and named.

## Output

`state`: in order: branch and tree state; plan, phase, status; done and WIP; risks and proof gaps; one exact next action (the plan's, IF it still matches Git).

Full, stay on the topic, redact secrets and tokens:

- **Capsule** — at most 5 bullets: what the work is and where it stands, including steps 1–4.
- **Threads** — one line each, tagged with exactly one of `[merged #N]`, `[open PR #N]`, `[in flight <branch>]`, `[verified, uncommitted]`, `[reverted #N]`, `[planned, not started]`; cite a session ID or a source (PR #, issue ID, permalink).
- **Problems** — at most 5 recurring ones, including symptoms users keep reporting and fixes that shipped and were reverted.
- **Next move** — one exact action.
