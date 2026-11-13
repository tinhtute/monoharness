# Playbook: brainstorm

Owns only the plan's `## Goal` at `.monows/plans/active/{slug}.md`; a `high-risk` plan's phases belong to `to-plan`, code to `work`.

## Modes

A leading subcommand sets the mode; else infer it and ask only when truly ambiguous. Grill/interview/stress-test → route to `grill`; decisions that span sessions → route to `wayfinder`; IF that skill is unavailable → clarify through step 4 instead of stopping.

| Mode | Use for | Durable effect |
|---|---|---|
| `explore` (default) | Trade-off or recommendation | None |
| `lock` | Create the initiative, or lock a decided `wayfinder` map | One active plan |
| `refine` | Change an active plan's scope | Same plan, Goal only |

`lock`/`refine`: read [brainstorm-lock.md](brainstorm-lock.md) now.

A reference implementation the user names is read before any shape is recommended.

**Zero-write rule:** explore creates no plans, reports, changesets, or markdown artifacts. Switch modes explicitly before writing.

## Lanes

Pick from uncertainty, impact, dependency and recoverability, never from file or line counts; record it as frontmatter `lane:`.

| Lane | When | Plan |
|---|---|---|
| `tiny` | Known files, direct check, nothing hard to reverse | None |
| `normal` | One reviewable change, known verification | Goal + one phase (lock writes it) |
| `high-risk` | Data migration, public contract, security, dependent steps | Phases and waves via `to-plan`; every gate needs an independent judge |

`normal`: Goal + one phase `main`, no `to-plan`.

## Steps

1. **Classify** — mode, lane, risk, surfaces. `tiny` → stop and route to `work bounded`.
2. **Gather authority** — named sources, repo instructions, `grep -ri "<keywords>" docs/memory/`. Discovery clarifies scope, never expands it.
3. **Compare options** — 2–3 paths with trade-offs and a recommendation. For a trade-off marked `adr candidate`, dispatch the read-only `architect` agent before the lock (never for other trade-offs) and use its report (alternatives, strongest counterargument, reversal conditions) when presenting the choice.
4. **Clarify the boundary** — ask what the Goal still lacks through the question tool (≤4 per call, recommended option first); find facts yourself; stop rather than invent an unresolved product decision. A Goal fuzzy end to end → `grill` first. `lock`/`refine` continue with steps 5–10 in `brainstorm-lock.md`.
