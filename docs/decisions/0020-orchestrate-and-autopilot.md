# 0020 — Port orchestrate and autopilot as `mono` playbooks; every merge goes through Land

## Status

Accepted 2026-11-09; implementation pending (plan `orchestrate-autopilot`, phases `orchestrate` and `autopilot`). The owner asked for this record before implementation, following the [0015](0015-skill-owned-procedures-and-safe-retirement.md) and [0016](0016-lean-workflow-method-latitude.md) precedent. Repository line citations resolve at `5210571`, the base this record was written on; upstream lines resolve at `6b03002`; plan lines resolve in the plan's main-checkout copy at writing. Phases `orchestrate` and `autopilot` rewrite several of the cited lines.

## Context

Upstream pstack (cursor/plugins `pstack/` v0.15.36, commit `6b03002`, MIT, Lauren Tan) has three playbooks this repository lacks:

- `orchestrate` runs a multi-day program. Each PR has one owner and a verifier from a different model family. One canary unit goes end to end before fan-out. Failed workers are retried by cause (`pstack/skills/poteto-mode/playbooks/orchestrate.md:9`, `:13`, `:14`, `:22`).
- `autopilot-full` carries a queue of PRs to merge. Each owner merges its own PR after a swarm verdict (`pstack/skills/poteto-mode/playbooks/autopilot-full.md:8`, `:17`).
- `autopilot-stack` stops at verified and stacks a PR only when it builds on another (`pstack/skills/poteto-mode/playbooks/autopilot-stack.md:5`, `:6`).

Upstream runs them on Cursor runtime: cloud VMs (`orchestrate.md:10`), a Project tracker and store, PR and CI event subscriptions (`orchestrate.md:5`), sub-coordinators up to three levels (`orchestrate.md:11`), and `cursor-team-kit` skills (`autopilot-full.md:10`, `:14`).

This repository skipped them before:

- The `pstack-lessons` plan excluded event-driven orchestration (NG1) and rejected porting pstack's orchestration scripts (`.harness/plans/completed/pstack-lessons.md:20`, `:26`).
- The retro note lists event-driven orchestration among the items the concepts audit rejected (`docs/research/2026-10-22-pstack-retro-5.md:44`, `:47`). The audit itself has no orchestration finding. It skipped pstack's `orch` and `watch-pr` scripts as runtime-specific and below the lightweight bar (`docs/research/pstack-concepts-audit.md:139`).
- The `multi-agent` plan adopted only an orchestrate-lite section in `fanout`, with all state in the plan Log (`.harness/plans/completed/multi-agent.md:11`; `skills/mono/playbooks/fanout.md:14`-`:22`).

The current rules this record changes or relies on:

- `fanout` step 4 allows one fresh retry, then `blocked` (`skills/mono/playbooks/fanout.md:6`). `work-fanout.md` Aggregate step 3 says the same (`skills/stages/work/references/work-fanout.md:58`), and `cli/src/embedded.rs:405` pins its "A second miss → log `blocked`" text.
- No worker may merge, rebase or force-push (`skills/stages/work/references/work-fanout.md:3`, the brief's FORBIDDEN line `:44`).
- `git` owns outward actions such as merge (ADR 0016 inventory, `docs/decisions/0016-lean-workflow-method-latitude.md:24`). The one carve-out is `ship.md` § Land, which merges a low-risk PR only when the base branch's AGENTS.md opts in (`skills/mono/playbooks/ship.md:3`, `:33`-`:44`; `AGENTS.md:93`-`:101`).
- ADR 0016 decision 1 classes FORBIDDEN and outward permission as boundary rules that change only through a new authority record. Decision 3 requires amending authority before such an edit (`docs/decisions/0016-lean-workflow-method-latitude.md:13`, `:41`).

On 2026-11-09 the owner asked to port orchestrate and autopilot, which reverses the earlier skip. An owner request counts as the recorded ask, as in [0018](0018-opt-in-multi-model-review.md) (`docs/research/2026-10-22-pstack-retro-5.md:9`). This ADR is the new authority record that ADR 0016 requires for the boundary changes in decisions 1 and 2 below.

## Decision

The owner (therealtinhtute) made these decisions on 2026-11-09.

1. **Merge authority: `stack` is the default, and `full` merges only through Land.** `autopilot` has two modes. `stack` stops at verified and never merges. `full` routes every merge through [`ship.md` § Land](../../skills/mono/playbooks/ship.md#land): a risk verdict bound to the head SHA from an independent judge, and the `Auto-merge: low-risk` opt-in read from the base branch's AGENTS.md (`skills/mono/playbooks/ship.md:38`, `:40`, `:42`). A PR owner agent never merges by itself. It never applies the `owner-reviewed` or `allow-test-weakening` label (`AGENTS.md:99`, `:100`; `skills/mono/playbooks/ship.md:44`). Rejected: upstream autopilot-full, where each owner merges its own PR (`autopilot-full.md:8`, `:17`). That bypasses Land and its opt-in.
2. **Owner force-push: a scoped exception to FORBIDDEN.** A PR-owner agent may rebase and force-push only its own PR branch, with `--force-with-lease` pinned to the SHA it last pushed. Plain fanout workers stay forbidden to merge, rebase or force-push (`skills/stages/work/references/work-fanout.md:3`, `:44`). Upstream pins the lease to the SHA the owner last pushed or took over (`autopilot-full.md:12`); this rule names only the last pushed SHA. A respawned owner, one that `session-pickup` restarts, has pushed nothing yet: it pins the lease to the SHA the plan `## Log` records for that branch, and only after `git ls-remote` shows that SHA as the remote head; otherwise it logs `blocked` and does not push (coordinator decision, plan `orchestrate-autopilot` Log 2026-11-09T04:27Z). FORBIDDEN is a boundary rule under ADR 0016 decision 1 (`docs/decisions/0016-lean-workflow-method-latitude.md:13`), and this record is the authority that changes it. Rejected: no exception. A PR owner that lives for days could then never rebase onto a moving base.
3. **Retry by cause, at most 2, everywhere.** `work-fanout.md` Aggregate step 3 replaces one fresh retry followed by "A second miss → log `blocked`" (`skills/stages/work/references/work-fanout.md:58`) with a retry chosen by cause:
   - after a context limit, retry with a smaller scope;
   - after a dropped connection, retry with the same brief;
   - after a tool error, retry with a different model.

   After 2 retries the unit is `blocked`. The rule lives in the shared reference, so `fanout`, `orchestrate` and `autopilot` read one rule. Upstream: `orchestrate.md:22`. Rejected: the current single retry, which ignores the cause and re-runs a context-limit failure at the same scope.
4. **Topology: two levels, a root coordinator and workers.** The main agent coordinates. `mono-lead` and `mono-worker` agents own PRs or units. Rejected: upstream's sub-coordinator level, up to three levels (`orchestrate.md:11`). `mono-lead` cannot spawn sub-agents (`agents/mono-lead.md:15`).
5. **Runtime: in-session, plus Claude Code `/loop`.** The coordinator runs in the owner's session. A recurring audit runs as a `/loop`, for example `/loop 1h` (upstream `autopilot-full.md:22`). Claude Code sub-agents end with the session. Across days, the plan `## Log` and the `session-pickup` playbook (`skills/mono/playbooks/session-pickup.md:3`-`:5`) respawn the owners from logged state. Rejected: cloud routines and background agents. They run work and hold state outside the session and the plan.
6. **File shape: two new playbooks, and `fanout` keeps one wave.** A new `orchestrate.md` in `skills/mono/playbooks/` runs a multi-day program and replaces fanout's `## Orchestrate-lite` section (`skills/mono/playbooks/fanout.md:14`). A new `autopilot.md` in the same directory carries a PR queue. `fanout` keeps one in-session wave. Rejected: extending `fanout` in place. It would grow long, and the router could no longer tell a wave, a program and a PR queue apart.
7. **State: the plan `## Log` and git/forge only.** Every spawn, retry, verdict, `done` and `blocked` is a plan `## Log` entry. PR and branch state is read live from git and `gh`. There is no task database and no store. Rejected: upstream's Project tracker and store (`orchestrate.md:5`). AGENTS.md says "There is no task database" (`AGENTS.md:90`).
8. **Delivery split.** `hillclimb` and `pause` go first, as PR #252. `orchestrate` and `autopilot` form this high-risk plan, because they change merge and push boundaries. Rejected: one plan for all four playbooks. It would hold two low-risk playbooks behind a high-risk review.

**Dropped upstream pieces.**

| Upstream piece | Source | Reason |
|---|---|---|
| Cloud VMs and remote owners | `orchestrate.md:10`, `autopilot-full.md:8` | Decision 5: the runtime is in-session; a remote owner holds state outside the plan. |
| PR and CI event and webhook subscriptions | `orchestrate.md:5` | Event-driven orchestration stays rejected (`.harness/plans/completed/pstack-lessons.md:20`, `docs/research/2026-10-22-pstack-retro-5.md:47`). The coordinator reads live `gh` state at each step and at each `/loop` tick. |
| Sub-coordinators | `orchestrate.md:11` | Decision 4: `mono-lead` cannot spawn sub-agents. |
| Project tracker and store | `orchestrate.md:5`, `autopilot-full.md:12` | Decision 7: the plan `## Log` replaces it. |
| Cursor-only skills: `control-ui`, `control-cli`, `deslop` (`cursor-team-kit`) | `orchestrate.md:10`, `autopilot-full.md:10`, `:14` | Not available on Claude Code. A playbook names this repository's skills instead. |

## Consequences

The owner can hand off a multi-day program or a PR queue and still keep one merge gate. `autopilot full` merges through the same Land step as `ship`, so it adds no new route to `main`. The retry rule changes in one shared reference, and all three fan-out playbooks read it.

The costs:

- **Enforcement is prompt-only.** No guard checks that an owner never merges, never applies an override label, or pins its lease. The executable backstops are the existing PR gates: the required `risk-verdict` check and the test-weakening check (`AGENTS.md:48`, `:51`, `:100`).
- **The force-push exception widens a boundary.** It must not leak to plain workers. Phase `orchestrate` has to scope both lines that ban rebasing and force-pushing: the role sentence (`skills/stages/work/references/work-fanout.md:3`) and FORBIDDEN (`:44`). If it changes only one, the two lines contradict each other.
- **A respawned owner has no pushed SHA.** An owner that `session-pickup` respawns has not pushed yet, so it holds no "last pushed" SHA to pin the lease to. Decision 2 settles it: the predecessor's SHA in the plan `## Log` counts only once `git ls-remote` shows it as the remote head, and otherwise the owner logs `blocked` and does not push. This is a coordinator decision (plan Log 2026-11-09T04:27Z), not an owner decision; a stale or missing Log entry blocks the owner instead of letting it push.
- **The retry text is pinned.** `cli/src/embedded.rs:405` pins "A second miss → log `blocked`". The plan Log records the owner's approval to replace that pin with the retry-by-cause wording at equal strength. `fanout.md` step 4 (`skills/mono/playbooks/fanout.md:6`) is a second copy of the rule and changes with it.
- **Nothing runs between sessions.** A `/loop` audit lives only as long as its session. Work an owner has not pushed is lost when the session ends. The program resumes only when the owner opens a session and runs `session-pickup`.
- **The router grows to 17 playbooks** (13 at `5210571`, 15 after PR #252). Routing a request between a wave, a program and a PR queue is a new place to misroute.
- **The `zharness` product boundary is unchanged.** The new playbooks are skill text. The binary installs no orchestration (`README.md:9`, `:131`; `:129` at `5210571`, before PR #252's README edit), and cross-repository orchestration stays out of scope (`docs/guides/workspace-boundaries.md:26`, `:30`).
- **These are adaptations, not copies.** A later upstream change is not picked up automatically.

Recovery: every phase is docs-only, so reverting the phase commit undoes it. Reversing a decision here needs a new record that supersedes this one.

## Authority

- Owner decisions of 2026-11-09, recorded in the Goal authority and Log of plan `orchestrate-autopilot` (`.harness/plans/active/orchestrate-autopilot.md:12`, `:73`-`:75` at writing).
- Upstream cursor/plugins `pstack/` v0.15.36, commit `6b03002`, MIT, Lauren Tan: `pstack/skills/poteto-mode/playbooks/orchestrate.md`, `pstack/skills/poteto-mode/playbooks/autopilot-full.md`, `pstack/skills/poteto-mode/playbooks/autopilot-stack.md`.
- `AGENTS.md:90`, `:93`-`:101` (Harness; Unattended Shipping).
- `skills/mono/playbooks/ship.md:3`, `:33`-`:44` (§ Land).
- `skills/stages/work/references/work-fanout.md:3`, `:44`, `:58`; `skills/mono/playbooks/fanout.md:6`, `:14`; `cli/src/embedded.rs:405`.
- `docs/decisions/0016-lean-workflow-method-latitude.md:13`, `:24`, `:41`.
- Earlier skip: `.harness/plans/completed/pstack-lessons.md:20`, `:26`; `.harness/plans/completed/multi-agent.md:11`; `docs/research/2026-10-22-pstack-retro-5.md:44`, `:47`; `docs/research/pstack-concepts-audit.md:139`.
- `agents/mono-lead.md:15`; `skills/mono/playbooks/session-pickup.md:3`-`:5`.
