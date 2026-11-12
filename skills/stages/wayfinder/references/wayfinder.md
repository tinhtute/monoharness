# Playbook: wayfinder

Use when the way to a lockable Goal is fogged: decisions hang on other decisions, facts, or prototypes, and resolving them takes more than one session. Keeps a decision map in the one active plan at `.monows/plans/active/{slug}.md`, resolves it one decision at a time, then hands it to `brainstorm lock`. A map plans; it never builds. Until the lock, it owns only that plan's partial `## Goal` and `## Map`.

## Map

A new map writes this file; set `lane:` per `brainstorm` § Lanes (the lock may revise it with approval):

```markdown
---
status: active
lane: normal
---
# <Title>

## Goal
- outcome: <the destination: what reaching the end of this map looks like>
- success_signal: <checkable once reached>
- actors: <who uses or is affected by the change>
- authority: <owner decision, spec, or source files>
- requirements: none until the map is decided
- non-goals:
  - NG1: <work ruled beyond the destination>

## Map
- Q1: <precise question> | type: grill | by: HITL | blocked_by: none | status: open
- Q2: <precise question> | type: research | by: AFK | blocked_by: Q1 | status: open
- fog: <an area you can see coming but cannot phrase as a question yet>

## Phases and Verification
- approach: not-planned

## Log

## Validation

## Current State and Next Action
- active_phase: none
- lifecycle_status: planned
- blockers: none
- open_items: <n> map lines
- exact_next_action: wayfinder
```

| Type | By | Resolves through |
|---|---|---|
| `grill` | HITL | the user's decision, through `grill` scoped to that one question |
| `prototype` | HITL | a throwaway artifact the user reacts to (`prototype` playbook) |
| `research` | AFK | a fact from `read`, `learn`, or `librarian` |
| `task` | HITL or AFK | a manual step that unblocks a decision (access, sign-up, sample data) |

**Question or fog** — a question you can state precisely now is a `Q` line, even when blocked; anything vaguer stays a `fog:` line. Do not pre-slice fog.

**Prototype guard** — use `prototype` only when no grill or research can decide it; the line names the decision it unblocks and a cap (`cap: <time or sessions>`). Past the cap → turn it back into a `grill` line.

## Steps

1. **Start** — IF the one non-empty plan under `.monows/plans/active/` holds `## Map` and `requirements: none until the map is decided` → this is a resumed map: go to step 2. IF any other non-empty plan exists → stop and name it. Else ask the user for the destination (`outcome`, `success_signal`), then grill breadth-first only to name the frontier's questions, not to answer them. IF every decision fits this session and no fog shows → no map: run `grill`, then `brainstorm lock`. Write the file above; this session resolves nothing else.
2. **Work the map** — the frontier is every `open` line whose `blocked_by` lines are all `decided`. Fan out every frontier `research` line to sub-agents in parallel, briefed per `work-full.md` step 4 of `work`. Resolve at most one HITL question per session: a `grill` line runs `grill` on that question for as many rounds as it takes; never answer your own grill.
3. **Record** — set the line to `status: decided → <one-line answer> | evidence: <path, URL, SHA, or user YYYY-MM-DD>`; the answer lives on that line only. Promote any fog the answer made precise into new `Q` lines. A line past the destination becomes `status: out-of-scope` plus a `non-goals:` entry; every line it blocks is dropped, marked out-of-scope, or loses that edge. A decision that invalidates another line → edit or drop that line. Update `open_items:`.
4. **Graduate** — once every `Q` line is `decided` or `out-of-scope` and no `fog:` line remains → run `brainstorm lock` on this same plan; it keeps `## Map` as the decision record, derives requirements from the decisions, and writes the lane's phase and next action.

In replies, name a question by its text, not a bare `Q` id.

**Reply:** the destination, decided this session, the next frontier, and the fog left.
