# Codify — turn a recurring pattern into a skill, rule, or script

Loaded by `retro.md` when a finding's fix would create a new skill, script, or
global rule, when a standing preference needs recurrence, or when the user asks for
`retro codify` (mine several sessions instead of one). § 1 replaces only
`retro.md` step 1's session loading; its other steps still apply: the output is still findings in its step 5 schema, and any edit
still waits for its step 6 approval. Supervisor mode does not use this file.

## 1. Mine several sessions

- Scope: this project's sessions only, `~/.claude/projects/<cwd slug>/*.jsonl`
  (step 1's path in `retro.md`). Never read another project's directory; it
  holds unrelated private work.
- Window: the last 3 weeks, at most 15 sessions, newest first
  (`ls -t`). The user can name a different window.
- Digest each session with `python3 scripts/session-digest.py <id>`.
  Over 5 sessions → split them into 3 slices by date and dispatch one `scout`
  per slice with the session ids; each returns patterns with evidence
  (session id plus digest line or turn), not conclusions.
  On Claude Code in Code Mode (`REPL` and `Poll` tools), digest the whole window in one script, each call with
  `.nothrow()`; over 5 sessions, write each slice's digests to a scratch file
  outside the repo and brief its scout with that path.
- Hunt these signals:
  - a user correction or redirect, and a rejected `(Recommended)` answer
  - the same command sequence (3 or more tool calls, same order) re-typed
  - a multi-step procedure the agent re-derived, or the user re-explained
  - the same file or doc searched for or read in full again
  - the same error class hit again (same tool, same failure)
  - a standing preference: length, tone, format, delegation, what "done" means

## 2. Count before promoting

For each pattern, count `S`: distinct sessions with citable evidence. Merge
what the slices report before counting; one session counted twice is still 1.

| Count | Grade | Use |
|---|---|---|
| contradicted in any session | conflict | `fix mode: human`: ask the user which holds |
| `S >= 2` | high | may stand as a finding on its own |
| `S = 1` | weak | evidence for another finding, never a new skill, script, or global rule on its own |

A fix to an artifact that already exists (a broken check, a stale pointer, a
wrong skill step, one more line in a review doc) needs no recurrence; the
one-session retro covers it.

## 3. Pick the artifact

Extend before you create. List what exists first: the repo's `skills/`,
`scripts/` and gate list, `~/.claude/skills/`, and `~/.claude/rules/`. When an
existing skill's description would already trigger on the pattern, extend that
skill's `references/` or `scripts/` instead of adding a skill.

| Pattern | Threshold | `home` | How it is built |
|---|---|---|---|
| Mechanical violation of an accepted rule | `S >= 1` | check | guard mode, `encoding-invariants.md` |
| Same deterministic command sequence | `S >= 2` and 3+ runs in total | script, in the owning skill's `scripts/` or repo `scripts/`, plus one fixture | experiment mode |
| Procedure of 3+ steps with judgement, a nameable trigger, and no skill covering it | `S >= 2` | skill (a new one, or a reference in an existing one) | `create-skill` from monoclaudian |
| Judgement rule a reviewer should apply | `S >= 1` | review surface | experiment mode |
| Standing user preference | `S >= 2`, no contradiction | global rule, in monoclaudian `rules/*.md` | experiment mode |
| The agent looked in the wrong place | `S >= 1` | steering: a pointer in `AGENTS.md` | experiment mode |
| Reference knowledge the agent lacked | `S >= 1` | docs, extend before you create | experiment mode |

Authoring tools live outside this skill. `create-skill` and the global rules
are in [monoclaudian](https://github.com/tinhtute/monoclaudian): use them when
they are installed; otherwise say which one is missing and stop at the finding.

## 4. Draft rules

- Write a specific, non-default rule ("tables when comparing options"); a generic one ("communicate clearly") is dropped.
- Point to other skills and docs by path; never paste their text.
- Add a section only when it holds such a rule; leave out empty sections instead of matching another file's shape.
- Write "the user", not a person's name.
- Follow `docs/guides/prompt-engineering-principles.md` when the repo has it.

## 5. Report and gate

Each promoted pattern is one `retro.md` step 5 finding: `recurrence` names `S`
and the session ids, `home` takes the value from the table in § 3. The 5-finding cap and the one
`Next` apply across all mined sessions. Step 6 builds only the approved
`Next`. A new skill, script, or global rule runs in experiment mode, and is called an
improvement only after a fresh session reruns the job.

## Not for

- The user asks for one named skill → `create-skill` directly; nothing to mine.
- A personal "mode" skill that holds the user's conventions → standing preferences go to global rules, the one home they already have.
