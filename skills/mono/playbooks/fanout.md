# Playbook: fanout

1. `brainstorm` — frame the wave: the outcome, the shape (partition, race or review panel) and the done predicate; work one agent finishes in the session runs sequentially instead.
2. `work full` — separate before spawning per [work-fanout.md](../../stages/work/references/work-fanout.md): one owner per shared file, shared tooling lands first, one worktree per writer.
3. `work full` — spawn the wave in one message, in the background, an explicit model per role and a full brief each.
4. `work full` — aggregate: a report is a claim; accept only after checking its source, diff and acceptance output; retry by cause, at most 2, then `blocked` (work-fanout.md Aggregate step 3).
5. `work full` — integrate one branch at a time, edit held shared files after, run the full phase check on the combined tree.
6. `check full` — a verifier on a different model family is recommended; required judges follow the lane.
7. `git` — commit, push or PR only when the owner asks.
8. `handoff` — record Current State; close the plan after a clean final check.

A design bakeoff (several candidates for one artifact) runs `arena` instead of steps 3–5.

A long or multi-day run of many units or PRs runs [orchestrate.md](orchestrate.md) instead.

Reply: units integrated, blocked and pending, with each one's model, branch and SHA.
