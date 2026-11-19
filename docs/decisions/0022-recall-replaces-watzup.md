# 0022 — `recall` replaces `watzup`; transcript and source findings stay unverified leads

## Status

Accepted 2026-11-19 (owner's call). Supersedes decision 2 of [0019](0019-arena-and-transcript-recall.md); its decision 1 (implementation arena) stands.

## Context

ADR 0019 decision 2 deferred transcript recall until a `LOST_DECISION` block was recorded, and fixed the limits for a later build: opt-in through a `watzup recall` argument only, the newest 3 sessions, at most 40 output lines, no new skill, no transcript text leaving the machine (`0019-arena-and-transcript-recall.md:25`–`:32`). No `LOST_DECISION` block has been recorded since.

The owner compared the harness skill names against pstack and asked for pstack's `recall` instead of `watzup` (2026-11-19). The two answer different questions. `watzup` read only Git and the active plan. pstack's `recall` (cursor/plugins `e58dd04`, 0.15.44) rebuilds working context from the user's recent chat transcripts and a sweep of shared sources, then verifies them against `git` and `gh`. Three playbooks called `watzup` for the cheap Git recap: `ship` (commits since the last tag), `retro` and `session-pickup`.

## Decision

Replace the `watzup` skill with `recall`, in two modes (`skills/stages/recall/references/recall.md:5`):

- `recall state` runs watzup's four steps unchanged (`recall.md:18`–`:32`). `ship`, `retro` and `session-pickup` call it by name (`skills/poteto/playbooks/ship.md:22`, `retro.md:3`, `session-pickup.md:3`).
- Full `recall [topic]` adds steps 5–8 (`recall.md:33`–`:36`). It mines the last 7 days of this repository's Claude Code transcripts through parallel read-only subagents and sweeps GitHub and every MCP source already connected in the session. It sends only topic terms to a source, never transcript text, and verifies every artifact with `git` and `gh`.

The owner chose each point (2026-11-19): replace rather than add beside `watzup`; a 7-day window with fan-out over ADR 0019's newest 3 sessions; MCP sources included; one PR without a plan.

From ADR 0019 these limits stand, because nobody overturned them. A transcript or source finding is a `lead (unverified)` until Git or GitHub confirms it, and it is never written to the plan, its Log or its Validation (`recall.md:14`). Secrets and tokens are redacted from the output. The repository stays the system of record (`AGENTS.md` Harness section).

Rejected:
- Bare rename with the full sweep as the only mode. Every `ship` would then mine a week of transcripts to list commits since a tag.
- Keeping `watzup` beside a new `recall`. This was the agent's recommendation. The owner chose one entry point.
- The `watzup recall` argument within ADR 0019's limits. Three sessions miss the week-old context the owner wants, and it has no source sweep.

## Consequences

One skill answers "where did I leave off". Its cheap mode keeps the old cost for playbook steps. Cross-session decisions that never reached the repository can now be found, but only as labelled leads.

Costs:
- Full `recall` reads data outside the repository. It sends topic terms to connected third-party services, and spends several subagent runs per call.
- Consumer repositories keep a projected `WORKFLOW.md` that names `watzup` until a `zharness` release carries the new router (`cli/docs/embedded/WORKFLOW.md:20`).
- Machines keep an installed `watzup` until `scripts/reinstall-all.sh` retires it (`RETIRED_SKILLS`).
- `cli/src/installer/retirement.rs` keeps `watzup.md` in its fixed legacy-playbook inventory (ADR 0015). That entry names an old consumer playbook file, not the skill.

## Authority

The owner's answers in the session of 2026-11-19. Upstream: https://github.com/cursor/plugins/blob/e58dd04/pstack/skills/recall/SKILL.md. Superseded limits: `docs/decisions/0019-arena-and-transcript-recall.md:25`–`:32`.
