# Playbook: hillclimb

Sustained improvement of one measurable thing toward a target, run as a loop. A one-off regression or a single slow path is `perf`; this is the loop around many attempts. The main agent owns the metric and the experiment's integrity: it supervises and reviews, and delegates the attempts.

Core rule: one change, one measurement, keep or revert. Never stack untested changes; never claim a win from reading code.

1. `think` — ground the workload before choosing the metric: name the dimensions that move the result (data size, history, state, concurrency) and pick a case that reproduces the complaint; no reproducing case → fix the repro first. Fix one metric, its better direction, and a stop predicate that pairs a target with a floor on attempts (e.g. "≥ 50% better than baseline and ≥ 10 attempts"), so a lucky early win cannot end the run. Use the owner's numbers when given; otherwise agree them.
2. Build the measurement harness, prove it is sensitive, then freeze it. Contrasting workloads must separate as expected; the target case must reproduce the symptom. Vet it per `perf` step 1 (limiter, unit, run count, variance, timed the right work); for a command-line workload use [bench.sh](../scripts/bench.sh). Make it print its error count and a count of work done. Frozen means one repeatable command emitting the metric as a median of N. Record the baseline and a green run of the regression gate (the tests that must keep passing) before any change.
3. `git` — the hillclimb request authorizes local commits on a dedicated branch: create it before the first attempt, never commit attempts to the default branch. Push and PR wait for the owner's ask.
4. Open `decision.tsv` outside the repository (the session scratchpad): one row per attempt with id, hypothesis, change, before, after, delta, tests, verdict (`kept` / `reverted`), note. Read it before each attempt.
5. `hunt` — ground each hypothesis in a named mechanism ("defer X off the boot path because it blocks first paint"), not "try memoizing something". For a performance metric, order hypotheses by the `perf` step 4 mantras; borrow only the order, not its stop rule.
6. `work` — loop, one hypothesis per iteration:
   - Delegate the change to a sub-agent with a tight brief per [work-fanout.md](../../stages/work/references/work-fanout.md) (`worker` for mechanical changes, `lead` for ones needing judgment); review the diff rather than typing it. Independent live hypotheses may run in parallel, one worktree each.
   - Measure before and after on the frozen harness, then run the regression gate.
   - Keep only when the metric moves past noise and the gate stays green; otherwise revert in full. "Might help" is not kept.
   - One commit per kept change, staging only its files (never `git add -A`); with an active plan, log it in `## Log` with the SHA. Write the `decision.tsv` row either way.
   - Unattended runs pace iterations with Claude Code `/loop`; the stop rule stays the predicate from step 1.
7. Push past the first plateau: after several rejects in a row, pivot category, combine near-misses, re-read the source, or try something more radical. Correctness and simplicity outrank the number: revert a win that breaks behavior, keep a simplification that holds the number.
8. Stop when the predicate is met, or when the remaining ideas cost more than they could win. Never relax the predicate to meet it, and never quit while cheap untried hypotheses remain. Stuck → surface it with the log instead of spinning.
9. `check` — compare the final against the baseline on the frozen harness; `git` — PR with the kept commits in landing order, only when the owner asks.

Reply: the metric and target, baseline → final with the percent delta, attempts run (kept vs reverted), each kept change on one line with its SHA, the `decision.tsv` path, and the best untried idea.
