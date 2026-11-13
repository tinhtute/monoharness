---
status: active
lane: normal
---
# Supervisor–Lead–Peer: decide the audit's three options

## Goal
- outcome: each option in `docs/research/2026-11-12-supervisor-lead-peer-audit.md` (PR #275) is decided adopt, reject, or defer, with the scope of each adopted one stated, ready for `brainstorm lock`
- success_signal: every `Q` line below is `decided` or `out-of-scope`, no `fog:` line remains, and each of the three options maps to at least one decided line
- actors: the owner; the main agent as Lead; the `scout`, `worker`, `engineer`, `verifier` agents; the risk judge
- authority: owner decisions via `grill`; ADR 0020 (`docs/decisions/0020-orchestrate-and-autopilot.md`); `skills/stages/check/references/check-risk.md`; `skills/stages/work/references/work-fanout.md`
- requirements: none until the map is decided
- non-goals:
  - NG1: building any option; this map plans, `work` builds after the lock
  - NG2: a standing multi-repo Supervisor session; the audit already defers it to multi-repo or multi-day runs

## Map
- Q1: Where does the Lead self-accept today without an independent judge: only PR Land, or also `check` on bounded low-risk changes the main agent wrote itself? | type: research | by: AFK | blocked_by: none | status: open
- Q2: Can a separate Claude Code session read the Lead's live `~/.claude/projects/<project>/*.jsonl` and relay one finding to it through `SendMessage`, end to end? | type: research | by: AFK | blocked_by: none | status: open
- Q3: Option 1 — which path must get an independent judge so the Lead never accepts its own work, given that a judge cannot lower an always-review verdict (as on #273)? | type: grill | by: HITL | blocked_by: Q1 | status: open
- Q4: Option 2 — adopt an Architect disposition, and if so, as a new read-only agent file or as a `verifier` brief mode? | type: grill | by: HITL | blocked_by: none | status: open
- Q5: Option 3 — adopt the event-triggered `retro` as a light Supervisor, and on which events (fanout wave end, `orchestrate` round)? | type: grill | by: HITL | blocked_by: Q2 | status: open
- fog: whether `worker` and `engineer` should collapse into one Peer profile at two tiers (they differ in model, `maxTurns`, and `worker`'s missing-VERIFY `BLOCKED (spec)` line)

## Phases and Verification
- approach: not-planned

## Log

## Validation

## Current State and Next Action
- active_phase: none
- lifecycle_status: planned
- blockers: none
- open_items: 6 map lines
- exact_next_action: wayfinder
