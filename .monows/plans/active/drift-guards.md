---
status: active
lane: normal
---
# Drift guards: plan-vs-git at pickup, pushed-migration guard at write

## Goal
- outcome: two event-triggered guards cover what a standing Supervisor would catch on multi-repo, multi-day runs: (a) at session pickup, the Lead is told when the active plan's claims (branch, commit status, Current State) disagree with git; (b) before a write lands, the Lead is warned or stopped when it edits a versioned migration that already exists on the upstream ref
- success_signal: in fixture repositories built by a test script in this repo, guard (a) flags a plan whose Current State says "not committed" on branch `feat/x` while git holds commits on `feat/x-v2`, guard (b) flags an edit to a migration file that already exists on the upstream ref, and both stay silent on a clean fixture; every flag carries its proof (the plan's path:line and the git ref and SHA it contradicts)
- actors: the owner; the main agent as Lead; consumer repos that install the harness skills
- authority: owner choice 2026-11-13 ("Two drift guards"); feedback from a peer multi-repo, multi-day session 2026-11-13 (self-reported, not yet verified against its transcript); `skills/poteto/playbooks/session-pickup.md`; AGENTS.md § Harness (`zharness` only installs, updates, and uninstalls); audit `docs/research/2026-11-12-supervisor-lead-peer-audit.md`; `.monows/plans/completed/supervisor-lead-peer.md` NG2
- requirements: none until the map is decided
- non-goals:
  - NG1: a standing Supervisor session (peer: not worth it for this workload; NG2 of supervisor-lead-peer stays)
  - NG2: a cross-session view (concurrent sessions changing shared state); one self-reported case so far, revisit after more evidence
  - NG3: matching recorded owner decisions at write time; in the one reported case the owner's objection came after the writes, so a matcher would not have prevented them
  - NG4: the legacy `docs/` and `.harness/` plan layouts; the guards read only `.monows/`, with no compatibility shim, and a repo on an old layout migrates with `zharness update` (v0.37.0 or later) first (owner 2026-11-13: breaking change)

## Map
- Q1: Where must the guards run: only in this repository, in consumer repositories through the installed skills, or also through Claude Code hooks shipped from the monoclaudian repo (cross-repo work)? A `zharness` subcommand conflicts with AGENTS.md § Harness and would need an ADR | type: grill | by: HITL | blocked_by: none | status: decided → this repo and consumer repos through the installed skills, plus Claude Code hooks shipped from monoclaudian; no `zharness` subcommand | evidence: user 2026-11-13
- Q2: Which plan claims can be checked against git mechanically today (Current State branch and lifecycle, Log SHAs, "not committed" prose), and what does `session-pickup` step 2 and `watzup` already reconcile? For each claim, can the state be recomputed from git (refs, `git log`, merge-base) and compared, rather than parsed from the plan's prose? | type: research | by: AFK | blocked_by: none | status: open
- Q7: Collect the multi-repo, multi-day sessions to replay beyond the one peer session: their session ids and repos, kept outside this public repository. Done when at least 5 sessions across at least 2 repos are listed, each running at least 2 days with a plan file | type: task | by: HITL | blocked_by: none | status: open
- Q3: Did the peer session and the sessions from Q7 run `session-pickup` or any harness playbook at their start, on which plan layout, and how often did a plan claim contradict git before a wrong write? Read each transcript with `session-digest.py`, not a session's own account | type: research | by: AFK | blocked_by: Q7 | status: open
- Q4: What form does guard (a) take: a script-backed reconcile step in `session-pickup.md`, or a SessionStart hook shipped from monoclaudian? A step in the playbook is prose the Lead must remember to run, which is the invocation gap Q3 and Q8 measure; a hook runs without being asked. Name the level each form reaches on the ladder in `docs/guides/patterns/encoding-invariants.md` | type: grill | by: HITL | blocked_by: Q1, Q2, Q3 | status: open
- Q5: Is "the path matches a declared immutable glob and the file exists on the upstream ref" enough to detect a pushed versioned migration, and is the APPEND-ONLY guard in `scripts/install-git-hooks.sh` a reusable precedent? | type: research | by: AFK | blocked_by: none | status: open
- Q6: What form and strength does guard (b) take: a pre-commit guard or a PreToolUse hook (monoclaudian), warn or block, and where is the immutable glob declared, given that `encoding-invariants.md` § 1 requires an accepted authority in the consumer repo before a check exists? Which ladder level does each form reach: a pre-commit hook is an optional hook a consumer may never install, while the consumer CI template (`docs/guides/consumer-ci-guards.md`) reaches CI. Does reversibility set the strength (a migration already applied upstream cannot be undone by `git revert`, so block with an owner override; an unpushed one only warns)? | type: grill | by: HITL | blocked_by: Q1, Q5 | status: open
- Q8: Self-acceptance on build and lint with no tests in the peer session: did the peer and Q7 sessions run `check` or an independent `verifier` before accepting their own work, and were those skills installed in those repos? A missing install or a skipped invocation makes this an invocation gap, and `out-of-scope` with a non-goal is a valid answer | type: research | by: AFK | blocked_by: Q7 | status: open
- Q9: Unrequested scope (changes the owner never asked for) in the peer session: would the Plan check in `skills/stages/check/references/check-risk.md` (a diff doing what the plan or Goal did not set out to do) or acceptance criteria written before the work have caught it, and did either run there? `out-of-scope` with a non-goal is a valid answer | type: research | by: AFK | blocked_by: Q7 | status: open
- Q10: Who writes the fixtures and mutations for both guards: a separate checker agent before the guard exists, which the implementer cannot edit, or the implementer under `verifier` review? | type: grill | by: HITL | blocked_by: Q4, Q6 | status: open

## Phases and Verification
- approach: not-planned

## Log
- 2026-11-13T07:48Z — map — decision — owner: keep the map, do not resolve it yet; collect more multi-repo, multi-day sessions first (Q7). `brainstorm lock` stays blocked until every Q line is decided. Research bar for Q2, Q3, Q5 (ambition depth lens, lint ok): measure the base rate of plan-vs-git drift by replaying `.monows/plans/completed/*.md` Current State against git at every commit that touched them, plus the Q7 transcripts via `session-digest.py`; assumption to refute: at least 3 contradicted claims, and no pickup reconcile ran before the first wrong write; fewer than 3, or pickup did run → guard (a) is the wrong fix and the gap is invocation; judge: counts with path:line or SHA evidence, and a fixture script (drifting repo, pushed-migration repo, clean repo, built under `mktemp -d` as in `scripts/ci/test-guards.sh`) that exits 0 with each rule and non-zero under each rule's mutation; fail: a decision resting on a session's self-report, an asserted count, or a rule surviving its mutation; target: zero false positives over the completed plans
- 2026-11-13T09:29Z — map — decision — owner interview (the owner asked to resolve lines in this session, overriding wayfinder's one-HITL-per-session limit): Q1 decided (skills plus monoclaudian hooks); Q7 gets a done criterion (at least 5 sessions, at least 2 repos, each at least 2 days with a plan file); Q8 and Q9 stay in scope; success_signal confirmed. Q4, Q6, Q10 stay open until their research lands
- 2026-11-13T09:55Z — map — decision — owner: drop the legacy plan layouts as a breaking change (NG4); every repo still on an old layout migrates to `.monows/` with `zharness update`

## Validation

## Current State and Next Action
- active_phase: none
- lifecycle_status: planned
- blockers: Q7, the owner is collecting more multi-repo, multi-day sessions
- open_items: 9 map lines
- exact_next_action: owner finishes Q7, then `wayfinder` fans out Q2, Q3, Q5, Q8, Q9 to sub-agents under the 07:48Z Log research bar
