# Playbook: session-pickup

1. `watzup` — recap the branch, the dirty tree and the active plan. No plan is active → read the body of the branch's latest `chore(wip)` commit (`git log -1 --grep='^chore(wip)' --format=%H%n%B`), even when later commits or a rebase moved HEAD past it: [pause](pause.md) left the resume state there.
2. Reconcile the plan with Git: a `done` Log entry counts only for the source it names; re-run its check when that source changed.
3. Route the remaining work to the matching playbook; do not redo logged `done` work.

Reply: where the work stands, what was reconciled, and the next action.
