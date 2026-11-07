# Playbook: brainstorm (chart)

Loaded by [brainstorm.md](brainstorm.md) for `chart`, with [brainstorm-grill.md](brainstorm-grill.md).

Chart when the way to a lockable Goal is fogged: decisions hang on other decisions, facts, or prototypes, and resolving them takes more than one session. A chart plans; it never builds. Code waits for the lock and `work`.

## Map

A chart writes the plan skeleton from [brainstorm-lock.md](brainstorm-lock.md) with a partial Goal, then adds `## Map` right after `## Goal`:

```markdown
## Goal
- outcome: <the destination: what reaching the end of this map looks like>
- success_signal: <checkable once reached>
- requirements: none until the map is decided
- non-goals:
  - NG1: <work ruled beyond the destination>

## Map
- Q1: <precise question> | type: grill | by: HITL | blocked_by: none | status: open
- Q2: <precise question> | type: research | by: AFK | blocked_by: Q1 | status: open
- fog: <an area you can see coming but cannot phrase as a question yet>
```

| Type | By | Resolves through |
|---|---|---|
| `grill` | HITL | the user's answer, per [brainstorm-grill.md](brainstorm-grill.md) |
| `prototype` | HITL | a throwaway artifact the user reacts to (`prototype` playbook) |
| `research` | AFK | a fact from `read`, `learn`, or `librarian` |
| `task` | HITL or AFK | a manual step that unblocks a decision (access, sign-up, sample data) |

**Question or fog** — a question you can state precisely now is a `Q` line, even when blocked; anything vaguer stays a `fog:` line. Do not pre-slice fog.

Current State while charting: `lifecycle_status: planned`, `open_items: <n> map lines`, `exact_next_action: brainstorm chart`; `session-pickup` resumes from it.

## Steps

1. **Chart** — confirm no non-empty plan exists under `.harness/plans/active/`; IF one exists → stop and name it. Grill the destination first (`outcome`, `success_signal`), then grill breadth-first for the frontier. IF every decision is answerable this session and no fog shows → no chart: run `grill`, then `lock`. Write the skeleton, the partial Goal, and `## Map`.
2. **Work the map** — the frontier is every `open` line whose `blocked_by` lines are decided. Fan out every frontier `research` line to sub-agents in parallel, briefed per `work-full.md` step 4. Resolve at most one HITL question per session, through the question tool; never answer your own grill.
3. **Record** — set the line to `status: decided → <one-line answer> | evidence: <path, URL, or SHA>`; the answer lives on that line only. Promote any fog the answer made precise into new `Q` lines. A line past the destination becomes `status: out-of-scope` plus a `non-goals:` entry. A decision that invalidates another line → edit or drop that line.
4. **Graduate** — once every `Q` line is `decided` or `out-of-scope` and no `fog:` line remains, derive numbered requirements from the decisions (`source: Q<n>`), then finish this same plan with [brainstorm-lock.md](brainstorm-lock.md) steps 6 and 8–10; its own chart satisfies step 7. `## Map` stays as the decision record.

In replies, name a question by its text, not a bare `Q` id.

**Reply:** the destination, decided this session, the next frontier, and the fog left.
