# Playbook: orchestrate

A standing program handed to one coordinator: multi-day, many PRs, few owner turns. One in-session wave is [fanout](fanout.md); a queue of PRs taken to verified or merged is [autopilot](autopilot.md); work one agent finishes in the session is not a program. The coordinator (the main agent) runs the program, never the code: it decides which agent does each unit and checks what each one produces. The brief template, retry by cause, and the PR-owner force-push and respawn lease rules live in [work-fanout.md](../../stages/work/references/work-fanout.md); follow them there.

Rules for the whole run:

- **Two levels, one PR owner per PR:** the coordinator and the agents it spawns; `lead` and `worker` cannot spawn agents of their own. A `lead` (judgment) or `worker` (mechanical) agent in its own worktree (`isolation: worktree`) is the only writer of its branch; conflicts, rebases and fixes go to the PR owner, never to the coordinator. The owner's program request covers each PR owner pushing its own branch and opening its PR; no PR owner merges, merging stays with [ship.md § Land](ship.md#land).
- **A verifier per PR:** `verifier`, a different model family from the PR owner (or the same family when the session's `advisorModel` is `fable`), read-only; its verdict covers one patch at one head SHA and carries across a rebase only under the `git patch-id` and base-change rule in [autopilot.md](autopilot.md); any other new push needs a new verdict.
- **Standing Orders:** paste the plan's `## Standing Orders` into every spawn and retry brief, PR owners and verifiers alike.
- **Rolling window:** at most 10 agents in flight; when a unit lands or is blocked, spawn the next ready unit instead of waiting on the batch.
- **Live state:** read `gh pr view` and `gh pr checks` before any report or decision, never an agent's last report; liveness comes from branches, `git status`, the task list and `gh`. Never resume an agent to ask status: judge it by its pushes and PR activity.
- **State:** the plan `## Log` only; every spawn, retry, verdict, `done` and `blocked` is an entry naming model, branch and SHA, and every spawned agent ends as `done`, replaced, absorbed into another's scope, or `blocked`. Nothing lives outside the plan and git/`gh`.
- **Ask the owner only for a real decision:** an irreversible action, a product or preference call no experiment settles, a dead end that survived a replan, or a PR Land leaves for review. Rebases, retries, CI flakes, review triage and "keep going?" never reach the owner.
- **Runtime:** in-session plus a Claude Code `/loop` audit, e.g. `/loop 1h`: read `gh` and the Log, judge each agent by pushes and PR activity, refill the window. Agents end with the session; next session `session-pickup` respawns PR owners: read each unit's branch, SHA and model from the `## Log`, read live `gh pr view` first, then respawn its PR owner with the lease rule from work-fanout.md.

1. `brainstorm` — frame the program in the plan: the goal, the units, each unit's done evidence (a command and its expected output, or an artifact), and a `## Standing Orders` section holding the rules every agent gets. A unit whose evidence you cannot name is not scoped yet.
2. `work full` — canary: take one unit end to end (brief, PR owner, verifier, Land) before fanning out, so a flaw in the brief costs one agent instead of fifty.
3. `work full` — fan out: brief each PR owner per work-fanout.md with an explicit model and the PR-owner exception under FORBIDDEN; spawn in the background and keep the window full.
4. `check full` — per PR, the verifier reads the diff, not the summary; green CI is an input, not a verdict. Send back work that drifts past scope; keep only fixes that block the program and park the rest as follow-ups.
5. `git` — land each verified PR only via [ship.md § Land](ship.md#land): its own risk judge binds the head SHA and merges only with the base's opt-in; `merge-ready` or needs-review goes to the owner.
6. `work full` — supervise: stop or replace an agent that stalls or loops; retry by cause per work-fanout.md, then `blocked` and replan around it. A stopped agent that returns late: check its result against the PR's live state and hand unique findings to a fresh PR owner.
7. `handoff` — keep Current State and the `## Log` current at every step, so `session-pickup` can respawn each PR owner from its logged branch and SHA.

Reply: what landed against the goal, each PR's live `gh` state and verdict SHA with its link, what was dropped and why, and the decisions waiting on the owner.
