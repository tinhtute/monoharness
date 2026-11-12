# Playbook: work (fan-out)

Loaded by [work-full.md](work-full.md) step 4 when a wave runs tasks on sub-agents. The main agent owns every worker's output: it frames, briefs, integrates and verifies. Workers never merge, rebase, force-push, or edit outside their scope; the one exception, a PR owner rebasing and force-pushing only its own branch, is stated after the brief template.

## When to fan out

- Only tasks the plan marks independent. Work one agent finishes in the session runs sequentially; prefer fewer, broader workers over many thin ones.
- Shape: **partition** (disjoint slices, all required), **race** (N workers on one identical brief; declare `first pass`, `rank all` or `best-of` before spawning), or **review panel** (read-only reviewers on one diff).
- State the done predicate for the wave before spawning: what each worker returns and what the combined tree must pass.

## Separate before spawning

Instructions are not concurrency control; a fence in the brief's prose is not a lock.

1. List each task's write set from its `owner:` scope, then grep the files each task will edit (docs that cite moved paths, CI workflows, `AGENTS.md`, contracts, ignore lists).
2. Any file in two write sets → give it one owner, or hold it for the main agent after the merge. Never let two workers edit one file.
3. A task that moves or rewrites shared tooling (git hooks, scripts a hook or CI calls, installers) lands first; reinstall the hook before spawning the rest, or every other worktree's commit breaks.
4. Each writer gets its own worktree or branch; read-only workers get their own scratch output path outside the repo.

## Models per role

Pass `model` explicitly on every dispatch and name it in the brief; never rely on the parent default. On Claude Code with the harness agents installed (`bash scripts/install-agents.sh`), dispatch the role's agent instead of `general-purpose` so the role and model show in the agent list: `scout` (`haiku`, read-only: file search, log reading, summaries; never code edits or judgment calls), `worker` (`sonnet`), `engineer` (`opus`), `verifier` (`opus` at `high`, read-only, with the session's `fable` advisor, set by `/advisor fable` and inherited by subagents); use `scout` instead of the built-in `Explore`, whose model is not pinned; the Claude Code setup adds `test-runner` (`haiku`, read-only: runs a suite and returns only failures). `models.json` is the policy for these; `scripts/ci/test-agent-models.sh` fails when an agent's `model:` or `effort:` disagrees with it.

| Role | Agent and model |
|---|---|
| Search, log reading, summaries (no edits) | `scout` (fast tier, `haiku`) |
| Bounded edits with a stated check: moves, renames, link fixes, docs, a clear spec with a test | `worker` (worker tier, `sonnet`) |
| Ordinary implementation that needs judgment; migrations, perf, multi-layer changes even with a clear spec | `engineer` (default tier, `opus`) |
| Cross-cutting design, concurrency, subtle algorithms, no precedent in the codebase | `engineer` dispatched with `model: fable` (strongest tier) at `medium` |
| Verifier, judge, cross-review | `verifier`; a different model family from the worker, or the same family when the session's `advisorModel` is `fable` |

A spec you cannot turn into ACCEPTANCE lines is not settled: settle it with the owner (`grill`) before spawning. Higher effort on an open spec only makes more assumptions for the owner, and the clearer the spec, the cheaper the agent that can do it.

The owner's named model wins over this table. Evidence of the model that ran is the dispatch parameter and the sub-agent transcript's assistant `model` field; harness entries such as an advisor attachment are not the worker's model.

## The brief

Pointers, not copies. A field you cannot fill is a task not yet scoped; do not spawn it.

```
GOAL       one sentence a stranger with no chat access can execute
SCOPE      paths it may write; paths it may not; its worktree or branch
CONTEXT    plan path + phase/task id, files to read, upstream reports pasted in full
DESIGN     the current approach as a hypothesis the agent may challenge, or `open`; never the fix in disguise
ACCEPTANCE checkable criteria, one per line
VERIFY     the exact check command, plus known gotchas (hook path, commit-msg format)
TIMEBOX    a time budget; on expiry return partial findings and stop
FORBIDDEN  no merge, rebase, force-push, --no-verify, or fixes outside SCOPE
REPORT     PASS | ISSUES | BLOCKED (spec | premise | scope); `PASS (DESIGN deviation)` when it met ACCEPTANCE another way; branch, commit SHA (or dirty-diff hash), the commands actually run and their output, deviations
```

PR-owner exception (ADR 0020 decision 2, `docs/decisions/0020-orchestrate-and-autopilot.md`): a PR-owner agent that `orchestrate` or `autopilot` spawns may rebase and force-push only its own PR branch, with `--force-with-lease=<branch>:<sha>` pinned to the SHA it last pushed. A respawned owner, or one spawned onto an already-open PR, has pushed nothing yet: it pins the SHA the plan `## Log` records for that branch (for an already-open PR, the coordinator logs its head SHA at spawn), only after `git ls-remote` shows that SHA as the remote head; otherwise it logs `blocked` and does not push. An already-open PR whose latest push did not come from an agent of this run is taken over only on the owner's go, so no owner force-pushes over a person still working on that branch. The PR owner's brief states this exception under FORBIDDEN; every other brief keeps FORBIDDEN as written. No worker merges, PR owners included.

Size it to the task: a one-command task collapses the template to a paragraph that still names goal, scope, check and report. Shared exploration runs once into a scratch file outside the repo, and briefs point at it.

## Fan out

Spawn the whole wave in one message, in the background, each with its own worktree. Never resume a worker to check on it; read its branch, `git status`, or the task list. A worker that will not be reused is stopped, and its stop confirmed.

## Aggregate

1. A report is a claim: reject it unless it names the tested source and the acceptance output. A `BLOCKED` report is a request, not a rejected result, and costs no retry; answer its reason first: `spec` → settle it with the owner (`grill`), unless it names a missing VERIFY or ACCEPTANCE line, which is your brief gap: fill it and re-brief; `premise` → weigh the evidence, then re-brief or keep the DESIGN with your reason; `scope` → widen SCOPE, route the file to its owner, or hold it until after the merge. A `PASS (DESIGN deviation)` is a result, judged like any other against GOAL and ACCEPTANCE, never against the DESIGN. An intent the DESIGN carried but the GOAL left out is a brief gap, not a failed result: write it into the GOAL and re-brief; that costs no retry. Free re-briefs stop at two per unit: a third `BLOCKED` or brief gap on the same unit goes to the owner.
2. Accept only after checking that source, its diff against SCOPE, and its acceptance check yourself. Inspect a worker tree with `git -C <worktree>` or a subshell `(cd <worktree> && …)` so your shell stays in the main checkout.
3. A rejected or missing result gets a retry chosen by cause, at most 2 per unit, each logged with its cause:
   - context limit → a fresh worker with a smaller scope;
   - dropped connection, or no report and no visible cause → the same brief, once;
   - tool error → a different model;
   - rejected result (wrong output) → a fresh worker with consolidated scope (the original brief, later directives, the prior report and branch), one rung up the ladder:
     1. no real check behind the result (no test, build or repro output) → add one to VERIFY and keep the agent;
     2. the same agent at `effort: high`;
     3. the next model at its default effort (`worker` → `engineer` → `engineer` with `model: fable`). Past `high`, change the model, not the effort.

     Start each unit on its role's default effort; raise effort only after a failed check, not up front. A result that guessed at an open spec is not a rung: return to the owner instead. The same symptom after a retry stops the climb: find the mechanism behind both failures (re-read the path, re-frame the brief) before the next rung; a stronger model on the same framing only patches the symptom again.

   After the second failed retry → log `blocked` and plan around it; a gap never counts as a pass.
4. Race: apply the rule declared up front. For a design bakeoff, score each candidate against a 3–6 point rubric, ask a cross-family judge for its pick, choose one base, and graft the best part of each loser by hand; wild divergence means the brief was under-specified, so reframe and re-run rather than averaging.

## Integrate

The target is the main checkout the session started in, addressed by absolute path. A host notice that your shell moved into a worker worktree changes neither that target nor the wave: integrate there and continue.

An accepted result is not yet `done`: log a worker task's `done` only after its output is in the main checkout and the combined tree passes step 3.

1. Merge accepted branches one at a time; resolve conflicts against the plan, never by taking one side blindly. A worker that left its change uncommitted → bring over exactly its SCOPE paths, new files included, by absolute path.
2. Edit the held shared files once, after the merges.
3. Review the shared interfaces, then run the full phase check on the combined tree.
4. `high-risk` phases: a verifier on a different model family from the workers (or the same family when the session's `advisorModel` is `fable`) reviews the combined diff before the gate.
5. Each `done` names the worker's model, branch and commit SHA, and the combined tree it passed on. Removing worker worktrees and branches is a delete: do it only with the owner's approval.
