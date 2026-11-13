# Playbook: grill

Turns a fuzzy idea, or a plan to validate, into decisions the user made. Writes nothing: a result worth keeping goes to `brainstorm lock`, or `brainstorm refine` on an active plan.

## Modes

| Mode | Use for |
|---|---|
| default | Grill until the **Done** condition below holds |
| `raw` | Fast first pass: at most 2 rounds, then print decided / assumed / open; no lock offer |

## Grill

Grill until the **Done** condition below holds. Map decisions as a tree and work in rounds.

- **Frontier** — every open decision whose prerequisites are settled; ask it all in one round (question tool, ≤4 per call, recommended option first). Recompute after each answer; a contradiction reopens its branch.
- **Facts vs decisions** — find facts yourself (repo, docs, `docs/memory/`, or a sub-agent briefed per `work-full.md` step 4 of `work`); put decisions to the user.
- **Stress-test** — one canonical term per concept (reuse `.monows/PROJECT.md`); probe edge cases; raise code-vs-statement contradictions as questions.
- **Absent owner** — `open_question: <question> | owner: <who>`; it blocks the lock only if it blocks a requirement.
- **Too big** — the tree holds decisions that cannot all be made this session, or that wait on facts, prototypes, or other people → stop and offer `wayfinder`.
- **Done** — the next stage (lock for normal, `to-plan` for high-risk) could proceed without asking: concrete `outcome`, checkable `success_signal`, `actors`, `authority`, requirements each with `acceptance:`, `non-goals`. Summarize the tree, list open questions, mark hard-to-reverse trade-offs `adr candidate`, dispatch the read-only `architect` agent for each one (never for other trade-offs) and present the choice with its report (alternatives, strongest counterargument, reversal conditions), then ask: lock (or refine) now?
- **Grill on a plan** — Goal gaps → offer `brainstorm refine`; gaps in planned phases are findings (phases are immutable).
- **One question** — `wayfinder` hands over a single map question: Done is that question decided; return the answer and stop.

**Zero-write rule:** grill creates no plans, reports, changesets, or markdown artifacts until the user approves `brainstorm lock` or `refine`.
