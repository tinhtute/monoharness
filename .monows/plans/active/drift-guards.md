---
status: active
lane: normal
---
# Drift guards: plan-vs-git at pickup, pushed-migration guard at write

## Goal
- outcome: two event-triggered guards cover what a standing Supervisor would catch on multi-repo, multi-day runs: (a) at session pickup, the Lead is told when the active plan's claims (branch, commit status, Current State) disagree with git; (b) before a write lands, the Lead is warned or stopped when it edits a versioned migration that already exists on the upstream ref
- success_signal: in fixture repositories built by a test script in this repo, guard (a) flags a plan whose Current State says "not committed" on branch `feat/x` while git holds commits on `feat/x-v2`, guard (b) flags an edit to a migration file that already exists on the upstream ref, and both stay silent on a clean fixture (pending owner confirmation)
- actors: the owner; the main agent as Lead; consumer repos that install the harness skills
- authority: owner choice 2026-11-13 ("Two drift guards"); feedback from a peer multi-repo, multi-day session 2026-11-13 (self-reported, not yet verified against its transcript); `skills/poteto/playbooks/session-pickup.md`; AGENTS.md § Harness (`zharness` only installs, updates, and uninstalls); audit `docs/research/2026-11-12-supervisor-lead-peer-audit.md`; `.monows/plans/completed/supervisor-lead-peer.md` NG2
- requirements: none until the map is decided
- non-goals:
  - NG1: a standing Supervisor session (peer: not worth it for this workload; NG2 of supervisor-lead-peer stays)
  - NG2: a cross-session view (two sessions writing the same table, a merge request's state changed under a push); one finding so far, revisit after more evidence
  - NG3: matching recorded owner decisions at write time; in the peer session the owner's "no" came after the unrequested writes, so a matcher would not have prevented them

## Map
- Q1: Where must the guards run: only in this repository, in consumer repositories through the installed skills, or also through Claude Code hooks shipped from the monoclaudian repo (cross-repo work)? A `zharness` subcommand conflicts with AGENTS.md § Harness and would need an ADR | type: grill | by: HITL | blocked_by: none | status: open
- Q2: Which plan claims can be checked against git mechanically today (Current State branch and lifecycle, Log SHAs, "not committed" prose), and what does `session-pickup` step 2 and `watzup` already reconcile? | type: research | by: AFK | blocked_by: none | status: open
- Q7: Collect the multi-repo, multi-day sessions to replay beyond the one peer session: their session ids and repos, kept outside this public repository | type: task | by: HITL | blocked_by: none | status: open
- Q3: Did the peer session and the sessions from Q7 run `session-pickup` or any harness playbook at their start, under which plan layout (the peer's plan lived under `.harness/`, not `.monows/`), and how often did a plan claim contradict git before a wrong write? Read each transcript with `session-digest.py`, not a session's own account | type: research | by: AFK | blocked_by: Q7 | status: open
- Q4: What form does guard (a) take: a script-backed reconcile step in `session-pickup.md`, or a SessionStart hook shipped from monoclaudian? | type: grill | by: HITL | blocked_by: Q1, Q2, Q3 | status: open
- Q5: Is "the path matches a declared immutable glob and the file exists on the upstream ref" enough to detect a pushed versioned migration, and is the APPEND-ONLY guard in `scripts/install-git-hooks.sh` a reusable precedent? | type: research | by: AFK | blocked_by: none | status: open
- Q6: What form and strength does guard (b) take: a pre-commit guard or a PreToolUse hook (monoclaudian), warn or block, and where is the immutable glob declared? | type: grill | by: HITL | blocked_by: Q1, Q5 | status: open
- fog: unrequested scope (an index and a new migration file the owner never asked for) was the real failure behind the owner's walk-backs in the peer session; no guard here covers it
- fog: self-acceptance on build and lint with no tests in the peer session; it may belong to the existing `check` gate, not these guards

## Phases and Verification
- approach: not-planned

## Log
- 2026-11-13T07:48Z — map — decision — owner: keep the map, do not resolve it yet; collect more multi-repo, multi-day sessions first (Q7). `brainstorm lock` stays blocked until every Q line is decided. Research bar for Q2, Q3, Q5 (ambition depth lens, lint ok): measure the base rate of plan-vs-git drift by replaying `.monows/plans/completed/*.md` Current State against git at every commit that touched them, plus the Q7 transcripts via `session-digest.py`; assumption to refute: at least 3 contradicted claims, and no pickup reconcile ran before the first wrong write; fewer than 3, or pickup did run → guard (a) is the wrong fix and the gap is invocation; judge: counts with path:line or SHA evidence, and a fixture script (drifting repo, pushed-migration repo, clean repo, built under `mktemp -d` as in `scripts/ci/test-guards.sh`) that exits 0 with each rule and non-zero under each rule's mutation; fail: a decision resting on a session's self-report, an asserted count, or a rule surviving its mutation; target: zero false positives over the completed plans

## Validation

## Current State and Next Action
- active_phase: none
- lifecycle_status: planned
- blockers: Q7, the owner is collecting more multi-repo, multi-day sessions
- open_items: 9 map lines
- exact_next_action: owner finishes Q7, then `wayfinder` fans out Q2, Q3, Q5 to sub-agents under the 07:48Z Log research bar
